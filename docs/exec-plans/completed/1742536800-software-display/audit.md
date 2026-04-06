# Audit: Software Display Mode + PIP Window

## Files Changed (findings flagged)
- `Model/OfficeScene.swift`
- `Views/OfficeRenderer.swift`
- `Views/PIPWindowController.swift`
- `Services/BridgeService.swift`
- `Views/MenuBarView.swift`

## QA Audit
- **[FIXED] Q2**: `SpriteCache.characterFrame` modulo with potentially empty array — added `guard !charSheets.isEmpty` before modulo
- Q1: Bubble timer 0.0 means "persistent" — semantically confusing but functionally correct
- Q5: `findOrAssignChar` may assign walking-to-activity character — cleaned up by `applyAgentStates`

## Security Audit
- **[FIXED] S1**: `isInteractionPointFree` accesses `path[pathLen-1]` without bounds check — added `pathLen <= path.count` guard
- **[FIXED] S5**: `CGContext` allocation failure produces nil with no diagnostics — added NSLog on failure
- S3: `SpriteCache` not annotated `@MainActor`/`Sendable` — safe in practice (only accessed from `@MainActor`)
- S4: `requestScreenshot` accesses `serialTransport` from background queue — pre-existing, not from this change

## Interface Contract Audit
- **[FIXED] IC-4**: `OfficeScene.lastAppliedStates` not cleared on mode/session reset — added `resetAppliedStates()`, called from `resetSessionState()`
- IC-2: Bubble duration 0.0 ambiguous — same as Q1, intentional firmware behavior
- IC-5: Screenshot background thread issue — same as S4, pre-existing
- **[FIXED] IC-8**: PIP window close via delegate doesn't stop scene timer — added `sceneTimerNeedsUpdate()` call in `windowWillClose`
- IC-9: Timer uses unnecessary `Task { @MainActor }` indirection — pre-existing pattern, low impact
- IC-11: `seatIdx` used as array index without upper-bound check — safe due to `findFreeSeat()` range, low priority

## State Management Audit
- **[FIXED] S1/IC-8**: `isPIPShown` two-writer issue — `windowWillClose` now calls `sceneTimerNeedsUpdate()`
- **[FIXED] S4/IC-4**: Stale dedup cache on reconnect — `resetAppliedStates()` added
- S2: `@Published` on `OfficeScene.characters`/`pet` fires into void — unnecessary overhead but harmless
- S7: `serialTransport` accessed from background queue — pre-existing

## Resource & Concurrency Audit
- RC-1/RC-11: Data race in `requestScreenshot` — pre-existing, not from this change
- RC-4: 15 FPS CGImage creation is ~280KB/frame — acceptable for macOS
- RC-10: BFS allocates ~9KB heap per call — low frequency (only on walk start), acceptable
- RC-2: `SpriteCache` thread safety — safe in practice (dispatch_once init, read-only after)
- RC-5: `usageFetchTimer` inconsistent MainActor pattern — pre-existing

## Testing Coverage Audit
- T1: No tests for OfficeScene (830 lines) — new module, tests recommended for `applyAgentStates`, BFS, `isReadingTool`
- T2: No tests for OfficeRenderer — rendering module, lower priority
- T4: No tests for BridgeService scene timer logic — integration test recommended
- T7: `Float.random` makes tests non-deterministic — injectable random source recommended for future

## DX & Maintainability Audit
- D1: 5 functions exceed 50 lines (largest 190) — acceptable as 1:1 firmware port
- D2: Magic numbers for bubble types — enum would improve clarity, deferred
- D3: Duplicated tile-to-pixel conversion (~20x), direction logic (3x), walk movement (char+pet) — acceptable for firmware parity
- D6: Scene dimensions 320x224 scattered across 4 files — shared constant recommended, deferred
- D13: BridgeService extension in MenuBarView.swift — should move to BridgeService.swift, deferred
