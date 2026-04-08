import Foundation

/// Severity level for a provider status incident.
enum ProviderStatusSeverity: Equatable {
    case degraded   // yellow dot: degraded_performance, under_maintenance, SERVICE_INFORMATION, SERVICE_DISRUPTION
    case outage     // red dot: partial_outage, major_outage, SERVICE_OUTAGE
}

/// A single active incident affecting a provider's API.
struct ProviderIncident: Equatable, Identifiable {
    let id: String                          // upstream incident ID (drives dismissal tracking)
    let title: String                       // incidents[].name or external_desc
    let severity: ProviderStatusSeverity
    let statusPageURL: URL                  // e.g. https://status.claude.com
}

/// Result of a single status check for one provider.
struct ProviderStatusResult: Equatable {
    let provider: UsageProvider
    let incident: ProviderIncident?         // nil = operational / no active incident
    let lastChecked: Date
}
