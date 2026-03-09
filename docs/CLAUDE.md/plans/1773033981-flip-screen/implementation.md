# Implementation: Add "Flip Screen" option to hamburger menu

## Files Changed

- `firmware/src/config.h` — increased `MENU_H` from 70 to 90
- `firmware/src/office_state.h` — added `_screenFlipped` member, `isScreenFlipped()`, `setScreenFlipped()`
- `firmware/src/office_state.cpp` — NVS load/save for `flipScr`, `setScreenFlipped()`, `hitTestMenuItem()` row 3
- `firmware/src/renderer.cpp` — `drawMenuOverlay()` row 3 with "Flip: ON/OFF"
- `firmware/src/touch_input.h` — added `setDisplayRotation()` declaration
- `firmware/src/touch_input.cpp` — added `setDisplayRotation()` implementation
- `firmware/src/main.cpp` — reordered `office.init()` before rotation, applied flip on boot, added item==5 touch handler

## Summary

Implemented exactly as planned. The flip screen feature follows the same pattern as the dog toggle:
- State stored in `OfficeState::_screenFlipped`
- Persisted via NVS key `flipScr`
- Rendered as a menu row with green ON / red OFF indicator
- Touch hit test returns `5` for the flip row
- `main.cpp` applies `tft.setRotation(3)` for flipped, `1` for normal
- Touch panel rotation updated via `touchInput.setDisplayRotation()` to match
- `office.init()` moved before `tft.setRotation()` in setup so the persisted setting is available at boot

No deviations from the plan.

## Verification

1. `pio run -e cyd-2432s028r` — SUCCESS (RAM: 12.3%, Flash: 82.5%)
2. `pio run -e lilygo-t-display-s3` — SUCCESS (compiles clean, touch code excluded via `#if defined(HAS_TOUCH)`)

## Follow-ups

- Hardware verification needed: confirm XPT2046 `setRotation(3)` correctly maps touch coordinates in the flipped orientation
- LILYGO has no touch — flip would need a different trigger mechanism (e.g., serial command) if desired on that board

## Audit Fixes

### Fixes applied

1. Updated `hitTestMenuItem` return value comment in `main.cpp` to document value `5` for flip screen (addresses Q2, D1, D2, I1, M3)
2. Added doc comment on `setScreenFlipped()` declaration noting caller must also update TFT and touch rotation (addresses I3, M1, S6, D3)
3. Added derivation comment on `MENU_H = 90` in `config.h` (addresses D5, M6)
4. Added comment on `office.closeMenu()` after flip toggle explaining why menu auto-closes (addresses D7)
5. Added 8 manual test items to `docs/CLAUDE.md/testing-checklist.md` covering flip screen toggle, persistence, touch correctness, and screenshots (addresses T1-T8, T10)

### Verification checklist

- [x] CYD build succeeds after comment additions
- [ ] Touch coordinates map correctly after `setRotation(3)` on hardware (Q4/I5/T5)
- [ ] Flip setting persists across power cycle (T4)
- [ ] Screenshot in flipped mode is correctly oriented (T10)

### Unresolved items

- **D4** (duplicated rotation coordination): Accepted — only 2 call sites, a helper function would require TFT + touch references adding complexity for marginal benefit.
- **R1** (NVS write latency): Pre-existing pattern shared with dog toggle. Deferred.
- **R4/I2** (NVS write failure not checked): Pre-existing. Deferred.
