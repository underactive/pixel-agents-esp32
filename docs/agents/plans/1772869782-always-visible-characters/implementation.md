# Implementation: Always-Visible Characters

## Files changed

- `firmware/src/config.h` -- Added `SocialZone` enum and zone boundary constants
- `firmware/src/office_state.h` -- Added `agentId`, `homeZone` to Character struct; added `spawnAllCharacters()`, `getActiveAgentCount()`, `findOrAssignChar()`, `startZoneWander()`, `walkToZone()`, `findCharByAgentId()`; removed `addAgent()`/`removeAgent()`
- `firmware/src/office_state.cpp` -- Complete rewrite of character lifecycle: `spawnAllCharacters()`, dynamic agent-to-character mapping, zone-constrained wandering, walk-to-zone on deactivation, DESPAWN -> IDLE instead of alive=false
- `firmware/src/renderer.cpp` -- Status bar OVERVIEW shows "N/6 active" instead of "N agents"
- `firmware/src/main.cpp` -- Call `spawnAllCharacters()` after init, moved `randomSeed()` before it

## Summary

Implemented the always-visible characters feature. All 6 characters are now initialized at boot and placed in social zones (break room: chars 0-2, library: chars 3-5). Characters wander within their assigned zone when idle. When an agent becomes active, a character is dynamically assigned and walks to a workstation desk. When the agent goes inactive or offline, the character releases its seat, unassigns the agent, and walks back to its home zone.

**Deviations from plan:**
- Zone bounds adjusted from plan values to match actual walkable tiles: break room rows 3-4 (plan said 1-3, but rows 0-2 are blocked by counters/furniture), library rows 8-13 for CYD / 8-9 for LILYGO (plan said 5-8/5-12, but rows 5-7 are blocked by bookshelves)
- No spawn animation at boot -- characters appear immediately as IDLE (simpler, avoids 6 simultaneous spawn effects)

## Verification

- Both board targets (LILYGO and CYD) build successfully with no new warnings
- Pre-existing clang LSP warnings about Arduino.h not found and array-bounds (initTileMap on LILYGO) are unchanged
- Code reviewed for all audit findings (see Audit Fixes below)

## Follow-ups

- Pre-existing: `initTileMap()` out-of-bounds writes for LILYGO (rows 10-13 exceed GRID_ROWS=10). Should be fixed separately with bounds guards.
- Pre-existing: Some WORKSTATIONS entries reference coordinates beyond LILYGO grid. Should be validated per-board.
- Hardware testing needed: verify 6 simultaneous characters render without frame drops on CYD (no PSRAM).

## Audit Fixes

1. **[Q3/S1/IC-2] agentId bounds check** -- Added `if (id >= MAX_AGENTS) return;` at top of `setAgentState()` to prevent uint8_t values >= 128 from colliding with the -1 sentinel after int8_t cast.

2. **[Q6/S4/IC-8/SM-S4] Seat leak on IDLE during WALK** -- Expanded the IDLE branch condition in `setAgentState()` from `ch.state == TYPE || READ` to also include `ch.state == WALK && ch.seatIdx >= 0`, ensuring seat is released when character was walking to desk but receives IDLE.

3. **[SM-S1] Double walkToZone removal** -- Removed `walkToZone()` call from `setAgentState()` IDLE branch. Now `updateCharacter()` is the sole authority for transitioning TYPE/READ characters to zone walk when `!isActive` is detected. This prevents double path computation.

4. **[IC-4] Mid-walk reactivation** -- Removed the `ch.state != CharState::WALK` guard in the TYPE/READ branch of `setAgentState()`. Now when an agent becomes active while a character is walking (e.g., returning to zone), `startWalk()` is called to redirect the character to the desk, canceling the previous path.

### Verification checklist

- [ ] Verify agent ID >= 128 is rejected (no character assigned, no crash)
- [ ] Verify IDLE received while walking to desk releases the seat (seat available for other agents)
- [ ] Verify TYPE/READ -> IDLE transition only computes one path (no double walk)
- [ ] Verify re-activating an agent while character walks to zone redirects to desk
