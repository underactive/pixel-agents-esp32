# Implementation: Fix Agent IDs >= 6 silently rejected by firmware

## Files changed
- `firmware/src/config.h` — added `MAX_AGENT_ID` constant (127)
- `firmware/src/office_state.cpp` — relaxed agent ID guard from `>= MAX_AGENTS` to `> MAX_AGENT_ID`
- `macos/PixelAgents/PixelAgents/Model/AgentTracker.swift` — added `recycledIds` array with recycle-on-prune, reuse-on-create, docstring
- `companion/pixel_agents_bridge.py` — added `_recycled_ids` list with same recycle logic, cleared on reconnect
- `macos/PixelAgents/PixelAgentsTests/AgentTrackerTests.swift` — replaced wrap test with 3 recycling tests

## Summary
Implemented as planned with additional audit-driven improvements:
- Used symbolic constant `MAX_AGENT_ID` instead of magic number 128
- Clear recycled IDs on Python companion reconnect
- Added `testResetClearsRecycledIds` test
- Added docstring explaining recycling rationale

## Verification
- Firmware build: `pio run -e cyd-2432s028r` — SUCCESS (84.2% flash)
- macOS unit tests: `xcodebuild test` — 25/25 tests passed (0 failures)
- Manual test: pending hardware

## Follow-ups
- None identified

## Audit Fixes

### Fixes applied
1. Replaced magic number `128` with `MAX_AGENT_ID` constant in `config.h` (addresses Q1, I1, D1)
2. Python `_reset_session_state()` now clears `_recycled_ids` on reconnect (addresses SM1)
3. Added docstring to Swift AgentTracker explaining recycling rationale (addresses D2)
4. Added `testResetClearsRecycledIds` test to verify reset clears recycle pool (addresses T1)

### Verification checklist
- [x] Firmware builds with `MAX_AGENT_ID` constant — confirmed via `pio run`
- [x] All 25 macOS unit tests pass including 3 new recycling tests
- [ ] Verify agents with IDs 6+ appear on device after companion prunes earlier agents (hardware test)
