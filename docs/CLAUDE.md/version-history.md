# Version History

| Ver | Changes |
|-----|---------|
| 0.1.0 | Initial implementation: sprite converter, ESP32 firmware (renderer, FSM, BFS pathfinding, serial protocol), Python companion bridge, project docs |
| 0.2.0 | Office Tileset integration: extract tiles from PNG spritesheet for floor/wall/furniture rendering, tileset support in layout editor, fallback to hand-drawn sprites when tileset absent |
| 0.3.0 | Always-visible characters: all 6 characters idle in social zones (break room, library) at boot, walk to desks when agents activate, walk back when inactive; status bar shows "N/6 active" |
| 0.4.0 | French Bulldog pet: 16x16 animated dog roams the office with WANDER/FOLLOW/NAP behavior FSM, depth-sorted with characters, BFS pathfinding, sprite generator tool |
| 0.4.1 | Updated dog sprites: replaced hand-drawn 32x24 with 25x19 pixel art from PNG sprite sheet, 23 frames (8 idle, 4 walk, 8 run, sit, lay down, pee), side-view only with LEFT flip, added run and pee behaviors |
| 0.5.0 | Hamburger menu + multi-color dog: 4 dog color variants (black, brown, gray, tan), CYD touch hamburger menu for dog toggle and color selection, NVS settings persistence across reboots |
| 0.6.0 | Screenshot capture: press 's' in companion to capture ESP32 framebuffer as BMP/PNG, RLE-compressed transfer over serial, LILYGO full-buffer only (CYD returns graceful error) |
| 0.6.1 | CYD screenshot support: read pixels back from ILI9341 display controller via SPI readRect row-by-row, no framebuffer needed |
| 0.7.0 | Animated boot splash screen: random character at 2x scale with walk-down animation, verbose boot log, backlight fade transition to office scene on companion connection |
| 0.7.1 | Splash screenshot capture: re-render splash into sprite buffer for screenshot during boot, CYD half-buffer two-pass support, footer with version string, audit fixes (null guard, _drawYOffset consistency) |
| 0.8.0 | BLE transport + PIN pairing: NimBLE Nordic UART Service for untethered operation, Transport abstraction layer, lock-free SPSC ring buffer with atomic memory ordering, companion --transport ble mode with bleak, 4-digit PIN per boot for multi-CYD device selection via manufacturer advertising data, --ble-pin CLI option, interactive PIN prompt, unified session-state reset on reconnect |
| 0.8.1 | Companion launcher script: `run_companion.py` auto-creates venv, installs deps (hash-cached), forwards CLI args — replaces 5-step manual setup with single command |
| 0.8.2 | Browser firmware flasher + CI/CD: standalone `tools/firmware_update.html` using Web Serial API + esptool-js for flashing CYD/LILYGO from Chrome, drag-and-drop file selection, two flash modes (update only / full flash), GitHub Actions workflow for automated firmware builds and releases on tag push |
| 0.8.3 | ESP32 thermal management: junction temperature monitoring with thermal soak timing, thermal throttling with backlight management and CYD fault indicator LED |
| 0.8.4 | CYD display improvements: flip screen toggle in hamburger menu, strip-buffer fallback replacing half-screen buffer for no-PSRAM rendering |
| 0.8.5 | Native macOS companion menu bar app (Swift/SwiftUI, serial + BLE transport, usage stats API), BLE reconnection fix with explicit Connect button, spawn effect duration increase to 3s, README corrections, future improvements housekeeping |
| 0.8.6 | Fix CI release build (pioarduino platform URL for Arduino Core 3.x), fix usage stats fetch-on-launch and reduce poll to 15min |
