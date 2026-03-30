import SwiftUI

/// systemSmall: compact 2x2 grid with brand icon + percentage bar per provider.
struct WidgetSmallView: View {
    let entry: UsageEntry

    var body: some View {
        let providers = entry.providers.filter { $0.usage != nil }
        let display = providers.isEmpty ? entry.providers : providers

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(display.prefix(4))) { snapshot in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        BrandIconView(icon: snapshot.provider.brandIcon, size: 10, color: snapshot.provider.brandColor)
                        Text(snapshot.provider.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    WidgetUsageBar(pct: Int(snapshot.usage?.currentPct ?? 0), color: snapshot.provider.brandColor, height: 3)

                    Text("\(Int(snapshot.usage?.currentPct ?? 0))%")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(4)
    }
}
