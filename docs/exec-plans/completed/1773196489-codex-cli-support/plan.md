# Plan: Codex CLI Support

## Objective

Add OpenAI Codex CLI support to both companion implementations (Python and macOS), enabling the ESP32 display to show agents from Claude Code and Codex CLI simultaneously. Each active session (regardless of source) gets its own agent ID and character on the display.

## Changes

### Python Companion (`companion/pixel_agents_bridge.py`)

1. **Add Codex constants** — `CODEX_SESSIONS_DIR = ~/.codex/sessions/`
2. **Extend `TranscriptWatcher`** — `find_active_transcripts()` returns `List[Tuple[Path, str]]` (path, source) instead of `List[Path]`. New `_find_codex_transcripts()` walks `~/.codex/sessions/YYYY/MM/DD/` for recent `rollout-*.jsonl` files.
3. **Add `derive_codex_state()` function** — Parses Codex rollout events. Maps tool call items → TYPE, turn completion → IDLE. Handles both `RolloutLine` envelope format and `codex exec --json` event format. Silently skips unrecognized records.
4. **Update `process_transcripts()`** — Receives `(path, source)` tuples, dispatches to `derive_state()` or `derive_codex_state()` based on source.
5. **Update CLI output** — Print both watched directories on startup.

### macOS Companion

6. **Add `CodexStateDeriver.swift`** (`Model/CodexStateDeriver.swift`) — Swift equivalent of `derive_codex_state()`.
7. **Extend `TranscriptWatcher.swift`** — Add `codexSessionsDir`, `TranscriptSource` enum, register FSEvents on both directories, `findActiveTranscripts()` returns `[(URL, TranscriptSource)]`.
8. **Update `BridgeService.processTranscripts()`** — Source-aware deriver dispatch.

### Documentation

9. **Update `CLAUDE.md`** — Architecture diagram, External Integrations, companion bridge description.

### Firmware

No changes needed. The binary protocol is source-agnostic.

## Dependencies

- TranscriptWatcher changes must land before BridgeService/process_transcripts changes.
- CodexStateDeriver is independent and can be written in parallel with Python deriver.

## Risks / Open Questions

1. **Rollout format instability** — OpenAI considers the on-disk rollout JSONL format an internal detail. It has already undergone breaking changes. Mitigation: fault-tolerant parsing, skip unknown records.
2. **Read vs Write distinction** — Codex uses shell commands, not named tools. Heuristic READ detection for obvious read commands (cat, grep, find, ls) is fragile. Initial implementation defaults to TYPE for most tool activity.
3. **No local testing** — User doesn't have Codex CLI installed. Implementation based on documented formats.
4. **Codex `--ephemeral` mode** — Skips writing rollout files; those sessions won't be detected.
