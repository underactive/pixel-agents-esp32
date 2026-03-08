# Changelog

All notable changes to Pixel Agents are documented here.

## [0.8.0] - 2026-03-08

- Add BLE transport via NimBLE Nordic UART Service for untethered operation
- Add Transport abstraction (SerialTransport, BleTransport) with abstract base class
- Add lock-free SPSC ring buffer with std::atomic acquire/release ordering for multi-core safety
- Add companion `--transport ble` and `--ble-name` CLI options
- Add bleak Python BLE client with background asyncio event loop
- Add separate Protocol instances per transport to prevent parser state corruption
- Add BLE PIN pairing for multi-CYD device selection (4-digit PIN per boot)
- Embed PIN in BLE manufacturer-specific advertising data (company ID 0xFFFF)
- Display PIN on CYD boot splash "Waiting for companion..." line in white text
- Add companion `--ble-pin` CLI option and interactive PIN prompt
- Add unified session-state reset on serial/BLE reconnect
- Fix `volatile bool` to `std::atomic<bool>` for cross-core BLE connection flag

## [0.7.1] - 2026-03-07

- Add splash screen screenshot capture (re-render into sprite buffer)
- Add CYD half-buffer two-pass support for splash screenshots
- Add footer with version string to boot splash screen
- Fix null dereference in `sendSplashScreenshot()` for direct-draw mode
- Fix `_drawYOffset` consistency in `clearCharArea()` and `addLog()`
- Extract version string to `SPLASH_VERSION_STR` constant in `config.h`

## [0.7.0] - 2026-03-07

- Add animated boot splash screen with random character at 2x scale
- Add walk-down animation cycle during boot
- Add verbose boot log with green terminal-style text
- Add backlight fade transition (fade out, render office, fade in) on companion connection
- Add serial drain callback during fade to prevent UART buffer overflow

## [0.6.1] - 2026-03-07

- Add CYD screenshot support via SPI readRect row-by-row
- No framebuffer needed for CYD screenshots

## [0.6.0] - 2026-03-07

- Add screenshot capture: press 's' in companion to capture display
- Add RLE-compressed pixel transfer over serial
- Add BMP/PNG export in companion

## [0.5.0] - 2026-03-07

- Add 4 dog color variants: black, brown, gray, tan
- Add CYD touch hamburger menu for dog toggle and color selection
- Add NVS settings persistence across reboots

## [0.4.1] - 2026-03-07

- Update dog sprites: 25x19 pixel art from PNG sprite sheet (23 frames)
- Add run and pee behaviors
- Add side-view with horizontal flip for LEFT direction

## [0.4.0] - 2026-03-07

- Add French Bulldog pet with WANDER/FOLLOW/NAP behavior FSM
- Add depth-sorted rendering with characters
- Add BFS pathfinding for pet movement
- Add dog sprite generator tool

## [0.3.0] - 2026-03-07

- Add always-visible characters: all 6 idle in social zones at boot
- Characters walk to desks when agents activate, walk back when inactive
- Status bar shows "N/6 active"

## [0.2.0] - 2026-03-06

- Add office tileset integration from PNG spritesheet
- Add tileset support in layout editor
- Add fallback to hand-drawn sprites when tileset absent

## [0.1.0] - 2026-03-05

- Initial implementation
- Sprite converter tool
- ESP32 firmware: renderer, character FSM, BFS pathfinding, binary serial protocol
- Python companion bridge (JSONL watcher + serial sender)
- Project documentation
