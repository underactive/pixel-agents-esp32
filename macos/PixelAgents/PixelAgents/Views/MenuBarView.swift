import SwiftUI

/// Main popover content displayed when clicking the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var bridge: BridgeService
    @AppStorage(SettingsKeys.showRemaining) private var showRemaining = false
    @AppStorage(SettingsKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(SettingsKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(SettingsKeys.showGeminiUsage) private var showGeminiUsage = true
    @AppStorage(SettingsKeys.showCursorUsage) private var showCursorUsage = true
    @AppStorage(SettingsKeys.showAgentsList) private var showAgentsList = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Display mode picker
            Picker("Mode", selection: Binding(
                get: { bridge.displayMode },
                set: { bridge.setDisplayMode($0) }
            )) {
                ForEach(DisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Divider()
                .padding(.vertical, 4)

            switch bridge.displayMode {
            case .off:
                // Off mode: just show agents list
                if showAgentsList {
                    AgentListView(agents: bridge.displayAgents)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                        .padding(.horizontal, 4)
                    Spacer().frame(height: 2)
                }

            case .software:
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
                    OfficeCanvasWithPIP()
                        .padding(.horizontal, 4)
                }

                if showAgentsList {
                    Divider()
                        .padding(.vertical, 4)

                    // Agent list
                    AgentListView(agents: bridge.displayAgents)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                        .padding(.horizontal, 4)
                    Spacer().frame(height: 2)
                }

            case .hardware:
                // Hardware mode: transport picker + agents
                TransportPicker()

                Divider()
                    .padding(.vertical, 4)

                if showAgentsList {
                    AgentListView(agents: bridge.displayAgents)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                        .padding(.horizontal, 4)
                    Spacer().frame(height: 2)
                }
            }

            // Usage stats (always visible regardless of display mode or connection)
            usageStatsSection
            Spacer().frame(height: 4)

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

                if bridge.displayMode == .hardware && bridge.transportMode == .serial {
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
        .frame(width: (bridge.displayMode == .software && !bridge.isPIPShown) ? 328 : 300)
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
                           claudeSignInAction: claudeNeedsSignIn ? { bridge.onOpenSettings?() } : nil,
                           claudeHeatmap: bridge.claudeHeatmapData,
                           codexHeatmap: bridge.codexHeatmapData,
                           geminiHeatmap: bridge.geminiHeatmapData,
                           cursorHeatmap: bridge.cursorHeatmapData,
                           cursorAgentHeatmap: bridge.cursorAgentHeatmapData
                           )
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            .padding(.horizontal, 4)
        }
    }
}

/// Office canvas with a PIP button that only appears on hover.
private struct OfficeCanvasWithPIP: View {
    @EnvironmentObject var bridge: BridgeService
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OfficeCanvasView()

            if isHovering {
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
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// Convenience to check serial connection from view
extension BridgeService {
    var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
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
