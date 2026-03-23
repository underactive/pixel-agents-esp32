import SwiftUI
import ServiceManagement
import Sparkle

/// Settings window with Companion and Device tabs.
struct SettingsView: View {
    let updater: SPUUpdater
    @ObservedObject var bridge: BridgeService

    var body: some View {
        TabView {
            CompanionSettingsTab(updater: updater)
                .tabItem { Label("Companion", systemImage: "laptopcomputer") }

            DeviceSettingsView(bridge: bridge)
                .tabItem { Label("Device", systemImage: "cpu") }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Companion settings tab: usage stats, menu bar, launch at login, auto-updates.
private struct CompanionSettingsTab: View {
    let updater: SPUUpdater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var autoCheckForUpdates: Bool = true
    @AppStorage(SettingsKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(SettingsKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(SettingsKeys.showCursorUsage) private var showCursorUsage = true
    @AppStorage(SettingsKeys.showAgentCount) private var showAgentCount = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Stats")
                .font(.subheadline.weight(.semibold))

            Toggle("Show Claude usage", isOn: $showClaudeUsage)
                .font(.subheadline)

            Toggle("Show Codex usage", isOn: $showCodexUsage)
                .font(.subheadline)

            Toggle("Show Cursor usage", isOn: $showCursorUsage)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            Text("Menu Bar")
                .font(.subheadline.weight(.semibold))

            Toggle("Show active agent count", isOn: $showAgentCount)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .font(.subheadline)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Divider()
                .padding(.vertical, 4)

            Text("Updates")
                .font(.subheadline.weight(.semibold))

            Toggle("Check for updates automatically", isOn: $autoCheckForUpdates)
                .font(.subheadline)
                .onChange(of: autoCheckForUpdates) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            autoCheckForUpdates = updater.automaticallyChecksForUpdates
        }
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
