# CLAUDE.md - Pixel Agents ESP32 Project Context

## Project Overview

**Pixel Agents ESP32** is a standalone hardware display that renders Claude Code agents as animated 16x24 pixel art characters in a virtual office scene on an ESP32-S3 with a small color TFT, driven by JSONL transcripts from Claude Code CLI via a Python companion bridge.

**Current Version:** 0.12.2
**Status:** In development

---

## Hardware

### Microcontroller
Two board targets are supported:

**ESP32-2432S028R "Cheap Yellow Display" (CYD)** (primary)
- ESP32 (non-S3), dual-core, 240 MHz
- WiFi + BLE (not used in v1)
- No PSRAM
- 2.8" ILI9341 320x240, resistive touch (XPT2046)
- SC8002B mono amp on GPIO 26 (ESP32 internal DAC) + 2-pin 1.25mm JST speaker header

**Freenove ESP32-S3 2.8" (fnk0104)** (`freenove-s3-28c`)
- ESP32-S3, Xtensa LX7 dual-core, 240 MHz
- WiFi + BLE
- 16MB Flash, 8MB PSRAM (OPI)
- USB-C, 2.8" ILI9341 320x240, capacitive touch (FT6336G over I2C)
- ES8311 audio codec + speaker amplifier (I2S + I2C)

**LILYGO T-Display S3** (secondary)
- ESP32-S3, Xtensa LX7 dual-core, 240 MHz
- WiFi + BLE (not used in v1)
- 16MB Flash, 8MB PSRAM (OPI)
- USB-C, built-in 1.9" IPS ST7789 display (170x320)

Pin assignments and component details: see `docs/agents/hardware.md`.

---

## Architecture

### System Architecture
```
[Claude Code CLI] --> writes JSONL --> [Python companion] --> USB Serial --> [ESP32 + TFT]
[Codex CLI]       --> writes JSONL --|        |                  or
[Gemini CLI]      --> writes JSON  --|  reads ~/.claude/rate-limits-cache.json
                                              |
                                              +--> BLE (NUS) --> [ESP32 + TFT]

[Claude Code CLI] --> writes JSONL --> [macOS companion app] --> USB Serial / BLE --> [ESP32 + TFT]
[Codex CLI]       --> writes JSONL --|        |
[Gemini CLI]      --> writes JSON  --|  reads OAuth token from Keychain
                                  fetches usage stats from Anthropic API, Google Gemini API
                                  writes ~/.claude/rate-limits-cache.json
```

### Core Files
Modular C++ firmware with Python companion service and native macOS app.

- `firmware/src/main.cpp` -- Entry point: setup, main loop, serial callbacks
- `firmware/src/config.h` -- Constants, enums, structs (tile grid, timing, protocol, workstations)
- `firmware/src/office_state.h/.cpp` -- Character FSM, BFS pathfinding, agent lifecycle, idle activities, usage stats
- `firmware/src/renderer.h/.cpp` -- TFT_eSprite double-buffered rendering pipeline
- `firmware/src/protocol.h/.cpp` -- Binary serial protocol parser (non-blocking state machine)
- `firmware/src/transport.h/.cpp` -- Transport abstraction (base class, SerialTransport, BleTransport, RingBuffer)
- `firmware/src/ble_service.h/.cpp` -- NimBLE BLE NUS server (`HAS_BLE`)
- `firmware/src/touch_input.h/.cpp` -- Touch input driver (`HAS_TOUCH` / `CAP_TOUCH`)
- `firmware/src/sound.h/.cpp` -- Event-driven sound system (`HAS_SOUND`)
- `firmware/src/wakeword.h/.cpp` -- ESP-SR wake word detection (`HAS_WAKEWORD`)
- `firmware/src/battery.h/.cpp` -- Battery voltage monitoring (`HAS_BATTERY`)
- `companion/pixel_agents_bridge.py` -- Transcript watcher + serial sender (Claude Code + Codex CLI + Gemini CLI)
- `macos/PixelAgents/` -- Native macOS menu bar companion app (Swift/SwiftUI)

Full file inventory: see `docs/agents/file-inventory.md`.

### Dependencies
- **PlatformIO** -- Build system
- **espressif32** -- ESP32 platform
- **Arduino framework** -- Runtime
- **TFT_eSPI** (Bodmer, ^2.5.0) -- Display driver
- **XPT2046_Touchscreen** (PaulStoffregen) -- Touch driver (CYD only)
- **NimBLE-Arduino** (h2zero, ^2.1.0) -- BLE stack (CYD and CYD-S3, `HAS_BLE`)
- **Adafruit NeoPixel** (adafruit, ^1.12.0) -- WS2812B LED driver (CYD-S3 only, `LED_TYPE_NEOPIXEL`)
- **ES8311 codec driver** (Espressif component, Apache-2.0) -- I2C codec control for CYD-S3 audio
- **ESP-SR** (Espressif, espressif/esp-sr ^1.9.0) -- WakeNet9 wake word detection (CYD-S3 only, `HAS_WAKEWORD`)
- **pyserial** (>=3.5) -- Python serial communication
- **bleak** (>=0.21.0) -- Python BLE client (for `--transport ble`)
- **Sparkle** (sparkle-project, ^2.6.0) -- macOS auto-update framework (EdDSA-signed appcast)
- **Xcode 15+** -- macOS companion app build (Swift 5.9+, SwiftUI, CoreBluetooth, IOKit)

### Key Subsystems

Detailed specs: see `docs/agents/subsystems.md`.

| # | Subsystem | Source | Guard | Purpose |
|---|-----------|--------|-------|---------|
| 1 | Rendering Pipeline | `renderer.cpp` | — | Double-buffered TFT_eSprite, 15 FPS, strip-buffer fallback on CYD |
| 2 | Character State Machine | `office_state.cpp` | — | FSM (OFFLINE/IDLE/WALK/TYPE/READ/SPAWN/DESPAWN/ACTIVITY), BFS pathfinding |
| 3 | Serial Protocol | `protocol.cpp` | — | Binary framing `[0xAA][0x55][TYPE][PAYLOAD][XOR]`, 10 message types |
| 4 | Companion Bridge | `pixel_agents_bridge.py` | — | Watches Claude/Codex/Gemini transcripts, sends binary updates |
| 5 | Sprite System | `sprites/*.h` | — | RGB565 PROGMEM arrays, generated by `tools/` scripts |
| 6 | BLE Transport | `ble_service.cpp` | `HAS_BLE` | NimBLE NUS server, lock-free ring buffer, 4-digit PIN |
| 7 | Touch Input | `touch_input.cpp` | `HAS_TOUCH` | XPT2046 (CYD) / FT6336G (CYD-S3), hamburger menu |
| 8 | Status Bar | `renderer.cpp` | — | USB/BT icons, 5 display modes, battery indicator |
| 9 | LED Ambient | `led_ambient.cpp` | `HAS_LED` | PWM (CYD) / NeoPixel (CYD-S3), 5 auto-selected modes |
| 10 | Audio / Sound | `sound.cpp` | `HAS_SOUND` | I2S playback, 5 event clips, ES8311 (CYD-S3) / DAC (CYD) |
| 11 | macOS Companion | `macos/PixelAgents/` | — | Swift menu bar app, Serial/BLE, Sparkle auto-update |
| 12 | Wake Word | `wakeword.cpp` | `HAS_WAKEWORD` | ESP-SR WakeNet9 "Computer", CYD-S3 only |
| 13 | Battery Monitor | `battery.cpp` | `HAS_BATTERY` | ADC + LiPo curve, CYD-S3 + LILYGO |

---

## Build Configuration

### PlatformIO Configuration

Three environments in `platformio.ini`:

**`[env:cyd-2432s028r]`** (default)
- **board:** `esp32dev` -- generic ESP32 board definition
- **-DBOARD_CYD=1** -- enables CYD-specific layout, grid size, LED ambient, and conditional compilation
- **-DHAS_TOUCH=1** -- enables touch input subsystem compilation (XPT2046 resistive)
- **-DHAS_BLE=1** -- enables BLE NUS transport compilation
- **board_build.partitions=huge_app.csv** -- 3MB app partition (no OTA) to fit PCM sound data
- No PSRAM; renderer uses strip-buffer fallback (`_stripMode`, 320x30 bands) or direct-draw

**`[env:freenove-s3-28c]`**
- **board:** `esp32-s3-devkitc-1` -- ESP32-S3 CYD with ILI9341 + FT6336G capacitive touch
- **-DBOARD_CYD_S3=1** -- enables CYD-S3-specific layout and conditional compilation
- **-DUSE_FSPI_PORT=1** -- fixes TFT_eSPI SPI register address bug on ESP32-S3 with pioarduino (forces `SPI_PORT = 2`)
- **-DTFT_INVERSION_ON=1** -- fixes ILI9341 color inversion on this panel variant
- **-DHAS_TOUCH=1 / -DCAP_TOUCH=1** -- enables capacitive touch input (FT6336G over I2C)
- **-DHAS_BLE=1** -- enables BLE NUS transport compilation
- **board_build.arduino.memory_type=qio_opi** -- enables PSRAM for full-frame double buffer
- **board_build.partitions=partitions_sr_16MB.csv** -- custom partition table with `srmodels` partition for ESP-SR WakeNet model (drops OTA)

**`[env:lilygo-t-display-s3]`**
- **board:** `lilygo-t-display-s3` -- ESP32-S3 with built-in ST7789 display
- **-DUSE_FSPI_PORT=1** -- fixes TFT_eSPI SPI register address bug on ESP32-S3 with pioarduino
- **board_build.arduino.memory_type=qio_opi** -- enables PSRAM for full-frame double buffer
- **board_build.partitions=default_16MB.csv** -- full 16MB flash partition layout

**Shared flags (all environments):**
- **-DUSER_SETUP_LOADED=1** -- tells TFT_eSPI to use build_flags instead of User_Setup.h
- **-DSPI_FREQUENCY=40000000** -- 40MHz SPI for fast display updates
- **-DLOAD_FONT2=1 / LOAD_FONT4=1 / SMOOTH_FONT=1** -- font rendering for status bar text

### Environment Variables

| Variable | Purpose | Values |
|----------|---------|--------|
| `BOARD_CYD` | Build-time board selection (ESP32 CYD), enables PWM LED and CYD-specific layout | Defined in CYD env only |
| `BOARD_CYD_S3` | Build-time board selection (ESP32-S3 CYD) | Defined in CYD-S3 env only |
| `HAS_TOUCH` | Enables touch input + hamburger menu compilation | Defined in CYD and CYD-S3 envs |
| `CAP_TOUCH` | Selects capacitive touch driver (FT6336G) instead of resistive (XPT2046) | Defined in CYD-S3 env only |
| `HAS_BLE` | Enables BLE NUS transport compilation | Defined in CYD and CYD-S3 envs |
| `USE_FSPI_PORT` | Forces TFT_eSPI `SPI_PORT = 2` on ESP32-S3 (workaround for pioarduino `FSPI = 0` bug) | Defined in both S3 envs |
| `HAS_LED` | Enables LED ambient subsystem (auto-defined in `config.h` from `BOARD_CYD` or `BOARD_CYD_S3`) | Auto |
| `HAS_SOUND` | Enables sound playback (auto-defined in `config.h` for `BOARD_CYD` and `BOARD_CYD_S3`) | Auto |
| `HAS_WAKEWORD` | Enables ESP-SR wake word detection (auto-defined in `config.h` for `BOARD_CYD_S3` only) | Auto |
| `HAS_BATTERY` | Enables battery voltage monitoring (auto-defined in `config.h` for `BOARD_CYD_S3` and LILYGO) | Auto |
| `BATTERY_ADC_PIN` | GPIO pin for battery ADC: 9 (CYD-S3), 4 (LILYGO). Only defined when `HAS_BATTERY` is set | Auto |
| `SOUND_DAC_INTERNAL` | Selects ESP32 internal DAC I2S mode (auto-defined in `config.h` for `BOARD_CYD`) | Auto |
| `SOUND_HAS_AMP_ENABLE` | Whether amp has a GPIO enable pin: 1 for CYD-S3 (ES8311), 0 for CYD (SC8002B always-on) | Auto |
| `LED_TYPE_PWM` | Selects PWM-driven common-anode RGB LED (auto-defined in `config.h` for `BOARD_CYD`) | Auto |
| `LED_TYPE_NEOPIXEL` | Selects WS2812B NeoPixel LED (auto-defined in `config.h` for `BOARD_CYD_S3`) | Auto |
| `USER_SETUP_LOADED` | TFT_eSPI config via build_flags | Always `1` |

Environment files / define sources:
- `firmware/platformio.ini` -- all build defines set via `build_flags` per environment
- `firmware/src/config.h` -- derived defines (`HAS_LED`, `HAS_SOUND`, `HAS_WAKEWORD`, `SOUND_DAC_INTERNAL`, `SOUND_HAS_AMP_ENABLE`, `LED_TYPE_PWM`, `LED_TYPE_NEOPIXEL`) set from board selection

---

## Code Style

- **Linter:** None configured (manual review)
- **Formatter:** None configured (manual review)
- **Indentation:** 4 spaces (C++), 4 spaces (Python)
- **C++ style:** `camelCase` for functions/variables, `PascalCase` for classes/enums, `UPPER_SNAKE` for constants/defines
- **Python style:** PEP 8, `snake_case`
- **Line endings:** LF

---

## External Integrations

### Claude Code JSONL Transcripts
- **What:** JSONL files written by Claude Code CLI, one per conversation session
- **Loaded via:** filesystem polling (`~/.claude/projects/*/` directory)
- **Lifecycle:** Files created when a Claude Code session starts; companion watches files modified within the last 5 minutes
- **Gotchas:** JSONL format is not a public API and may change between Claude Code versions. The companion only reads `type`, `message.content[].type`, `message.stop_reason`, and `turn_duration` fields.

### OpenAI Codex CLI Rollout Files
- **What:** JSONL rollout files written by Codex CLI, one per session
- **Loaded via:** filesystem polling (`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`)
- **Lifecycle:** Files created when a Codex session starts; companion watches files modified within the last 5 minutes
- **Gotchas:** Rollout JSONL format is an internal detail of Codex CLI and may change between versions. The companion handles both `codex exec --json` event format and `RolloutLine` envelope format, and silently skips unrecognized records.

### Google Gemini CLI Session Files
- **What:** Monolithic JSON session files written by Gemini CLI (`@google/gemini-cli`), one per conversation
- **Loaded via:** filesystem polling (`~/.gemini/tmp/{project-slug}/chats/session-*.json`)
- **Lifecycle:** Files created when a Gemini CLI session starts; companion watches files modified within the last 5 minutes
- **Key fields:** `messages[].type` ("user" or "gemini"), `messages[].toolCalls[].name`, `messages[].toolCalls[].displayName`
- **Gotchas:** Unlike Claude/Codex, Gemini uses monolithic JSON (not JSONL). The entire file must be re-parsed on each poll cycle (optimized by tracking file size changes). Session format is an internal detail of Gemini CLI and may change between versions.

### Google Gemini CLI Usage API
- **What:** OAuth-based quota API for Gemini CLI usage statistics (macOS companion app only)
- **Auth:** Reads OAuth credentials from `~/.gemini/oauth_creds.json`; refreshes tokens via Google OAuth2 endpoint using client credentials from Gemini CLI source
- **API endpoints:** `loadCodeAssist` for project discovery, `retrieveUserQuota` for quota buckets (both at `cloudcode-pa.googleapis.com`)
- **Gotchas:** Requires `oauth-personal` auth type. Client credentials are extracted from Gemini CLI npm package source (safe per Google's installed-app OAuth spec, but may change if Google rotates them).

### Claude Code Rate Limits Cache
- **What:** JSON file written by Claude Code CLI containing current/weekly usage percentages and reset timestamps
- **Loaded via:** file read from `~/.claude/rate-limits-cache.json` every 10s
- **Lifecycle:** Updated by Claude Code; read-only by companion
- **Key fields:** `current_pct`, `weekly_pct`, `current_resets_at` (ISO 8601), `weekly_resets_at` (ISO 8601)
- **Gotchas:** File may not exist if Claude Code hasn't been run. Format is undocumented and may change.

---

## Known Issues / Limitations

1. **Transcript formats not public APIs** -- Claude Code JSONL, Codex CLI rollout JSONL, and Gemini CLI session JSON formats may change between versions
2. **No WiFi mode** -- USB serial or BLE only (no WiFi/WebSocket)
3. **No wireless OTA updates** -- Must flash via USB (browser-based flasher available at `tools/firmware_update.html`)
4. **ESP32 CYD has no PSRAM** -- Renderer uses fallback modes (strip-buffer or direct-draw) which may have visual artifacts
5. **CYD audio is 8-bit DAC** -- ESP32 internal DAC provides only 8-bit resolution vs 16-bit on CYD-S3 (ES8311). Sound quality is lower; `SOUND_VOLUME_SHIFT` provides software attenuation to reduce distortion
6. **CYD uses no-OTA partition** -- `huge_app.csv` (3MB app) was required to fit PCM sound data; wireless OTA (if ever added) would not work on CYD

---

## Development Rules

### 1. Validate all external input at the boundary
Every value arriving from serial must be validated and clamped before use. Never assign an externally-supplied value without bounds checking.

### 2. Guard all array-indexed lookups
Any value used as an index into an array must have a bounds check before access: `(val < COUNT) ? ARRAY[val] : fallback`. This is defense-in-depth against corrupt or unvalidated values.

### 3. Reset connection-scoped state on disconnect
Serial buffer state, heartbeat timer reset on reconnect. Buffers, flags, and session variables that accumulate state during a connection must be reset on disconnect to prevent cross-session corruption.

### 4. Avoid memory-fragmenting patterns in long-running code
Use fixed-size arrays for characters, paths, tool names. No dynamic allocation in the main loop. Reserve dynamic allocation for short-lived, one-shot operations.

### 5. Use symbolic constants, not magic numbers
All values defined in `config.h`. Never hardcode index values or numeric constants -- use named defines or enums. When data structures are reordered, update both the data and all symbolic references together.

### 6. Throttle event-driven output
Agent count messages sent only on change. Frame rate capped at 15 FPS. Usage stats sent only when values change.

### 7. Use bounded string formatting
Always `snprintf(buf, sizeof(buf), ...)` for text rendering. This prevents silent overflow if format arguments change in the future.

### 8. Report errors, don't silently fail
Invalid protocol messages are discarded with state reset, not silently consumed. When input exceeds limits or operations fail, provide actionable error feedback to the caller.

---

## Plan Pre-Implementation

Before planning, check `docs/agents/plans/` for prior plans that touched the same areas. Scan the **Files changed** lists in both `implementation.md` and `audit.md` files to find relevant plans without reading every file -- then read the full `plan.md` only for matches. This keeps context window usage low while preserving access to project history.

When a plan is finalized and about to be implemented, write the full plan to `docs/agents/plans/{epoch}-{plan_name}/plan.md`, where `{epoch}` is the Unix timestamp at the time of writing and `{plan_name}` is a short kebab-case description of the plan (e.g., `1709142000-add-user-auth/plan.md`).

The epoch prefix ensures chronological ordering -- newer plans visibly supersede earlier ones at a glance based on directory name ordering.

The plan document should include:
- **Objective** -- what is being implemented and why
- **Changes** -- files to modify/create, with descriptions of each change
- **Dependencies** -- any prerequisites or ordering constraints between changes
- **Risks / open questions** -- anything flagged during planning that needs attention

---

## Plan Post-Implementation

After a plan has been fully implemented, write the completed implementation record to `docs/agents/plans/{epoch}-{plan_name}/implementation.md`, using the same directory as the corresponding `plan.md`.

The implementation document **must** include:
- **Files changed** -- list of all files created, modified, or deleted. This section is **required** -- it serves as a lightweight index for future planning, allowing prior plans to be found by scanning file lists without reading full plan contents.
- **Summary** -- what was actually implemented (noting any deviations from the plan)
- **Verification** -- steps taken to verify the implementation is correct (tests run, manual checks, build confirmation)
- **Follow-ups** -- any remaining work, known limitations, or future improvements identified during implementation

If the implementation added or changed user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/agents/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Post-Implementation Audit

After finishing implementation of a plan, run 7 audit subagents **in parallel** on all changed files: (1) QA, (2) Security, (3) Interface Contract, (4) State Management, (5) Resource & Concurrency, (6) Testing Coverage, (7) DX & Maintainability.

Full audit descriptions, scope/output directives, and post-audit fix process: see `docs/agents/audit-checklist.md`.

---

## Common Modifications

### Version bumps
Version string appears in 5 files:
1. `CLAUDE.md` -- "Current Version" in Project Overview section
2. `CHANGELOG.md` -- add a new `## [x.y.z]` section at top with bullet points
3. `docs/agents/version-history.md` -- append a new row to the table
4. `firmware/src/config.h` -- `SPLASH_VERSION_STR` (boot splash footer text) and `FIRMWARE_VERSION_ENCODED` (identify response, encoded as `major*1000 + minor*10 + patch`)
5. `macos/PixelAgents/project.yml` -- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (Sparkle update comparison)

**Keep all version references in sync.** Always bump all files together during any version bump.

### Add a new board variant
1. Add a new `[env:board-name]` section in `firmware/platformio.ini` with board-specific build_flags
2. Add `#if defined(BOARD_XXX)` conditionals in `firmware/src/config.h` for grid dimensions, workstation layout, and any board-specific pin definitions
3. If the board has unique peripherals (e.g., touch), add conditional compilation in `main.cpp` and create a new driver module
4. Update the Hardware section of this file
5. Add hardware testing items to `docs/agents/testing-checklist.md`

### Add a new protocol message type
1. Define `MSG_NEW_TYPE` constant in `firmware/src/config.h` (next available hex value after 0x0A)
2. Add matching constant in `companion/pixel_agents_bridge.py`
3. Add payload struct in `firmware/src/protocol.h`
4. Add callback type and member in `Protocol` class (`protocol.h`)
5. Add `payloadLength()` case and `dispatch()` handler in `firmware/src/protocol.cpp`
6. Add `build_new_type()` function in `companion/pixel_agents_bridge.py`
7. Wire callback in `firmware/src/main.cpp` setup

### Add a new sound effect
1. Place MP3 in `assets/sounds/`
2. Run `python3 tools/convert_sound.py assets/sounds/xxx.mp3` (use `-n name` to override auto-slug)
3. Add enum value to `SoundId` in `firmware/src/sound.h` (before `COUNT`)
4. Add `#include` for the PCM header in `firmware/src/sound.cpp`
5. Add table entry in `CLIPS[]` in `firmware/src/sound.cpp` (order must match enum)
6. Trigger via `queueSound(SoundId::XXX)` in `office_state.cpp`, or `sound.play(SoundId::XXX)` in `main.cpp`

### Add a new character sprite frame
1. Add the new frame to the source PNG sprite sheets in `assets/characters/`
2. Update `FRAMES_PER_DIR` in `firmware/src/config.h` if frame count changed
3. Run `python3 tools/convert_characters.py` to regenerate `firmware/src/sprites/characters.h`
4. Update `getFrameIndex()` in `firmware/src/renderer.cpp` to map the new frame
5. Verify in `tools/sprite_validation.html`

### Add a new furniture sprite
1. Define the sprite as RGB565 data in `tools/sprite_converter.py`
2. Run `python3 tools/sprite_converter.py` to regenerate `firmware/src/sprites/furniture.h`
3. Add placement coordinates in `firmware/src/renderer.cpp` `drawFurniture()`
4. Mark occupied tiles as `TileType::BLOCKED` in `office_state.cpp` `initTileMap()`
5. Verify in `tools/sprite_validation.html`

---

## File Inventory

See `docs/agents/file-inventory.md` for the complete file and directory listing.

---

## Build Instructions

### Prerequisites
- PlatformIO CLI or VS Code extension
- Python 3.8+ (dependencies installed automatically by `run_companion.py`)

### Quick Start
```bash
# Generate sprite headers (run once, or after sprite changes)
python3 tools/sprite_converter.py

# Build and flash firmware (CYD)
cd firmware && pio run -e cyd-2432s028r --target upload

# Build and flash firmware (CYD-S3 Capacitive)
cd firmware && pio run -e freenove-s3-28c --target upload

# Build and flash firmware (LILYGO T-Display S3)
cd firmware && pio run -e lilygo-t-display-s3 --target upload

# Start companion bridge
python3 run_companion.py
```

### Troubleshooting Build
- **"No ESP32 serial port found."** -- Ensure the board is connected via USB-C. On macOS, check for `/dev/cu.usbmodem*` or `/dev/cu.usbserial*`. Try `--port /dev/cu.XXX` to specify manually.
- **"PSRAM not found" or crash on LILYGO** -- Verify `board_build.arduino.memory_type = qio_opi` is set in platformio.ini.
- **CYD display is blank** -- CYD has no reset pin (`TFT_RST=-1`). Ensure `ILI9341_DRIVER` is defined, not `ST7789_DRIVER`.
- **Touch not responding on CYD** -- XPT2046 uses a separate SPI bus (VSPI). Check that `HAS_TOUCH=1` build flag is set.

---

## Testing

See `docs/agents/testing-checklist.md` for the full QA testing checklist.

---

## Future Improvements

See `docs/agents/future-improvements.md` for the ideas backlog.

---

## Maintaining This File

### Keep CLAUDE.md in sync with the codebase
**Every plan that adds, removes, or changes a feature must include CLAUDE.md updates as part of the implementation.** Treat CLAUDE.md as a living spec -- if the code and this file disagree, this file is wrong and must be fixed before the work is considered complete. During plan post-implementation, verify that all sections affected by the change are accurate. If a feature is removed, delete its documentation here rather than leaving stale references.

### When to update CLAUDE.md
- **Adding a new subsystem or module** -- add it to Architecture (Core Files + Key Subsystems table here, detailed spec in `docs/agents/subsystems.md`) and `docs/agents/file-inventory.md`
- **Removing a subsystem or module** -- remove it from Architecture, `docs/agents/subsystems.md`, and `docs/agents/file-inventory.md`; remove or update any cross-references in other sections
- **Adding a new setting or config field** -- update the relevant subsystem section in `docs/agents/subsystems.md` and Common Modifications
- **Discovering a new bug class** -- add a Development Rule to prevent recurrence
- **Changing the build process** -- update Build Instructions and/or Build Configuration
- **Adding/changing build defines** -- update Build Configuration > Environment Variables
- **Adding a new board variant** -- update Hardware (here + `docs/agents/hardware.md`), Build Configuration, and follow Common Modifications recipe
- **Integrating a new third-party service or SDK** -- add to External Integrations and Dependencies
- **Removing an integration or dependency** -- remove from External Integrations and Dependencies
- **Bumping the version** -- update the version in Project Overview
- **Adding/removing files** -- update `docs/agents/file-inventory.md`
- **Finding a new limitation** -- add to Known Issues
- **Resolving a known limitation** -- remove from Known Issues
- **Adding a new protocol message** -- update Serial Protocol table in `docs/agents/subsystems.md` and follow Common Modifications recipe

### Supplementary docs
For sections that grow large, move them to separate files under `docs/agents/` and link from here. Currently extracted: `subsystems.md`, `hardware.md`, `audit-checklist.md`, `file-inventory.md`, `testing-checklist.md`, `future-improvements.md`, `version-history.md`.

### Future improvements tracking
When a new feature is added and related enhancements or follow-up ideas are suggested but declined, add them as `- [ ]` items to `docs/agents/future-improvements.md`. This preserves good ideas for later without cluttering the current task.

### Version history maintenance
When making changes that are committed to the repository, add a row to the version history table in `docs/agents/version-history.md`. Each entry should include:

- **Ver** -- A semantic version identifier (e.g., `v0.1.0`, `v0.2.0`). Follow semver: MAJOR.MINOR.PATCH. Use the most recent entry in the table to determine the next version number.
- **Changes** -- A brief summary of what changed.

Append new rows to the bottom of the table. Do not remove or rewrite existing entries.

### Testing checklist maintenance
When adding or modifying user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/agents/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

### What belongs here vs. in code comments
- **Here:** Architecture decisions, cross-cutting concerns, "how things fit together," gotchas, recipes
- **In code:** Implementation details, function-level docs, inline explanations of tricky logic

---

## Origin

Created with Claude (Anthropic)
