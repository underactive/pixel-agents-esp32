import Foundation
import AppKit

/// UserDefaults keys for @AppStorage settings, shared across views and AppDelegate.
enum SettingsKeys {
    static let showClaudeUsage = "showClaudeUsage"
    static let showCodexUsage = "showCodexUsage"
    static let showAgentCount = "showAgentCount"
    static let showRemaining = "showRemaining"
    static let showGeminiUsage = "showGeminiUsage"
    static let showCursorUsage = "showCursorUsage"
}

/// Connection state for display.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(String) // transport info string
}

/// Display mode: hardware (physical device) or software (local rendering).
enum DisplayMode: String, CaseIterable, Identifiable {
    case hardware = "ESP32 Device"
    case software = "Software"

    var id: String { rawValue }
}

/// Transport mode selection (hardware transports only).
enum TransportMode: String, CaseIterable, Identifiable {
    case serial = "USB"
    case ble = "Bluetooth"

    var id: String { rawValue }
}

/// Main orchestrator — watches transcripts, manages transports, sends protocol messages.
/// Replaces PixelAgentsBridge.run() from the Python companion.
@MainActor
final class BridgeService: ObservableObject {

    /// Number of character slots shown in the UI (matches firmware workstation count).
    static let maxDisplaySlots = 6

    // MARK: - Actions (set by AppDelegate)

    var onOpenSettings: (() -> Void)?

    // MARK: - Published state for SwiftUI

    @Published var connectionState: ConnectionState = .disconnected
    @Published var displayAgents: [Agent] = (0..<maxDisplaySlots).map { Agent(id: UInt8($0), state: .offline) }
    @Published var usageStats: UsageStatsData?
    @Published var codexUsageStats: UsageStatsData?
    @Published var geminiUsageStats: UsageStatsData?
    @Published var cursorUsageStats: UsageStatsData?
    @Published var displayMode: DisplayMode = .hardware
    @Published var transportMode: TransportMode = .serial

    // MARK: - Device settings (synced from ESP32)

    @Published var deviceDogEnabled: Bool = true
    @Published var deviceDogColor: UInt8 = 1  // BROWN
    @Published var deviceScreenFlip: Bool = false
    @Published var deviceSoundEnabled: Bool = false
    @Published var deviceDogBarkEnabled: Bool = true
    @Published var deviceSettingsReceived: Bool = false

    // MARK: - Office scene (software display + PIP)

    let officeScene = OfficeScene()
    let officeRenderer = OfficeRenderer()
    @Published var officeFrame: CGImage?
    @Published var isPIPShown = false
    lazy var pipController = PIPWindowController(bridge: self)
    private var sceneTimer: Timer?
    private var lastSceneDate: Date?

    // MARK: - Sub-components

    let serialPortDetector = SerialPortDetector()
    let bleTransport = BLETransport()

    // MARK: - Private state

    private let tracker = AgentTracker()
    private let watcher = TranscriptWatcher()
    private var serialTransport = SerialTransport()
    private let usageFetcher = UsageStatsFetcher()
    private let codexUsageFetcher = CodexUsageFetcher()
    private let geminiUsageFetcher = GeminiUsageFetcher()
    private let cursorUsageFetcher = CursorUsageFetcher()

    private var activeTransport: TransportProtocol? {
        switch transportMode {
        case .serial: return serialTransport
        case .ble:    return bleTransport
        }
    }

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

    private let heartbeatInterval: TimeInterval = 2.0
    private let usageInterval: TimeInterval = 10.0
    private let usageFetchInterval: TimeInterval = 900  // 15 min API poll
    private let staleTimeout: TimeInterval = 30.0
    private let reconnectInterval: TimeInterval = 2.0

    // MARK: - Lifecycle

    func start() {
        serialPortDetector.startMonitoring()
        watcher.startMonitoring { [weak self] in
            Task { @MainActor in
                self?.processTranscripts()
            }
        }

        bleTransport.onDisconnect = { [weak self] in
            Task { @MainActor in
                self?.handleDisconnect()
            }
        }

        // Wire device-to-companion settings state callbacks
        serialTransport.onSettingsState = { [weak self] payload in
            self?.handleSettingsState(payload)
        }
        bleTransport.onSettingsState = { [weak self] payload in
            self?.handleSettingsState(payload)
        }

        // Kick off initial API fetch for usage stats
        usageFetcher.fetchAndCache()
        codexUsageFetcher.fetchAndCache()
        geminiUsageFetcher.fetchAndCache()
        cursorUsageFetcher.fetchAndCache()

        startTimers()
        updateSceneTimerState()
        attemptConnect()
    }

    func stop() {
        stopTimers()
        stopSceneTimer()
        pipController.close()
        activeTransport?.disconnect()
        serialPortDetector.stopMonitoring()
        watcher.stopMonitoring()
        connectionState = .disconnected
    }

    func setDisplayMode(_ mode: DisplayMode) {
        guard mode != displayMode else { return }
        displayMode = mode
        if mode == .software {
            // Disconnect hardware, enter software display
            activeTransport?.disconnect()
            connectionState = .connected("Software Display")
            resetSessionState()
        } else {
            // Switch back to hardware — reconnect
            connectionState = .disconnected
            attemptConnect()
        }
        updateSceneTimerState()
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

        // Capture local reference before dispatching to background thread
        // to avoid accessing @MainActor-isolated property off the main actor.
        let transport = serialTransport
        DispatchQueue.global(qos: .userInitiated).async {
            if let url = ScreenshotService.capture(via: transport) {
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
        if displayMode == .software {
            connectionState = .connected("Software Display")
            return
        }
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
        officeScene.resetAppliedStates()
        deviceSettingsReceived = false
    }

    // MARK: - Timers

    private func startTimers() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendHeartbeat()
                self?.pruneAndUpdateDisplay()
            }
        }

        usageTimer = Timer.scheduledTimer(withTimeInterval: usageInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUsageStats()
            }
        }

        usageFetchTimer = Timer.scheduledTimer(withTimeInterval: usageFetchInterval, repeats: true) { [weak self] _ in
            self?.usageFetcher.fetchAndCache()
            self?.codexUsageFetcher.fetchAndCache()
            self?.geminiUsageFetcher.fetchAndCache()
            self?.cursorUsageFetcher.fetchAndCache()
        }

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.displayMode == .software { return }
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
        heartbeatTimer?.invalidate()
        usageTimer?.invalidate()
        usageFetchTimer?.invalidate()
        reconnectTimer?.invalidate()
        heartbeatTimer = nil
        usageTimer = nil
        usageFetchTimer = nil
        reconnectTimer = nil
    }

    // MARK: - Core logic

    private func sendHeartbeat() {
        if displayMode == .software { return }
        guard let transport = activeTransport, transport.isConnected else { return }
        let msg = ProtocolBuilder.heartbeat()
        if !transport.send(msg) {
            handleDisconnect()
        }
    }

    private func checkUsageStats() {
        let isSoftware = displayMode == .software

        // Update Codex usage stats for UI (always, not sent to hardware)
        let codexData = codexUsageFetcher.currentStats()
        if codexData != codexUsageStats {
            codexUsageStats = codexData
        }

        // Update Gemini usage stats for UI (always, not sent to hardware)
        let geminiData = geminiUsageFetcher.currentStats()
        if geminiData != geminiUsageStats {
            geminiUsageStats = geminiData
        }

        // Update Cursor usage stats for UI (always, not sent to hardware)
        let cursorData = cursorUsageFetcher.currentStats()
        if cursorData != cursorUsageStats {
            cursorUsageStats = cursorData
        }

        // Claude usage: requires transport connection in hardware mode
        if !isSoftware {
            guard let transport = activeTransport, transport.isConnected else { return }
            _ = transport
        }

        guard let data = usageFetcher.currentStats() else { return }

        // Only update if changed
        if data != lastUsageData {
            lastUsageData = data
            usageStats = data
            // Send to hardware (skip in software mode)
            if !isSoftware, let transport = activeTransport {
                let msg = ProtocolBuilder.usageStats(
                    currentPct: data.currentPct,
                    weeklyPct: data.weeklyPct,
                    currentResetMin: data.currentResetMin,
                    weeklyResetMin: data.weeklyResetMin
                )
                _ = transport.send(msg)
            }
        }
    }

    private func processTranscripts() {
        let isSoftware = displayMode == .software
        if !isSoftware {
            guard let transport = activeTransport, transport.isConnected else { return }
            _ = transport  // suppress unused warning; used below
        }

        let transcripts = watcher.findActiveTranscripts()

        for (transcript, source) in transcripts {
            let key = transcript.path
            var agent = tracker.getOrCreate(key: key, source: source)

            // Update last seen
            tracker.update(key: key) { $0.lastSeen = Date() }

            // Read new records (JSONL for most sources, JSON for Gemini)
            let records: [[String: Any]]
            if source == .gemini {
                records = watcher.readNewGeminiMessages(from: transcript)
            } else {
                records = watcher.readNewLines(from: transcript)
            }

            for record in records {
                agent = tracker.agents[key] ?? agent

                let result: (CharState, String)?
                switch source {
                case .codex:
                    result = CodexStateDeriver.derive(from: record, agent: &agent)
                case .claude:
                    result = StateDeriver.derive(from: record, agent: &agent)
                case .gemini:
                    result = GeminiStateDeriver.derive(from: record, agent: &agent)
                case .cursor:
                    result = CursorStateDeriver.derive(from: record, agent: &agent)
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
                        lastStates[key] = (state, tool)
                        // Send protocol message to hardware (skip in software mode)
                        if !isSoftware, let transport = activeTransport {
                            let msg = ProtocolBuilder.agentUpdate(id: agent.id, state: state, tool: tool)
                            _ = transport.send(msg)
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

        pruneAndUpdateDisplay()
    }

    /// Prune stale agents, send count updates, and refresh the published display array.
    /// Called from both FSEvents-driven processTranscripts() and the periodic heartbeat timer.
    private func pruneAndUpdateDisplay() {
        let isSoftware = displayMode == .software
        let transportConnected = activeTransport?.isConnected ?? false

        if isSoftware || transportConnected {
            // Prune stale agents
            let pruned = tracker.pruneStale(timeout: staleTimeout)
            for agent in pruned {
                if !isSoftware, let transport = activeTransport {
                    let msg = ProtocolBuilder.agentUpdate(id: agent.id, state: .offline)
                    _ = transport.send(msg)
                }
            }
            // Clean up lastStates for pruned keys
            let activeKeys = Set(tracker.agents.keys)
            lastStates = lastStates.filter { activeKeys.contains($0.key) }

            // Send agent count if changed
            let count = tracker.count
            if count != lastCount {
                lastCount = count
                if !isSoftware, let transport = activeTransport {
                    let msg = ProtocolBuilder.agentCount(UInt8(min(count, 255)))
                    _ = transport.send(msg)
                }
            }
        }

        // Update published agents for UI — only if changed to prevent unnecessary SwiftUI redraws.
        let active = tracker.sortedAgents
        let newAgents = (0..<Self.maxDisplaySlots).map { i in
            if i < active.count {
                return Agent(id: UInt8(i), state: active[i].state, toolName: active[i].toolName, source: active[i].source)
            } else {
                return Agent(id: UInt8(i), state: .offline)
            }
        }
        if newAgents != displayAgents {
            displayAgents = newAgents
        }
    }

    // MARK: - Device Settings

    func setDeviceDogEnabled(_ enabled: Bool) {
        deviceDogEnabled = enabled
        sendDeviceSettings()
    }

    func setDeviceDogColor(_ color: UInt8) {
        deviceDogColor = min(color, 3)
        sendDeviceSettings()
    }

    func setDeviceScreenFlip(_ flipped: Bool) {
        deviceScreenFlip = flipped
        sendDeviceSettings()
    }

    func setDeviceSoundEnabled(_ enabled: Bool) {
        deviceSoundEnabled = enabled
        sendDeviceSettings()
    }

    func setDeviceDogBarkEnabled(_ enabled: Bool) {
        deviceDogBarkEnabled = enabled
        sendDeviceSettings()
    }

    private func sendDeviceSettings() {
        guard displayMode == .hardware,
              let transport = activeTransport, transport.isConnected else { return }
        let msg = ProtocolBuilder.deviceSettings(
            dogEnabled: deviceDogEnabled,
            dogColor: deviceDogColor,
            screenFlip: deviceScreenFlip,
            soundEnabled: deviceSoundEnabled,
            dogBarkEnabled: deviceDogBarkEnabled
        )
        _ = transport.send(msg)
    }

    private func handleSettingsState(_ payload: Data) {
        guard payload.count >= 5 else { return }
        Task { @MainActor in
            self.deviceDogEnabled = payload[0] != 0
            self.deviceDogColor = min(payload[1], 3)
            self.deviceScreenFlip = payload[2] != 0
            self.deviceSoundEnabled = payload[3] != 0
            self.deviceDogBarkEnabled = payload[4] != 0
            self.deviceSettingsReceived = true
        }
    }

    // MARK: - PIP

    func togglePIP() {
        isPIPShown.toggle()
        if isPIPShown {
            pipController.show()
        } else {
            pipController.close()
        }
        updateSceneTimerState()
    }

    // MARK: - Scene Timer

    /// Called by PIPWindowController when the window closes via the OS close button.
    func sceneTimerNeedsUpdate() {
        updateSceneTimerState()
    }

    /// Starts/stops the 15 FPS scene timer based on whether the office scene is needed.
    private func updateSceneTimerState() {
        let needsScene = displayMode == .software || isPIPShown
        if needsScene && sceneTimer == nil {
            startSceneTimer()
        } else if !needsScene && sceneTimer != nil {
            stopSceneTimer()
        }
    }

    private func startSceneTimer() {
        lastSceneDate = Date()
        sceneTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickScene()
            }
        }
    }

    private func stopSceneTimer() {
        sceneTimer?.invalidate()
        sceneTimer = nil
        lastSceneDate = nil
    }

    private func tickScene() {
        let now = Date()
        let dt: Float
        if let last = lastSceneDate {
            dt = min(Float(now.timeIntervalSince(last)), 0.2)
        } else {
            dt = 1.0 / 15.0
        }
        lastSceneDate = now

        officeScene.applyAgentStates(displayAgents)
        officeScene.update(dt: dt)
        officeFrame = officeRenderer.render(scene: officeScene)
    }

    // MARK: - Sleep/Wake

    func handleSleep() {
        stopTimers()
        stopSceneTimer()
    }

    func handleWake() {
        startTimers()
        updateSceneTimerState()
        if !(activeTransport?.isConnected ?? false) {
            attemptConnect()
        }
    }
}

