import SwiftUI
import WidgetKit

/// Routes to the appropriate view based on widget size.
struct UsageWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            WidgetSmallView(entry: entry)
        case .systemMedium:
            WidgetMediumView(entry: entry)
        case .systemLarge:
            WidgetLargeView(entry: entry)
        default:
            WidgetMediumView(entry: entry)
        }
    }
}
