import WidgetKit
import SwiftUI

/// Timeline entry with all data needed to render the widget.
struct UsageEntry: TimelineEntry {
    let date: Date
    let providers: [ProviderSnapshot]
    let selectedProvider: WidgetProvider

    static let placeholder = UsageEntry(
        date: Date(),
        providers: WidgetProvider.allCases.map { .placeholder(for: $0) },
        selectedProvider: .claude
    )
}

/// Snapshot of a single provider's data for widget rendering.
struct ProviderSnapshot: Identifiable {
    let provider: WidgetProvider
    let usage: SharedProviderUsage?
    let heatmapData: ActivityHeatmapData?
    var id: String { provider.rawValue }

    static func placeholder(for provider: WidgetProvider) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            usage: SharedProviderUsage(currentPct: 42, weeklyPct: 67, currentResetMin: 180, weeklyResetMin: 4320),
            heatmapData: nil
        )
    }
}

// MARK: - Timeline Provider

struct UsageTimelineProvider: TimelineProvider {
    typealias Entry = UsageEntry

    private let decoder = JSONDecoder()

    func placeholder(in context: Context) -> UsageEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> UsageEntry {
        let defaults = AppGroupConstants.sharedDefaults

        // Read user's selected provider (persisted by SelectProviderIntent)
        let selectedRaw = defaults?.string(forKey: SharedUsageKeys.selectedProvider) ?? WidgetProvider.claude.rawValue
        let selected = WidgetProvider(rawValue: selectedRaw) ?? .claude

        let providers = WidgetProvider.allCases.map { provider -> ProviderSnapshot in
            let usage: SharedProviderUsage? = {
                guard let data = defaults?.data(forKey: provider.usageDefaultsKey) else { return nil }
                return try? decoder.decode(SharedProviderUsage.self, from: data)
            }()

            // Only load heatmap for the selected provider
            let heatmap: ActivityHeatmapData? = {
                guard provider == selected else { return nil }
                let rows = SharedHeatmapReader.shared.loadRows(provider: provider.heatmapDBKey)
                guard !rows.isEmpty else { return nil }
                return ActivityHeatmapData.from(rows: rows)
            }()

            return ProviderSnapshot(provider: provider, usage: usage, heatmapData: heatmap)
        }

        return UsageEntry(date: Date(), providers: providers, selectedProvider: selected)
    }
}

// MARK: - Widget Definition

struct UsageStatsWidget: Widget {
    let kind: String = "UsageStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: UsageTimelineProvider()
        ) { entry in
            UsageWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Usage Stats")
        .description("Monitor AI provider usage and activity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
