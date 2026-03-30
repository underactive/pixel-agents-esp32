import Foundation
import SQLite3

/// Read-only heatmap data loader for the widget extension.
/// Opens the shared SQLite database from the App Group container.
final class SharedHeatmapReader {

    static let shared = SharedHeatmapReader()

    private let dbURL: URL? = {
        AppGroupConstants.containerURL?
            .appendingPathComponent(SharedUsageKeys.heatmapDBFilename)
    }()

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    /// Load heatmap rows for a provider. Returns (dateString, count) tuples.
    func loadRows(provider: String) -> [(String, Int)] {
        guard let dbURL = dbURL else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        sqlite3_busy_timeout(db, 500)

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -366, to: Date()) ?? Date()
        let cutoff = dateFmt.string(from: cutoffDate)

        let sql = "SELECT date, count FROM daily_activity WHERE provider = ?1 AND date >= ?2 ORDER BY date"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let SQLITE_TRANSIENT_PTR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, (provider as NSString).utf8String, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 2, (cutoff as NSString).utf8String, -1, SQLITE_TRANSIENT_PTR)

        var rows: [(String, Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cStr = sqlite3_column_text(stmt, 0) else { continue }
            rows.append((String(cString: cStr), Int(sqlite3_column_int(stmt, 1))))
        }
        return rows
    }
}
