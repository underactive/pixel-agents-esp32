# Plan: Idle Screensaver — Characters Do Random Activities

## Objective

When no real Claude Code agents are active, idle characters should perform engaging activities (reading at bookshelves, getting coffee, visiting the water cooler, socializing with each other) rather than only wandering randomly within their home zones. This makes the idle scene more lively as a desk decoration.

**Excluded:** Sitting at desks and pretending to type (reserved for real agent work only).

## Approach

Add `CharState::ACTIVITY` (value 7) as a new character state, plus `IdleActivity` enum and interaction point tables. Characters roll a 40% chance on each wander trigger to perform an activity instead. Activities last 4-10 seconds, then the character returns to their home zone with a cooldown preventing back-to-back activities.

## Changes

### `firmware/src/config.h`
- Add `ACTIVITY = 7` to `CharState` enum
- Add `IdleActivity` enum (NONE, READING, COFFEE, WATER, SOCIALIZING)
- Add `InteractionPoint` struct with col, row, facingDir
- Add static tables: READING_POINTS (4 tiles at row 8), COFFEE_POINTS (2 tiles at row 3), WATER_POINTS (1 tile at row 3)
- Add timing constants: ACTIVITY_DURATION_MIN/MAX_SEC, ACTIVITY_CHANCE, ACTIVITY_COOLDOWN_SEC, READ_ACTIVITY_FRAME_SEC

### `firmware/src/office_state.h`
- Add `idleActivity`, `activityTimer`, `activityCooldown` fields to `Character` struct
- Add private methods: `startIdleActivity()`, `pickActivityTarget()`, `isInteractionPointFree()`, `findSocializeTarget()`

### `firmware/src/office_state.cpp`
- Initialize new fields in `spawnAllCharacters()`
- Add ACTIVITY to `findOrAssignChar()` guard for agent preemption
- Clear activity state in `setAgentState()` (both OFFLINE and assignment paths)
- Modify IDLE wander logic: 40% chance to start activity instead of zone wander
- Modify WALK completion: transition to ACTIVITY state when arriving at activity destination
- Add ACTIVITY case in `updateCharacter()`: animate reading, count down timer, return to zone on expiry
- Implement `startIdleActivity()`: weighted random (30% READ, 20% COFFEE, 20% WATER, 30% SOCIAL)
- Implement `pickActivityTarget()`: find free interaction point or adjacent tile for socializing
- Implement `isInteractionPointFree()`: check no other char on or walking to tile
- Implement `findSocializeTarget()`: find random idle/unassigned character
- Clear `idleActivity` in `walkToZone()`

### `firmware/src/renderer.cpp`
- Override frame selection in `drawCharacter()`: standing pose for non-READING activities
- Add ACTIVITY case in `getFrameIndex()`: use READ frames for bookshelf reading
- Add "ACT" string in status bar AGENT_LIST

## Dependencies

No ordering constraints between files. Firmware-only change; no companion modifications.

## Risks / Open Questions

1. Two chars targeting same point simultaneously: `isInteractionPointFree()` checks walk destinations, but small race window. Visual overlap is brief and harmless.
2. Water cooler has only 1 point: falls back to zone wander if occupied.
3. Socializing target moves away: character stands alone briefly then returns to idle.
