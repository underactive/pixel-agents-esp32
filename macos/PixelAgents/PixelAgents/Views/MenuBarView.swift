import SwiftUI

/// Main popover content displayed when clicking the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var bridge: BridgeService
    @AppStorage(SettingsKeys.showRemaining) private var showRemaining = false
    @AppStorage(SettingsKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(SettingsKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(SettingsKeys.showGeminiUsage) private var showGeminiUsage = true
    @AppStorage(SettingsKeys.showCursorUsage) private var showCursorUsage = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Connection status
            ConnectionStatusView(state: bridge.connectionState,
                                 batteryLevel: bridge.deviceBatteryLevel)

            Divider()
                .padding(.vertical, 4)

            // Display mode picker (hidden when hardware transport is connected)
            if !(bridge.isConnected && !bridge.isSoftwareMode) {
                Picker("Display Mode", selection: Binding(
                    get: { bridge.displayMode },
                    set: { bridge.setDisplayMode($0) }
                )) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)

                Divider()
                    .padding(.vertical, 4)
            }

            if bridge.isSoftwareMode {
                // Software mode: office canvas or PIP indicator
                if bridge.isPIPShown {
                    HStack {
                        Image(systemName: "pip.fill")
                            .foregroundColor(.secondary)
                        Text("PIP enabled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            bridge.togglePIP()
                        } label: {
                            Image(systemName: "pip.exit")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                } else {
                    ZStack(alignment: .topTrailing) {
                        OfficeCanvasView()

                        Button {
                            bridge.togglePIP()
                        } label: {
                            Image(systemName: "pip.enter")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(.black.opacity(0.5))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    .padding(.horizontal, 4)
                }

                Divider()
                    .padding(.vertical, 4)

                // Agent list
                AgentListView(agents: bridge.displayAgents)

                Divider()
                    .padding(.vertical, 4)

            } else {
                // Hardware mode: transport picker
                TransportPicker()

                Divider()
                    .padding(.vertical, 4)

                if bridge.isConnected {
                    AgentListView(agents: bridge.displayAgents)

                    Divider()
                        .padding(.vertical, 4)
                }
            }

            // Usage stats (always visible regardless of display mode or connection)
            usageStatsSection

            // Bottom actions
            HStack {
                Button {
                    bridge.onOpenSettings?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("Settings")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                if !bridge.isSoftwareMode && bridge.transportMode == .serial {
                    Button("Screenshot") {
                        bridge.requestScreenshot()
                    }
                    .font(.system(size: 11))
                    .disabled(!bridge.serialTransportConnected)
                }

                Spacer()

                Button("Quit") {
                    bridge.stop()
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: (bridge.isSoftwareMode && !bridge.isPIPShown) ? 328 : 300)
        .padding(.vertical, 4)
    }

    /// Usage stats section, conditionally shown based on settings toggles.
    @ViewBuilder
    private var usageStatsSection: some View {
        let claudeNeedsSignIn = showClaudeUsage && bridge.usageStats == nil && !bridge.claudeAuth.isAuthenticated
        let enabledSet = Set<UsageProvider>(
            [showClaudeUsage ? .claude : nil,
             showCodexUsage ? .codex : nil,
             showGeminiUsage ? .gemini : nil,
             showCursorUsage ? .cursor : nil].compactMap { $0 }
        )

        if !enabledSet.isEmpty {
            UsageStatsView(stats: bridge.usageStats,
                           codexStats: bridge.codexUsageStats,
                           geminiStats: bridge.geminiUsageStats,
                           cursorStats: bridge.cursorUsageStats,
                           enabled: enabledSet,
                           showRemaining: $showRemaining,
                           claudeSignInAction: claudeNeedsSignIn ? { bridge.onOpenSettings?() } : nil)

            Divider()
                .padding(.vertical, 4)
        }
    }
}

// Convenience to check serial connection from view
extension BridgeService {
    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }

    var isSoftwareMode: Bool {
        displayMode == .software
    }

    var serialTransportConnected: Bool {
        if case .connected = connectionState, transportMode == .serial {
            return true
        }
        return false
    }

    /// Battery level from BLE Battery Service (nil when serial or not available).
    var deviceBatteryLevel: UInt8? {
        guard transportMode == .ble, isConnected else { return nil }
        return bleTransport.batteryLevel
    }
}
