import SwiftUI

/// systemMedium: usage bars (current + weekly) for all providers side-by-side.
struct WidgetMediumView: View {
    let entry: UsageEntry

    var body: some View {
        let providers = entry.providers.filter { $0.usage != nil }
        let display = providers.isEmpty ? entry.providers : providers

        HStack(alignment: .top, spacing: 8) {
            ForEach(Array(display.prefix(4))) { snapshot in
                MediumProviderColumn(snapshot: snapshot)
            }
        }
        .padding(4)
    }
}

private struct MediumProviderColumn: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        let brandColor = snapshot.provider.brandColor
        let currentPct = Int(snapshot.usage?.currentPct ?? 0)
        let weeklyPct = Int(snapshot.usage?.weeklyPct ?? 0)
        let resetMin = snapshot.usage?.currentResetMin ?? 0

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                BrandIconView(icon: snapshot.provider.brandIcon, size: 10, color: brandColor)
                Text(snapshot.provider.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }

            // Current bar
            WidgetUsageBar(pct: currentPct, color: brandColor, height: 5)
            Text("Current \(currentPct)%")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary)

            // Weekly bar
            if weeklyPct > 0 || (snapshot.usage?.weeklyResetMin ?? 0) > 0 {
                WidgetUsageBar(pct: weeklyPct, color: brandColor, height: 5)
                Text("Weekly \(weeklyPct)%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Reset countdown
            if resetMin > 0 {
                Text("Resets \(formatMinutes(resetMin))")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func formatMinutes(_ minutes: UInt16) -> String {
    let mins = Int(minutes)
    if mins < 60 { return "\(mins)m" }
    let hours = mins / 60
    let remainMins = mins % 60
    if hours < 24 { return "\(hours)h \(remainMins)m" }
    let days = hours / 24
    let remainHours = hours % 24
    return "\(days)d \(remainHours)h"
}
