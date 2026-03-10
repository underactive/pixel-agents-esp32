import SwiftUI

@main
struct PixelAgentsApp: App {
    @StateObject private var bridge = BridgeService()

    init() {
        // start() and lifecycle observers are registered in .onAppear of the
        // menu bar label, which fires once at app launch (not on popover open).
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(bridge)
        } label: {
            menuBarLabel
                .onAppear {
                    bridge.start()
                    registerLifecycleObservers()
                }
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var menuBarLabel: some View {
        Image("MenuBarIcon")
            .opacity(bridge.connectionState == .disconnected ? 0.5 : 1.0)
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
