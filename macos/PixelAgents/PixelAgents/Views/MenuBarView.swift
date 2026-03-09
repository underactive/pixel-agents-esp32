import SwiftUI
import ServiceManagement

/// Main popover content displayed when clicking the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var bridge: BridgeService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Connection status
            ConnectionStatusView(state: bridge.connectionState)

            Divider()
                .padding(.vertical, 4)

            // Transport picker
            TransportPicker()

            Divider()
                .padding(.vertical, 4)

            // Agent list
            AgentListView(agents: bridge.displayAgents)

            Divider()
                .padding(.vertical, 4)

            // Usage stats
            UsageStatsView(stats: bridge.usageStats)

            Divider()
                .padding(.vertical, 4)

            // Bottom actions
            HStack {
                if bridge.transportMode == .serial {
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
                    .onChange(of: launchAtLogin) { newValue in
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
        .frame(width: 300)
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
    var serialTransportConnected: Bool {
        if case .connected = connectionState, transportMode == .serial {
            return true
        }
        return false
    }
}
