import Foundation
import AppKit

/// Connection state for display.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(String) // transport info string
}

/// Transport mode selection.
enum TransportMode: String, CaseIterable, Identifiable {
    case serial = "Serial"
    case ble = "BLE"

    var id: String { rawValue }
}

/// Main orchestrator — watches transcripts, manages transports, sends protocol messages.
/// Replaces PixelAgentsBridge.run() from the Python companion.
@MainActor
final class BridgeService: ObservableObject {

    /// Number of character slots shown in the UI (matches firmware workstation count).
    static let maxDisplaySlots = 6

    // MARK: - Published state for SwiftUI

    @Published var connectionState: ConnectionState = .disconnected
    @Published var displayAgents: [Agent] = (0..<maxDisplaySlots).map { Agent(id: UInt8($0), state: .offline) }
    @Published var usageStats: UsageStatsData?
    @Published var transportMode: TransportMode = .serial

    // MARK: - Sub-components

    let serialPortDetector = SerialPortDetector()
    let bleTransport = BLETransport()

    // MARK: - Private state

    private let tracker = AgentTracker()
    private let watcher = TranscriptWatcher()
    private var serialTransport = SerialTransport()
    private let usageFetcher = UsageStatsFetcher()

    private var activeTransport: TransportProtocol? {
        switch transportMode {
        case .serial: return serialTransport
        case .ble:    return bleTransport
        }
    }

    private var pollTimer: Timer?
    private var heartbeatTimer: Timer?
    private var usageTimer: Timer?
    private var usageFetchTimer: Timer?
    private var reconnectTimer: Timer?

    // Dedup state (reset on reconnect)
    private var lastStates: [String: (CharState, String)] = [:]
    private var lastUsageData: UsageStatsData?
    private var lastCount: Int = -1

    /// Selected serial port path (nil = auto-detect).
    @Published var selectedPort: String?
    /// Selected BLE device PIN.
    @Published var selectedBLEPin: UInt16?

    // MARK: - Timing constants (matching Python bridge)

    private let pollInterval: TimeInterval = 0.25       // 4 Hz
    private let heartbeatInterval: TimeInterval = 2.0
    private let usageInterval: TimeInterval = 10.0
    private let usageFetchInterval: TimeInterval = 900  // 15 min API poll
    private let staleTimeout: TimeInterval = 30.0
    private let reconnectInterval: TimeInterval = 2.0

    // MARK: - Lifecycle

    func start() {
        serialPortDetector.startMonitoring()
        watcher.startMonitoring { [weak self] in
            // FSEvents fired — next poll cycle will pick up changes
            _ = self
        }

        bleTransport.onDisconnect = { [weak self] in
            Task { @MainActor in
                self?.handleDisconnect()
            }
        }

        // Kick off initial API fetch for usage stats
        usageFetcher.fetchAndCache()

        startTimers()
        attemptConnect()
    }

    func stop() {
        stopTimers()
        activeTransport?.disconnect()
        serialPortDetector.stopMonitoring()
        watcher.stopMonitoring()
        connectionState = .disconnected
    }

    func setTransport(_ mode: TransportMode) {
        guard mode != transportMode else { return }
        manualDisconnect = false
        activeTransport?.disconnect()
        transportMode = mode
        resetSessionState()
        connectionState = .disconnected
        attemptConnect()
    }

    /// Take a screenshot (serial only).
    func requestScreenshot() {
        guard transportMode == .serial, serialTransport.isConnected else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            if let url = ScreenshotService.capture(via: self.serialTransport) {
                DispatchQueue.main.async {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }
        }
    }

    // MARK: - Connection management

    func connect() {
        manualDisconnect = false
        attemptConnect()
    }

    /// When true, suppress auto-reconnect so the user can pick a device manually.
    private var manualDisconnect = false

    func disconnect() {
        manualDisconnect = true
        if transportMode == .ble {
            bleTransport.disconnectKeepDevices()
        } else {
            activeTransport?.disconnect()
        }
        connectionState = .disconnected
    }

    private func attemptConnect() {
        guard !(activeTransport?.isConnected ?? false) else { return }
        guard !manualDisconnect else { return }

        switch transportMode {
        case .serial:
            connectionState = .connecting
            let port = selectedPort ?? serialPortDetector.availablePorts.first?.path
            guard let port = port else {
                connectionState = .disconnected
                return
            }
            if serialTransport.connect(port: port) {
                connectionState = .connected("Serial: \(port.components(separatedBy: "/").last ?? port)")
                resetSessionState()
            } else {
                connectionState = .disconnected
            }

        case .ble:
            if bleTransport.isConnected {
                let name = bleTransport.connectedDeviceName ?? "Device"
                connectionState = .connected("BLE: \(name)")
                resetSessionState()
                return
            }
            // If a manual connect is already in progress, don't overwrite .connecting
            if bleTransport.pendingPeripheralID != nil {
                connectionState = .connecting
                return
            }
            // reconnect() tries UUID-based reconnect first, then falls back to scanning
            if bleTransport.reconnect() {
                connectionState = .connecting
            } else {
                // Just scanning — show disconnected so user can pick a device
                connectionState = .disconnected
            }
        }
    }

    func connectBLEDevice(_ device: BLEDevice) {
        manualDisconnect = false
        selectedBLEPin = device.pin
        connectionState = .connecting
        bleTransport.connect(to: device)
    }

    private func handleDisconnect() {
        connectionState = .disconnected
        // Reconnect timer will handle retry
    }

    private func resetSessionState() {
        lastStates.removeAll()
        lastUsageData = nil
        lastCount = -1
    }

    // MARK: - Timers

    private func startTimers() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processTranscripts()
            }
        }

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendHeartbeat()
            }
        }

        usageTimer = Timer.scheduledTimer(withTimeInterval: usageInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUsageStats()
            }
        }

        usageFetchTimer = Timer.scheduledTimer(withTimeInterval: usageFetchInterval, repeats: true) { [weak self] _ in
            self?.usageFetcher.fetchAndCache()
        }

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !(self.activeTransport?.isConnected ?? false) {
                    self.attemptConnect()
                } else if case .connecting = self.connectionState {
                    // Update state if BLE connected asynchronously
                    if self.bleTransport.isConnected {
                        let name = self.bleTransport.connectedDeviceName ?? "Device"
                        self.connectionState = .connected("BLE: \(name)")
                        self.resetSessionState()
                    }
                }
            }
        }
    }

    private func stopTimers() {
        pollTimer?.invalidate()
        heartbeatTimer?.invalidate()
        usageTimer?.invalidate()
        usageFetchTimer?.invalidate()
        reconnectTimer?.invalidate()
        pollTimer = nil
        heartbeatTimer = nil
        usageTimer = nil
        usageFetchTimer = nil
        reconnectTimer = nil
    }

    // MARK: - Core logic

    private func sendHeartbeat() {
        guard let transport = activeTransport, transport.isConnected else { return }
        let msg = ProtocolBuilder.heartbeat()
        if !transport.send(msg) {
            handleDisconnect()
        }
    }

    private func checkUsageStats() {
        guard let transport = activeTransport, transport.isConnected else { return }

        guard let data = usageFetcher.currentStats() else { return }

        // Only send if changed
        if data != lastUsageData {
            let msg = ProtocolBuilder.usageStats(
                currentPct: data.currentPct,
                weeklyPct: data.weeklyPct,
                currentResetMin: data.currentResetMin,
                weeklyResetMin: data.weeklyResetMin
            )
            if transport.send(msg) {
                lastUsageData = data
                usageStats = data
            }
        }
    }

    private func processTranscripts() {
        guard let transport = activeTransport, transport.isConnected else { return }

        let transcripts = watcher.findActiveTranscripts()

        for (transcript, source) in transcripts {
            let key = transcript.path
            var agent = tracker.getOrCreate(key: key, source: source)

            // Update last seen
            tracker.update(key: key) { $0.lastSeen = Date() }

            // Read new lines
            let records = watcher.readNewLines(from: transcript)

            for record in records {
                agent = tracker.agents[key] ?? agent

                let result: (CharState, String)?
                switch source {
                case .codex:
                    result = CodexStateDeriver.derive(from: record, agent: &agent)
                case .claude:
                    result = StateDeriver.derive(from: record, agent: &agent)
                }

                if let (state, tool) = result {
                    // Write back all mutated agent fields
                    tracker.update(key: key) { a in
                        a.state = state
                        a.toolName = tool
                        a.hadToolInTurn = agent.hadToolInTurn
                        a.activeTools = agent.activeTools
                    }

                    if lastStates[key]?.0 != state || lastStates[key]?.1 != tool {
                        let msg = ProtocolBuilder.agentUpdate(id: agent.id, state: state, tool: tool)
                        if transport.send(msg) {
                            lastStates[key] = (state, tool)
                        }
                    }
                } else {
                    // Write back hadToolInTurn/activeTools even when no state change
                    tracker.update(key: key) { a in
                        a.hadToolInTurn = agent.hadToolInTurn
                        a.activeTools = agent.activeTools
                    }
                }
            }
        }

        // Prune stale agents
        let pruned = tracker.pruneStale(timeout: staleTimeout)
        for agent in pruned {
            let msg = ProtocolBuilder.agentUpdate(id: agent.id, state: .offline)
            _ = transport.send(msg)
        }
        // Clean up lastStates for pruned keys
        let activeKeys = Set(tracker.agents.keys)
        lastStates = lastStates.filter { activeKeys.contains($0.key) }

        // Send agent count if changed
        let count = tracker.count
        if count != lastCount {
            let msg = ProtocolBuilder.agentCount(UInt8(min(count, 255)))
            if transport.send(msg) {
                lastCount = count
            }
        }

        // Update published agents for UI — always show maxDisplaySlots slots.
        // Use slot index as the Identifiable id to avoid duplicates in ForEach.
        let active = tracker.sortedAgents
        displayAgents = (0..<Self.maxDisplaySlots).map { i in
            if i < active.count {
                return Agent(id: UInt8(i), state: active[i].state, toolName: active[i].toolName, source: active[i].source)
            } else {
                return Agent(id: UInt8(i), state: .offline)
            }
        }
    }

    // MARK: - Sleep/Wake

    func handleSleep() {
        stopTimers()
    }

    func handleWake() {
        startTimers()
        if !(activeTransport?.isConnected ?? false) {
            attemptConnect()
        }
    }
}

