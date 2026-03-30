import Foundation

/// App Group constants shared between the main app and the widget extension.
enum AppGroupConstants {
    static let suiteName = "group.com.pixelagents.companion"

    /// Shared UserDefaults for widget data.
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Container URL for shared files (SQLite database).
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }
}

/// UserDefaults keys for shared widget data.
enum SharedUsageKeys {
    static let claudeUsage = "widget.claude.usage"
    static let codexUsage = "widget.codex.usage"
    static let geminiUsage = "widget.gemini.usage"
    static let cursorUsage = "widget.cursor.usage"
    static let lastUpdated = "widget.lastUpdated"

    /// Which provider is selected for the large widget heatmap.
    static let selectedProvider = "widget.selectedProvider"

    /// Shared SQLite database filename.
    static let heatmapDBFilename = "activity.db"
}
