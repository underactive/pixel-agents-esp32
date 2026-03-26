import SwiftUI
import ServiceManagement
import Sparkle

/// Settings window with Companion, Accounts, and Device tabs.
struct SettingsView: View {
    let updater: SPUUpdater
    @ObservedObject var bridge: BridgeService

    var body: some View {
        TabView {
            CompanionSettingsTab(updater: updater, bridge: bridge)
                .tabItem { Label("Companion", systemImage: "laptopcomputer") }

            AccountsSettingsView(claudeAuth: bridge.claudeAuth, bridge: bridge)
                .tabItem { Label("Accounts", systemImage: "person.crop.circle") }

            DeviceSettingsView(bridge: bridge)
                .tabItem { Label("Device", systemImage: "cpu") }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Companion settings tab: usage stats, menu bar, sync, launch at login, auto-updates.
private struct CompanionSettingsTab: View {
    let updater: SPUUpdater
    let bridge: BridgeService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var autoCheckForUpdates: Bool = true
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @AppStorage(SettingsKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(SettingsKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(SettingsKeys.showGeminiUsage) private var showGeminiUsage = true
    @AppStorage(SettingsKeys.showCursorUsage) private var showCursorUsage = true
    @AppStorage(SettingsKeys.showAgentCount) private var showAgentCount = true
    @AppStorage(SettingsKeys.showMiniBarsWhenSelected) private var showMiniBarsWhenSelected = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu Bar")
                .font(.subheadline.weight(.semibold))

            Toggle("Show active agent count", isOn: $showAgentCount)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            Text("Provider Options")
                .font(.subheadline.weight(.semibold))

            Toggle("Show mini progress bars when highlighted", isOn: $showMiniBarsWhenSelected)
                .font(.subheadline)

            Toggle("Show Claude usage", isOn: $showClaudeUsage)
                .font(.subheadline)

            Toggle("Show Codex usage", isOn: $showCodexUsage)
                .font(.subheadline)

            Toggle("Show Gemini usage", isOn: $showGeminiUsage)
                .font(.subheadline)

            Toggle("Show Cursor usage", isOn: $showCursorUsage)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            Text("Sync")
                .font(.subheadline.weight(.semibold))

            Toggle("Sync activity heatmaps via iCloud", isOn: $iCloudSyncEnabled)
                .font(.subheadline)
                .onChange(of: iCloudSyncEnabled) { _, newValue in
                    bridge.setICloudSyncEnabled(newValue)
                }

            Divider()
                .padding(.vertical, 4)

            Text("Misc")
                .font(.subheadline.weight(.semibold))

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .font(.subheadline)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

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
