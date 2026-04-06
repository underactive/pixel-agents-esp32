# Plan: Add "Flip Screen" option to hamburger menu

## Objective

Add a 4th row ("Flip: ON/OFF") to the CYD hamburger menu so users can rotate the display 180° when the board is mounted with the USB port on the opposite side. The setting persists across power cycles via NVS.

## Changes

### `firmware/src/config.h`
- Increase `MENU_H` from 70 to 90 (add 20px for the new row)

### `firmware/src/office_state.h`
- Add `bool _screenFlipped = false;` private member
- Add `isScreenFlipped()` and `setScreenFlipped(bool)` public methods

### `firmware/src/office_state.cpp`
- `loadSettings()`: Read `flipScr` bool from NVS
- `saveSettings()`: Write `flipScr` bool to NVS
- Add `setScreenFlipped()`: set member + save
- `hitTestMenuItem()`: Add row 3 handler returning `5` for flip screen tap

### `firmware/src/renderer.cpp` — `drawMenuOverlay()`
- Add separator line + "Flip:" label + ON/OFF text after color swatches row

### `firmware/src/touch_input.h` / `touch_input.cpp`
- Add `setDisplayRotation(int rotation)` method to update touch panel rotation

### `firmware/src/main.cpp`
- Move `office.init()` before display rotation so flip setting is loaded early
- Apply `tft.setRotation(3)` if flipped, update touch rotation
- Handle `item == 5` in touch handler: toggle flip, apply rotation, close menu

## Dependencies

- `office.init()` must run before `tft.setRotation()` so the persisted flip setting is available
- Touch rotation must match display rotation

## Risks / Open Questions

- XPT2046 `setRotation(3)` behavior needs hardware verification — the touch panel rotation values may not map identically to TFT_eSPI rotation values
- TFT_eSPI `setRotation(3)` is documented as 180° from rotation 1 for both ILI9341 and ST7789 drivers
