import SwiftUI

/// Accounts settings tab: provider sign-in management for Claude, Cursor, Codex, and Gemini.
struct AccountsSettingsView: View {
    @ObservedObject var claudeAuth: ClaudeAuthService
    @ObservedObject var bridge: BridgeService
    @State private var showPasteSheet = false
    @State private var pastedToken = ""
    @State private var pasteError: String?

    private var codexCredentialsFound: Bool {
        let path: String
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !codexHome.isEmpty {
            path = (codexHome as NSString).appendingPathComponent("auth.json")
        } else {
            path = (NSHomeDirectory() as NSString).appendingPathComponent(".codex/auth.json")
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private var geminiCredentialsFound: Bool {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".gemini/oauth_creds.json")
        return FileManager.default.fileExists(atPath: path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: - Claude Account

            Text("Claude")
                .font(.subheadline.weight(.semibold))

            Text("Sign in to fetch usage stats from the Anthropic API.")
                .font(.caption)
                .foregroundColor(.secondary)

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

            // MARK: - Cursor Account

            Text("Cursor")
                .font(.subheadline.weight(.semibold))

            Text("Sign in to fetch activity heatmaps from Cursor.")
                .font(.caption)
                .foregroundColor(.secondary)

            if !bridge.cursorNeedsDashboardAuth {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text("Signed in")
                        .font(.subheadline)
                    Spacer()
                    Button("Sign Out") {
                        bridge.signOutCursorDashboard()
                    }
                    .font(.subheadline)
                }
            } else {
                Button("Connect Cursor Dashboard") {
                    bridge.authenticateCursorDashboard()
                }
                .font(.subheadline)
            }

            Divider()
                .padding(.vertical, 4)

            // MARK: - Codex

            Text("Codex")
                .font(.subheadline.weight(.semibold))

            Text("Detected automatically from Codex CLI login. No sign-in needed.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                if codexCredentialsFound {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text("Credentials found")
                        .font(.subheadline)
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                    Text("Not found \u{2014} run `codex` to log in")
                        .font(.subheadline)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // MARK: - Gemini

            Text("Gemini")
                .font(.subheadline.weight(.semibold))

            Text("Detected automatically from Gemini CLI login. No sign-in needed.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                if geminiCredentialsFound {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    Text("Credentials found")
                        .font(.subheadline)
                } else {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                    Text("Not found \u{2014} run `gemini` to authenticate")
                        .font(.subheadline)
                }
            }

        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
}
