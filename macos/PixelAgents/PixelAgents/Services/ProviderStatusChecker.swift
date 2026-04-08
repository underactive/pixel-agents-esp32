import Foundation
import os

/// Polls provider status pages for active incidents affecting their APIs.
///
/// Supports Atlassian Statuspage v2 (Claude, Codex, Cursor) and Google Cloud Status (Gemini).
/// Called by BridgeService on the same 15-minute interval as usage fetchers.
@MainActor
final class ProviderStatusChecker {

    private static let log = Logger(subsystem: "com.pixelagents", category: "ProviderStatus")

    // MARK: - State

    /// Latest status result per provider. Updated after each check cycle.
    private(set) var results: [UsageProvider: ProviderStatusResult] = [:]

    // MARK: - Provider Configuration

    private struct StatuspageConfig {
        let componentsURL: URL
        let incidentsURL: URL
        let componentId: String
        let statusPageURL: URL
        /// If true, incidents endpoint returns all incidents (must filter out resolved).
        /// If false, endpoint returns only unresolved incidents.
        let incidentsIncludeResolved: Bool
    }

    private static let statuspageConfigs: [UsageProvider: StatuspageConfig] = [
        .claude: StatuspageConfig(
            componentsURL: URL(string: "https://status.anthropic.com/api/v2/components.json")!,
            incidentsURL: URL(string: "https://status.anthropic.com/api/v2/incidents/unresolved.json")!,
            componentId: "k8w3r06qmzrp",
            statusPageURL: URL(string: "https://status.claude.com")!,
            incidentsIncludeResolved: false
        ),
        .codex: StatuspageConfig(
            componentsURL: URL(string: "https://status.openai.com/api/v2/components.json")!,
            incidentsURL: URL(string: "https://status.openai.com/api/v2/incidents.json")!,
            componentId: "01KMP3KP5MGE23B80K1EK4S8PV",
            statusPageURL: URL(string: "https://status.openai.com")!,
            incidentsIncludeResolved: true
        ),
        .cursor: StatuspageConfig(
            componentsURL: URL(string: "https://status.cursor.com/api/v2/components.json")!,
            incidentsURL: URL(string: "https://status.cursor.com/api/v2/incidents/unresolved.json")!,
            componentId: "92rkl6jnscl8",
            statusPageURL: URL(string: "https://status.cursor.com")!,
            incidentsIncludeResolved: false
        ),
    ]

    private static let geminiIncidentsURL = URL(string: "https://status.cloud.google.com/incidents.json")!
    private static let geminiProductId = "Z0FZJAMvEB4j3NbCJs6B"
    private static let geminiStatusPageURL = URL(string: "https://status.cloud.google.com")!

    // MARK: - Public API

    /// Check status for all configured providers. Non-configured providers are skipped.
    func checkAll(configured: Set<UsageProvider>) {
        Task {
            await withTaskGroup(of: (UsageProvider, ProviderStatusResult).self) { group in
                for provider in configured {
                    group.addTask { [self] in
                        let result: ProviderStatusResult
                        if provider == .gemini {
                            result = await self.fetchGoogleStatus()
                        } else if let config = Self.statuspageConfigs[provider] {
                            result = await self.fetchStatuspageStatus(provider: provider, config: config)
                        } else {
                            result = ProviderStatusResult(provider: provider, incident: nil, lastChecked: Date())
                        }
                        return (provider, result)
                    }
                }
                for await (provider, result) in group {
                    results[provider] = result
                }
            }
        }
    }

    // MARK: - Atlassian Statuspage (Claude, Codex, Cursor)

    private func fetchStatuspageStatus(provider: UsageProvider, config: StatuspageConfig) async -> ProviderStatusResult {
        let now = Date()

        // Step 1: Check component status
        guard let componentsJSON = await fetchJSON(from: config.componentsURL) else {
            return ProviderStatusResult(provider: provider, incident: nil, lastChecked: now)
        }

        guard let components = componentsJSON["components"] as? [[String: Any]] else {
            Self.log.error("\(provider.displayName, privacy: .public) status: missing components array")
            return ProviderStatusResult(provider: provider, incident: nil, lastChecked: now)
        }

        let target = components.first { ($0["id"] as? String) == config.componentId }
        let componentStatus = target?["status"] as? String ?? "operational"

        guard componentStatus != "operational" else {
            return ProviderStatusResult(provider: provider, incident: nil, lastChecked: now)
        }

        // Step 2: Component is non-operational — fetch incidents for the title
        let severity = severityFromComponentStatus(componentStatus)
        guard let incidentsJSON = await fetchJSON(from: config.incidentsURL) else {
            // Have severity from component but no incident title — use a generic title
            let incident = ProviderIncident(
                id: "\(provider.rawValue)-\(componentStatus)",
                title: "\(provider.displayName) API: \(componentStatus.replacingOccurrences(of: "_", with: " "))",
                severity: severity,
                statusPageURL: config.statusPageURL
            )
            return ProviderStatusResult(provider: provider, incident: incident, lastChecked: now)
        }

        guard let incidents = incidentsJSON["incidents"] as? [[String: Any]] else {
            let incident = ProviderIncident(
                id: "\(provider.rawValue)-\(componentStatus)",
                title: "\(provider.displayName) API: \(componentStatus.replacingOccurrences(of: "_", with: " "))",
                severity: severity,
                statusPageURL: config.statusPageURL
            )
            return ProviderStatusResult(provider: provider, incident: incident, lastChecked: now)
        }

        // Filter to unresolved if endpoint includes resolved incidents (Codex)
        let activeIncidents: [[String: Any]]
        if config.incidentsIncludeResolved {
            activeIncidents = incidents.filter { incident in
                let status = incident["status"] as? String ?? ""
                return status != "resolved" && status != "postmortem"
            }
        } else {
            activeIncidents = incidents
        }

        // Find the first incident that affects our target component
        let matchingIncident = activeIncidents.first { incident in
            guard let affectedComponents = incident["components"] as? [[String: Any]] else { return false }
            return affectedComponents.contains { ($0["id"] as? String) == config.componentId }
        } ?? activeIncidents.first  // Fallback: use first active incident if no component match

        if let match = matchingIncident,
           let incidentId = match["id"] as? String,
           let incidentName = match["name"] as? String {
            let impact = match["impact"] as? String
            let incidentSeverity = severityFromImpact(impact) ?? severity
            let incident = ProviderIncident(
                id: incidentId,
                title: incidentName,
                severity: incidentSeverity,
                statusPageURL: config.statusPageURL
            )
            return ProviderStatusResult(provider: provider, incident: incident, lastChecked: now)
        }

        // Component degraded but no matching incident — use generic
        let incident = ProviderIncident(
            id: "\(provider.rawValue)-\(componentStatus)",
            title: "\(provider.displayName) API: \(componentStatus.replacingOccurrences(of: "_", with: " "))",
            severity: severity,
            statusPageURL: config.statusPageURL
        )
        return ProviderStatusResult(provider: provider, incident: incident, lastChecked: now)
    }

    // MARK: - Google Cloud Status (Gemini)

    private func fetchGoogleStatus() async -> ProviderStatusResult {
        let now = Date()

        guard let incidentsArray = await fetchJSONArray(from: Self.geminiIncidentsURL) else {
            return ProviderStatusResult(provider: .gemini, incident: nil, lastChecked: now)
        }

        // Find active incidents affecting the Gemini API product
        let activeGeminiIncident = incidentsArray.first { incident in
            // Must be an active incident (no end date)
            if incident["end"] is String { return false }

            // Must affect the Gemini API product
            guard let products = incident["affected_products"] as? [[String: Any]] else { return false }
            return products.contains { ($0["id"] as? String) == Self.geminiProductId }
        }

        guard let match = activeGeminiIncident,
              let incidentId = match["id"] as? String else {
            return ProviderStatusResult(provider: .gemini, incident: nil, lastChecked: now)
        }

        let title = match["external_desc"] as? String ?? "Gemini API incident"
        let statusImpact = match["status_impact"] as? String ?? ""
        let severity = severityFromGoogleStatus(statusImpact)

        let incident = ProviderIncident(
            id: incidentId,
            title: title,
            severity: severity,
            statusPageURL: Self.geminiStatusPageURL
        )
        return ProviderStatusResult(provider: .gemini, incident: incident, lastChecked: now)
    }

    // MARK: - HTTP

    private func fetchJSON(from url: URL) async -> [String: Any]? {
        guard let data = await fetchData(from: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.log.error("Status response is not a JSON object: \(url.absoluteString, privacy: .public)")
            return nil
        }
        return json
    }

    private func fetchJSONArray(from url: URL) async -> [[String: Any]]? {
        guard let data = await fetchData(from: url) else { return nil }
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            Self.log.error("Status response is not a JSON array: \(url.absoluteString, privacy: .public)")
            return nil
        }
        return array
    }

    private func fetchData(from url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                Self.log.error("Status API returned HTTP \(code): \(url.absoluteString, privacy: .public)")
                return nil
            }
            return data
        } catch {
            Self.log.error("Status API request failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Severity Mapping

    /// Map Statuspage component status to severity.
    private func severityFromComponentStatus(_ status: String) -> ProviderStatusSeverity {
        switch status {
        case "partial_outage", "major_outage":
            return .outage
        default: // degraded_performance, under_maintenance
            return .degraded
        }
    }

    /// Map Statuspage incident impact to severity.
    private func severityFromImpact(_ impact: String?) -> ProviderStatusSeverity? {
        switch impact {
        case "major", "critical":
            return .outage
        case "minor":
            return .degraded
        default:
            return nil
        }
    }

    /// Map Google Cloud status_impact to severity.
    private func severityFromGoogleStatus(_ statusImpact: String) -> ProviderStatusSeverity {
        switch statusImpact {
        case "SERVICE_OUTAGE":
            return .outage
        default: // SERVICE_INFORMATION, SERVICE_DISRUPTION
            return .degraded
        }
    }
}
