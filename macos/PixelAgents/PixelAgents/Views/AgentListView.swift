import SwiftUI

/// Displays the list of active agents with their current state.
struct AgentListView: View {
    let agents: [Agent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Agents (\(agents.count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            if agents.isEmpty {
                Text("No active agents")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            } else {
                ForEach(agents) { agent in
                    AgentRow(agent: agent)
                }
            }
        }
    }
}

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 8) {
            Text("#\(agent.id)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            Circle()
                .fill(stateColor)
                .frame(width: 6, height: 6)

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
        default:       return .purple
        }
    }
}
