import SwiftUI

/// Displays connection status with colored indicator dot and transport info.
struct ConnectionStatusView: View {
    let state: ConnectionState
    var batteryLevel: UInt8? = nil

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer()

            if let level = batteryLevel {
                HStack(spacing: 3) {
                    Image(systemName: batteryIconName(level))
                        .foregroundColor(batteryColor(level))
                        .font(.system(size: 11))
                    Text("\(level)%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(batteryColor(level))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var dotColor: Color {
        switch state {
        case .disconnected: return .red
        case .connecting:   return .orange
        case .connected:    return .green
        }
    }

    private var statusText: String {
        switch state {
        case .disconnected:        return "Disconnected"
        case .connecting:          return "Connecting..."
        case .connected(let info): return info
        }
    }

    private func batteryIconName(_ level: UInt8) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        case 1...25:   return "battery.25"
        default:       return "battery.0"
        }
    }

    private func batteryColor(_ level: UInt8) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .yellow }
        return .red
    }
}
