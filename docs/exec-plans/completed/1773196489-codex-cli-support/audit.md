# Audit: Codex CLI Support

## Files changed

- `companion/pixel_agents_bridge.py`
- `macos/PixelAgents/PixelAgents/Model/CodexStateDeriver.swift`
- `macos/PixelAgents/PixelAgents/Model/TranscriptWatcher.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`

## Findings

### QA Audit

- **Q1** (Low): The Codex JSONL format is undocumented and may change. The deriver handles two known formats but future formats could be silently ignored. — Accepted: by-design, same risk as Claude Code transcripts.
- **[FIXED] Q2** (Medium): Quoted shell commands (e.g. `'grep foo'` or `"cat bar"`) would not match in `toolLabel`/`isReadCommand` because the first word would include the quote character.

### Security Audit

- **S1** (Info): Codex transcript files are read from the user's home directory. No additional attack surface beyond existing Claude Code transcript reading. — Accepted: no action needed.

### Interface Contract Audit

- **I1** (Info): `BridgeService.processTranscripts()` correctly dispatches by `TranscriptSource` enum. Protocol output is source-agnostic. — No action needed.

### State Management Audit

- **[FIXED] M6** (Medium): `derive_codex_state()` and `CodexStateDeriver.derive()` did not set `had_tool_in_turn = True` or populate `active_tools` on tool-use events. The Claude deriver does this (allowing `processTranscripts` to write back mutation state). Codex tool events would leave these fields stale.

### Resource & Concurrency Audit

- **[FIXED] R3** (Medium): `_find_codex_transcripts()` called `iterdir()` on YYYY/MM/DD directories without `try/except`. An `OSError` (permissions, dangling symlink) would propagate and crash the poll cycle.
- **R4** (Low): Three-level nested `iterdir()` in `findCodexTranscripts()` (Swift) could be slow with many year/month directories. — Accepted: unlikely in practice (sessions accumulate slowly).

### DX & Maintainability Audit

- **[FIXED] D6** (Low): Unused `query = item.get("query", "")` variable on line 446 of `pixel_agents_bridge.py`.
- **[FIXED] D7** (Low): `mcp_tool_call` fallback was `""` in Python but `"tool"` in Swift. Inconsistent empty-string default could render a blank tool name on the display.
- **D8** (Info): `readingCommands` sets are duplicated between Python and Swift. — Accepted: standard cross-language duplication, shared constant files would add complexity.

### Testing Coverage Audit

- **T1** (Medium): No unit tests for `CodexStateDeriver` (Swift) or `derive_codex_state()` (Python). — Deferred: noted in implementation follow-ups; blocked until Codex rollout file format can be verified with real data.
- **T2** (Low): `_find_codex_transcripts()` directory walking logic is untested. — Accepted: filesystem interaction testing requires mock setup, low risk given existing pattern from Claude transcript finder.
