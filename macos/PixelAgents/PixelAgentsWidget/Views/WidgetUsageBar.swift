import SwiftUI

/// Simple non-interactive progress bar for widget use.
struct WidgetUsageBar: View {
    let pct: Int
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(pct >= 90 ? Color.red : color)
                    .frame(width: max(0, geo.size.width * CGFloat(min(pct, 100)) / 100.0))
            }
        }
        .frame(height: height)
    }
}
