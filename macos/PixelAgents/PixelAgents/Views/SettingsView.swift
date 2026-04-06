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
        .frame(maxWidth: .infinity)
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
    @AppStorage(SettingsKeys.showAgentsList) private var showAgentsList = true
    @AppStorage(SettingsKeys.softwareSoundEnabled) private var softwareSoundEnabled = true
    @AppStorage(SettingsKeys.softwareDogBarkEnabled) private var softwareDogBarkEnabled = true
    @AppStorage(SettingsKeys.softwareSoundVolume) private var softwareSoundVolume: Double = 0.65

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu Bar")
                .font(.subheadline.weight(.semibold))

            Toggle("Show active agent count", isOn: $showAgentCount)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            Text("Agents")
                .font(.subheadline.weight(.semibold))

            Toggle("Show agents list", isOn: $showAgentsList)
                .font(.subheadline)

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

            Text("Audio")
                .font(.subheadline.weight(.semibold))

            Toggle("Sound effects", isOn: $softwareSoundEnabled)
                .font(.subheadline)

            Toggle("Dog bark", isOn: $softwareDogBarkEnabled)
                .font(.subheadline)
                .disabled(!softwareSoundEnabled)

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Slider(value: $softwareSoundVolume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(Int(softwareSoundVolume * 100))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }
            .disabled(!softwareSoundEnabled)

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

        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
