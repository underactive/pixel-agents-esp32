import SwiftUI

// NSStatusItem + NSPopover managed by AppDelegate.
// LSUIElement = true in Info.plist hides the dock icon.

@main
struct PixelAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Invisible window — required to satisfy Scene protocol.
        // LSUIElement prevents it from appearing in the dock.
        Window("", id: "empty") {
            EmptyView()
        }
        .defaultSize(width: 0, height: 0)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
