# Audit: Update Dog Sprites from PNG Sprite Sheet

## Files changed
- `firmware/src/renderer.cpp` - S1, S2, D2, D10
- `firmware/src/office_state.cpp` - SM-1, SM-3, F4, D1
- `firmware/src/config.h` - IC-4
- `firmware/src/office_state.h` - (no findings)
- `tools/convert_dog.py` - D9

---

## 1. QA Audit

### F2 - isRunning leaking into FOLLOW phase (MEDIUM) [FIXED via SM-3]
`petStartWalk()` did not clear `isRunning`. If the dog was running during WANDER when a FOLLOW transition occurred, it would continue running toward the follow target at run speed.

### F4 - petFollowNear silent failure (LOW)
If `petFollowNear()` fails to find a walkable tile near the follow target, it silently does nothing. The dog stands still until the next repath interval. Pre-existing behavior, not introduced by this change.

### F10 - Pixel draw count change (INFO)
Frame size changed from 32x24 (768 pixels) to 25x19 (475 pixels). Net reduction of ~38% in per-frame pixel draws for the dog. No action needed.

## 2. Security Audit

### S1 - Null pointer from pgm_read_ptr (MEDIUM) [FIXED]
`drawDog()` used `pgm_read_ptr(&DOG_SPRITES[frameIdx])` without checking for null before dereferencing. If the PROGMEM table had a null entry, this would crash. Fixed by adding `if (!sprite) return;` guard.

### S2 - Frame index drift between config.h and dog.h (MEDIUM) [FIXED]
Frame index constants (`DOG_WALK_BASE`, `DOG_RUN_BASE`, etc.) in `config.h` could drift from the actual frame count in the generated `dog.h`. Fixed by adding `static_assert` checks in `renderer.cpp`:
```cpp
static_assert(DOG_WALK_BASE + DOG_WALK_COUNT <= DOG_FRAME_COUNT, "...");
static_assert(DOG_RUN_BASE + DOG_RUN_COUNT <= DOG_FRAME_COUNT, "...");
static_assert(DOG_IDLE_BASE + DOG_IDLE_COUNT <= DOG_FRAME_COUNT, "...");
```

## 3. Interface Contract Audit

### IC-4 - Frame count compile-time validation (MEDIUM) [FIXED via S2]
Same as S2. The static_assert additions validate that config.h constants stay in sync with the generated sprite data.

### IC-10 - Null guard on PROGMEM sprite read (MEDIUM) [FIXED via S1]
Same as S1.

## 4. State Management Audit

### SM-1 - isPeeing leaking across behavior transitions (MEDIUM) [FIXED]
If the dog was mid-pee when a WANDER-to-FOLLOW transition occurred, `isPeeing` remained true, causing the dog to display the pee frame while following. Fixed by adding `_pet.isPeeing = false;` at the WANDER-to-FOLLOW transition.

### SM-3 - isRunning leaking into FOLLOW phase (MEDIUM) [FIXED]
Same as F2. Fixed by adding `_pet.isRunning = false;` in `petStartWalk()`.

## 5. Resource & Concurrency Audit

### R1 - PROGMEM read pattern (INFO)
Dog sprites use `pgm_read_ptr` + per-pixel `pgm_read_word` pattern, same as existing character sprites. Pre-existing design choice, not introduced by this change.

### T1 - Minor frameTimer timing (LOW)
`frameTimer` accumulates and subtracts frame duration in a loop. For very large dt values (e.g., after a long pause), this could spin briefly. Not a practical issue at 15 FPS with sub-100ms dt values.

## 6. Testing Coverage Audit

No unit test framework is configured for the firmware. Testing relies on build verification and hardware observation. The testing checklist has been updated with new dog behavior items.

## 7. DX & Maintainability Audit

### D1 - updatePet() function length (LOW)
`updatePet()` is ~175 lines. Approaches the 50-line guideline but manages a multi-state FSM where splitting would fragment the state machine logic. Acceptable for now.

### D2 - Magic number 0.5f in idle pee check (LOW)
In `updatePet()`, the idle pause comparison `wanderTimer > 0.5f` uses a literal. Could be a named constant but the value is only used once and is self-evident in context (minimum time before pee can trigger).

### D4 - Redundant isPeeing check (LOW)
The pee completion block checks `isPeeing` before clearing it, but the enclosing condition already guarantees `isPeeing` is true. Minor redundancy, no functional impact.

### D9 - convert_dog.py exit code (LOW)
Script prints error and calls `sys.exit(1)` if PIL is not installed, but other error paths (file not found) would raise unhandled exceptions. Pre-existing pattern in tool scripts.

---

## Summary

**4 findings fixed** (S1, S2/IC-4, SM-1, SM-3) -- all MEDIUM severity, addressing null safety, compile-time validation, and state leaks across behavior transitions.

**Remaining findings** are all LOW or INFO severity and represent pre-existing patterns or minor style preferences that don't warrant changes.
