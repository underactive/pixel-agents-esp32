import AppKit
import SwiftUI
import Combine
import Sparkle

/// Central coordinator — owns the NSStatusItem, popover, right-click menu, and
/// secondary windows. Uses NSStatusItem directly (not MenuBarExtra) for full
/// control over the menu bar button's image and title.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    let bridge = BridgeService()
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var rightClickMenu: NSMenu!
    private var cancellables = Set<AnyCancellable>()
    private var lifecycleObservers: [Any] = []

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        bridge.onOpenSettings = { [weak self] in self?.openSettings() }
        bridge.start()
        registerLifecycleObservers()

        setupStatusItem()
        setupPopover()
        setupRightClickMenu()
        subscribeToStatusUpdates()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Load icon via SwiftUI ImageRenderer — NSImage(named:) can't find
            // asset catalog images in this app configuration.
            let renderer = ImageRenderer(content: Image("MenuBarIcon"))
            renderer.scale = 2.0
            if let nsImage = renderer.nsImage {
                nsImage.size = NSSize(width: 18, height: 18)
                nsImage.isTemplate = true
                button.image = nsImage
            }
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            statusItem.menu = rightClickMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover(sender)
        }
    }

    // MARK: - Agent Count + Connection State

    private func updateStatusTitle() {
        let showCount = UserDefaults.standard.object(forKey: SettingsKeys.showAgentCount) as? Bool ?? true
        let count = bridge.displayAgents.filter { $0.state != .offline }.count
        statusItem.button?.title = (showCount && count > 0) ? "\(count)" : ""
    }

    private func subscribeToStatusUpdates() {
        bridge.$displayAgents
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusTitle() }
            .store(in: &cancellables)

        bridge.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.statusItem.button?.appearsDisabled = (state == .disconnected)
            }
            .store(in: &cancellables)
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 500)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(bridge)
        )
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Right-Click Menu

    private func setupRightClickMenu() {
        rightClickMenu = NSMenu()

        let aboutItem = NSMenuItem(title: "About Pixel Agents",
                                   action: #selector(showAbout),
                                   keyEquivalent: "")
        aboutItem.target = self
        rightClickMenu.addItem(aboutItem)

        let checkUpdatesItem = NSMenuItem(title: "Check for Updates...",
                                          action: #selector(checkForUpdates),
                                          keyEquivalent: "")
        checkUpdatesItem.target = self
        rightClickMenu.addItem(checkUpdatesItem)

        rightClickMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        rightClickMenu.addItem(quitItem)
    }

    // MARK: - Settings Window

    func openSettings() {
        if popover.isShown { popover.performClose(nil) }

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(updater: updaterController.updater)
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Pixel Agents Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 300, height: 260))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - About Window

    @objc private func showAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = AboutView()
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Pixel Agents"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 300, height: 200))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        aboutWindow = window
    }

    // MARK: - Actions

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func quitApp() {
        bridge.stop()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Sleep / Wake

    private func registerLifecycleObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        lifecycleObservers.append(
            nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.bridge.handleSleep()
            }
        )
        lifecycleObservers.append(
            nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.bridge.handleWake()
            }
        )
    }
}
