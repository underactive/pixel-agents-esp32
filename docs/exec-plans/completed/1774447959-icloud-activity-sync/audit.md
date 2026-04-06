# Audit Report: iCloud Sync for Activity Heatmap Data

## Files Changed

- `macos/PixelAgents/PixelAgents/Services/ActivitySyncService.swift`
- `macos/PixelAgents/PixelAgents/Services/ActivityDatabase.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- `macos/PixelAgents/project.yml`

---

## 1. QA Audit

**[FIXED] Q1 (Medium)** — `NSMetadataQueryDidFinishGathering` not observed. Added observer for initial gather to close race window.

**[FIXED] Q2 (Medium)** — `mergeRows` not wrapped in transaction. Added `BEGIN`/`COMMIT`.

**[FIXED] Q3 (Low)** — `Int32` truncation crash on untrusted count. Changed to `Int32(clamping:)`.

**[FIXED] Q4 (Low)** — Device ID substring match. Changed to exact filename comparison.

**Q5 (Low)** — Full DB export on every dirty cycle. Accepted — ~1,095 rows max is trivially small.

**Q6 (Info)** — iCloud entitlement commented out. Intentional — requires Apple Developer portal setup.

**[FIXED] Q7 (Low)** — Observer token discarded. Now stored in `queryObservers` array with `stop()` cleanup.

**[FIXED] Q8 (Low)** — No log on version mismatch. Added log message.

**[FIXED] Q9 (Low)** — Strong `self` capture in `Task.detached`. Changed to `[weak self]`.

## 2. Security Audit

**[FIXED] S1 (Low)** — `Int32` truncation crash. Same as Q3.

**S2 (Low)** — No validation of date/provider strings from JSON. Accepted — parameterized queries prevent injection; junk rows don't surface in UI since `loadHeatmapData` filters by known provider and date range.

**S3 (Low)** — No file size limit on iCloud JSON reads. Accepted — files are tiny (~50KB for a full year). iCloud Drive has its own size limits.

**S4 (Low)** — `importFromCloud` on MainActor. Accepted — small file count (one per device), synchronous reads are fast.

## 3. Interface Contract Audit

**I1 (High)** — iCloud entitlement commented out. Accepted — intentional, documented in code and plan.

**[FIXED] I2 (Medium)** — Imported data never marks heatmap dirty. Added `onRemoteDataMerged` callback wired in BridgeService.

**[FIXED] I3 (Low)** — No log on version mismatch. Same as Q8.

**[FIXED] I4 (Low)** — Transaction wrapping. Same as Q2.

**I5 (Low)** — Full-table export. Same as Q5.

**[FIXED] I6 (Low)** — Strong `self` capture. Same as Q9.

**[FIXED] I7 (Low)** — Substring device ID match. Same as Q4.

## 4. State Management Audit

**[FIXED] M1 (High)** — Remote merge doesn't refresh UI. Same as I2.

**[FIXED] M2 (Medium)** — Transaction wrapping. Same as Q2.

**[FIXED] M3 (Medium)** — NSMetadataQuery never stopped. Added `stop()` method.

**[FIXED] M4 (Low)** — Strong `self` in detached task. Same as Q9.

**M5 (Low)** — `needsExport` access control. Fixed to `private(set)` with `markNeedsExport()` method.

**M6 (Info)** — Unqualified `count` in MAX clause. Correct as-is.

## 5. Resource & Concurrency Audit

**[FIXED] R1 (Medium)** — NSMetadataQuery never stopped, no re-entry guard. Added `stop()` and `guard metadataQuery == nil` in `start()`.

**[FIXED] R2 (Low)** — Strong `self` capture. Same as Q9.

**[FIXED] R3 (Low-Medium)** — Transaction wrapping. Same as Q2.

**R4 (Low-Medium)** — Synchronous file I/O on MainActor. Accepted — small files, bounded device count.

**R5 (Low)** — No `startDownloadingUbiquitousItem` for evicted files. Accepted — iCloud auto-downloads within the ubiquity container.

**R6 (Low)** — `exportAllRows` has no date cutoff. Accepted — same as Q5.

**R8 (Low)** — No coalescing of rapid NSMetadataQuery notifications. Accepted — imports are idempotent with MAX merge.

## 6. Testing Coverage Audit

**T1-T4** — No unit tests for new code. Accepted — project has no test infrastructure for these modules.

**T5 (Low)** — Transaction wrapping. Fixed.

**T6 (Low)** — Device ID substring. Fixed.

**T7 (Low)** — No testing checklist items. Will add.

## 7. DX & Maintainability Audit

**[FIXED] D1 (Medium)** — Commented-out entitlement not discoverable. Added prerequisite doc comment on `ActivitySyncService` class.

**[FIXED] D2 (Low)** — Public mutable `needsExport`. Changed to `private(set)` with `markNeedsExport()`.

**D3 (Low)** — Full-export rationale undocumented. Accepted — method name `exportAllRows` is self-documenting.

**[FIXED] D4 (Low)** — Transaction wrapping. Same as Q2.

**D5 (Medium)** — `LIKE 'activity-*.json'` wildcard. Investigated: `NSMetadataQuery` predicates DO use `*` as wildcard (Spotlight/NSMetadataQuery LIKE follows shell glob semantics, not SQL LIKE). This is correct.

**[FIXED] D6 (Low)** — Observer token discarded. Same as Q7.

**D9 (Low)** — Version evolution undocumented. Accepted — version 1 is the only format; will document when v2 is needed.
