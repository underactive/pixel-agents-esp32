# Fix Codex CLI State Derivation (Stale JSONL Format)

## Objective

The Codex CLI changed its rollout JSONL format from PascalCase (`ResponseItem`/`EventMsg`) and `item.started`/`item.completed` to snake_case (`response_item`/`event_msg`) with new payload types (`function_call` with `exec_command`, `custom_tool_call`, `web_search_call`, `task_complete`, `turn_aborted`). Because no record types matched, `derive_codex_state()` always returned `nil`/`None`, so agents never transitioned from idle.

## Changes

1. **`companion/pixel_agents_bridge.py`** — Add `response_item` and `event_msg` handlers to `derive_codex_state()`. Parse `exec_command` function_call's `arguments` JSON string for shell command. Handle `custom_tool_call`, `web_search_call`, `task_complete`, `turn_aborted`. No-op `session_meta`, `turn_context`, `compacted`. Keep legacy handlers.

2. **`macos/PixelAgents/PixelAgents/Model/CodexStateDeriver.swift`** — Mirror Python changes. Add `parseExecCommandArgs()` helper for JSON string arguments parsing.

3. **`macos/PixelAgents/PixelAgentsTests/CodexStateDeriverTests.swift`** (new) — 16 test cases covering all new record types, legacy backward compat, and malformed arguments fallback.

4. **`macos/PixelAgents/PixelAgents.xcodeproj/project.pbxproj`** — Add `CodexStateDeriverTests.swift` to test target.

5. **`CLAUDE.md`** — Update sections 4 and 11 to document three supported Codex formats.

## Dependencies

None. No firmware changes required.

## Risks / open questions

- Codex CLI format may change again. The three-format approach provides defense in depth.
- `arguments` field for `exec_command` is a JSON string (not dict) — requires `json.loads()`/`JSONSerialization` with error handling.
