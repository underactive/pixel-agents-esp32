import AppIntents
import WidgetKit

/// Interactive intent: tapping a provider tab in the large widget switches the heatmap.
/// Stores the selection in shared UserDefaults and reloads the timeline.
struct SelectProviderIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Provider"
    static var description: IntentDescription = "Switch which provider's heatmap is shown."

    @Parameter(title: "Provider")
    var providerRaw: String

    init() {
        self.providerRaw = WidgetProvider.claude.rawValue
    }

    init(provider: WidgetProvider) {
        self.providerRaw = provider.rawValue
    }

    func perform() async throws -> some IntentResult {
        AppGroupConstants.sharedDefaults?.set(providerRaw, forKey: SharedUsageKeys.selectedProvider)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
