import Foundation
import SQLite3
import os

/// SQLITE_TRANSIENT tells SQLite to copy the bound string immediately,
/// avoiding dangling pointers from temporary NSString bridges.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Persists daily tool-call counts for Claude, Codex, and Gemini in a local SQLite database.
/// Used to power activity heatmaps for providers that lack external analytics APIs.
///
/// Database location: ~/Library/Application Support/com.pixelagents.companion/activity.db
///
/// Thread safety: All access is serialized via `@MainActor`. The `SQLITE_OPEN_NOMUTEX` flag
/// relies on this guarantee — do not access from background threads.
@MainActor
final class ActivityDatabase {

    static let shared = ActivityDatabase()

    private static let log = Logger(subsystem: "com.pixelagents.companion", category: "ActivityDatabase")

    private var db: OpaquePointer?

    /// Date formatter for YYYY-MM-DD keys (local timezone).
    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    // MARK: - Lifecycle

    private init() {
        openDatabase()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Setup

    private func openDatabase() {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.pixelagents.companion")

        // Create directory if needed
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                Self.log.error("Failed to create activity DB directory: \(error.localizedDescription)")
                return
            }
        }

        let dbPath = dir.appendingPathComponent("activity.db").path
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            Self.log.error("Failed to open activity database at \(dbPath)")
            return
        }

        sqlite3_busy_timeout(db, 1000)

        // WAL mode for concurrent reads
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)

        // Create table
        let createSQL = """
            CREATE TABLE IF NOT EXISTS daily_activity (
                date     TEXT NOT NULL,
                provider TEXT NOT NULL,
                count    INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (date, provider)
            )
            """
        if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
            Self.log.error("Failed to create daily_activity table")
        }
    }

    // MARK: - Recording

    /// Increment today's tool call count for a provider.
    func recordToolCall(provider: String) {
        guard let db = db else { return }

        let today = dateFmt.string(from: Date())
        let sql = """
            INSERT INTO daily_activity (date, provider, count)
            VALUES (?1, ?2, 1)
            ON CONFLICT(date, provider) DO UPDATE SET count = count + 1
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Self.log.error("Failed to prepare recordToolCall statement")
            return
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (today as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (provider as NSString).utf8String, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) != SQLITE_DONE {
            Self.log.error("Failed to record tool call for \(provider)")
        }
    }

    // MARK: - Loading

    /// Days of history to load — 366 to cover a full 53-week grid plus leap year margin.
    private static let heatmapHistoryDays = 366

    /// Load activity for a provider over the heatmap window, returning heatmap data.
    func loadHeatmapData(provider: String) -> ActivityHeatmapData {
        guard let db = db else { return .empty }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.heatmapHistoryDays, to: Date()) ?? Date()
        let cutoff = dateFmt.string(from: cutoffDate)

        let sql = "SELECT date, count FROM daily_activity WHERE provider = ?1 AND date >= ?2 ORDER BY date"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            Self.log.error("Failed to prepare loadHeatmapData query")
            return .empty
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (provider as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (cutoff as NSString).utf8String, -1, SQLITE_TRANSIENT)

        var rows: [(String, Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
            let dateStr = String(cString: cStr)
            let count = Int(sqlite3_column_int(stmt, 1))
            rows.append((dateStr, count))
        }

        return ActivityHeatmapData.from(rows: rows)
    }
}
