# Project History

Evolution of Pixel Agents ESP32 from initial concept to v0.14.1.

---

## Timeline Overview

| Phase | Versions | Focus |
|-------|----------|-------|
| 0: Foundation | v0.1.0–v0.2.0 | Core firmware, sprite system, companion bridge, tileset |
| 1: Characters & Pets | v0.3.0–v0.4.1 | Always-visible characters, French Bulldog pet, dog sprites |
| 2: CYD Touch & Menu | v0.5.0–v0.6.1 | Hamburger menu, dog colors, screenshot capture |
| 3: Boot, BLE & Transport | v0.7.0–v0.8.4 | Boot splash, BLE NUS, PIN pairing, thermal management, strip-buffer |
| 4: macOS Companion | v0.8.5–v0.8.8 | Native macOS app, Sparkle updates, BLE UX, agent ID fix |
| 5: Multi-CLI & CYD-S3 | v0.9.0–v0.9.6 | Codex CLI, CYD-S3 board, sound system, wake word, battery, settings |
| 6: macOS Features | v0.10.0–v0.10.7 | Software Display, Settings window, Sparkle, Cursor IDE, Gemini CLI |
| 7: Analytics & Polish | v0.11.0–v0.14.1 | Activity heatmaps, iCloud sync, device fingerprinting, mini-agents, provider status monitoring |

---

## Phase 0: Foundation (v0.1.0–v0.2.0)

Bootstrapped the entire system: ESP32 firmware with 16x24 pixel art characters, BFS pathfinding, binary serial protocol, Python companion bridge parsing Claude Code JSONL transcripts, and sprite converter toolchain.

**Key choice:** Binary protocol over serial (not JSON) — minimal parsing overhead on ESP32, bounded message sizes, XOR checksum for integrity.

- **v0.1.0** — Initial implementation: sprite converter, ESP32 firmware (renderer, FSM, BFS pathfinding, serial protocol), Python companion bridge, project docs
- **v0.2.0** — Office tileset integration: extract tiles from PNG spritesheet for floor/wall/furniture rendering

---

## Phase 1: Characters & Pets (v0.3.0–v0.4.1)

Made the display feel alive even without active agents. Characters now idle in social zones at boot, and a French Bulldog roams the office.

**Key choice:** All 6 characters visible at all times — idle in break room/library, walk to desks when agents activate. This made the display feel alive instead of empty.

- **v0.3.0** — Always-visible characters: 6 characters idle at boot in social zones, walk to desks when agents activate
- **v0.4.0** — French Bulldog pet: 16x16 animated dog with WANDER/FOLLOW/NAP behavior FSM
- **v0.4.1** — Updated dog sprites: 25x19 pixel art from PNG sprite sheet, 23 frames

---

## Phase 2: CYD Touch & Menu (v0.5.0–v0.6.1)

Added physical interaction via CYD's resistive touch panel and screenshot capture for sharing.

**Key choice:** Hamburger menu pattern (☰) for touch UI — simple, discoverable, extensible for future menu items.

- **v0.5.0** — Hamburger menu + multi-color dog: 4 dog color variants, CYD touch menu, NVS persistence
- **v0.6.0** — Screenshot capture: press 's' in companion for BMP/PNG, RLE-compressed transfer
- **v0.6.1** — CYD screenshot support: read pixels back from ILI9341 via SPI readRect

---

## Phase 3: Boot, BLE & Transport (v0.7.0–v0.8.4)

Added wireless connectivity via BLE NUS, proper boot experience, and robustness improvements for the CYD's limited hardware.

**Key choice:** Transport abstraction layer with lock-free SPSC ring buffer — allows serial and BLE to coexist with identical protocol, atomic memory ordering for ESP32 dual-core safety.

- **v0.7.0** — Animated boot splash screen: random character at 2x scale, backlight fade transition
- **v0.7.1** — Splash screenshot capture, footer with version string
- **v0.8.0** — BLE transport + PIN pairing: NimBLE NUS, Transport abstraction, lock-free ring buffer, 4-digit PIN
- **v0.8.1** — Companion launcher script (`run_companion.py`)
- **v0.8.2** — Browser firmware flasher + CI/CD: Web Serial flasher, GitHub Actions workflow
- **v0.8.3** — Thermal management: junction temperature monitoring, thermal throttling
- **v0.8.4** — CYD display: flip screen toggle, strip-buffer fallback for no-PSRAM rendering

---

## Phase 4: macOS Companion (v0.8.5–v0.8.8)

Built the native macOS menu bar app replacing the Python bridge for daily use, with proper UX and auto-updates.

**Key choice:** Native Swift/SwiftUI app over Electron — lower resource usage, direct CoreBluetooth access, system-native feel for a menu bar utility.

- **v0.8.5** — Native macOS companion menu bar app (Swift/SwiftUI, serial + BLE, usage stats)
- **v0.8.6** — Fix CI release build, fix usage stats fetch-on-launch
- **v0.8.7** — Custom pixel art app icon, BLE UX improvements (auto-scan, colored buttons)
- **v0.8.8** — Fix agent IDs >= 6 rejected, add agent ID recycling

---

## Phase 5: Multi-CLI & CYD-S3 (v0.9.0–v0.9.6)

Expanded beyond Claude Code to support Codex CLI and added the Freenove CYD-S3 board variant with I2S audio and wake word detection.

**Key choice:** CYD-S3 with ES8311 codec enabled 16-bit I2S audio and ESP-SR wake word — major capability upgrade over CYD's 8-bit DAC. Custom partition table (`partitions_sr_16MB.csv`) trades OTA for WakeNet model storage.

- **v0.9.0** — Codex CLI support, CYD-S3 board (ILI9341 + FT6336G + BLE + NeoPixel), unified LED ambient, event-driven sound system (I2S + ES8311 / DAC), simplified agent list UI
- **v0.9.1** — CYD-S3 build added to GitHub Actions release
- **v0.9.2** — ESP-SR WakeNet9 wake word detection ("Computer"), custom partition table
- **v0.9.3** — "Remaining" usage display mode in macOS companion
- **v0.9.4** — Display sleep, battery monitor, transport icons, BLE Battery Service, OAuth caching
- **v0.9.5** — macOS code signing, notarization, DMG packaging
- **v0.9.6** — Fix high CPU: FSEvents-driven processing replacing blind polling

---

## Phase 6: macOS Features (v0.10.0–v0.10.7)

Built the Software Display mode for users without ESP32 hardware, added Sparkle auto-updates, and expanded to Cursor IDE and Gemini CLI.

**Key choice:** Software Display renders the same office scene natively on macOS (SharedOfficeRenderer) — same FSM, BFS, dog AI, but outputting CGImage at 15 FPS instead of TFT sprites.

- **v0.10.0** — Software Display mode (PIP window, NSPanel), Settings window, Sparkle auto-update
- **v0.10.1** — Custom DMG background, appcast signature fix
- **v0.10.2** — Ko-fi donation link
- **v0.10.3** — Fix Sparkle CFBundleVersion mismatch
- **v0.10.4** — Move "Check for Updates" to About window
- **v0.10.5** — Remote device settings over serial/BLE (DEVICE_SETTINGS protocol)
- **v0.10.6** — Cursor IDE support: usage stats via api2.cursor.sh, brand SVG icons
- **v0.10.7** — Gemini CLI support: session JSON parsing, OAuth usage quota, brand color

---

## Phase 7: Analytics & Polish (v0.11.0–v0.14.1)

Added activity heatmaps for all providers, iCloud sync, device fingerprinting, and mini-agents for overflow characters.

**Key choice:** Local SQLite for activity data with iCloud Drive sync — works offline, per-device JSON files with MAX merge strategy, no server dependency.

- **v0.11.0** — Activity heatmaps: SQLite database, GitHub-style 53-week grids, per-provider brand colors
- **v0.11.1** — iCloud Drive sync for heatmap data
- **v0.11.2** — Fix Cursor usage with immutable SQLite URI mode
- **v0.11.3** — Device fingerprinting (MSG_IDENTIFY_REQ/RSP), BLE NUS TX notifications
- **v0.11.4** — Fix Settings window height, fix Device settings actor isolation
- **v0.11.5** — Device fingerprint validation warning
- **v0.11.6** — Provider brand icons in agent list, Cursor auth moved to Settings
- **v0.11.7** — Accounts tab, Settings menu item, Disconnect button
- **v0.11.8** — Cursor Tool Calls heatmap
- **v0.11.9** — Fix tool call heatmap counting without hardware
- **v0.12.0** — Card backgrounds, collapsible heatmaps, Gemini color update, Software default
- **v0.12.1** — Three-mode display picker (Off/Software/ESP32), Settings reorganization
- **v0.12.2** — BLE battery percentage, fix device settings over BLE
- **v0.13.0** — Mini-agents (60%-scale robots for overflow beyond 6 desks), MSG_REBOOT, agent sync
- **v0.13.1** — Software mode sound effects, agent list show/hide toggle, fix mini-agent idle bug
- **v0.13.2** — Crash reporter, AgentTracker stability fixes, settings window auto-sizing, docs restructure
- **v0.14.0** — Provider status monitoring: poll Claude/Codex/Gemini/Cursor status pages, show incident banners in usage tabs
- **v0.14.1** — Preserve raw API timestamps and extra usage credits in cache file
