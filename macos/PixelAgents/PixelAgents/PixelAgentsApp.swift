import SwiftUI

@main
struct PixelAgentsApp: App {
    @StateObject private var bridge = BridgeService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(bridge)
                .onAppear {
                    bridge.start()
                    registerLifecycleObservers()
                }
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        switch bridge.connectionState {
        case .connected:
            Image(systemName: "person.fill")
                .font(.system(size: 12))
        case .connecting:
            Image(systemName: "person.badge.clock")
                .font(.system(size: 12))
        case .disconnected:
            Image(systemName: "person")
                .font(.system(size: 12))
        }
    }

    private func registerLifecycleObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [bridge] _ in
            bridge.handleSleep()
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [bridge] _ in
            bridge.handleWake()
        }
    }
}
