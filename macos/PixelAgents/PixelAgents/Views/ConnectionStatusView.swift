import SwiftUI

/// Displays connection status with colored indicator dot and transport info.
struct ConnectionStatusView: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
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
}
