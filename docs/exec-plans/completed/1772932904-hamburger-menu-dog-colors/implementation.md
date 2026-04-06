# Implementation: Hamburger Menu + Multi-Color Dog Settings

## Files Changed

| File | Action |
|------|--------|
| `tools/convert_dog.py` | Rewritten for multi-color output (4 per-color headers + master) |
| `firmware/src/sprites/dog.h` | Regenerated (master include with `DOG_COLOR_SPRITES` array) |
| `firmware/src/sprites/dog_black.h` | New (generated) |
| `firmware/src/sprites/dog_brown.h` | New (generated) |
| `firmware/src/sprites/dog_gray.h` | New (generated) |
| `firmware/src/sprites/dog_tan.h` | New (generated) |
| `firmware/src/config.h` | Added `DogColor` enum, `DOG_COLOR_COUNT`, `DOG_DEFAULT_COLOR`, menu constants |
| `firmware/src/office_state.h` | Added `DogSettings` struct, menu state, getters/setters, hit test methods |
| `firmware/src/office_state.cpp` | Added NVS load/save, `setDogEnabled`/`setDogColor`, menu hit tests, guarded `updatePet` |
| `firmware/src/renderer.h` | Updated `drawDog` signature, added `drawHamburgerIcon`/`drawMenuOverlay` |
| `firmware/src/renderer.cpp` | Color-aware sprite lookup, hamburger icon, menu overlay, guarded depth-sort |
| `firmware/src/main.cpp` | Menu-aware touch dispatch |
| `CLAUDE.md` | Version bump to 0.5.0, file inventory |
| `docs/HISTORY.md` | Added 0.5.0 entry |
| `docs/references/testing-checklist.md` | Added hamburger menu testing items |

## Summary

Implemented exactly as planned with no deviations:
- `convert_dog.py` generates per-color headers with prefixed names (`DOG_BLACK_SIT`, etc.) and a master `dog.h` with `DOG_COLOR_SPRITES[4]` lookup table
- `DogSettings` struct holds enabled flag and color enum, persisted via ESP32 `Preferences` NVS
- Menu overlay renders a 130x70px panel with title, dog toggle, and 4 color swatches with green highlight on selected
- Touch dispatch prioritizes: open menu items > hamburger icon > status bar > character bubbles
- `DOG_SPRITES` macro aliased to `DOG_TAN_SPRITES` for backward compatibility

## Verification

- `python3 tools/convert_dog.py` — generated all 5 files successfully
- `pio run -e lilygo-t-display-s3` — SUCCESS (no touch code compiled)
- `pio run -e cyd-2432s028r` — SUCCESS (touch + menu compiled)

## Follow-ups

- Hardware testing required for CYD touch interaction and NVS persistence
- LILYGO could add serial command to change dog settings in future
- **Pre-existing critical (S7/S8):** `initTileMap()` and `WORKSTATIONS` reference rows 11-13, out of bounds on LILYGO (`GRID_ROWS=10`). Needs separate fix to guard tile map writes per board.

## Audit Fixes

### Fixes applied

1. **Q1 — `DOG_COLOR_COUNT` redefinition:** Removed `#define DOG_COLOR_COUNT` from generated `dog.h` output in `convert_dog.py`. The authoritative definition is the `static constexpr int` in `config.h`.
2. **Q4 — Menu close on title tap:** Changed `hitTestMenuItem` to return -2 for "inside menu, no action" (title row, swatch gaps, bottom padding) and -1 only for "outside menu". Updated `main.cpp` to only close menu on -1.
3. **Q7 — Exit code on missing assets:** Added `sys.exit(1)` to `convert_dog.py` when input PNG files are missing.
4. **S6 — `spriteTable` null check:** Added null guard on `spriteTable` pointer before dereference in `drawDog()` (`renderer.cpp`).
5. **IC-2 — Enum/generator ordering cross-reference:** Added comment on `DogColor` enum in `config.h`: "Order must match COLORS list in tools/convert_dog.py".
6. **IC-6/D12/SM-8 — Shared swatch constants:** Extracted `SWATCH_AREA_X`, `SWATCH_W`, `SWATCH_GAP` to `config.h`. Updated both `hitTestMenuItem()` and `drawMenuOverlay()` to use shared constants.
7. **D11 — Redundant `isPeeing` check:** Removed inner `!_pet.isPeeing` check that was already guarded by outer `if (!_pet.walking && !_pet.isPeeing)` block.
8. **D20 — Unused `timestamp` parameter:** Added `(void)timestamp;` in `onHeartbeat()` callback to suppress compiler warning.

### Verification checklist

- [x] `pio run -e lilygo-t-display-s3` — SUCCESS
- [x] `pio run -e cyd-2432s028r` — SUCCESS
- [ ] Verify swatch hit-test alignment matches rendered swatch positions on CYD hardware
- [ ] Verify tapping "Settings" title row keeps menu open (returns -2, not -1)
- [ ] Verify tapping between swatch gaps keeps menu open
- [ ] Verify `spriteTable` null guard does not affect normal dog rendering
