import Foundation
import os
import Security

/// Fetches usage stats directly from the Anthropic OAuth API, replacing the external
/// launchd-based fetch-usage.sh script. Reads the OAuth token from macOS Keychain
/// (stored by Claude Code), polls the API, and writes results to
/// ~/.claude/rate-limits-cache.json so both the macOS app and Python bridge can consume them.
///
/// Owned by BridgeService which drives the fetch timer alongside its other timers.
final class UsageStatsFetcher {

    // MARK: - Constants

    private static let log = Logger(subsystem: "com.pixelagents", category: "Usage")

    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let keychainService = "Claude Code-credentials"
    private let cachePath: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/rate-limits-cache.json")

    // MARK: - State

    /// Latest data from the API. Falls back to cache file if nil.
    private(set) var latestData: UsageStatsData?

    /// Cached OAuth token to avoid repeated Keychain prompts.
    /// Each access triggers a macOS Keychain permission dialog for dev-signed builds,
    /// so we cache the token and only re-read when it expires.
    private var cachedToken: String?
    private var cachedTokenExpiresAt: Double = 0

    /// Returns latest fetched data, or falls back to reading the cache file.
    func currentStats() -> UsageStatsData? {
        return latestData ?? UsageStatsReader.read()
    }

    /// Fetch from API and update cache. Call from a timer or on-demand.
    func fetchAndCache() {
        Task {
            guard let token = readOAuthToken() else {
                Self.log.warning("Skipping fetch — no valid OAuth token (missing, expired, or unreadable)")
                return
            }
            guard let data = await callUsageAPI(token: token) else { return }

            Self.log.info("Fetched: current=\(data.currentPct)% weekly=\(data.weeklyPct)%")

            await MainActor.run {
                self.latestData = data
            }

            writeCacheFile(data)
        }
    }

    // MARK: - Keychain

    /// Reads the Claude Code OAuth access token, returning a cached copy when still valid
    /// to avoid repeated Keychain access prompts on dev-signed builds.
    private func readOAuthToken() -> String? {
        // Return cached token if still valid (with 60s safety margin)
        let nowMs = Date().timeIntervalSince1970 * 1000
        if let token = cachedToken, cachedTokenExpiresAt > nowMs + 60_000 {
            return token
        }

        // Cache miss or expired — read from Keychain
        cachedToken = nil
        cachedTokenExpiresAt = 0

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            Self.log.error("Keychain lookup failed (status \(status)) — Claude Code OAuth token not found")
            return nil
        }
        guard let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String,
              !accessToken.isEmpty
        else {
            Self.log.error("Keychain data found but OAuth token missing or malformed")
            return nil
        }

        // Check expiry
        if let expiresAt = oauth["expiresAt"] as? Double {
            if expiresAt < nowMs {
                let expiredAgo = Int((nowMs - expiresAt) / 1000 / 60)
                Self.log.error("OAuth token expired \(expiredAgo) minutes ago — start Claude Code to refresh")
                return nil
            }
            cachedToken = accessToken
            cachedTokenExpiresAt = expiresAt
        } else {
            // No expiry info — cache for 1 hour as a reasonable default
            cachedToken = accessToken
            cachedTokenExpiresAt = nowMs + 3_600_000
        }

        return accessToken
    }

    // MARK: - API call

    private func callUsageAPI(token: String) async -> UsageStatsData? {
        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 30

        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            let (d, r) = try await URLSession.shared.data(for: request)
            guard let hr = r as? HTTPURLResponse else {
                Self.log.error("API response is not HTTP")
                return nil
            }
            responseData = d
            httpResponse = hr
        } catch {
            Self.log.error("API request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: responseData.prefix(256), encoding: .utf8) ?? "<binary>"
            Self.log.error("API returned HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            Self.log.error("API returned 200 but response is not valid JSON")
            return nil
        }

        let fiveHour = json["five_hour"] as? [String: Any]
        let sevenDay = json["seven_day"] as? [String: Any]

        let currentPct = clampPct(fiveHour?["utilization"])
        let weeklyPct = clampPct(sevenDay?["utilization"])
        let currentResetMin = minutesUntilReset(fiveHour?["resets_at"])
        let weeklyResetMin = minutesUntilReset(sevenDay?["resets_at"])

        return UsageStatsData(
            currentPct: currentPct,
            weeklyPct: weeklyPct,
            currentResetMin: currentResetMin,
            weeklyResetMin: weeklyResetMin
        )
    }

    // MARK: - Cache file writer

    private func writeCacheFile(_ stats: UsageStatsData) {
        let currentResetDate = Date().addingTimeInterval(Double(stats.currentResetMin) * 60)
        let weeklyResetDate = Date().addingTimeInterval(Double(stats.weeklyResetMin) * 60)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let cache: [String: Any] = [
            "current_pct": Int(stats.currentPct),
            "current_resets_at": fmt.string(from: currentResetDate),
            "weekly_pct": Int(stats.weeklyPct),
            "weekly_resets_at": fmt.string(from: weeklyResetDate),
            "updated_at": ISO8601DateFormatter().string(from: Date()),
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: cache,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            Self.log.error("Failed to serialize cache JSON")
            return
        }

        do {
            try data.write(to: cachePath, options: .atomic)
        } catch {
            Self.log.error("Failed to write cache file: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Parsing helpers

    private func clampPct(_ value: Any?) -> UInt8 {
        if let num = value as? NSNumber {
            return UInt8(min(max(num.intValue, 0), 100))
        }
        return 0
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func minutesUntilReset(_ value: Any?) -> UInt16 {
        guard let str = value as? String else { return 0 }
        let date = Self.isoFormatter.date(from: str) ?? Self.isoFormatterNoFrac.date(from: str)
        guard let resetDate = date else { return 0 }
        let minutes = resetDate.timeIntervalSinceNow / 60.0
        let clamped = max(0.0, min(minutes, Double(UInt16.max)))
        return UInt16(clamped)
    }
}
