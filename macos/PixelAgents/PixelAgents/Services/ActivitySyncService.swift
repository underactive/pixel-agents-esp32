import Foundation
import os

/// Syncs local activity heatmap data to iCloud Drive using per-device JSON files.
///
/// Each Mac writes its own `activity-{deviceId}.json` file to the iCloud container,
/// avoiding write conflicts. On startup and when remote files change (via NSMetadataQuery),
/// all remote device files are imported and merged into the local SQLite database using
/// a MAX strategy (higher count wins for each date/provider pair).
///
/// Degrades gracefully when iCloud is unavailable — sync is simply skipped.
///
/// **Prerequisite:** The iCloud entitlement `com.apple.developer.ubiquity-container-identifiers`
/// must be enabled in both the Apple Developer portal and `project.yml` for sync to function.
/// Without it, `url(forUbiquityContainerIdentifier:)` returns nil and sync is silently disabled.
@MainActor
final class ActivitySyncService {

    private static let log = Logger(subsystem: "com.pixelagents.companion", category: "ActivitySync")

    private nonisolated static let containerIdentifier = "iCloud.com.pixelagents.companion"
    private nonisolated static let deviceIdKey = "activitySyncDeviceId"

    private let database: ActivityDatabase

    /// True when local data has changed since last export.
    private(set) var needsExport = false

    /// Called when remote data is merged, so the caller can refresh heatmaps.
    var onRemoteDataMerged: (() -> Void)?

    /// iCloud container Documents directory (nil if iCloud unavailable).
    private var cloudDocsURL: URL?

    /// Metadata query for monitoring remote file changes.
    private var metadataQuery: NSMetadataQuery?

    /// Observer tokens for notification cleanup.
    private var queryObservers: [Any] = []

    /// This device's unique identifier (persisted in UserDefaults).
    private let deviceId: String

    /// Filename for this device's sync file.
    private var ownFilename: String { "activity-\(deviceId).json" }

    // MARK: - Lifecycle

    init(database: ActivityDatabase) {
        self.database = database

        // Get or create stable device ID
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIdKey) {
            self.deviceId = existing
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: Self.deviceIdKey)
            self.deviceId = newId
        }
    }

    /// Mark that local data changed and needs to be exported on the next cycle.
    func markNeedsExport() {
        needsExport = true
    }

    /// Check iCloud availability and start monitoring for remote changes.
    func start() {
        guard metadataQuery == nil else { return } // prevent double-start

        // Check iCloud availability (must be called on a background thread per Apple docs)
        Task.detached { [weak self] in
            let id = Self.containerIdentifier
            let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: id)
            await MainActor.run {
                guard let self = self else { return }
                guard let containerURL = containerURL else {
                    Self.log.info("iCloud unavailable — activity sync disabled")
                    return
                }

                let docsURL = containerURL.appendingPathComponent("Documents")

                // Create Documents directory if needed
                let fm = FileManager.default
                if !fm.fileExists(atPath: docsURL.path) {
                    try? fm.createDirectory(at: docsURL, withIntermediateDirectories: true)
                }

                self.cloudDocsURL = docsURL
                Self.log.info("iCloud sync enabled at \(docsURL.path)")

                // Import any existing remote data
                self.importFromCloud()

                // Start monitoring for remote changes
                self.startMetadataQuery()
            }
        }
    }

    /// Stop monitoring and clean up observers.
    func stop() {
        metadataQuery?.stop()
        metadataQuery = nil
        for observer in queryObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        queryObservers.removeAll()
    }

    // MARK: - Export

    /// Export local DB to this device's iCloud JSON file if needed.
    func exportIfNeeded() {
        guard needsExport, let docsURL = cloudDocsURL else { return }
        needsExport = false

        let rows = database.exportAllRows()
        guard !rows.isEmpty else { return }

        let payload = SyncPayload(
            version: 1,
            deviceId: deviceId,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            days: rows.map { SyncDay(date: $0.date, provider: $0.provider, count: $0.count) }
        )

        guard let data = try? JSONEncoder().encode(payload) else {
            Self.log.error("Failed to encode sync payload")
            return
        }

        let fileURL = docsURL.appendingPathComponent(ownFilename)
        do {
            try data.write(to: fileURL, options: .atomic)
            Self.log.debug("Exported \(rows.count) rows to iCloud")
        } catch {
            Self.log.error("Failed to write sync file: \(error.localizedDescription)")
        }
    }

    // MARK: - Import

    /// Import all remote device files and merge into local DB.
    func importFromCloud() {
        guard let docsURL = cloudDocsURL else { return }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: docsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        var totalMerged = 0
        for file in files {
            guard file.pathExtension == "json",
                  file.lastPathComponent.hasPrefix("activity-"),
                  file.lastPathComponent != ownFilename else { continue }

            guard let data = try? Data(contentsOf: file) else { continue }
            guard let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) else { continue }

            guard payload.version == 1 else {
                Self.log.info("Skipping \(file.lastPathComponent): unsupported version \(payload.version)")
                continue
            }

            let rows = payload.days.map { (date: $0.date, provider: $0.provider, count: $0.count) }
            database.mergeRows(rows)
            totalMerged += rows.count
        }

        if totalMerged > 0 {
            Self.log.info("Merged \(totalMerged) rows from remote devices")
            onRemoteDataMerged?()
        }
    }

    // MARK: - NSMetadataQuery

    private func startMetadataQuery() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        // NSMetadataQuery LIKE uses * as wildcard (not SQL %)
        query.predicate = NSPredicate(format: "%K LIKE 'activity-*.json'", NSMetadataItemFSNameKey)

        let gatherObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.importFromCloud()
            }
        }

        let updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.importFromCloud()
            }
        }

        queryObservers = [gatherObserver, updateObserver]
        query.start()
        self.metadataQuery = query
    }

    // MARK: - Codable Types

    private struct SyncPayload: Codable {
        let version: Int
        let deviceId: String
        let exportedAt: String
        let days: [SyncDay]
    }

    private struct SyncDay: Codable {
        let date: String
        let provider: String
        let count: Int
    }
}
