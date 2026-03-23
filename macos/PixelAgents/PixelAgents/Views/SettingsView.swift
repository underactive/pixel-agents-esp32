import SwiftUI
import ServiceManagement
import Sparkle

/// Settings window content with usage stats toggles, menu bar options, Launch at Login, and auto-updates.
struct SettingsView: View {
    let updater: SPUUpdater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var autoCheckForUpdates: Bool = true
    @AppStorage(SettingsKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(SettingsKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(SettingsKeys.showAgentCount) private var showAgentCount = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Stats")
                .font(.subheadline.weight(.semibold))

            Toggle("Show Claude usage", isOn: $showClaudeUsage)
                .font(.subheadline)

            Toggle("Show Codex usage", isOn: $showCodexUsage)
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
