# Implementation: iCloud Sync for Activity Heatmap Data

## Files Changed

### New
- `macos/PixelAgents/PixelAgents/Services/ActivitySyncService.swift`

### Modified
- `macos/PixelAgents/PixelAgents/Services/ActivityDatabase.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- `macos/PixelAgents/project.yml` (entitlement commented out — requires Apple Developer portal setup)

## Summary

1. **ActivityDatabase** — Added `exportAllRows()` (SELECT all rows) and `mergeRows()` (UPSERT with MAX strategy). Both use prepared statements with `SQLITE_TRANSIENT` bindings.

2. **ActivitySyncService** — New `@MainActor` class. Per-device JSON files (`activity-{deviceId}.json`) avoid write conflicts. Uses `NSMetadataQuery` with `NSMetadataQueryUbiquitousDocumentsScope` to watch for remote changes. `start()` checks iCloud availability via `url(forUbiquityContainerIdentifier:)` on a background thread, then imports remote data and starts monitoring. `exportIfNeeded()` writes local data to this device's JSON file. `importFromCloud()` reads all remote device files and merges via MAX.

3. **BridgeService** — Creates `ActivitySyncService` lazily, starts it in `start()`, sets `needsExport = true` alongside `activityHeatmapDirty` on tool call recording, calls `exportIfNeeded()` in `checkUsageStats()`.

4. **Entitlements** — `com.apple.developer.ubiquity-container-identifiers` for `iCloud.com.pixelagents.companion` added to `project.yml` but **commented out**. Must be enabled after configuring iCloud Documents capability in Apple Developer portal.

## Verification

- `xcodebuild` — **BUILD SUCCEEDED** (with entitlement commented out for local builds)
- Sync service degrades gracefully when iCloud unavailable (logs "iCloud unavailable — activity sync disabled")
- No new dependencies

## Audit Fixes

### Fixes applied
1. **M1/I2 — Remote merge doesn't refresh UI**: Added `onRemoteDataMerged` callback on `ActivitySyncService`, wired in `BridgeService` to set `activityHeatmapDirty = true`
2. **Q2/R3/D4 — Transaction wrapping**: Wrapped `mergeRows` loop in `BEGIN`/`COMMIT` for atomicity and performance
3. **Q3/S1 — Int32 truncation crash**: Changed `Int32(row.count)` to `Int32(clamping: row.count)`
4. **Q4/I7 — Device ID substring match**: Changed `contains(deviceId)` to exact `!= ownFilename` comparison
5. **Q1 — Missing initial gather observer**: Added `NSMetadataQueryDidFinishGathering` observer alongside `didUpdate`
6. **Q7/R1/D6 — Observer cleanup**: Stored observer tokens in `queryObservers` array, added `stop()` method with cleanup
7. **Q9/R2/I6 — Strong self capture**: Changed `Task.detached { [self] }` to `[weak self]`
8. **Q8/I3 — Version mismatch logging**: Added `Self.log.info` when skipping files with unsupported version
9. **D1 — Entitlement discoverability**: Added prerequisite doc comment on `ActivitySyncService` class
10. **D2/M5 — needsExport encapsulation**: Changed to `private(set)` with `markNeedsExport()` method

### Verification checklist
- [ ] Build succeeds after all fixes (`xcodebuild` — confirmed)
- [ ] `onRemoteDataMerged` callback fires after import, refreshing heatmaps
- [ ] `mergeRows` runs in a single transaction (BEGIN/COMMIT)
- [ ] `Int32(clamping:)` doesn't crash on large counts
- [ ] `stop()` properly cleans up query and observers

### Deferred items
- **S2 — Date/provider validation**: Accepted — junk rows don't surface in UI
- **R4 — Synchronous MainActor I/O**: Accepted — small files, bounded device count
- **T1-T4 — Unit tests**: No test infrastructure for these modules
- **D5 — NSPredicate LIKE wildcard**: Confirmed correct — NSMetadataQuery uses `*` as wildcard (shell glob semantics)

## Follow-ups

- Enable iCloud Documents for `com.pixelagents.companion` in Apple Developer portal
- Uncomment the entitlement in `project.yml`
- Test on two Macs with iCloud signed in
- Consider adding a UI indicator when iCloud sync is active/last synced
