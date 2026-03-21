import AppKit
import SwiftUI

// MARK: - PIPWindowController

/// Manages an NSPanel-based floating picture-in-picture window that renders
/// the office scene from BridgeService.officeFrame.
@MainActor
final class PIPWindowController: NSObject, NSWindowDelegate {

    private var panel: NSPanel?
    private weak var bridge: BridgeService?

    init(bridge: BridgeService) {
        self.bridge = bridge
        super.init()
    }

    func show() {
        if let panel = panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 448),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .nonactivatingPanel,
                .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.contentAspectRatio = NSSize(width: 320, height: 224)
        panel.minSize = NSSize(width: 320, height: 224)
        panel.backgroundColor = .black
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.setFrameAutosaveName("PIPWindow")
        panel.hasShadow = true

        guard let bridge = bridge else { return }

        let hostingView = NSHostingView(rootView: PIPOfficeView().environmentObject(bridge))
        let trackingView = PIPTrackingView(panel: panel)
        trackingView.addSubview(hostingView)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
        ])

        panel.contentView = trackingView

        // Hide titlebar buttons until the user hovers over the window
        for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(buttonType)?.superview?.alphaValue = 0
        }

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        bridge?.isPIPShown = false
        bridge?.sceneTimerNeedsUpdate()
        panel = nil
    }
}

// MARK: - PIPTrackingView

/// NSView that installs a tracking area over the entire PIP window so that
/// the standard titlebar buttons fade in on mouse-enter and fade out on
/// mouse-exit.
class PIPTrackingView: NSView {

    private weak var panel: NSPanel?
    private var trackingArea: NSTrackingArea?

    init(panel: NSPanel) {
        self.panel = panel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PIPTrackingView does not support NSCoder")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                panel?.standardWindowButton(buttonType)?.superview?.animator().alphaValue = 1.0
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            for buttonType: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
                panel?.standardWindowButton(buttonType)?.superview?.animator().alphaValue = 0.0
            }
        }
    }
}

// MARK: - PIPOfficeView

/// SwiftUI view displayed inside the PIP window. Renders the current office
/// frame from BridgeService with nearest-neighbor interpolation to preserve
/// pixel art crispness.
struct PIPOfficeView: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        if let frame = bridge.officeFrame {
            Image(decorative: frame, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .ignoresSafeArea()
        } else {
            Color.black
                .ignoresSafeArea()
        }
    }
}
