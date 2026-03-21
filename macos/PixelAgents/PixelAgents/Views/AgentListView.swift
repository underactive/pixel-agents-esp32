import SwiftUI

/// Displays all 6 character slots with their current state.
struct AgentListView: View {
    let agents: [Agent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Agents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            ForEach(agents) { agent in
                AgentRow(agent: agent)
            }
        }
    }
}

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 6, height: 6)

            if agent.state != .offline {
                Image(systemName: agent.source == .claude ? "sparkle" : "apple.terminal")
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
            }

            Text(agent.state.label)
                .font(.system(size: 12, weight: .medium))

            if !agent.toolName.isEmpty {
                Text("(\(agent.toolName))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }

    private var stateColor: Color {
        switch agent.state {
        case .type:    return .green
        case .read:    return .blue
        case .idle:    return .yellow
        case .walk:    return .orange
        case .offline: return .gray
        case .spawn, .despawn: return .purple
        }
    }
}
