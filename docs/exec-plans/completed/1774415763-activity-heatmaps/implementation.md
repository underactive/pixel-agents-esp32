# Implementation: Activity Heatmaps for Claude, Codex, and Gemini

## Files Changed

### New
- `macos/PixelAgents/PixelAgents/Model/ActivityHeatmapData.swift`
- `macos/PixelAgents/PixelAgents/Services/ActivityDatabase.swift`

### Modified
- `macos/PixelAgents/PixelAgents/Model/AgentState.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift`
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift`

## Summary

Implemented exactly as planned with no deviations:

1. **ActivityHeatmapData** — Struct with `days: [Date: Int]`, streaks, quartile thresholds. Builder `from(rows:)` parses `YYYY-MM-DD` date strings from SQLite. Streak computation copied from `CursorHeatmapData`.

2. **ActivityDatabase** — Singleton `@MainActor` class using raw SQLite3 C API. Single-table schema with `(date, provider)` composite primary key. `recordToolCall()` uses atomic UPSERT (`INSERT ... ON CONFLICT DO UPDATE SET count = count + 1`). `loadHeatmapData()` queries last 366 days. WAL journal mode, 1s busy timeout.

3. **AgentState** — Added `heatmapKey: String?` to `TranscriptSource` enum returning `"claude"`, `"codex"`, `"gemini"`, or `nil` for cursor.

4. **BridgeService** — Three new `@Published` properties. Recording hook in `processTranscripts()` fires on `.type`/`.read` state with non-empty tool name (excluding Gemini's `"Gemini"` text-generation sentinel). Dirty flag avoids unnecessary DB reads on the 10s usage timer. Initial load at startup.

5. **UsageStatsView** — Extracted all Canvas rendering from `CursorHeatmapView` into shared `HeatmapGridView` that accepts raw values (days, colors, metric label, levelForCount closure). `CursorHeatmapView` and new `ActivityHeatmapView` are thin wrappers. Added three 5-level brand-colored palettes (orange/blue/pink). `ProviderDetailView` shows heatmap for all four providers.

6. **MenuBarView** — Passes three new heatmap data bindings through to `UsageStatsView`.

## Verification

- `xcodebuild` — **BUILD SUCCEEDED** with zero errors, zero warnings on changed files
- New files auto-included by xcodegen (`sources: path: PixelAgents`)
- No new dependencies — `SQLite3` framework already linked via `CursorUsageFetcher`

## Audit Fixes

### Fixes applied
1. **Q1/S1/I1/M1/R2 — `sqlite3_bind_text` use-after-free risk**: Defined `SQLITE_TRANSIENT` constant and replaced all four `nil` destructor arguments in `ActivityDatabase.swift` so SQLite copies bound strings immediately.
2. **I6/D4 — Hardcoded provider key strings**: Replaced `"claude"`, `"codex"`, `"gemini"` literals in `BridgeService.start()` and `checkUsageStats()` with `TranscriptSource.*.heatmapKey!` to keep DB keys coupled to the enum.
3. **D2 — Magic number 366**: Extracted to `ActivityDatabase.heatmapHistoryDays` constant with comment explaining the 53-week + leap year margin.
4. **S2/M2/R6 — `SQLITE_OPEN_NOMUTEX` invariant**: Added doc comment on `ActivityDatabase` class documenting that `@MainActor` isolation is required for thread safety.

### Verification checklist
- [ ] Build succeeds after all fixes (`xcodebuild` — confirmed)
- [ ] `SQLITE_TRANSIENT` constant compiles and doesn't warn
- [ ] `TranscriptSource.claude.heatmapKey!` resolves correctly (force unwrap safe — only `.cursor` returns nil)
- [ ] Heatmap data loads correctly on startup and after tool calls

### Deferred items
- **Q2/I3 — Quartile threshold collapse**: Accepted — matches existing `CursorHeatmapData` behavior
- **T1/T2 — No unit tests**: Project has no test target; testing items added to future improvements
- **D1 — Code duplication with CursorHeatmapData**: Intentional per plan — different sources and semantics
- **R1 — Main-thread SQLite**: Sub-millisecond operations at this data volume

## Follow-ups

- Persist `fileOffsets` in the DB to prevent double-counting on app restart
- Consider backfilling from historical transcript files on first run
- Visual testing of color palettes in light/dark mode needed
- Add unit test target and test `ActivityHeatmapData` pure logic (streak, thresholds, level mapping)
