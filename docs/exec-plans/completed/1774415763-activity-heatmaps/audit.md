# Audit Report: Activity Heatmaps for Claude, Codex, and Gemini

## Files Changed

- `macos/PixelAgents/PixelAgents/Model/ActivityHeatmapData.swift`
- `macos/PixelAgents/PixelAgents/Services/ActivityDatabase.swift`
- `macos/PixelAgents/PixelAgents/Model/AgentState.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift`
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift`

---

## 1. QA Audit

**[FIXED] Q1 (Major)** — `sqlite3_bind_text` with `nil` destructor on transient NSString bridge. Temporary `NSString` from `as NSString` bridge could be freed before `sqlite3_step` reads the pointer.

**Q2 (Major)** — Quartile thresholds collapse for sparse datasets (1-3 non-zero values), making color levels 2/3 unreachable. Accepted — matches existing `CursorHeatmapData` behavior; the heatmap still renders correctly with fewer color gradations.

**Q3 (Minor)** — `mostActiveDay` tracking assumes one row per date. Accepted — guaranteed by the `(date, provider)` primary key.

**Q4 (Minor)** — Single dirty flag reloads all 3 providers even when only one changed. Accepted — three 366-row queries are trivially fast.

**Q5 (Minor)** — `deinit` on singleton never executes. Accepted — standard singleton pattern, OS reclaims resources.

**Q6 (Minor)** — `SQLITE_OPEN_NOMUTEX` safe only because of `@MainActor`. Accepted — added doc comment documenting this invariant.

**Q7 (Info)** — Heatmap grid height uses hardcoded 300 for cell size estimate. Pre-existing in `CursorHeatmapView`.

**Q8 (Info)** — Gemini tool named "Gemini" would be excluded from recording. Accepted — matches companion bridge behavior.

## 2. Security Audit

**[FIXED] S1 (Minor)** — Same as Q1. `sqlite3_bind_text` with `nil` destructor.

**S2 (Minor)** — `SQLITE_OPEN_NOMUTEX` removes safety net. Accepted — documented `@MainActor` invariant.

**S3 (Minor)** — No eviction of old rows. Accepted — growth is ~1,100 rows/year (3 providers × 365 days), negligible.

**S4 (Info)** — Force unwrap on `FileManager.urls` for Application Support. Always returns non-empty on macOS.

**S5 (Info)** — No SQL injection risk. All queries use parameterized bindings with hardcoded provider keys.

**S6 (Info)** — `deinit` on singleton never runs. Same as Q5.

## 3. Interface Contract Audit

**[FIXED] I1 (Major)** — Same as Q1/S1.

**I2 (Minor)** — `deinit` accesses `@MainActor` property without isolation. Accepted — singleton never deallocates.

**I3 (Minor)** — Quartile threshold collapse. Same as Q2.

**I4 (Info)** — `bestDay` tracking reviewed — no actual bug.

**I5 (Info)** — Dirty flag batching is intentional and correct.

**[FIXED] I6 (Info)** — Hardcoded provider key strings duplicated between `heatmapKey` and `BridgeService.start()`. Fixed to use `TranscriptSource.*.heatmapKey!`.

## 4. State Management Audit

**[FIXED] M1 (Minor)** — Same as Q1/S1/I1.

**M2 (Info)** — `SQLITE_OPEN_NOMUTEX` is safe given `@MainActor`. Same as S2.

**M3 (Info)** — Single dirty flag reloads all providers. Same as Q4.

**M5 (Info)** — Startup load is synchronous on main thread. At most 1,098 rows, trivially fast.

## 5. Resource & Concurrency Audit

**R1 (Major)** — SQLite I/O on main thread could block UI. Accepted — UPSERT and 366-row SELECT are sub-millisecond operations. Not worth the complexity of a background queue for this volume.

**[FIXED] R2 (Major)** — Same as Q1/S1/I1/M1.

**R3 (Minor)** — DB handle remains open if table creation fails. Accepted — `recordToolCall`/`loadHeatmapData` have `guard let db` checks and fail gracefully with logging.

**R4 (Minor)** — No data pruning. Same as S3.

**R5 (Minor)** — Three synchronous queries on dirty flag. Same as Q4.

**R6 (Info)** — `NOMUTEX` redundant given `@MainActor`. Same as S2/M2.

## 6. Testing Coverage Audit

**T1 (Major)** — No unit tests for `ActivityHeatmapData` pure logic. Accepted — project has no test target. Added to future improvements.

**T2 (Major)** — No unit tests for `ActivityDatabase`. Accepted — same reason.

**T3 (Minor)** — No tests for `heatmapKey` mapping. Accepted — trivial switch, same reason.

**T4 (Minor)** — Tool call recording logic untestable (embedded in large method). Accepted — matches existing pattern for all four state derivers.

**T5 (Info)** — `computeThresholds` boundary behavior with small datasets undocumented. Same as Q2.

**T6 (Info)** — `computeStreaks` uses `Date()` — flakiness risk if tests were added. Noted for future.

## 7. DX & Maintainability Audit

**D1 (Major)** — Code duplication between `ActivityHeatmapData` and `CursorHeatmapData`. Accepted — intentional design choice per plan. The two structs have different builders (SQLite rows vs API epoch-ms dates) and different semantics (tool calls vs line edits). Extracting a protocol adds abstraction overhead for two small value types.

**[FIXED] D2 (Minor)** — Magic number 366 without named constant. Added `heatmapHistoryDays` constant with comment.

**D3 (Minor)** — `UsageStatsView` parameter list growing unwieldy (11 params). Accepted — matches existing pattern for the 4-provider tabbed UI; refactoring to a per-provider data struct is a future improvement.

**D4 (Minor)** — Provider string keys are stringly-typed across DB boundary. Partially fixed by I6 fix (using `heatmapKey` at call sites), but `ActivityDatabase` API still accepts raw strings.

**D5 (Info)** — `safeColor` in `ProviderTab` is a redundant alias. Pre-existing, not introduced by this change.

**D6 (Info)** — `ProviderDetailView.body` at ~90 lines. Acceptable for a 4-case switch.

**D7 (Info)** — Doc comment on `heatmapKey` references Cursor specifically. Noted.
