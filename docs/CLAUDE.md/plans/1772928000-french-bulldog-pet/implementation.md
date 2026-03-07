# Implementation: French Bulldog Pet

## Files changed

- `firmware/src/config.h` — Added dog constants (dimensions, speeds, behavior timers, sprite layout), wander pause timing constants, and `DogBehavior` enum
- `firmware/src/office_state.h` — Added `Pet` struct, `getPet()` accessor, `_pet` member, and private methods (`initPet`, `updatePet`, `petStartWalk`, `petWander`, `petFollowNear`, `petPickTarget`)
- `firmware/src/office_state.cpp` — Pet initialization in `spawnAllCharacters()` via `initPet()`, `updatePet(dt)` called from `update()`, full behavior FSM (~200 lines): WANDER/FOLLOW/NAP phases with BFS pathfinding and walk movement
- `firmware/src/renderer.h` — Added `drawDog()` declaration
- `firmware/src/renderer.cpp` — Added `#include "sprites/dog.h"`, depth-sorted dog alongside characters using sentinel index `-1` in `drawScene()`, implemented `drawDog()` with direction-based frame selection and horizontal flip for LEFT
- `firmware/src/sprites/dog.h` — Generated 10-frame RGB565 sprite data (3 directions x 3 walk frames + 1 nap), ~5KB PROGMEM
- `tools/convert_dog.py` — New sprite generator defining 16x16 pixel art as character grids, converting to RGB565 C header

## Summary

Implemented a 16x16 pixel art French Bulldog that roams the office scene. The dog has three behavior phases:
- **WANDER** (20 min): walks to random tiles with 2-6s pauses
- **FOLLOW** (20 min): stays within 5 tiles of a randomly-picked character, re-pathfinds every 8s with 3-tile hysteresis
- **NAP** (30 min every 4 hours): lies down with dedicated nap sprite

The dog is depth-sorted with characters by Y position. LEFT-facing sprites are rendered by flipping RIGHT sprites at runtime. Walk animation uses a 4-frame cycle [walk1, stand, walk3, stand] at 0.12s/frame.

No deviations from the plan.

## Verification

- Both board targets build successfully (LILYGO SUCCESS, CYD SUCCESS)
- `python3 tools/convert_dog.py` generates `firmware/src/sprites/dog.h` with 10 frames, all 160 pixel art rows validated at exactly 16 characters wide
- All 7 post-implementation audit subagents completed; findings addressed (see audit.md)
- Bubble loop guard verified at `renderer.cpp:188` prevents `chars[-1]` access
- Pet defensive initialization verified in `initPet()` with `memset` + sentinel values
- `drawDog()` flat control flow verified — single bounds check, single draw call

## Follow-ups

- Integrate dog sprite frames into `tools/sprite_validation.html` for visual verification in browser
- Consider extracting shared walk-movement physics if a third walking entity is added
- Dog touch interaction on CYD (tap to see info) — not implemented, no defined behavior

## Audit Fixes

Fixes applied:
1. [Q1/D2] Added `if (indices[i] < 0) continue;` guard in bubble-drawing loop to prevent out-of-bounds `chars[-1]` access (renderer.cpp:188)
2. [Q2/D1] Refactored `drawDog()` from split control flow with early return to flat if/else with single draw call (renderer.cpp:310-341)
3. [I2/M2] Removed redundant `memset(&_pet, ...)` from `init()` — `initPet()` fully handles pet initialization (office_state.cpp)
4. [D3] Replaced magic numbers `3` and `9` with `DOG_FRAMES_PER_DIR` and `DOG_NAP_FRAME_IDX` constants (config.h, renderer.cpp)
5. [D4] Replaced magic timer literals with `DOG_WANDER_PAUSE_MIN_SEC`, `DOG_WANDER_PAUSE_MAX_SEC`, `DOG_WANDER_MOVE_MIN_SEC`, `DOG_WANDER_MOVE_MAX_SEC` constants (config.h, office_state.cpp)

Verification checklist:
- [x] Build passes on both LILYGO and CYD targets after all fixes
- [x] Bubble loop correctly skips dog sentinel index (line 188 guard)
- [x] `drawDog()` uses named constants for frame indices
- [x] Pet timer values reference config.h constants, no bare literals remain
- [x] `init()` no longer contains redundant pet initialization
