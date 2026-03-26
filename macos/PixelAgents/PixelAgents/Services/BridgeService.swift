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
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
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
    @Published var cursorHeatmapData: CursorHeatmapData?
    @Published var claudeHeatmapData: ActivityHeatmapData?
    @Published var codexHeatmapData: ActivityHeatmapData?
    @Published var geminiHeatmapData: ActivityHeatmapData?
    /// True once the initial cookie check is done and no session was found.
    @Published var cursorNeedsDashboardAuth: Bool = false
    @Published var displayMode: DisplayMode = .hardware
    @Published var transportMode: TransportMode = .serial

    // MARK: - Device settings (synced from ESP32)

    @Published var deviceDogEnabled: Bool = true
    @Published var deviceDogColor: UInt8 = 1  // BROWN
    @Published var deviceScreenFlip: Bool = false
    @Published var deviceSoundEnabled: Bool = false
    @Published var deviceDogBarkEnabled: Bool = true
    @Published var deviceSettingsReceived: Bool = false
    /// Device identification state: nil = waiting, true = confirmed Pixel Agents, false = timed out.
    @Published var deviceIdentified: Bool? = nil

    // MARK: - Office scene (software display + PIP)

    let officeScene = OfficeScene()
    let officeRenderer = OfficeRenderer()
    @Published var officeFrame: CGImage?
    @Published var isPIPShown = false
    private(set) var isPopoverVisible = false
    lazy var pipController = PIPWindowController(bridge: self)
    private var sceneTimer: Timer?
    private var lastSceneDate: Date?
    private var sceneTimerInterval: TimeInterval = 0

    /// Whether anything is currently displaying the rendered office scene.
    private var isSceneVisible: Bool { isPopoverVisible || isPIPShown }

    private let foregroundTickInterval: TimeInterval = 1.0 / 15.0
    private let backgroundTickInterval: TimeInterval = 1.0 / 4.0

    // Dirty-frame detection: skip re-rendering when nothing visual changed.
    // NOTE: Update CharVis/PetVis if new visual properties are added to the scene.
    private var lastFingerprint: SceneFingerprint?
    private var lastRenderedFrame: CGImage?

    // MARK: - Sub-components

    let serialPortDetector = SerialPortDetector()
    let bleTransport = BLETransport()

    // MARK: - Auth & Private state

    let claudeAuth = ClaudeAuthService()

    private let tracker = AgentTracker()
    private let watcher = TranscriptWatcher()
    private var serialTransport = SerialTransport()
    private let usageFetcher = UsageStatsFetcher()
    private let codexUsageFetcher = CodexUsageFetcher()
    private let geminiUsageFetcher = GeminiUsageFetcher()
    private let cursorUsageFetcher = CursorUsageFetcher()
    private lazy var activitySyncService = ActivitySyncService(database: ActivityDatabase.shared)

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
    private var identifyTimer: Timer?

    // Dedup state (reset on reconnect)
    private var lastStates: [String: (CharState, String)] = [:]
    private var lastUsageData: UsageStatsData?
    private var lastCount: Int = -1
    /// Dirty flag for local activity heatmaps — reload from DB on next checkUsageStats().
    private var activityHeatmapDirty = true

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
    private let identifyTimeout: TimeInterval = 4.0

    /// Toggle iCloud sync on or off at runtime.
    func setICloudSyncEnabled(_ enabled: Bool) {
        if enabled {
            activitySyncService.start()
            activitySyncService.markNeedsExport()
        } else {
            activitySyncService.stop()
        }
    }

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
            Task { @MainActor in
                self?.handleSettingsState(payload)
            }
        }
        bleTransport.onSettingsState = { [weak self] payload in
            Task { @MainActor in
                self?.handleSettingsState(payload)
            }
        }

        // Wire device identification callbacks
        serialTransport.onIdentifyResponse = { [weak self] payload in
            Task { @MainActor in
                self?.handleIdentifyResponse(payload)
            }
        }
        bleTransport.onIdentifyResponse = { [weak self] payload in
            Task { @MainActor in
                self?.handleIdentifyResponse(payload)
            }
        }

        // Wire auth service and bootstrap token from app Keychain (no system dialog)
        usageFetcher.authService = claudeAuth
        claudeAuth.bootstrap()

        // Load local activity heatmaps from DB (shows historical data immediately)
        claudeHeatmapData = ActivityDatabase.shared.loadHeatmapData(provider: TranscriptSource.claude.heatmapKey!)
        codexHeatmapData = ActivityDatabase.shared.loadHeatmapData(provider: TranscriptSource.codex.heatmapKey!)
        geminiHeatmapData = ActivityDatabase.shared.loadHeatmapData(provider: TranscriptSource.gemini.heatmapKey!)
        activityHeatmapDirty = false

        // Start iCloud sync if enabled (degrades gracefully if iCloud unavailable)
        activitySyncService.onRemoteDataMerged = { [weak self] in
            self?.activityHeatmapDirty = true
        }
        if UserDefaults.standard.bool(forKey: SettingsKeys.iCloudSyncEnabled) {
            activitySyncService.start()
        }

        // Kick off initial API fetch for usage stats
        usageFetcher.fetchAndCache()
        codexUsageFetcher.fetchAndCache()
        geminiUsageFetcher.fetchAndCache()
        cursorUsageFetcher.fetchAndCache()
        // Wire immediate heatmap update callback (bypasses 10s usage timer)
        cursorUsageFetcher.onHeatmapUpdate = { [weak self] data in
            self?.cursorHeatmapData = data
            self?.cursorNeedsDashboardAuth = false
        }
        // Try to restore cursor.com dashboard session and fetch heatmap.
        let hadPreviousAuth = cursorUsageFetcher.dashboardAuth.checkExistingSession()
        if hadPreviousAuth {
            cursorUsageFetcher.fetchAnalytics()
        } else {
            // Try force-fetch in case HTTPCookieStorage has persisted cookies
            cursorUsageFetcher.fetchAnalytics(force: true)
            // Show connect button only if no previous auth (will be cleared if fetch succeeds)
            cursorNeedsDashboardAuth = true
        }

        startTimers()
        updateSceneTimerState()
        attemptConnect()
    }

    func stop() {
        stopTimers()
        identifyTimer?.invalidate()
        identifyTimer = nil
        stopSceneTimer()
        pipController.close()
        activeTransport?.disconnect()
        serialPortDetector.stopMonitoring()
        watcher.stopMonitoring()
        connectionState = .disconnected
    }

    /// Open the Cursor dashboard auth window and fetch heatmap on success.
    func authenticateCursorDashboard() {
        cursorUsageFetcher.dashboardAuth.authenticate { [weak self] success in
            if success {
                self?.cursorNeedsDashboardAuth = false
                self?.cursorUsageFetcher.fetchAnalytics()
            }
        }
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
        identifyTimer?.invalidate()
        identifyTimer = nil
        deviceIdentified = nil
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
                _ = serialTransport.send(ProtocolBuilder.identifyRequest())
                startIdentifyTimer()
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
        identifyTimer?.invalidate()
        identifyTimer = nil
        deviceIdentified = nil
        connectionState = .disconnected
        // Reconnect timer will handle retry
    }

    private func resetSessionState() {
        lastStates.removeAll()
        lastUsageData = nil
        lastCount = -1
        officeScene.resetAppliedStates()
        deviceSettingsReceived = false
        deviceIdentified = nil
        identifyTimer?.invalidate()
        identifyTimer = nil
        lastFingerprint = nil
        lastRenderedFrame = nil
    }

    // MARK: - Timers

    // Timer callbacks use MainActor.assumeIsolated because Timer.scheduledTimer on
    // RunLoop.main always fires on the main thread, which IS the MainActor. This avoids
    // the overhead of creating a new Task on every tick.
    private func startTimers() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sendHeartbeat()
                self?.pruneAndUpdateDisplay()
            }
        }

        usageTimer = Timer.scheduledTimer(withTimeInterval: usageInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkUsageStats()
            }
        }

        usageFetchTimer = Timer.scheduledTimer(withTimeInterval: usageFetchInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                // Attempt token refresh before fetching (no-op if token is still valid)
                Task {
                    _ = await self.claudeAuth.refreshTokenIfNeeded()
                    self.usageFetcher.fetchAndCache()
                }
                self.codexUsageFetcher.fetchAndCache()
                self.geminiUsageFetcher.fetchAndCache()
                self.cursorUsageFetcher.fetchAndCache()
                self.cursorUsageFetcher.fetchAnalytics()
            }
        }

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
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
                        _ = self.bleTransport.send(ProtocolBuilder.identifyRequest())
                        self.startIdentifyTimer()
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

        // Update Cursor heatmap for UI
        let heatmap = cursorUsageFetcher.currentHeatmap()
        if heatmap != cursorHeatmapData {
            cursorHeatmapData = heatmap
            // Clear the auth-needed flag when heatmap data arrives
            if heatmap != nil && cursorNeedsDashboardAuth {
                cursorNeedsDashboardAuth = false
            }
        }

        // Update local activity heatmaps (Claude/Codex/Gemini)
        if activityHeatmapDirty {
            activityHeatmapDirty = false
            let newClaude = ActivityDatabase.shared.loadHeatmapData(provider: TranscriptSource.claude.heatmapKey!)
            if newClaude != claudeHeatmapData { claudeHeatmapData = newClaude }
            let newCodex = ActivityDatabase.shared.loadHeatmapData(provider: TranscriptSource.codex.heatmapKey!)
            if newCodex != codexHeatmapData { codexHeatmapData = newCodex }
            let newGemini = ActivityDatabase.shared.loadHeatmapData(provider: TranscriptSource.gemini.heatmapKey!)
            if newGemini != geminiHeatmapData { geminiHeatmapData = newGemini }
        }

        // Export to iCloud if local data changed
        activitySyncService.exportIfNeeded()

        guard let data = usageFetcher.currentStats() else { return }

        // Only update if changed
        if data != lastUsageData {
            lastUsageData = data
            usageStats = data
            // Send to hardware (only when connected in hardware mode)
            if !isSoftware, let transport = activeTransport, transport.isConnected {
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
                    // Record tool call in local activity DB for heatmap
                    if state == .type || state == .read {
                        let isToolCall: Bool
                        switch source {
                        case .claude, .codex: isToolCall = !tool.isEmpty
                        case .gemini:         isToolCall = !tool.isEmpty && tool != "Gemini"
                        case .cursor:         isToolCall = false
                        }
                        if isToolCall, let heatmapKey = source.heatmapKey {
                            ActivityDatabase.shared.recordToolCall(provider: heatmapKey)
                            activityHeatmapDirty = true
                            activitySyncService.markNeedsExport()
                        }
                    }

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

    private func handleIdentifyResponse(_ payload: Data) {
        guard let info = ProtocolBuilder.parseIdentifyResponse(payload) else { return }
        Task { @MainActor in
            self.identifyTimer?.invalidate()
            self.identifyTimer = nil
            self.deviceIdentified = true
            NSLog("[Bridge] Pixel Agents device: %@ firmware v%@ protocol %d",
                  info.boardName, info.firmwareVersion, info.protocolVersion)
        }
    }

    private func startIdentifyTimer() {
        identifyTimer?.invalidate()
        identifyTimer = Timer.scheduledTimer(withTimeInterval: identifyTimeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if case .connected = self.connectionState, self.deviceIdentified == nil {
                    self.deviceIdentified = false
                    NSLog("[Bridge] Device did not identify within %.0fs — may not be a Pixel Agents device", self.identifyTimeout)
                }
            }
        }
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

    // MARK: - Popover Visibility

    /// Called by AppDelegate when the popover opens.
    func popoverDidOpen() {
        isPopoverVisible = true
        updateSceneTimerState()
    }

    /// Called by AppDelegate when the popover closes.
    func popoverDidClose() {
        isPopoverVisible = false
        updateSceneTimerState()
    }

    // MARK: - Scene Timer

    /// Called by PIPWindowController when the window closes via the OS close button.
    func sceneTimerNeedsUpdate() {
        updateSceneTimerState()
    }

    /// Starts/stops the scene timer and adjusts its rate based on visibility.
    /// When visible: 15 FPS with rendering. When not visible: 4 FPS sim-only.
    private func updateSceneTimerState() {
        let needsScene = displayMode == .software || isPIPShown
        let targetInterval = isSceneVisible ? foregroundTickInterval : backgroundTickInterval

        if needsScene {
            if sceneTimer == nil {
                startSceneTimer(interval: targetInterval)
            } else if sceneTimerInterval != targetInterval {
                // Visibility changed — swap timer rate
                stopSceneTimer()
                startSceneTimer(interval: targetInterval)
                // Force fresh render when becoming visible
                if isSceneVisible {
                    lastFingerprint = nil
                    let frame = officeRenderer.render(scene: officeScene)
                    lastRenderedFrame = frame
                    officeFrame = frame
                }
            }
        } else if sceneTimer != nil {
            stopSceneTimer()
        }
    }

    private func startSceneTimer(interval: TimeInterval) {
        lastSceneDate = Date()
        sceneTimerInterval = interval
        sceneTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickScene()
            }
        }
    }

    private func stopSceneTimer() {
        sceneTimer?.invalidate()
        sceneTimer = nil
        lastSceneDate = nil
        sceneTimerInterval = 0
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

        // Only render + publish when something is actually displaying the frame
        guard isSceneVisible else { return }

        // Dirty-frame detection: skip re-rendering if nothing visual changed
        let fp = SceneFingerprint(scene: officeScene)
        if fp == lastFingerprint, let cached = lastRenderedFrame {
            // No visual change — reuse cached frame, don't republish (avoids SwiftUI invalidation)
            if officeFrame == nil { officeFrame = cached }
            return
        }
        lastFingerprint = fp

        let frame = officeRenderer.render(scene: officeScene)
        lastRenderedFrame = frame
        officeFrame = frame
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

// MARK: - Scene Fingerprint (dirty-frame detection)

/// Captures the visual state of all entities for comparison between frames.
/// If two fingerprints are equal, the rendered image is identical and can be reused.
/// NOTE: Update this struct whenever new visual properties are added to Character or Pet.
private struct SceneFingerprint: Equatable {
    struct CharVis: Equatable {
        let alive: Bool
        let x: Float, y: Float
        let state: OfficeSim.SimCharState
        let dir: OfficeSim.Dir
        let frame: Int
        let palette: Int
        let bubbleType: Int
        let effectTimer: Int16   // quantized to 0.05s steps
        let idleActivity: OfficeSim.IdleActivity
    }
    struct PetVis: Equatable {
        let x: Float, y: Float
        let dir: OfficeSim.Dir
        let frame: Int
        let idleFrame: Int
        let walking: Bool
        let isRunning: Bool
        let isSitting: Bool
        let isPeeing: Bool
        let behavior: OfficeSim.DogBehavior
    }
    let chars: [CharVis]
    let pet: PetVis
    let dogEnabled: Bool
    let dogColor: OfficeSim.DogColor

    @MainActor init(scene: OfficeScene) {
        chars = scene.characters.map { ch in
            CharVis(
                alive: ch.alive, x: ch.x, y: ch.y,
                state: ch.state, dir: ch.dir, frame: ch.frame,
                palette: ch.palette, bubbleType: ch.bubbleType,
                effectTimer: Int16(ch.effectTimer * 20),  // 0.05s quantization
                idleActivity: ch.idleActivity
            )
        }
        pet = PetVis(
            x: scene.pet.x, y: scene.pet.y,
            dir: scene.pet.dir, frame: scene.pet.frame,
            idleFrame: scene.pet.idleFrame,
            walking: scene.pet.walking,
            isRunning: scene.pet.isRunning,
            isSitting: scene.pet.isSitting,
            isPeeing: scene.pet.isPeeing,
            behavior: scene.pet.behavior
        )
        dogEnabled = scene.dogEnabled
        dogColor = scene.dogColor
    }
}

