import SwiftUI
import ServiceManagement
import Sparkle

/// Settings window with Companion and Device tabs.
struct SettingsView: View {
    let updater: SPUUpdater
    @ObservedObject var bridge: BridgeService

    var body: some View {
        TabView {
            CompanionSettingsTab(updater: updater, claudeAuth: bridge.claudeAuth, bridge: bridge)
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

/// Companion settings tab: usage stats, Claude auth, menu bar, launch at login, auto-updates.
private struct CompanionSettingsTab: View {
    let updater: SPUUpdater
    @ObservedObject var claudeAuth: ClaudeAuthService
    let bridge: BridgeService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var autoCheckForUpdates: Bool = true
    @AppStorage(SettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled = false
    @State private var showPasteSheet = false
    @State private var pastedToken = ""
    @State private var pasteError: String?
    @AppStorage(SettingsKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(SettingsKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(SettingsKeys.showGeminiUsage) private var showGeminiUsage = true
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

            Toggle("Show Gemini usage", isOn: $showGeminiUsage)
                .font(.subheadline)

            Toggle("Show Cursor usage", isOn: $showCursorUsage)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            // Claude Account section
            Text("Claude Account")
                .font(.subheadline.weight(.semibold))

            if claudeAuth.isAuthenticated {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text("Signed in")
                        .font(.subheadline)
                    if let expiry = claudeAuth.tokenExpiryDescription {
                        Text("(\(expiry))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Sign Out") {
                        claudeAuth.signOut()
                    }
                    .font(.subheadline)
                }
            } else {
                Text("Sign in to see Claude usage stats.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Button("Import from Claude Code") {
                        claudeAuth.importFromClaudeCode()
                    }
                    .font(.subheadline)

                    Button("Paste Token\u{2026}") {
                        pastedToken = ""
                        pasteError = nil
                        showPasteSheet = true
                    }
                    .font(.subheadline)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Cursor Account section
            Text("Cursor Account")
                .font(.subheadline.weight(.semibold))

            if !bridge.cursorNeedsDashboardAuth {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text("Connected")
                        .font(.subheadline)
                    Spacer()
                    Button("Sign Out") {
                        bridge.signOutCursorDashboard()
                    }
                    .font(.subheadline)
                }
            } else {
                Text("Sign in to see Cursor usage heatmap.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Connect Cursor Dashboard") {
                    bridge.authenticateCursorDashboard()
                }
                .font(.subheadline)
            }

            Divider()
                .padding(.vertical, 4)

            Text("Menu Bar")
                .font(.subheadline.weight(.semibold))

            Toggle("Show active agent count", isOn: $showAgentCount)
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
        .sheet(isPresented: $showPasteSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste Claude Token")
                    .font(.headline)

                Text("Run `claude setup-token` in your terminal and paste the output below.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $pastedToken)
                    .font(.system(.caption, design: .monospaced))
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.3))

                if let error = pasteError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showPasteSheet = false
                    }
                    Button("Import") {
                        let trimmed = pastedToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        if claudeAuth.importFromPastedJSON(trimmed) {
                            showPasteSheet = false
                        } else {
                            pasteError = "Invalid token format. Expected JSON from `claude setup-token`."
                        }
                    }
                    .disabled(pastedToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 400)
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
