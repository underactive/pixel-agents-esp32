import Foundation
import os

/// Fetches usage stats from the Google Gemini CLI quota API using OAuth credentials.
///
/// Auth pipeline:
/// 1. Read OAuth credentials from ~/.gemini/oauth_creds.json
/// 2. Refresh the access token if expired via Google OAuth2 token endpoint
/// 3. Discover the Cloud AI Companion project via loadCodeAssist
/// 4. Fetch quota buckets via retrieveUserQuota
/// 5. Map the most constrained bucket to UsageStatsData
@MainActor
final class GeminiUsageFetcher {

    private static let log = Logger(subsystem: "com.pixelagents", category: "GeminiUsage")

    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private static let codeAssistURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
    private static let quotaURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!

    private static let credsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.gemini/oauth_creds.json"
    }()

    // MARK: - State

    private(set) var latestData: UsageStatsData?
    /// True after the first fetch attempt completes, regardless of outcome.
    private(set) var hasFetched = false

    /// Cached access token and its expiry.
    private var cachedAccessToken: String?
    private var tokenExpiry: Date?
    /// Cached project ID from loadCodeAssist.
    private var cachedProjectId: String?
    /// Cached OAuth client credentials extracted from Gemini CLI installation.
    private var cachedClientCreds: (id: String, secret: String)?
    /// Set when API returns 401/403 — forces token refresh on next attempt, ignoring on-disk expiry.
    private var tokenRejected = false

    func currentStats() -> UsageStatsData? {
        latestData
    }

    /// Fetch from API and update latestData. Retries once on 401 with a refreshed token.
    func fetchAndCache() {
        Task {
            defer { self.hasFetched = true }
            var didRetry = false

            while true {
                guard let token = await getValidAccessToken() else { return }
                guard let projectId = await resolveProjectId(token: token) else {
                    // If token was rejected (401/403), retry once with refreshed token
                    if tokenRejected && !didRetry {
                        didRetry = true
                        continue
                    }
                    return
                }
                guard let data = await fetchQuota(token: token, projectId: projectId) else {
                    if tokenRejected && !didRetry {
                        didRetry = true
                        continue
                    }
                    return
                }

                Self.log.info("Gemini usage: \(data.currentPct)%")
                self.latestData = data
                return
            }
        }
    }

    // MARK: - OAuth Credentials

    /// Extract OAuth client credentials from the installed Gemini CLI's oauth2.js source.
    ///
    /// The client ID and secret are public installed-app credentials (safe to distribute per Google's
    /// OAuth2 spec for installed applications). We extract them at runtime rather than embedding them
    /// so they stay in sync with the user's installed Gemini CLI version.
    private func getClientCredentials() -> (id: String, secret: String)? {
        if let cached = cachedClientCreds { return cached }

        // Search known Gemini CLI installation paths for oauth2.js
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let searchPaths = [
            // Homebrew (macOS)
            "/opt/homebrew/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
            "/usr/local/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
            // npm global
            "\(home)/.npm/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
            // nvm
            "\(home)/.nvm/versions/node/*/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
            // Bun
            "\(home)/.bun/install/global/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
        ]

        let fm = FileManager.default
        var oauthFile: String?

        for pattern in searchPaths {
            if pattern.contains("*") {
                // Glob expansion for nvm version paths
                let parts = pattern.components(separatedBy: "*")
                guard parts.count == 2, let parentDir = parts.first else { continue }
                let parentURL = URL(fileURLWithPath: String(parentDir.dropLast()))
                guard let versions = try? fm.contentsOfDirectory(at: parentURL, includingPropertiesForKeys: nil) else { continue }
                for version in versions {
                    let candidate = version.path + parts[1]
                    if fm.fileExists(atPath: candidate) {
                        oauthFile = candidate
                        break
                    }
                }
                if oauthFile != nil { break }
            } else if fm.fileExists(atPath: pattern) {
                oauthFile = pattern
                break
            }
        }

        guard let path = oauthFile,
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            Self.log.debug("Gemini CLI oauth2.js not found — cannot extract client credentials for token refresh")
            return nil
        }

        // Extract OAUTH_CLIENT_ID and OAUTH_CLIENT_SECRET using regex
        guard let idMatch = content.range(of: #"OAUTH_CLIENT_ID\s*=\s*["']([^"']+)["']"#, options: .regularExpression),
              let secretMatch = content.range(of: #"OAUTH_CLIENT_SECRET\s*=\s*["']([^"']+)["']"#, options: .regularExpression) else {
            Self.log.error("Failed to extract OAuth credentials from Gemini CLI oauth2.js")
            return nil
        }

        let idLine = String(content[idMatch])
        let secretLine = String(content[secretMatch])

        // Extract the quoted value
        func extractQuoted(_ s: String) -> String? {
            guard let start = s.firstIndex(of: "'") ?? s.firstIndex(of: "\"") else { return nil }
            let after = s.index(after: start)
            guard let end = s[after...].firstIndex(of: s[start]) else { return nil }
            return String(s[after..<end])
        }

        guard let clientId = extractQuoted(idLine),
              let clientSecret = extractQuoted(secretLine) else {
            Self.log.error("Failed to parse OAuth credential values from Gemini CLI oauth2.js")
            return nil
        }

        cachedClientCreds = (clientId, clientSecret)
        return cachedClientCreds
    }

    /// Read OAuth credentials from ~/.gemini/oauth_creds.json.
    private func readCredentials() -> (accessToken: String, refreshToken: String?, expiryDate: Double?)? {
        guard FileManager.default.fileExists(atPath: Self.credsPath) else {
            Self.log.debug("Gemini oauth_creds.json not found — is Gemini CLI installed and logged in?")
            return nil
        }

        guard let data = FileManager.default.contents(atPath: Self.credsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            Self.log.error("Failed to read access_token from Gemini oauth_creds.json")
            return nil
        }

        let refreshToken = json["refresh_token"] as? String
        let expiryDate = json["expiry_date"] as? Double
        return (accessToken, refreshToken, expiryDate)
    }

    /// Get a valid access token, refreshing if expired or rejected by API.
    private func getValidAccessToken() async -> String? {
        // Check cached token (skip if API previously rejected it)
        if !tokenRejected, let token = cachedAccessToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }

        guard let creds = readCredentials() else { return nil }

        // Check if token is still valid (expiry_date is Unix timestamp in seconds).
        // Skip this trust check if the API already rejected the token — the on-disk
        // expiry_date may be unreliable (e.g. far-future values from Gemini CLI).
        if !tokenRejected, let expiry = creds.expiryDate {
            let expiryDate = Date(timeIntervalSince1970: expiry)
            if expiryDate > Date().addingTimeInterval(60) {
                // Token still valid with 60s safety margin
                cachedAccessToken = creds.accessToken
                tokenExpiry = expiryDate
                return creds.accessToken
            }
        }

        // Token expired or rejected by API — try to refresh
        guard let refreshToken = creds.refreshToken, !refreshToken.isEmpty else {
            Self.log.debug("Gemini token expired and no refresh_token available")
            return nil
        }

        let result = await refreshAccessToken(refreshToken: refreshToken)
        if result != nil { tokenRejected = false }
        return result
    }

    /// Refresh the access token using Google OAuth2 token endpoint.
    private func refreshAccessToken(refreshToken: String) async -> String? {
        guard let clientCreds = getClientCredentials() else {
            Self.log.error("Cannot refresh Gemini token — OAuth client credentials not found in Gemini CLI installation")
            return nil
        }

        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(clientCreds.id)",
            "client_secret=\(clientCreds.secret)",
            "refresh_token=\(refreshToken)",
            "grant_type=refresh_token"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                Self.log.error("Gemini token refresh failed with HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newToken = json["access_token"] as? String else {
                Self.log.error("Failed to parse refreshed Gemini access token")
                return nil
            }

            let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue ?? 3600
            cachedAccessToken = newToken
            tokenExpiry = Date().addingTimeInterval(expiresIn - 60)
            return newToken
        } catch {
            Self.log.error("Gemini token refresh request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Project Discovery

    /// Discover the Cloud AI Companion project ID via loadCodeAssist.
    private func resolveProjectId(token: String) async -> String? {
        if let cached = cachedProjectId { return cached }

        var request = URLRequest(url: Self.codeAssistURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "metadata": ["ideType": "GEMINI_CLI", "pluginType": "GEMINI"]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 401 || code == 403 {
                    cachedAccessToken = nil
                    tokenExpiry = nil
                    tokenRejected = true
                }
                Self.log.error("Gemini loadCodeAssist failed with HTTP \(code)")
                return nil
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let projectId = json["cloudaicompanionProject"] as? String, !projectId.isEmpty else {
                Self.log.error("Failed to parse Gemini project ID from loadCodeAssist response")
                return nil
            }

            cachedProjectId = projectId
            return projectId
        } catch {
            Self.log.error("Gemini loadCodeAssist request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Quota Fetch

    /// Fetch quota buckets and map to UsageStatsData.
    private func fetchQuota(token: String, projectId: String) async -> UsageStatsData? {
        var request = URLRequest(url: Self.quotaURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["project": projectId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            let (d, r) = try await URLSession.shared.data(for: request)
            guard let hr = r as? HTTPURLResponse else {
                Self.log.error("Gemini quota API response is not HTTP")
                return nil
            }
            responseData = d
            httpResponse = hr
        } catch {
            Self.log.error("Gemini quota API request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            Self.log.error("Gemini access token expired during quota fetch")
            cachedAccessToken = nil
            tokenExpiry = nil
            tokenRejected = true
            return nil
        default:
            let body = String(data: responseData.prefix(256), encoding: .utf8) ?? "<binary>"
            Self.log.error("Gemini quota API returned HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            return nil
        }

        return parseQuotaResponse(responseData)
    }

    // MARK: - Response Parsing

    /// Parse the retrieveUserQuota response.
    ///
    /// Response shape:
    /// ```
    /// {
    ///   "buckets": [
    ///     {
    ///       "remainingFraction": 0.75,
    ///       "modelId": "gemini-2.0-flash-lite",
    ///       "resetTime": "2026-03-24T00:00:00Z",
    ///       "tokenType": "INPUT"
    ///     }
    ///   ]
    /// }
    /// ```
    private func parseQuotaResponse(_ data: Data) -> UsageStatsData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buckets = json["buckets"] as? [[String: Any]], !buckets.isEmpty else {
            Self.log.error("Gemini quota response has no buckets")
            return nil
        }

        // Find the most constrained bucket (lowest remainingFraction).
        // Skip buckets whose resetTime is in the past — their quota period has
        // already rolled over, so the remainingFraction is stale.
        let now = Date()
        var minRemaining: Double = 1.0
        var earliestResetTime: String?

        for bucket in buckets {
            if let resetStr = bucket["resetTime"] as? String,
               let resetDate = parseISO8601(resetStr),
               resetDate <= now {
                continue   // expired quota period — ignore stale remainingFraction
            }
            let remaining = (bucket["remainingFraction"] as? NSNumber)?.doubleValue ?? 1.0
            if remaining < minRemaining {
                minRemaining = remaining
                earliestResetTime = bucket["resetTime"] as? String
            }
        }

        let usedPct = UInt8(min(100, max(0, ((1.0 - minRemaining) * 100).rounded())))

        let resetMin: UInt16
        if let resetTime = earliestResetTime {
            resetMin = minutesFromISO8601(resetTime)
        } else {
            resetMin = 0
        }

        return UsageStatsData(
            currentPct: usedPct,
            weeklyPct: 0,      // Gemini has no separate weekly window
            currentResetMin: resetMin,
            weeklyResetMin: 0
        )
    }

    // MARK: - Helpers

    private func parseISO8601(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private func minutesFromISO8601(_ dateString: String) -> UInt16 {
        guard let date = parseISO8601(dateString) else { return 0 }
        return minutesUntil(date)
    }

    private func minutesUntil(_ date: Date) -> UInt16 {
        let minutes = date.timeIntervalSinceNow / 60.0
        let clamped = max(0.0, min(minutes, Double(UInt16.max)))
        return UInt16(clamped)
    }
}
