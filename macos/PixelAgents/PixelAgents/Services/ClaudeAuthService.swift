import Foundation
import Security
import os

/// Manages Claude OAuth token storage in the app's own Keychain entry.
///
/// Instead of reading Claude Code CLI's Keychain item (which triggers a macOS permission
/// dialog on every access for dev-signed builds), this service stores tokens in an app-owned
/// Keychain entry that can be read without prompts.
///
/// Two import paths:
/// - **Import from Claude Code** — one-time read from Claude Code's Keychain (user-initiated)
/// - **Paste token** — user pastes output of `claude setup-token`
@MainActor
final class ClaudeAuthService: ObservableObject {

    private static let log = Logger(subsystem: "com.pixelagents", category: "ClaudeAuth")

    /// App-owned Keychain entry — created by us, readable without system prompts.
    private let ownKeychainService = "com.pixelagents.claude-oauth"
    /// Claude Code CLI's Keychain entry — reading triggers a system dialog.
    private let claudeCodeKeychainService = "Claude Code-credentials"

    private let tokenEndpoint = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    /// Claude Code's public OAuth client ID (installed-app credential).
    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    // MARK: - Callbacks

    /// Called when authentication succeeds (import or bootstrap). Use to trigger immediate data fetch.
    var onAuthenticated: (() -> Void)?

    // MARK: - Published State

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var tokenExpiryDescription: String?

    // MARK: - Cached Token

    private var cachedToken: String?
    private var cachedExpiresAt: Double = 0

    // MARK: - Lifecycle

    /// Check for an existing app-owned token on launch. No system dialog.
    func bootstrap() {
        if let blob = readOwnKeychainBlob(),
           let token = parseAccessToken(from: blob) {
            cachedToken = token.accessToken
            cachedExpiresAt = token.expiresAt
            isAuthenticated = true
            updateExpiryDescription(token.expiresAt)
            Self.log.info("Bootstrapped — token found in app Keychain")
        } else {
            isAuthenticated = false
            Self.log.info("No stored token — awaiting user sign-in")
        }
    }

    // MARK: - Token Reading

    /// Returns a valid access token from the app's own Keychain, or nil.
    /// If the token is near expiry and a refresh token is available, kicks off
    /// a background refresh (but still returns the current token for this call).
    func readToken() -> String? {
        let nowMs = Date().timeIntervalSince1970 * 1000
        if let token = cachedToken, cachedExpiresAt > nowMs + 60_000 {
            // Proactive refresh: if expiring within 5 min, fire background refresh
            if cachedExpiresAt < nowMs + 300_000 {
                Task { _ = await refreshTokenIfNeeded() }
            }
            return token
        }

        // Cache miss — re-read from own Keychain
        guard let blob = readOwnKeychainBlob(),
              let token = parseAccessToken(from: blob) else {
            return nil
        }

        let safeExpiry = token.expiresAt - 60_000
        guard safeExpiry > nowMs else {
            Self.log.warning("Stored token expired — re-import or refresh needed")
            isAuthenticated = false
            return nil
        }

        cachedToken = token.accessToken
        cachedExpiresAt = token.expiresAt
        return token.accessToken
    }

    // MARK: - Import from Claude Code Keychain

    /// One-time read from Claude Code's Keychain. Triggers a macOS system dialog,
    /// but only when the user explicitly clicks "Import from Claude Code" in Settings.
    @discardableResult
    func importFromClaudeCode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: claudeCodeKeychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            Self.log.error("Failed to read Claude Code Keychain (status \(status))")
            return false
        }

        // Store the entire blob in our own Keychain
        guard saveToOwnKeychain(data) else {
            Self.log.error("Failed to save imported token to app Keychain")
            return false
        }

        // Validate and cache
        if let token = parseAccessToken(from: data) {
            cachedToken = token.accessToken
            cachedExpiresAt = token.expiresAt
            isAuthenticated = true
            updateExpiryDescription(token.expiresAt)
            onAuthenticated?()
            Self.log.info("Imported token from Claude Code Keychain")
            return true
        }

        Self.log.error("Imported data from Claude Code but token is malformed")
        return false
    }

    // MARK: - Import from Pasted JSON

    /// Parse output of `claude setup-token` or a raw JSON blob with token fields.
    @discardableResult
    func importFromPastedJSON(_ json: String) -> Bool {
        guard let jsonData = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Self.log.error("Pasted text is not valid JSON")
            return false
        }

        // Handle both formats:
        // 1. Full Keychain blob: {"claudeAiOauth": {"accessToken": "...", ...}}
        // 2. Flat format: {"accessToken": "...", "refreshToken": "...", "expiresAt": ...}
        let oauthObj: [String: Any]
        if let nested = parsed["claudeAiOauth"] as? [String: Any] {
            oauthObj = nested
        } else if parsed["accessToken"] != nil {
            oauthObj = parsed
        } else {
            Self.log.error("Pasted JSON has no recognized token structure")
            return false
        }

        guard let accessToken = oauthObj["accessToken"] as? String, !accessToken.isEmpty else {
            Self.log.error("Pasted JSON missing accessToken")
            return false
        }

        // Re-wrap into the Keychain blob format for consistent storage
        let blob: [String: Any] = ["claudeAiOauth": oauthObj]
        guard let blobData = try? JSONSerialization.data(withJSONObject: blob),
              saveToOwnKeychain(blobData) else {
            Self.log.error("Failed to save pasted token to app Keychain")
            return false
        }

        let expiresAt = oauthObj["expiresAt"] as? Double ?? (Date().timeIntervalSince1970 * 1000 + 3_600_000)
        cachedToken = accessToken
        cachedExpiresAt = expiresAt
        isAuthenticated = true
        updateExpiryDescription(expiresAt)
        onAuthenticated?()
        Self.log.info("Imported token from pasted JSON")
        return true
    }

    // MARK: - Token Refresh

    /// Attempt to refresh the token using the stored refresh_token.
    /// Returns the new access token on success, or nil.
    func refreshTokenIfNeeded() async -> String? {
        let nowMs = Date().timeIntervalSince1970 * 1000

        // Only refresh if token is expiring within 10 minutes
        // (Claude Code access tokens are short-lived, ~2 hours)
        guard cachedExpiresAt > 0, cachedExpiresAt < nowMs + 600_000 else {
            return cachedToken  // Still valid for >10 min, no refresh needed
        }

        guard let blob = readOwnKeychainBlob(),
              let json = try? JSONSerialization.jsonObject(with: blob) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let refreshToken = oauth["refreshToken"] as? String, !refreshToken.isEmpty else {
            Self.log.debug("No refresh token available — user must re-import when token expires")
            return cachedToken
        }

        // POST to token endpoint
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(clientId)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                Self.log.error("Token refresh failed with HTTP \(code) — user must re-import")
                return cachedToken
            }

            guard let respJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccessToken = respJson["access_token"] as? String else {
                Self.log.error("Failed to parse refreshed token response")
                return cachedToken
            }

            let expiresIn = (respJson["expires_in"] as? NSNumber)?.doubleValue ?? 3600
            let newExpiresAt = Date().timeIntervalSince1970 * 1000 + expiresIn * 1000
            let newRefreshToken = respJson["refresh_token"] as? String ?? refreshToken

            // Update stored blob
            let updatedOauth: [String: Any] = [
                "accessToken": newAccessToken,
                "refreshToken": newRefreshToken,
                "expiresAt": newExpiresAt,
            ]
            let updatedBlob: [String: Any] = ["claudeAiOauth": updatedOauth]
            if let updatedData = try? JSONSerialization.data(withJSONObject: updatedBlob) {
                saveToOwnKeychain(updatedData)
            }

            cachedToken = newAccessToken
            cachedExpiresAt = newExpiresAt
            isAuthenticated = true
            updateExpiryDescription(newExpiresAt)
            Self.log.info("Token refreshed successfully")
            return newAccessToken
        } catch {
            Self.log.error("Token refresh request failed: \(error.localizedDescription, privacy: .public)")
            return cachedToken
        }
    }

    // MARK: - Token Expired (called by UsageStatsFetcher on HTTP 401)

    /// Mark the current token as expired. Next `readToken()` call will fail,
    /// prompting a refresh or re-import.
    func handleTokenExpired() {
        cachedToken = nil
        cachedExpiresAt = 0
        // Don't set isAuthenticated = false yet — the stored blob may have a
        // refresh token that can recover. Let the next fetch cycle try refresh first.
        Self.log.warning("Token marked as expired by API response")
    }

    // MARK: - Sign Out

    func signOut() {
        deleteOwnKeychain()
        cachedToken = nil
        cachedExpiresAt = 0
        isAuthenticated = false
        tokenExpiryDescription = nil
        Self.log.info("Signed out — app Keychain entry deleted")
    }

    // MARK: - Own Keychain CRUD

    private func readOwnKeychainBlob() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ownKeychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    @discardableResult
    private func saveToOwnKeychain(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ownKeychainService,
        ]

        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            return addStatus == errSecSuccess
        }

        return updateStatus == errSecSuccess
    }

    private func deleteOwnKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ownKeychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Parsing

    private struct TokenInfo {
        let accessToken: String
        let expiresAt: Double
    }

    private func parseAccessToken(from data: Data) -> TokenInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              !accessToken.isEmpty else {
            return nil
        }

        let expiresAt: Double
        if let exp = oauth["expiresAt"] as? Double {
            expiresAt = exp
        } else {
            // No expiry — assume 1 hour from now
            expiresAt = Date().timeIntervalSince1970 * 1000 + 3_600_000
        }

        return TokenInfo(accessToken: accessToken, expiresAt: expiresAt)
    }

    // MARK: - Helpers

    private func updateExpiryDescription(_ expiresAtMs: Double) {
        // If a refresh token is available, the access token auto-renews —
        // don't alarm the user with a short expiry countdown.
        if hasRefreshToken() {
            tokenExpiryDescription = nil
            return
        }

        let expiryDate = Date(timeIntervalSince1970: expiresAtMs / 1000)
        let now = Date()

        if expiryDate <= now {
            tokenExpiryDescription = "Token expired — re-import needed"
        } else {
            let interval = expiryDate.timeIntervalSince(now)
            let days = Int(interval / 86400)
            if days > 30 {
                tokenExpiryDescription = nil
            } else if days > 1 {
                tokenExpiryDescription = "Expires in \(days) days"
            } else {
                let hours = Int(interval / 3600)
                tokenExpiryDescription = "Expires in \(max(1, hours)) hour\(hours == 1 ? "" : "s") — re-import needed"
            }
        }
    }

    /// Check whether the stored blob contains a refresh token for auto-renewal.
    private func hasRefreshToken() -> Bool {
        guard let blob = readOwnKeychainBlob(),
              let json = try? JSONSerialization.jsonObject(with: blob) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let refreshToken = oauth["refreshToken"] as? String,
              !refreshToken.isEmpty else {
            return false
        }
        return true
    }
}
