# Implementation: Fix Codex CLI State Derivation

## Files changed

- `companion/pixel_agents_bridge.py` — Modified `derive_codex_state()` to add snake_case format handlers
- `macos/PixelAgents/PixelAgents/Model/CodexStateDeriver.swift` — Added snake_case format handlers and `parseExecCommandArgs()` helper
- `macos/PixelAgents/PixelAgentsTests/CodexStateDeriverTests.swift` — New: 22 test cases
- `macos/PixelAgents/PixelAgents.xcodeproj/project.pbxproj` — Added test file to test target
- `CLAUDE.md` — Updated sections 4 (Companion Bridge) and 11 (macOS Companion App)

## Summary

Added new snake_case record type handlers (`response_item`, `event_msg`, `session_meta`, `turn_context`, `compacted`) to both Python and Swift Codex state derivers. The new handlers are placed before the legacy PascalCase handlers so current-format records are matched first. Legacy `item.started`/`item.completed` and `ResponseItem`/`EventMsg` handlers are preserved for backward compatibility.

Key implementation details:
- `response_item` with `function_call` and `name == "exec_command"`: parses `arguments` JSON string to extract `cmd` field, reuses existing shell command classification logic
- `response_item` with `custom_tool_call`: maps to TYPE with the tool name
- `response_item` with `web_search_call`: maps to READ with "WebSearch"
- `event_msg` with `task_complete` or `turn_aborted`: maps to IDLE, clears turn state
- `session_meta`, `turn_context`, `compacted`: explicitly no-op (return nil/None)

No deviations from plan.

## Verification

1. Python companion syntax check: `py_compile.compile()` — passed
2. macOS companion build + tests: `xcodebuild test` — 47 tests, 0 failures (22 CodexStateDeriverTests + 25 existing)
3. Firmware build: CYD environment build — no firmware changes, sanity check only

## Follow-ups

None identified.

## Audit Fixes

### Fixes applied

1. Fixed empty-string `name` guard in Swift legacy `ResponseItem` handler — added `name.isEmpty ? "tool" : name` fallback to match Python behavior (Q2/I1)
2. Added 6 test cases for `codex exec --json` format: `item.started` command_execution (TYPE), `item.completed` read command (READ), `item.started` file_change (TYPE), `item.started` web_search (READ), `turn.completed` (IDLE with state clear), `turn.started` (nil) (D9/T1)
3. Added `activeTools.isEmpty` and `hadToolInTurn` assertions to `testTurnAbortedDerivesIdle` (T5)

### Verification checklist

- [x] Legacy `ResponseItem` with empty `name` field produces label `"tool"` (not empty string) in Swift
- [x] All 6 `codex exec --json` format code paths have test coverage
- [x] `testTurnAbortedDerivesIdle` asserts both `hadToolInTurn` and `activeTools` are cleared
- [x] All 47 tests pass after fixes
