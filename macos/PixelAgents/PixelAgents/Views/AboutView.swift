import SwiftUI
import Sparkle

/// About window content: centered app icon, name, version, GitHub link,
/// check-for-updates button with last-checked timestamp, and Ko-fi link.
struct AboutView: View {
    let updater: SPUUpdater
    @ObservedObject var bridge: BridgeService

    private static let githubURL = URL(string: "https://github.com/underactive/pixel-agents-esp32")
    private static let kofiURL = URL(string: "https://ko-fi.com/Q5Q06RX1Z")

    @State private var lastCheckDate: Date?

    var body: some View {
        VStack(spacing: 12) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text("Pixel Agents")
                .font(.title2.weight(.semibold))

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let url = Self.githubURL {
                Link("GitHub", destination: url)
                    .font(.subheadline)
            }

            if !bridge.providerStatuses.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(UsageProvider.allCases.filter { bridge.providerStatuses[$0] != nil }, id: \.self) { provider in
                        if let result = bridge.providerStatuses[provider] {
                            Text("\(provider.displayName) status last checked: \(result.lastChecked.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            VStack(spacing: 4) {
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                    lastCheckDate = updater.lastUpdateCheckDate
                }
                .font(.subheadline)

                Text(lastCheckDateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .onAppear { lastCheckDate = updater.lastUpdateCheckDate }

            if let url = Self.kofiURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("☕ Support me on Ko-fi")
                }
                .font(.subheadline)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var lastCheckDateText: String {
        guard let date = lastCheckDate else { return "Last checked on: Never" }
        return "Last checked on: \(date.formatted(date: .abbreviated, time: .shortened))"
    }
}
