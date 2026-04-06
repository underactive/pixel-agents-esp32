# Implementation: Idle Screensaver — Characters Do Random Activities

## Files Changed

- `firmware/src/config.h` — Added ACTIVITY state, IdleActivity enum, InteractionPoint struct/tables, timing constants
- `firmware/src/office_state.h` — Added activity fields to Character struct, new private methods
- `firmware/src/office_state.cpp` — Core activity logic: state transitions, activity selection, interaction points, socializing
- `firmware/src/renderer.cpp` — Frame selection for ACTIVITY state, status bar display

## Summary

Implemented as planned. Key details:

- `CharState::ACTIVITY` (value 7) added as a distinct state
- `IdleActivity` enum with NONE, READING, COFFEE, WATER, SOCIALIZING
- Interaction point tables for furniture-based activities (bookshelf row 8, coffee row 3, water cooler row 3)
- 40% chance per wander trigger for unassigned chars to start an activity
- Activity duration 4-10s random, followed by walkToZone() and cooldown
- Socializing: find random idle/unassigned char, walk to adjacent tile, face toward them
- Agent preemption: ACTIVITY added to findOrAssignChar() guard; activity state cleared on agent assignment
- Reading activity uses 2-frame READ animation at 0.4s/frame; other activities use standing pose
- `findSocializeTarget()` changed from const to non-const since it calls `randomInt()`

## Verification

- Built both environments successfully:
  - `pio run -e cyd-2432s028r` — SUCCESS (RAM 12.3%, Flash 82.4%)
  - `pio run -e lilygo-t-display-s3` — SUCCESS

## Follow-ups

- Hardware testing needed: observe idle scene, verify activity animations, test agent preemption

## Audit Fixes

### Fixes Applied

1. **S4/S3 — Orphaned `idleActivity` on walk failure**: In `pickActivityTarget()`, added check `if (ch.state != CharState::WALK)` after both `startWalk()` calls (socializing and furniture paths). If walk fails, `ch.idleActivity` is immediately reset to `NONE`, preventing incorrect ACTIVITY transitions at unrelated tiles.

2. **S6/R3 — Facing direction lost during walk**: Added `Dir activityDir` field to `Character` struct. `pickActivityTarget()` now stores the intended direction in `ch.activityDir` instead of `ch.dir`. When WALK completes and transitions to ACTIVITY, the intended direction is restored via `ch.dir = ch.activityDir`.

3. **IC-1 — Protocol validation bound comment**: Added `// WHY:` comment in `protocol.cpp` explaining that the DESPAWN(6) bound is intentional because ACTIVITY(7) is firmware-only and never sent over the wire.

4. **D11 — Split animation logic comment**: Added `// WHY:` comment in `renderer.cpp` `drawCharacter()` explaining why ACTIVITY frame selection is split between `drawCharacter()` and `getFrameIndex()`.

### Files Modified by Audit Fixes

- `firmware/src/office_state.h` — Added `activityDir` field to Character struct
- `firmware/src/office_state.cpp` — Walk failure guard, `activityDir` storage and restore, field init
- `firmware/src/protocol.cpp` — Comment clarifying validation bound
- `firmware/src/renderer.cpp` — Comment explaining split animation logic

### Verification Checklist

- [x] Both environments build successfully after fixes
- [ ] Verify characters face correct direction when performing activities (UP for furniture, toward target for socializing)
- [ ] Verify failed walks (no BFS path) do not leave orphaned activity state
- [ ] Verify agent preemption still works during activities
