import Foundation
import os

/// Fetches usage stats from the OpenAI Codex API via the ChatGPT backend.
/// Reads the OAuth token from ~/.codex/auth.json (written by `codex` CLI on login).
final class CodexUsageFetcher {

    private static let log = Logger(subsystem: "com.pixelagents", category: "CodexUsage")

    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private static let authPath: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !codexHome.isEmpty {
            return URL(fileURLWithPath: codexHome).appendingPathComponent("auth.json")
        }
        return home.appendingPathComponent(".codex/auth.json")
    }()

    // MARK: - State

    private(set) var latestData: UsageStatsData?

    /// Cached token to avoid re-reading auth.json on every poll.
    private var cachedToken: String?
    private var cachedAccountId: String?

    /// Returns latest fetched data, or nil if never fetched.
    func currentStats() -> UsageStatsData? {
        latestData
    }

    /// Fetch from API and update latestData.
    func fetchAndCache() {
        Task {
            guard let creds = readCredentials() else { return }
            guard let data = await callUsageAPI(token: creds.accessToken, accountId: creds.accountId) else { return }

            Self.log.info("Codex usage: primary=\(data.currentPct)% secondary=\(data.weeklyPct)%")

            await MainActor.run {
                self.latestData = data
            }
        }
    }

    // MARK: - Credentials

    private struct Credentials {
        let accessToken: String
        let accountId: String?
    }

    /// Reads OAuth token from ~/.codex/auth.json.
    private func readCredentials() -> Credentials? {
        // Return cached if available
        if let token = cachedToken {
            return Credentials(accessToken: token, accountId: cachedAccountId)
        }

        guard FileManager.default.fileExists(atPath: Self.authPath.path) else {
            Self.log.debug("Codex auth.json not found — run `codex` to log in")
            return nil
        }

        guard let data = try? Data(contentsOf: Self.authPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            Self.log.error("Failed to read or parse ~/.codex/auth.json")
            return nil
        }

        // Check for API key first (non-OAuth mode)
        if let apiKey = json["OPENAI_API_KEY"] as? String, !apiKey.isEmpty {
            cachedToken = apiKey
            cachedAccountId = nil
            return Credentials(accessToken: apiKey, accountId: nil)
        }

        // OAuth tokens
        guard let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty
        else {
            Self.log.debug("Codex auth.json has no tokens — run `codex` to log in")
            return nil
        }

        let accountId = tokens["account_id"] as? String
        cachedToken = accessToken
        cachedAccountId = accountId
        return Credentials(accessToken: accessToken, accountId: accountId)
    }

    // MARK: - API Call

    private func callUsageAPI(token: String, accountId: String?) async -> UsageStatsData? {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("PixelAgents", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            let (d, r) = try await URLSession.shared.data(for: request)
            guard let hr = r as? HTTPURLResponse else {
                Self.log.error("Codex API response is not HTTP")
                return nil
            }
            responseData = d
            httpResponse = hr
        } catch {
            Self.log.error("Codex API request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            Self.log.error("Codex OAuth token expired or invalid — run `codex` to re-authenticate")
            cachedToken = nil  // Force re-read on next attempt
            return nil
        default:
            let body = String(data: responseData.prefix(256), encoding: .utf8) ?? "<binary>"
            Self.log.error("Codex API returned HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            Self.log.error("Codex API returned 200 but response is not valid JSON")
            return nil
        }

        let rateLimit = json["rate_limit"] as? [String: Any]
        let primary = rateLimit?["primary_window"] as? [String: Any]
        let secondary = rateLimit?["secondary_window"] as? [String: Any]

        let currentPct = clampPct(primary?["used_percent"])
        let weeklyPct = clampPct(secondary?["used_percent"])
        let currentResetMin = minutesFromEpoch(primary?["reset_at"])
        let weeklyResetMin = minutesFromEpoch(secondary?["reset_at"])

        return UsageStatsData(
            currentPct: currentPct,
            weeklyPct: weeklyPct,
            currentResetMin: currentResetMin,
            weeklyResetMin: weeklyResetMin
        )
    }

    // MARK: - Parsing Helpers

    private func clampPct(_ value: Any?) -> UInt8 {
        if let num = value as? NSNumber {
            return UInt8(min(max(num.intValue, 0), 100))
        }
        return 0
    }

    /// Codex API returns `reset_at` as a Unix timestamp (seconds), not ISO 8601.
    private func minutesFromEpoch(_ value: Any?) -> UInt16 {
        guard let num = value as? NSNumber else { return 0 }
        let resetDate = Date(timeIntervalSince1970: num.doubleValue)
        let minutes = resetDate.timeIntervalSinceNow / 60.0
        let clamped = max(0.0, min(minutes, Double(UInt16.max)))
        return UInt16(clamped)
    }
}
