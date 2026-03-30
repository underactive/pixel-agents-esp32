import SwiftUI

/// systemLarge: tappable provider tabs at top + activity heatmap for the selected provider.
struct WidgetLargeView: View {
    let entry: UsageEntry

    var body: some View {
        let selected = entry.selectedProvider
        let selectedSnapshot = entry.providers.first(where: { $0.provider == selected })
        let providers = entry.providers.filter { $0.usage != nil }
        let display = providers.isEmpty ? entry.providers : providers

        VStack(alignment: .leading, spacing: 8) {
            // Tappable provider tabs — each is a Button with SelectProviderIntent
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(display.prefix(4))) { snapshot in
                    Button(intent: SelectProviderIntent(provider: snapshot.provider)) {
                        LargeSummaryCell(snapshot: snapshot, isSelected: snapshot.provider == selected)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Heatmap for selected provider
            if let snapshot = selectedSnapshot, let heatmap = snapshot.heatmapData {
                let brandColor = snapshot.provider.brandColor

                HStack(spacing: 4) {
                    BrandIconView(icon: snapshot.provider.brandIcon, size: 12, color: brandColor)
                    Text("\(snapshot.provider.displayName) Activity")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(formatCount(heatmap.totalCount))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                WidgetHeatmapView(data: heatmap, colors: snapshot.provider.heatmapColors)

                // Stats row
                HStack(spacing: 0) {
                    StatItem(label: "Current", value: "\(heatmap.currentStreak)d")
                    StatItem(label: "Longest", value: "\(heatmap.longestStreak)d")
                    if let mostActive = heatmap.mostActiveDay {
                        StatItem(label: "Most Active", value: formatDate(mostActive.date))
                    }
                }
            } else {
                Spacer()
                Text("No activity data for \(selected.displayName)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(4)
    }
}

private struct LargeSummaryCell: View {
    let snapshot: ProviderSnapshot
    let isSelected: Bool

    var body: some View {
        let brandColor = snapshot.provider.brandColor
        let currentPct = Int(snapshot.usage?.currentPct ?? 0)
        let weeklyPct = Int(snapshot.usage?.weeklyPct ?? 0)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                BrandIconView(icon: snapshot.provider.brandIcon, size: 10, color: brandColor)
                Text(snapshot.provider.displayName)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            WidgetUsageBar(pct: currentPct, color: brandColor, height: 3)
            if weeklyPct > 0 || (snapshot.usage?.weeklyResetMin ?? 0) > 0 {
                WidgetUsageBar(pct: weeklyPct, color: brandColor, height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(3)
        .background(isSelected ? brandColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
}

private struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 7))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func formatCount(_ count: Int) -> String {
    if count >= 1000 {
        return String(format: "%.1fk", Double(count) / 1000.0)
    }
    return "\(count)"
}

private let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

private func formatDate(_ date: Date) -> String {
    dateFormatter.string(from: date)
}
