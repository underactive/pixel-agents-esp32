# Plan: Hamburger Menu + Multi-Color Dog Settings

## Objective
Add a hamburger menu to the status bar (CYD touch only) that lets the user enable/disable the dog pet and select its color from 4 variants (black, brown, gray, tan). Settings persist across reboots via NVS.

## Changes

### Phase 1: Sprite Generation
- `tools/convert_dog.py` — Rewrite to generate 4 color-specific headers + master `dog.h`
- Output: `dog_black.h`, `dog_brown.h`, `dog_gray.h`, `dog_tan.h`, `dog.h` (master)

### Phase 2: Config + State
- `firmware/src/config.h` — Add `DogColor` enum, menu constants inside `HAS_TOUCH` block
- `firmware/src/office_state.h` — Add `DogSettings` struct, menu state, new public/private methods
- `firmware/src/office_state.cpp` — NVS persistence (load/save), dog enable/disable, color setting, menu hit tests, guard `updatePet` on `_dogSettings.enabled`

### Phase 3: Rendering
- `firmware/src/renderer.h` — Update `drawDog` signature, add `drawHamburgerIcon`/`drawMenuOverlay` under `HAS_TOUCH`
- `firmware/src/renderer.cpp` — Color-aware dog sprite lookup via `DOG_COLOR_SPRITES`, hamburger icon in status bar, menu overlay, guard depth-sort entry on dog enabled

### Phase 4: Input Wiring
- `firmware/src/main.cpp` — Menu-aware touch dispatch: menu items > hamburger > status bar > character hit test

### Phase 5: Housekeeping
- `CLAUDE.md` — Version bump to 0.5.0, file inventory update
- `docs/HISTORY.md` — New entry
- `docs/references/testing-checklist.md` — Menu/dog testing items

## Dependencies
- Phase 1 must complete before Phase 3 (renderer needs generated headers)
- Phase 2 must complete before Phase 3 and Phase 4 (they depend on new state methods)

## Risks
1. Flash usage: 4 colors = ~88KB PROGMEM total (vs ~22KB for one). Both boards have ample flash.
2. NVS write wear: `Preferences` writes only on setting change, negligible wear.
3. LILYGO has no touch: Menu is CYD-only. Dog defaults to enabled+tan on both boards.
