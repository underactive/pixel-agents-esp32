import Foundation
import SQLite3
import os

/// Fetches usage stats from the Cursor API using the IDE's access token.
///
/// Auth pipeline:
/// 1. Read access token from Cursor's internal vscdb storage
///    (~/Library/Application Support/Cursor/User/globalStorage/state.vscdb)
/// 2. Call GET https://api2.cursor.sh/auth/usage-summary with Bearer auth
/// 3. Parse the usage-summary response (plan used/limit, billing cycle dates)
@MainActor
final class CursorUsageFetcher {

    private static let log = Logger(subsystem: "com.pixelagents", category: "CursorUsage")

    private static let usageSummaryURL = URL(string: "https://api2.cursor.sh/auth/usage-summary")!

    private static let vscdbPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }()

    // MARK: - State

    private(set) var latestData: UsageStatsData?

    /// Cached token to avoid re-reading the database on every poll.
    private var cachedToken: String?

    func currentStats() -> UsageStatsData? {
        latestData
    }

    /// Fetch from API and update latestData.
    func fetchAndCache() {
        Task {
            guard let token = readAccessToken() else { return }
            guard let data = await callUsageSummaryAPI(token: token) else { return }

            Self.log.info("Cursor usage: plan=\(data.currentPct)%")
            self.latestData = data
        }
    }

    // MARK: - Token Reading

    /// Read the access token from Cursor's internal vscdb SQLite database.
    private func readAccessToken() -> String? {
        // Return cached if available
        if let token = cachedToken {
            return token
        }

        guard FileManager.default.fileExists(atPath: Self.vscdbPath) else {
            Self.log.debug("Cursor state.vscdb not found — is Cursor installed?")
            return nil
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(Self.vscdbPath, &db, flags, nil) == SQLITE_OK else {
            Self.log.error("Failed to open Cursor state.vscdb")
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken' LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Self.log.error("Failed to prepare Cursor token query")
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cStr = sqlite3_column_text(stmt, 0) else {
            Self.log.debug("No access token found in Cursor state.vscdb — log in to Cursor")
            return nil
        }

        let token = String(cString: cStr)
        guard !token.isEmpty else { return nil }

        cachedToken = token
        return token
    }

    // MARK: - API Call

    private func callUsageSummaryAPI(token: String) async -> UsageStatsData? {
        var request = URLRequest(url: Self.usageSummaryURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("PixelAgents", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            let (d, r) = try await URLSession.shared.data(for: request)
            guard let hr = r as? HTTPURLResponse else {
                Self.log.error("Cursor API response is not HTTP")
                return nil
            }
            responseData = d
            httpResponse = hr
        } catch {
            Self.log.error("Cursor API request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401, 403:
            Self.log.error("Cursor access token expired — reopen Cursor to refresh")
            cachedToken = nil  // Force re-read on next attempt
            return nil
        default:
            let body = String(data: responseData.prefix(256), encoding: .utf8) ?? "<binary>"
            Self.log.error("Cursor API returned HTTP \(httpResponse.statusCode): \(body, privacy: .public)")
            return nil
        }

        return parseUsageSummary(responseData)
    }

    // MARK: - Response Parsing

    /// Parse the /auth/usage-summary response.
    ///
    /// Response shape:
    /// ```
    /// {
    ///   "billingCycleEnd": "2026-04-06T17:01:41.000Z",
    ///   "membershipType": "pro",
    ///   "individualUsage": {
    ///     "plan": { "used": 11, "limit": 2000, "totalPercentUsed": 0.056, ... },
    ///     "onDemand": { "enabled": false, "used": 0, ... }
    ///   }
    /// }
    /// ```
    private func parseUsageSummary(_ data: Data) -> UsageStatsData? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.log.error("Cursor API returned 200 but response is not valid JSON")
            return nil
        }

        let individual = json["individualUsage"] as? [String: Any]
        let plan = individual?["plan"] as? [String: Any]
        let onDemand = individual?["onDemand"] as? [String: Any]

        // Primary: plan usage (totalPercentUsed is 0-100 scale as a fraction, e.g. 0.44 = 0.44%)
        let totalPercentUsed = (plan?["totalPercentUsed"] as? NSNumber)?.doubleValue ?? 0
        // The API returns percent as a fraction of 100 (e.g. 0.44 means 0.44%), so round it
        let planPct = UInt8(min(100, max(0, totalPercentUsed.rounded())))

        // Secondary: on-demand usage (if enabled)
        var onDemandPct: UInt8 = 0
        if let onDemandEnabled = onDemand?["enabled"] as? Bool, onDemandEnabled {
            let used = (onDemand?["used"] as? NSNumber)?.doubleValue ?? 0
            let limit = (onDemand?["limit"] as? NSNumber)?.doubleValue ?? 0
            if limit > 0 {
                onDemandPct = UInt8(min(100, max(0, (used / limit) * 100)))
            }
        }

        // Reset time from billing cycle end
        let resetMin: UInt16
        if let cycleEnd = json["billingCycleEnd"] as? String {
            resetMin = minutesFromISO8601(cycleEnd)
        } else {
            resetMin = 0
        }

        return UsageStatsData(
            currentPct: planPct,
            weeklyPct: onDemandPct,
            currentResetMin: resetMin,
            weeklyResetMin: 0
        )
    }

    // MARK: - Helpers

    private func minutesFromISO8601(_ dateString: String) -> UInt16 {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return minutesUntil(date)
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return minutesUntil(date)
        }
        return 0
    }

    private func minutesUntil(_ date: Date) -> UInt16 {
        let minutes = date.timeIntervalSinceNow / 60.0
        let clamped = max(0.0, min(minutes, Double(UInt16.max)))
        return UInt16(clamped)
    }
}
