import SwiftUI

/// Simplified Canvas heatmap for widget display.
/// 53-week × 7-day contribution grid without interactive elements.
struct WidgetHeatmapView: View {
    let data: ActivityHeatmapData
    let colors: [Color]

    private let cellSize: CGFloat = 4
    private let cellGap: CGFloat = 1
    private let weeks = 53
    private let daysPerWeek = 7

    var body: some View {
        Canvas { context, size in
            let totalW = CGFloat(weeks) * (cellSize + cellGap)
            let totalH = CGFloat(daysPerWeek) * (cellSize + cellGap)
            let offsetX = max(0, (size.width - totalW) / 2)
            let offsetY = max(0, (size.height - totalH) / 2)

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Find the Sunday of the current week
            let weekday = calendar.component(.weekday, from: today)
            let sundayOffset = -(weekday - 1)
            guard let currentSunday = calendar.date(byAdding: .day, value: sundayOffset, to: today) else { return }

            for week in 0..<weeks {
                let weekOffset = week - (weeks - 1)
                for day in 0..<daysPerWeek {
                    guard let cellDate = calendar.date(byAdding: .day, value: weekOffset * 7 + day, to: currentSunday) else { continue }
                    if cellDate > today { continue }

                    let count = data.days[calendar.startOfDay(for: cellDate)] ?? 0
                    let level = data.level(for: count)
                    let color = level < colors.count ? colors[level] : colors[0]

                    let x = offsetX + CGFloat(week) * (cellSize + cellGap)
                    let y = offsetY + CGFloat(day) * (cellSize + cellGap)
                    let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                    context.fill(RoundedRectangle(cornerRadius: 1).path(in: rect), with: .color(color))
                }
            }
        }
        .frame(height: CGFloat(daysPerWeek) * (cellSize + cellGap))
    }
}
