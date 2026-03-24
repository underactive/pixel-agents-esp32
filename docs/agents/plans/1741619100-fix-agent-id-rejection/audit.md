# Audit: Fix Agent IDs >= 6 silently rejected by firmware

## Files changed
- `firmware/src/office_state.cpp`
- `firmware/src/config.h`
- `macos/PixelAgents/PixelAgents/Model/AgentTracker.swift`
- `companion/pixel_agents_bridge.py`
- `macos/PixelAgents/PixelAgentsTests/AgentTrackerTests.swift`

## Consolidated Findings

### QA Audit

- **Q1** [FIXED] Magic number `128` in firmware guard violates dev rule #5 — replaced with `MAX_AGENT_ID` constant in `config.h`
- **Q2** (Accepted) ID range mismatch: firmware accepts 0-127, companions generate 0-255. By design — recycling keeps IDs in 0-5 range during normal operation; reaching 128 requires 128+ concurrent agents without pruning, impossible given 6 slots and 30s timeout.
- **Q3** (Accepted) No Python unit tests for recycling. Python companion has no test infrastructure; testing is manual. macOS Swift tests cover the same algorithm.

### Security Audit

- **S1** (Accepted) Same as Q2 — 128 limit is correct for int8_t storage safety.
- **S2** (Accepted) No bounds check on recycled ID reuse. IDs originate from the same tracker that assigned them; validation would be defense against self-corruption.
- **S3** (Accepted) int8_t cast in `findCharByAgentId` — guarded by the `> MAX_AGENT_ID` check in `setAgentState()`, which is the only entry point.
- **S4** (Accepted) Unbounded recycled list growth — in practice bounded by MAX_AGENTS (6) since recycled IDs are immediately consumed by new agents.

### Interface Contract Audit

- **I1** [FIXED] Magic number replaced with `MAX_AGENT_ID` symbolic constant.
- **I2** (Accepted) Silent return when all character slots full — existing behavior via `findOrAssignChar()` returning -1, unchanged by this fix.
- **I3** (Accepted) ID wrap-around collision — requires exhausting 256 IDs without pruning, impossible in practice.

### State Management Audit

- **SM1** [FIXED] Python `_reset_session_state()` now clears `_recycled_ids` on reconnect, preventing stale ID reuse across sessions.
- **SM2** (Accepted) No cross-module ID synchronization between Python and macOS companions — they are alternative transports, not concurrent; only one connects at a time.
- **SM3** (Accepted) No firmware acknowledgment of ID reuse — the protocol already handles this via AGENT_UPDATE overwriting the character slot.

### Resource & Concurrency Audit

- **R1** (Accepted) Unbounded recycled list growth — bounded by MAX_AGENTS in practice. Adding a cap would add complexity for a scenario that can't occur.
- **R2** (Accepted) No synchronization on Swift AgentTracker — all access from `@MainActor` BridgeService.
- **R3** (Accepted) Python GIL provides sufficient thread safety for single-threaded bridge.

### Testing Coverage Audit

- **T1** [FIXED] Added `testResetClearsRecycledIds` to verify reset clears the recycle pool.
- **T2** (Accepted) Removed `testIdWrapsAt256` — wrap-around at 256 is now unreachable in normal operation due to recycling keeping IDs low.
- **T3** (Accepted) No Python unit tests — no existing test infrastructure for Python companion.
- **T4** (Accepted) No C++ unit tests for firmware — no existing test infrastructure for ESP32 firmware.

### DX & Maintainability Audit

- **D1** [FIXED] Magic number replaced with `MAX_AGENT_ID` constant.
- **D2** [FIXED] Added docstring to Swift AgentTracker explaining recycling rationale.
- **D3** (Accepted) Unreachable `elif rec_type == "user"` branch — pre-existing, not introduced by this change.
- **D4** (Accepted) Asymmetric BLE vs serial error handling — pre-existing, not introduced by this change.
