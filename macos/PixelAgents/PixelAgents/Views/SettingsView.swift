import SwiftUI
import ServiceManagement
import Sparkle

/// Settings window with Companion, Accounts, Device, and Update tabs.
struct SettingsView: View {
    let updater: SPUUpdater
    @ObservedObject var bridge: BridgeService

    var body: some View {
        TabView {
            CompanionSettingsTab(bridge: bridge)
                .tabItem { Text("Companion") }

            AccountsSettingsView(claudeAuth: bridge.claudeAuth, bridge: bridge)
                .tabItem { Text("Accounts") }

            DeviceSettingsView(bridge: bridge)
                .tabItem { Text("ESP32 Device") }

            UpdateSettingsTab(updater: updater)
                .tabItem { Text("Update") }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Companion settings tab: usage stats, menu bar, sync, launch at login.
private struct CompanionSettingsTab: View {
    let bridge: BridgeService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
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

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Update settings tab: check for updates, last checked date, auto-update toggle.
private struct UpdateSettingsTab: View {
    let updater: SPUUpdater
    @State private var lastCheckDate: Date?
    @State private var autoCheckForUpdates: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Software Update")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                    lastCheckDate = updater.lastUpdateCheckDate
                }
                .font(.subheadline)

                Text(lastCheckDateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.vertical, 4)

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
            lastCheckDate = updater.lastUpdateCheckDate
            autoCheckForUpdates = updater.automaticallyChecksForUpdates
        }
    }

    private var lastCheckDateText: String {
        guard let date = lastCheckDate else { return "Last checked: Never" }
        return "Last checked: \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
