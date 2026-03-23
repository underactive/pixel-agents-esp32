import SwiftUI

/// About window content: centered app icon, name, version, and GitHub link.
struct AboutView: View {
    private static let githubURL = URL(string: "https://github.com/underactive/pixel-agents-esp32")
    private static let kofiURL = URL(string: "https://ko-fi.com/Q5Q06RX1Z")

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

            if let url = Self.kofiURL {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("☕")
                        Text("Support me on Ko-fi")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: NSColor(red: 0x72/255, green: 0xa4/255, blue: 0xf2/255, alpha: 1)))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
