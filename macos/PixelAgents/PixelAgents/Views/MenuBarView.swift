import SwiftUI
import ServiceManagement

/// Main popover content displayed when clicking the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var bridge: BridgeService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("showRemaining") private var showRemaining = false

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

                // Usage stats
                UsageStatsView(stats: bridge.usageStats, codexStats: bridge.codexUsageStats, showRemaining: $showRemaining)

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

                    UsageStatsView(stats: bridge.usageStats, codexStats: bridge.codexUsageStats, showRemaining: $showRemaining)

                    Divider()
                        .padding(.vertical, 4)
                }
            }

            // Bottom actions
            HStack {
                if !bridge.isSoftwareMode && bridge.transportMode == .serial {
                    Button("Screenshot") {
                        bridge.requestScreenshot()
                    }
                    .font(.system(size: 11))
                    .disabled(!bridge.serialTransportConnected)
                }

                Spacer()

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

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

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
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
