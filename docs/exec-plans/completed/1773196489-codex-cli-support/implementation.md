# Implementation: Codex CLI Support

## Files changed

- `companion/pixel_agents_bridge.py` — Modified: added Codex constants, extended `TranscriptWatcher` with `_find_codex_transcripts()`, added `derive_codex_state()` / `_codex_tool_label()` / `_is_codex_read_command()`, updated `process_transcripts()` for source dispatch, updated CLI output and docstring
- `macos/PixelAgents/PixelAgents/Model/CodexStateDeriver.swift` — Created: Swift equivalent of `derive_codex_state()` with `readingCommands` set, `toolLabel()`, and `isReadCommand()` helpers
- `macos/PixelAgents/PixelAgents/Model/TranscriptWatcher.swift` — Modified: added `TranscriptSource` enum, `codexSessionsDir` property, `findCodexTranscripts()` method, FSEvents watching on both directories, `findActiveTranscripts()` returns `[(URL, TranscriptSource)]`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — Modified: `processTranscripts()` destructures `(transcript, source)` tuples and dispatches to `CodexStateDeriver` or `StateDeriver`
- `macos/PixelAgents/PixelAgents.xcodeproj/project.pbxproj` — Modified: added `CodexStateDeriver.swift` to build
- `CLAUDE.md` — Modified: architecture diagram, companion bridge description, macOS companion description, external integrations (Codex rollout files), known issues, file inventory

## Summary

Added OpenAI Codex CLI support to both the Python companion bridge and macOS companion app. Both companions now watch two directories simultaneously:
- `~/.claude/projects/` for Claude Code transcripts
- `~/.codex/sessions/YYYY/MM/DD/` for Codex CLI rollout files

Each active session (from either source) gets its own agent ID and appears as a separate character on the ESP32 display. The Codex state deriver handles two JSONL formats:
1. `codex exec --json` events (`item.started`, `item.completed`, `turn.completed`)
2. `RolloutLine` envelopes (`ResponseItem`, `EventMsg`)

Read detection uses a heuristic for shell commands (cat, grep, find, ls, etc.) since Codex doesn't have named tools like Claude Code.

No firmware changes were needed — the binary protocol is source-agnostic.

## Verification

- macOS companion builds successfully (`xcodebuild -scheme PixelAgents build` — BUILD SUCCEEDED)
- All 25 existing unit tests pass (StateDeriverTests: 7, ProtocolBuilderTests: 9, AgentTrackerTests: 9)
- Python companion syntax verified (no import errors)
- No regressions: Claude Code transcript watching behavior unchanged

## Follow-ups

- Unit tests for `CodexStateDeriver` (once Codex rollout file format can be verified with real data)
- Verify with actual Codex CLI installation generating rollout files
- Consider adding a `--source` filter flag to companion if users want to watch only one source

## Audit Fixes

### Fixes applied

1. **Q2 — Quoted command matching**: Added `_strip_codex_command()` (Python) and `stripCommand()` (Swift) helpers that strip surrounding single/double quotes before extracting the tool label or checking read commands. Both `_codex_tool_label`/`_is_codex_read_command` (Python) and `toolLabel`/`isReadCommand` (Swift) now use the shared strip helper.

2. **M6 — Missing tool tracking state**: Added `had_tool_in_turn = True` and `active_tools.add(label)` / `activeTools.insert(label)` to all tool-use branches in both `derive_codex_state()` (Python) and `CodexStateDeriver.derive()` (Swift). Covers `command_execution`, `file_change`, `mcp_tool_call`, `web_search` (exec format) and `function_call` (RolloutLine format).

3. **R3 — Unhandled OSError on iterdir()**: Wrapped `CODEX_SESSIONS_DIR.iterdir()`, `year_dir.iterdir()`, `month_dir.iterdir()`, and `day_dir.iterdir()` in try/except `OSError` blocks in `_find_codex_transcripts()`. Each level gracefully skips on error.

4. **D6 — Unused variable**: Removed unused `query = item.get("query", "")` from `derive_codex_state()` `web_search` branch.

5. **D7 — Inconsistent fallback**: Changed `mcp_tool_call` default from `""` to `"tool"` in Python `derive_codex_state()` to match Swift behavior.

### Verification checklist

- [ ] Verify quoted commands like `'grep foo'` produce label `grep` (not `'grep`)
- [ ] Verify `hadToolInTurn` is `True` after a Codex tool event and `False` after turn completion
- [ ] Verify `_find_codex_transcripts()` gracefully handles permission-denied directories
- [ ] Verify `mcp_tool_call` with missing `tool` field shows "tool" on display (not blank)
