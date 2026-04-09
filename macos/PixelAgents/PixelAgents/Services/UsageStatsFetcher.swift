import Foundation
import os

/// Fetches usage stats directly from the Anthropic OAuth API and writes results to
/// ~/.claude/rate-limits-cache.json so both the macOS app and Python bridge can consume them.
///
/// Token management is delegated to ClaudeAuthService, which stores tokens in the app's
/// own Keychain entry (no system permission dialogs).
///
/// Owned by BridgeService which drives the fetch timer alongside its other timers.
@MainActor
final class UsageStatsFetcher {

    // MARK: - Constants

    private static let log = Logger(subsystem: "com.pixelagents", category: "Usage")

    private let apiURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let cachePath: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/rate-limits-cache.json")

    // MARK: - State

    /// Latest data from the API. Falls back to cache file if nil.
    private(set) var latestData: UsageStatsData?

    /// Auth service for token management (injected by BridgeService).
    var authService: ClaudeAuthService?

    /// Returns latest fetched data, or falls back to reading the cache file.
    func currentStats() -> UsageStatsData? {
        return latestData ?? UsageStatsReader.read()
    }

    /// Fetch from API and update cache. Call from a timer or on-demand.
    func fetchAndCache() {
        Task {
            guard let token = authService?.readToken() else {
                Self.log.warning("Skipping fetch — no valid OAuth token (not signed in or expired)")
                return
            }
            guard let response = await callUsageAPI(token: token) else { return }

            Self.log.info("Fetched: current=\(response.stats.currentPct)% weekly=\(response.stats.weeklyPct)%")

            self.latestData = response.stats

            writeCacheFile(response)
        }
    }

    // MARK: - Private response type

    private struct APIResponse {
        let stats: UsageStatsData
        let currentResetsAt: String
        let weeklyResetsAt: String
        let extraSpent: Double
        let extraLimit: Int
    }

    // MARK: - API call

    private func callUsageAPI(token: String) async -> APIResponse? {
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
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                authService?.handleTokenExpired()
            }
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
        let extraUsage = json["extra_usage"] as? [String: Any]

        let currentResetsAt = fiveHour?["resets_at"] as? String ?? ""
        let weeklyResetsAt = sevenDay?["resets_at"] as? String ?? ""

        let stats = UsageStatsData(
            currentPct: clampPct(fiveHour?["utilization"]),
            weeklyPct: clampPct(sevenDay?["utilization"]),
            currentResetMin: minutesUntilReset(currentResetsAt),
            weeklyResetMin: minutesUntilReset(weeklyResetsAt)
        )

        return APIResponse(
            stats: stats,
            currentResetsAt: currentResetsAt,
            weeklyResetsAt: weeklyResetsAt,
            extraSpent: (extraUsage?["used_credits"] as? NSNumber)?.doubleValue ?? 0,
            extraLimit: (extraUsage?["monthly_limit"] as? NSNumber)?.intValue ?? 0
        )
    }

    // MARK: - Cache file writer

    private func writeCacheFile(_ response: APIResponse) {
        let cache: [String: Any] = [
            "current_pct": Int(response.stats.currentPct),
            "current_resets_at": response.currentResetsAt,
            "weekly_pct": Int(response.stats.weeklyPct),
            "weekly_resets_at": response.weeklyResetsAt,
            "extra_spent": response.extraSpent,
            "extra_limit": response.extraLimit,
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

    private func minutesUntilReset(_ iso: String) -> UInt16 {
        guard !iso.isEmpty else { return 0 }
        let date = Self.isoFormatter.date(from: iso) ?? Self.isoFormatterNoFrac.date(from: iso)
        guard let resetDate = date else { return 0 }
        let minutes = resetDate.timeIntervalSinceNow / 60.0
        let clamped = max(0.0, min(minutes, Double(UInt16.max)))
        return UInt16(clamped)
    }
}
