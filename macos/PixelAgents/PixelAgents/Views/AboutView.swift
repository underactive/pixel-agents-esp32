import SwiftUI

/// About window content: centered app icon, name, version, and GitHub link.
struct AboutView: View {
    private static let githubURL = URL(string: "https://github.com/underactive/pixel-agents-esp32")

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
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
