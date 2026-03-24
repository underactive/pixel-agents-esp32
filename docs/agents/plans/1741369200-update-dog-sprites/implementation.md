# Implementation: Update Dog Sprites from PNG Sprite Sheet

## Files changed
- `tools/convert_dog.py` - Rewritten to extract 25x19 frames from `assets/doggy3.png` via PIL
- `firmware/src/sprites/dog.h` - Regenerated (23 frames, 25x19, RGB565)
- `firmware/src/config.h` - Updated DOG_W/H, frame indices, added run/pee constants, removed blink/happy/tail wag/Z constants
- `firmware/src/office_state.h` - Simplified Pet struct: removed blink/happy/tail wag/napZ fields, added isRunning/isPeeing/peeTimer
- `firmware/src/office_state.cpp` - Rewrote updatePet(): removed blink/happy/tail wag/Z toggle, added pee (idle variant) and run (random fast walk)
- `firmware/src/renderer.cpp` - Rewrote drawDog(): side-view only with flip for LEFT, added run/pee/laydown frame selection
- `CLAUDE.md` - Updated sprite system and file inventory descriptions

## Summary
Replaced hand-drawn 32x24 multi-directional dog sprites with 25x19 pixel art from `assets/doggy3.png`. The new sprite sheet provides:
- 8 idle frames (was 2)
- 4 walk frames (was 3 per direction x 3 directions)
- 8 run frames (new)
- 1 pee frame (new)
- 1 sit, 1 lay down

All animations are side-view only. LEFT direction flips the sprite horizontally. UP/DOWN movement reuses the current walk/run animation frame.

New behaviors:
- **Run**: 15% chance any wander walk becomes a run (faster speed, 8-frame run cycle)
- **Pee**: 8% chance during wander idle pauses (3s animation)

Removed behaviors: blink, happy (tongue out), tail wag, sleep Z overlay.

## Verification
- `python3 tools/convert_dog.py` generates 23 frames successfully
- `pio run -e lilygo-t-display-s3` builds cleanly (SUCCESS)
- `pio run -e cyd-2432s028r` builds cleanly (SUCCESS)

## Follow-ups
- Visual verification on hardware needed (frame ordering assumed from sprite sheet description)
- Run/pee timing values may need tuning after observing on device

## Audit Fixes

### Fixes applied
1. **S1 - Null pointer guard in drawDog()**: Added `if (!sprite) return;` after `pgm_read_ptr` in `renderer.cpp` to prevent crash on null PROGMEM entry.
2. **S2/IC-4 - Compile-time frame index validation**: Added 3 `static_assert` checks in `renderer.cpp` after `dog.h` include to verify `DOG_WALK_BASE`, `DOG_RUN_BASE`, and `DOG_IDLE_BASE` constants stay within `DOG_FRAME_COUNT`.
3. **SM-1 - isPeeing leak on WANDER-to-FOLLOW transition**: Added `_pet.isPeeing = false;` at the behavior transition point in `office_state.cpp` `updatePet()`.
4. **SM-3 - isRunning leak via petStartWalk()**: Added `_pet.isRunning = false;` in `petStartWalk()` in `office_state.cpp` so run state is always cleared when a new walk path starts.

### Verification checklist
- [x] Both board targets build cleanly after all fixes (`pio run -e lilygo-t-display-s3` SUCCESS, `pio run -e cyd-2432s028r` SUCCESS)
- [ ] Verify on hardware: dog does not display pee frame when transitioning from WANDER to FOLLOW mid-pee
- [ ] Verify on hardware: dog does not run at fast speed during FOLLOW phase
- [ ] Verify on hardware: no crash when drawDog() is called (null guard exercised implicitly)

### Unresolved items
- D1 (updatePet length), D2 (magic 0.5f), D4 (redundant check), D9 (exit code) -- all LOW severity, accepted as-is. Function length is reasonable for a FSM, other items are minor style preferences.
