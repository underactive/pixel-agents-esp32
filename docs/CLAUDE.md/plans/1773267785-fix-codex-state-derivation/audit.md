# Audit: Fix Codex CLI State Derivation

## Files changed

- `companion/pixel_agents_bridge.py`
- `macos/PixelAgents/PixelAgents/Model/CodexStateDeriver.swift`
- `macos/PixelAgents/PixelAgentsTests/CodexStateDeriverTests.swift`
- `macos/PixelAgents/PixelAgents.xcodeproj/project.pbxproj`
- `CLAUDE.md`

## 1. QA Audit

- Q1: [low] Legacy `EventMsg` handler in Python has a `token_count` guard that short-circuits before checking `type`, which the Swift version lacks. Both produce the same result in practice since `token_count` events use their own type value.
- [FIXED] Q2: [low] Legacy `ResponseItem` handler in Swift did not guard against empty-string `name`, producing an empty label. Python correctly fell back to `"tool"`.
- Q3: [low] `stripCommand` splits on literal space in Swift vs any whitespace in Python. Only diverges if tabs appear between `bash` and the command (unlikely).

## 2. Security Audit

- S1: [low] `activeTools` set grows unbounded within a turn. Bounded in practice by Codex CLI's per-turn token limits and 30s stale-agent pruning.
- S2: [low] Legacy `ResponseItem` empty-name handling (covered by Q2/I1 fix).
- S3: [info] `json.loads()` and `JSONSerialization` parse untrusted input safely with try/except guards.
- S4: [info] Tool name truncation consistently applied at MAX_TOOL_NAME_LEN (24).

## 3. Interface Contract Audit

- [FIXED] I1: [low] Legacy `ResponseItem` empty-name parity gap between Python and Swift. Same as Q2.
- I2: [low] Legacy `EventMsg` token_count guard parity gap. Same as Q1. Both produce `nil`/`None` in practice.
- I3: [info] `hadToolInTurn`/`activeTools` correctly written back on `nil` result in Swift caller.
- I4: [info] All three JSONL format families handled in parity between Python and Swift.

## 4. State Management Audit

- M1: [low] Swift value-type copy write-back pattern is fragile — future early returns could silently drop mutations. No current bug.
- M2: [low] Codex agents never set `tool_use_ts`, so permission detection logic safely short-circuits. Correct but implicit.
- M3: [info] `hasPlayedJobSound` is firmware-only. Not relevant to companion code.
- M4: [info] Mutation discipline is consistent between Python and Swift across all three formats.

## 5. Resource & Concurrency Audit

No issues found. Python is single-threaded. Swift is `@MainActor`-isolated. No shared mutable state across threads.

## 6. Testing Coverage Audit

- [FIXED] T1: [medium] No tests for `codex exec --json` format (`item.started`/`item.completed`/`turn.completed`/`turn.started`). Added 6 tests.
- T2: [medium] `toolLabel`/`stripCommand` helpers tested indirectly but edge cases (absolute paths, >24 char names) not covered. Accepted — these helpers are pre-existing untested code, not changed in this PR.
- T3: [medium] Only `cat` and `grep` tested from the 14-item `readingCommands` set. Accepted — set membership testing is straightforward.
- T4: [low] No Python unit tests for `derive_codex_state()`. Accepted — no Python test infrastructure exists in the project.
- [FIXED] T5: [low] `testTurnAbortedDerivesIdle` missing `activeTools.isEmpty` assertion. Added.
- T6: [low] No test for unrecognized `type` values. Accepted — trivial fallthrough to `return nil`.
- T7: [low] No test for missing `payload` key fallback. Accepted — trivial `?? record` fallback.

## 7. DX & Maintainability Audit

- D1: [low] `derive_codex_state()` is ~140 lines (Python) / ~155 lines (Swift). Accepted — three-format dispatch is inherently branchy and well-delimited by comment banners.
- D2: [low] Duplicated state-mutation boilerplate (3-line pattern repeated 7-8 times). Accepted — extraction would add indirection without meaningful benefit for this function size.
- D3: [low] No inline comment explaining why `EventMsg` accepts both `turn_complete` and `turn.completed`. Accepted — the comment banners provide sufficient context.
- D4: [info] `token_count` guard asymmetry between legacy and current `event_msg` handlers. Same as Q1/I2.
- D5-D6: Same as D1-D2 for Swift.
- D7: [low] Force-unwrap in `stripCommand` is safe behind `count >= 2` guard. Pre-existing code, not changed.
- D8: Same as Q1/I2.
- [FIXED] D9: [medium] Missing tests for `codex exec --json` format. Added 6 tests.
- D10: [low] No test for empty/missing `type` key. Accepted — guard clause is trivial.
- D11: [info] No test for tool name truncation. Accepted — pre-existing behavior.
