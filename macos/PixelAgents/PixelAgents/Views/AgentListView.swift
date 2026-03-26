import SwiftUI

/// Displays all 6 character slots with their current state.
struct AgentListView: View {
    let agents: [Agent]

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Agents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
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
            if agent.state == .offline {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 6, height: 6)
            } else {
                BrandIconView(icon: agent.brandIcon, size: 10, color: agent.brandColor)
            }

            Text(agent.state.label)
                .font(.system(size: 12, weight: .medium))

            if !agent.toolName.isEmpty {
                Text("(\(agent.toolName))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .clipped()
    }
}
