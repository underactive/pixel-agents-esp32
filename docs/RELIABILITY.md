# Reliability

Failure modes, system guarantees, and known limitations.

---

## System Guarantees

1. **Never crash on malformed input.** Invalid protocol messages are discarded with state reset, not consumed. The protocol parser resets to WAIT_HEADER on any framing error.
2. **Bounded memory usage.** Fixed-size arrays for characters (6 + 12 mini), paths (BFS grid), tool names. No dynamic allocation in the main loop.
3. **Watchdog recovery.** ESP32 task watchdog resets the system if the main loop hangs beyond the timeout.
4. **Graceful degradation.** CYD (no PSRAM) falls back to strip-buffer rendering. Missing tileset falls back to hand-drawn sprites. Missing sound clips are silently skipped.
5. **Session isolation.** All connection-scoped state (buffers, heartbeat timers, session flags) resets on disconnect to prevent cross-session corruption.

---

## Failure Mode Analysis

| Scenario | Likelihood | Impact | Mitigation |
|----------|-----------|--------|------------|
| Serial disconnect during transfer | High | Partial message in buffer | Protocol state machine resets to WAIT_HEADER on reconnect; ring buffer flushed |
| Malformed protocol message | Medium | Bad data in render | XOR checksum rejects corrupted frames; payload values bounds-checked before use |
| PSRAM unavailable (CYD) | Always | No full-frame buffer | Strip-buffer fallback renders in 320x30 bands; minor visual artifacts acceptable |
| Transcript format changes | Medium | Companion fails to parse | Companion silently skips unrecognized records; only reads well-defined field subset |
| BLE MTU fragmentation | Low | Oversized message split | NUS 20-byte MTU; messages are small (< 20 bytes each); ring buffer reassembles |
| Agent ID overflow (>18) | Low | Character not rendered | Firmware clamps to MAX_AGENTS; companion recycles IDs to keep count low |
| ESP32 thermal throttle | Low | Backlight dims | Thermal manager reduces backlight; CYD fault LED indicates throttle state |
| OAuth token expiry (Gemini) | Medium | Usage stats stale | macOS companion auto-refreshes tokens; graceful fallback to "Loading..." on failure |
| iCloud sync conflict | Low | Stale heatmap data | MAX merge strategy — always keeps the higher count per day per device |
| Sparkle update fetch failure | Low | No auto-update | User can manually download from GitHub Releases; "Check for Updates" in About window |

---

## Known Limitations

1. **Transcript formats not public APIs** — Claude Code JSONL, Codex CLI rollout JSONL, and Gemini CLI session JSON formats may change between versions
2. **No WiFi mode** — USB serial or BLE only (no WiFi/WebSocket)
3. **No wireless OTA updates** — Must flash via USB (browser-based flasher available at `tools/firmware_update.html`)
4. **ESP32 CYD has no PSRAM** — Renderer uses fallback modes (strip-buffer or direct-draw) which may have visual artifacts
5. **CYD audio is 8-bit DAC** — ESP32 internal DAC provides only 8-bit resolution vs 16-bit on CYD-S3 (ES8311). Sound quality is lower; `SOUND_VOLUME_SHIFT` provides software attenuation to reduce distortion
6. **CYD uses no-OTA partition** — `huge_app.csv` (3MB app) was required to fit PCM sound data; wireless OTA would not work on CYD

---

## Result Handling

- Protocol parser returns validated structs or discards — no partial state propagation
- Companion bridge: `try/except` around transcript parsing; unrecognized records skipped with no side effects
- macOS companion: Swift `Result` types for network fetches; UI shows "Loading..." / "Error" states, never crashes

---

## Resource Management

- **ESP32 heap:** Monitored via `ESP.getFreeHeap()` in debug builds. Strip-buffer mode keeps peak usage well within CYD's ~200KB available.
- **BLE ring buffer:** Fixed 512-byte SPSC buffer. Overflow drops oldest data (acceptable for real-time display).
- **SQLite (macOS):** WAL mode with immutable URI for read-only Cursor database access. Activity database uses standard WAL.
- **Timers/intervals:** All capped — 15 FPS render, 10s usage poll, 5-min transcript scan window. No unbounded polling.
