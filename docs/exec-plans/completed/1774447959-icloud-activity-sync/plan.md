# Plan: iCloud Sync for Activity Heatmap Data

## Objective

Sync activity heatmap data across multiple Macs via iCloud Drive. Each Mac exports its local SQLite data as a JSON file to the iCloud container; on startup and remote changes, remote device files are imported and merged using MAX strategy.

## Changes

- **Modify `PixelAgents.entitlements`** — add `com.apple.developer.ubiquity-container-identifiers` for `iCloud.com.pixelagents.companion`
- **Modify `ActivityDatabase.swift`** — add `exportAllRows()` and `mergeRows()` methods
- **New `ActivitySyncService.swift`** — per-device JSON export, NSMetadataQuery for remote changes, MAX merge on import
- **Modify `BridgeService.swift`** — create and start sync service, trigger export on tool calls

## Dependencies

- Apple Developer Portal must have iCloud Documents enabled for the app ID (manual step)
- User must be signed into iCloud on macOS

## Risks

- iCloud unavailability handled gracefully (sync simply disabled)
- MAX merge slightly undercounts when same day is active on two Macs, but avoids double-counting
- NSMetadataQuery works for non-sandboxed apps with ubiquity container entitlement
