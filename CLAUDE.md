# CLAUDE.md - Pixel Agents ESP32 Project Context

## Project Overview

**Pixel Agents ESP32** is a standalone hardware display that renders Claude Code agents as animated 16x24 pixel art characters in a virtual office scene on an ESP32-S3 with a small color TFT, driven by JSONL transcripts from Claude Code CLI via a Python companion bridge.

**Current Version:** 0.9.2
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

### Components
| Ref | Component | Purpose |
|-----|-----------|---------|
| U1 | ESP32 (CYD), ESP32-S3 (CYD-S3, LILYGO) | MCU + display driver |
| D1 | ILI9341 2.8" TFT (CYD, CYD-S3) or ST7789 1.9" IPS (LILYGO) | Pixel art scene display |
| T1 | XPT2046 (CYD) or FT6336G (CYD-S3) | Touch input |
| S1 | SC8002B mono amp (CYD) or ES8311 audio codec + speaker amp (CYD-S3) | Sound effects playback |
| M1 | ES8311 analog mic input (CYD-S3 only) | Wake word detection microphone |

### Pin Assignments

**LILYGO T-Display S3:**

| Pin | Function | Notes |
|-----|----------|-------|
| 11 | TFT_MOSI | SPI data |
| 12 | TFT_SCLK | SPI clock |
| 10 | TFT_CS | Chip select |
| 13 | TFT_DC | Data/command |
| 9 | TFT_RST | Reset |
| 14 | TFT_BL | Backlight |

**CYD (ESP32-2432S028R):**

| Pin | Function | Notes |
|-----|----------|-------|
| 13 | TFT_MOSI | SPI data |
| 14 | TFT_SCLK | SPI clock |
| 15 | TFT_CS | Chip select |
| 2 | TFT_DC | Data/command |
| -1 | TFT_RST | No reset pin |
| 21 | TFT_BL | Backlight |
| 12 | TFT_MISO | SPI read-back |
| 25 | TOUCH_CLK | XPT2046 SPI clock (separate bus) |
| 39 | TOUCH_MISO | XPT2046 SPI data in |
| 32 | TOUCH_MOSI | XPT2046 SPI data out |
| 33 | TOUCH_CS | XPT2046 chip select |
| 36 | TOUCH_IRQ | XPT2046 interrupt |
| 26 | AUDIO_DAC | ESP32 internal DAC → SC8002B amp → speaker header |

**CYD-S3 Capacitive (`freenove-s3-28c`):**

| Pin | Function | Notes |
|-----|----------|-------|
| 11 | TFT_MOSI | SPI data |
| 12 | TFT_SCLK | SPI clock |
| 10 | TFT_CS | Chip select |
| 46 | TFT_DC | Data/command |
| -1 | TFT_RST | No reset pin |
| 45 | TFT_BL | Backlight |
| 16 | TOUCH_SDA | FT6336G I2C data (shared with ES8311) |
| 15 | TOUCH_SCL | FT6336G I2C clock (shared with ES8311) |
| 42 | LED_NEOPIXEL | WS2812B addressable RGB LED |
| 4 | I2S_MCK | ES8311 master clock |
| 5 | I2S_BCLK | I2S bit clock |
| 6 | I2S_DIN | I2S data in (ES8311 ADC, wake word mic input) |
| 7 | I2S_WS | I2S word select |
| 8 | I2S_DOUT | I2S data out |
| 1 | AMP_ENABLE | Speaker amp enable (AP_ENABLE) |

---

## Architecture

### System Architecture
```
[Claude Code CLI] --> writes JSONL --> [Python companion] --> USB Serial --> [ESP32 + TFT]
[Codex CLI]       --> writes JSONL --|        |                  or
                                  reads ~/.claude/rate-limits-cache.json
                                              |
                                              +--> BLE (NUS) --> [ESP32 + TFT]

[Claude Code CLI] --> writes JSONL --> [macOS companion app] --> USB Serial / BLE --> [ESP32 + TFT]
[Codex CLI]       --> writes JSONL --|        |
                                  reads OAuth token from Keychain
                                  fetches usage stats from Anthropic API
                                  writes ~/.claude/rate-limits-cache.json
```

### Core Files
Modular C++ firmware with Python companion service and native macOS app.

- `firmware/src/main.cpp` -- Entry point: setup, main loop, serial callbacks
- `firmware/src/config.h` -- Constants, enums, structs (tile grid, timing, protocol, workstations)
- `firmware/src/office_state.h/.cpp` -- Character FSM, BFS pathfinding, agent lifecycle, idle activities, usage stats
- `firmware/src/renderer.h/.cpp` -- TFT_eSprite double-buffered rendering pipeline
- `firmware/src/protocol.h/.cpp` -- Binary serial protocol parser (non-blocking state machine)
- `firmware/src/splash.h/.cpp` -- Animated boot splash screen (title, 2x character, boot log, backlight fade)
- `firmware/src/thermal_mgr.h/.cpp` -- ESP32 junction temperature monitoring and thermal soak management
- `firmware/src/transport.h` -- Transport abstraction (abstract base, SerialTransport, BleTransport, RingBuffer)
- `firmware/src/transport.cpp` -- SerialTransport implementation (wraps Arduino Serial)
- `firmware/src/ble_service.h/.cpp` -- NimBLE BLE NUS server (CYD and CYD-S3, `#if defined(HAS_BLE)`)
- `firmware/src/touch_input.h/.cpp` -- Touch input driver: XPT2046 resistive (CYD) or FT6336G capacitive (CYD-S3, `CAP_TOUCH`)
- `firmware/src/led_ambient.h/.cpp` -- RGB LED ambient indicator (CYD + CYD-S3, `#if defined(HAS_LED)`)
- `firmware/src/sound.h/.cpp` -- Event-driven sound system (CYD-S3, `#if defined(HAS_SOUND)`)
- `firmware/src/wakeword.h/.cpp` -- ESP-SR WakeNet9 wake word detection (CYD-S3, `#if defined(HAS_WAKEWORD)`)
- `firmware/src/codec/es8311/*` -- ES8311 codec driver (Apache-2.0)
- `firmware/src/sounds/*.h` -- PCM sound data headers: startup chime, dog bark, keyboard type, notification click, minimal pop (PROGMEM)
- `firmware/src/sprites/characters.h` -- Character sprites as direct RGB565 arrays (PROGMEM, generated by convert_characters.py)
- `firmware/src/sprites/furniture.h` -- Furniture sprites as RGB565 arrays (PROGMEM)
- `firmware/src/sprites/bubbles.h` -- Speech bubble sprites as RGB565 arrays (PROGMEM)
- `firmware/src/sprites/dog.h` -- Dog pet sprites as RGB565 arrays (PROGMEM, generated by convert_dog.py)
- `companion/pixel_agents_bridge.py` -- JSONL watcher + serial sender (Claude Code + Codex CLI)
- `macos/PixelAgents/` -- Native macOS menu bar companion app (Swift/SwiftUI, Claude Code + Codex CLI)
- `tools/sprite_converter.py` -- Generates C headers from sprite definitions (furniture, bubbles, tiles)
- `tools/convert_characters.py` -- Generates character sprite headers from PNG sprite sheets
- `tools/convert_dog.py` -- Generates dog sprite headers from PNG sprite sheets
- `tools/convert_sound.py` -- Converts MP3 files to C PCM headers (ffmpeg, 24kHz mono s16le)

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
- **Xcode 15+** -- macOS companion app build (Swift 5.9+, SwiftUI, CoreBluetooth, IOKit)

### Key Subsystems

#### 1. Rendering Pipeline (`renderer.cpp`)
- Landscape via `tft.setRotation(1)` -- 320x170 (LILYGO) or 320x240 (CYD)
- Full-frame double buffer with `TFT_eSprite` in PSRAM -- `pushSprite(0,0)`
- CYD (no PSRAM): strip-buffer fallback (`_stripMode`, 320x30 bands) or direct-draw (`_directMode`)
- Render order: floor --> walls --> depth-sorted entities (furniture + characters by Y) --> speech bubbles --> status bar
- 15 FPS target (~66ms/frame)
- Character sprites: template index --> palette lookup --> RGB565 --> `fillRect` per pixel
- LEFT-facing sprites rendered by horizontally flipping RIGHT sprites

#### 2. Character State Machine (`office_state.cpp`)
- States: `OFFLINE`, `IDLE`, `WALK`, `TYPE`, `READ`, `SPAWN`, `DESPAWN`, `ACTIVITY`
- IDLE: standing still, periodic wander (random tile, 2-20s pause between moves, 3-6 moves per wander burst)
- WALK: 4-frame cycle [walk1, walk2, walk3, walk2] at 0.15s/frame, BFS pathfinding, 48px/s
- TYPE/READ: 2-frame cycle at 0.3s/frame, seated at assigned desk
- ACTIVITY: idle activity at interaction points (reading at bookshelf, coffee, water, socializing near another character)
  - 40% chance per wander trigger, with cooldown to prevent repeats
  - Interaction points defined per activity type with specific tile positions and facing directions
  - Social zones: BREAK_ROOM (upper-right) and LIBRARY (lower-right)
- Agent active --> pathfind to desk --> TYPE/READ. Inactive --> stand --> IDLE --> wander/activity
- Spawn/despawn: matrix column-reveal effect over 3.0s
- 6 workstations with board-specific layouts defined in `config.h`
- Dog settings and screen flip persisted to NVS flash

#### 3. Serial Protocol (`protocol.cpp`)
Binary framing: `[0xAA][0x55][MSG_TYPE][PAYLOAD...][XOR_CHECKSUM]`

| Message | Type | Payload |
|---------|------|---------|
| AGENT_UPDATE | 0x01 | agent_id(1) + state(1) + tool_name_len(1) + tool_name(0-24) |
| AGENT_COUNT | 0x02 | count(1) |
| HEARTBEAT | 0x03 | timestamp(4, big-endian) |
| STATUS_TEXT | 0x04 | agent_id(1) + text_len(1) + text(0-32) |
| USAGE_STATS | 0x05 | current_pct(1) + weekly_pct(1) + current_reset_min(2, big-endian) + weekly_reset_min(2, big-endian) |
| SCREENSHOT_REQ | 0x06 | (none) |

Screenshot response (ESP32 → companion) uses distinct sync bytes `[0xBB][0x66]` followed by a 10-byte header and RLE pixel data. Not part of the standard framing protocol.

Non-blocking state machine parser. Heartbeat watchdog: "Disconnected" if no heartbeat for 6s.

#### 4. Companion Bridge (`companion/pixel_agents_bridge.py`)
- Watches `~/.claude/projects/` and `~/.codex/sessions/` for active JSONL transcript files (modified within 5 minutes)
- Supports Claude Code and OpenAI Codex CLI simultaneously -- each active session gets its own agent
- Supports `--transport serial` (default) or `--transport ble` for untethered operation
- Polls at 4Hz, sends HEARTBEAT every 2s
- Derives agent state from JSONL records:
  - **Claude Code:** `tool_use` in assistant message --> TYPE (or READ if tool in `READING_TOOLS` set: Read, Grep, Glob, WebFetch, WebSearch); `turn_duration` / `end_turn` --> IDLE
  - **Codex CLI (3 formats):**
    - *Current rollout (snake_case):* `response_item` with `function_call`/`custom_tool_call` --> TYPE (or READ for read commands via `exec_command`); `web_search_call` --> READ; `event_msg` with `task_complete`/`turn_aborted` --> IDLE; `session_meta`/`turn_context`/`compacted` ignored
    - *codex exec --json:* `item.started`/`item.completed` with `command_execution` --> TYPE/READ; `turn.completed` --> IDLE
    - *Legacy RolloutLine (PascalCase):* `ResponseItem`/`EventMsg` envelopes (backward compat)
- Sends binary AGENT_UPDATE on state change only
- Prunes stale agents after 30s, auto-reconnects on disconnect
- BLE mode: scans for device by name using bleak, writes to NUS RX characteristic, resets tracking state on reconnect
- Screenshots only available over serial (disabled over BLE)
- Reads `~/.claude/rate-limits-cache.json` every 10s, sends USAGE_STATS on change

#### 5. Sprite System
- Characters: direct RGB565 (16x32 pixels/frame, 512 pixels = 1024 bytes/frame), 6 variants
- 0x0000 = transparent. Art is bottom-aligned with top padding in the 16x32 frame.
- 21 frames per character: 7 frames x 3 directions (DOWN, UP, RIGHT). LEFT = flip RIGHT.
- Frames per direction: walk1, walk2 (standing), walk3, type1, type2, read1, read2
- Dog: 23 direct RGB565 frames (25x19), 4 color variants (black, brown, gray, tan). LEFT = flip RIGHT.
- Furniture/bubbles: direct RGB565 uint16_t arrays
- All sprite data in PROGMEM (flash)
- Generated by `tools/convert_characters.py` (characters), `tools/sprite_converter.py` (furniture/bubbles/tiles), and `tools/convert_dog.py` (dog)

#### 6. BLE Transport (`ble_service.cpp`, CYD and CYD-S3)
- NimBLE Nordic UART Service (NUS) — standard BLE serial profile
- ESP32 acts as BLE peripheral (server), companion as central (client)
- RX characteristic receives protocol messages from companion
- TX characteristic reserved for future bidirectional messages
- Lock-free SPSC ring buffer transfers bytes from NimBLE callback context to main loop
- Ring buffer uses `std::atomic` acquire/release ordering for multi-core safety
- Deferred reset on disconnect (flagged atomically, executed in main loop)
- Separate `Protocol` instance per transport prevents parser state corruption
- BLE and Serial can be active simultaneously
- Screenshots are serial-only (BLE transport does not support SCREENSHOT_REQ)
- Device advertises as `BLE_DEVICE_NAME` ("PixelAgents")
- 4-digit PIN (1000-9999) generated per boot via `esp_random()`, embedded in manufacturer-specific advertising data for multi-device selection
- PIN is device-selection convenience (not security) — broadcast in cleartext, no server-side verification
- Manufacturer data format: 2-byte company ID (`0xFFFF`, little-endian) + 2-byte PIN (big-endian), fits within 31-byte advertising limit
- PIN displayed as white suffix on "Waiting for companion..." log line during CYD boot splash
- Companion `--ble-pin XXXX` connects directly; interactive mode prompts for PIN; non-interactive mode connects to first device
- Memory overhead: ~312KB flash + 15KB RAM (NimBLE with central/observer roles disabled)

#### 7. Touch Input (`touch_input.cpp`, CYD and CYD-S3)
- Compiled only when `HAS_TOUCH` build flag is set
- CYD: XPT2046 resistive on separate VSPI bus (pins 25/39/32/33, IRQ on 36)
- CYD-S3: FT6336G capacitive on I2C (compiled when `CAP_TOUCH` is defined)
- Debounced at 200ms, tap-on-release detection
- Tap status bar --> cycles through 5 status modes (overview, usage, agent list, FPS, uptime)
- Tap character --> shows info bubble for 3s
- Hamburger menu (7x5px icon, top-left): tap to open settings overlay
  - Toggle dog on/off
  - Dog color swatches (black, brown, gray, tan)
  - Screen flip toggle (persisted to NVS)
  - Sound on/off toggle (CYD defaults off, CYD-S3 defaults on, persisted to NVS)


#### 8. Status Bar
5 display modes, cycled via touch (CYD) or auto on LILYGO:

| Mode | Content |
|------|---------|
| OVERVIEW | Connection dot (green/red) + agent count |
| USAGE_STATS | Current + weekly usage percentage bars |
| AGENT_LIST | Per-agent ID:state |
| PERFORMANCE | FPS counter |
| UPTIME | Device uptime |

#### 9. LED Ambient (`led_ambient.cpp`, CYD and CYD-S3)
- CYD: active-low common-anode RGB LED on pins R=4, G=16, B=17 (PWM 5kHz, 8-bit)
- CYD-S3: WS2812B NeoPixel addressable RGB LED on GPIO 42 (Adafruit NeoPixel library)
- 5 modes, auto-selected based on state:

| Mode | Trigger | Effect |
|------|---------|--------|
| OFF | Disconnected | Black |
| IDLE_BREATHE | Connected, no active agents | Dim cyan sine-wave breathing (4s period) |
| ACTIVE | 1-3 active agents | Steady green, brightness scales with agent count |
| BUSY | 4+ active agents | Steady orange |
| RATE_LIMITED | Usage >= 90% | Red pulse (2s period) |

#### 10. Audio / Sound System (`sound.cpp`, CYD and CYD-S3)
- Two I2S backends, selected at compile time via `SOUND_DAC_INTERNAL`:
  - **CYD:** ESP32 internal 8-bit DAC (`I2S_MODE_DAC_BUILT_IN`) on GPIO 26 → SC8002B mono amp (always-on, no enable pin)
  - **CYD-S3:** External I2S to ES8311 codec (I2C control), AP_ENABLE gate pin, MCLK/BCLK/WS/DOUT pinout
- CYD internal DAC: signed PCM converted to unsigned (+0x8000), software volume attenuation via `SOUND_VOLUME_SHIFT` (>>2 = /4)
- CYD uses larger DMA buffers (16x512) for stutter-free playback during strip-buffer rendering; CYD-S3 uses 12x512
- Inter-strip audio feeding: `sound.update()` called between strip renders via callback to prevent DMA underrun
- Table-driven `SoundId` enum + `CLIPS[]` lookup — adding a sound is enum + table entry + include
- `play(SoundId)` with preemption: new sounds interrupt currently playing clips
- Amp enabled per-clip (in `startClip()`), disabled when playback ends (in `update()`) — guarded by `SOUND_HAS_AMP_ENABLE` (CYD-S3 only)
- 5 event-triggered clips:
  - **STARTUP** — chime on splash → office transition after first connection
  - **DOG_BARK** — bark when dog picks new follow target
  - **KEYBOARD_TYPE** — typing sound on agent's first TYPE transition per job (deduplicated via `hasPlayedJobSound`)
  - **NOTIFICATION_CLICK** — click when agent finishes turn (goes IDLE / waiting for user input)
  - **MINIMAL_POP** — pop when agent is waiting for tool permission approval
- PCM stored in PROGMEM (24kHz mono), duplicated to stereo before I2S writes
- PCM headers generated by `tools/convert_sound.py` (ffmpeg MP3 → 24kHz s16le → C header)
- Sound on/off toggle via hamburger menu, persisted to NVS (`"soundOn"` key). CYD defaults off, CYD-S3 defaults on. `queueSound()` checks `_soundEnabled` before queuing; startup sound also gated in `main.cpp`
- Generic pending-sound queue in `OfficeState` (`queueSound(SoundId)` / `consumePendingSound()`)
- Permission detection in Python companion: timeout heuristic (1s after `tool_use` with `stop_reason="tool_use"` and no new JSONL records → sends TYPE with "PERMISSION" tool name)
#### 11. macOS Companion App (`macos/PixelAgents/`)
- Native Swift/SwiftUI menu bar app (alternative to Python companion bridge)
- Runs as menu bar extra (hidden from dock, `LSUIElement`)
- Connects via Serial (POSIX file descriptors) or BLE (CoreBluetooth NUS client)
- FSEvents-based transcript watching (`~/.claude/projects/` and `~/.codex/sessions/`)
- Reads OAuth token from macOS Keychain, fetches usage stats from Anthropic API directly
- Writes `~/.claude/rate-limits-cache.json` (same format as Python bridge reads)
- Screenshot capture: decodes RLE response, saves PNG to `~/Pictures/PixelAgents/`
- IOKit-based serial port auto-detection with USB device notifications
- Launch at login via `SMAppService`
- UI: connection status dot, transport picker (serial/BLE), agent list with state indicators, usage bars with reset timers
- Codex CLI support: `CodexStateDeriver` parses rollout JSONL alongside Claude's `StateDeriver` (supports current snake_case, codex exec --json, and legacy PascalCase formats)
- Unit tests: StateDeriverTests, CodexStateDeriverTests, ProtocolBuilderTests, AgentTrackerTests

#### 12. Wake Word Detection (`wakeword.cpp`, CYD-S3 only)
- ESP-SR WakeNet9 neural net for "Computer" keyword detection
- Runs on dedicated FreeRTOS task pinned to Core 0 (main loop on Core 1)
- Audio pipeline: I2S RX (24kHz stereo) → left-channel mono extraction → 3:2 linear interpolation downsample → 16kHz WakeNet feed
- PSRAM buffers for stereo, mono 24kHz, and 16kHz feed (allocated once in task, never freed — device lifetime)
- `std::atomic<bool>` for cross-core `_detected` and `_paused` flags (written on Core 0, read on Core 1)
- Pause/resume API: `wakeword_pause()` / `wakeword_resume()` called by sound system around clip playback
- Post-pause DMA flush: 16 iterations draining stale I2S RX buffers to prevent false detections from leftover speaker audio
- 5-second cooldown between detections (`WAKEWORD_COOLDOWN_MS`) to prevent rapid re-triggering
- Detection triggers `DOG_BARK` sound via `office.queueSound()` (respects sound toggle)
- Custom partition table `partitions_sr_16MB.csv`: drops OTA partition to fit `srmodels` partition for WakeNet9 model binary
- Compile-time gated by `#if defined(HAS_WAKEWORD)` — only active for CYD-S3 (requires ESP-SR + PSRAM + ES8311 mic)
- Init failure is non-fatal: logs error, device continues without wake word

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

### Claude Code Rate Limits Cache
- **What:** JSON file written by Claude Code CLI containing current/weekly usage percentages and reset timestamps
- **Loaded via:** file read from `~/.claude/rate-limits-cache.json` every 10s
- **Lifecycle:** Updated by Claude Code; read-only by companion
- **Key fields:** `current_pct`, `weekly_pct`, `current_resets_at` (ISO 8601), `weekly_resets_at` (ISO 8601)
- **Gotchas:** File may not exist if Claude Code hasn't been run. Format is undocumented and may change.

---

## Known Issues / Limitations

1. **JSONL formats not public APIs** -- Claude Code transcript format and Codex CLI rollout format may change between versions
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

Before planning, check `docs/CLAUDE.md/plans/` for prior plans that touched the same areas. Scan the **Files changed** lists in both `implementation.md` and `audit.md` files to find relevant plans without reading every file -- then read the full `plan.md` only for matches. This keeps context window usage low while preserving access to project history.

When a plan is finalized and about to be implemented, write the full plan to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/plan.md`, where `{epoch}` is the Unix timestamp at the time of writing and `{plan_name}` is a short kebab-case description of the plan (e.g., `1709142000-add-user-auth/plan.md`).

The epoch prefix ensures chronological ordering -- newer plans visibly supersede earlier ones at a glance based on directory name ordering.

The plan document should include:
- **Objective** -- what is being implemented and why
- **Changes** -- files to modify/create, with descriptions of each change
- **Dependencies** -- any prerequisites or ordering constraints between changes
- **Risks / open questions** -- anything flagged during planning that needs attention

---

## Plan Post-Implementation

After a plan has been fully implemented, write the completed implementation record to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/implementation.md`, using the same directory as the corresponding `plan.md`.

The implementation document **must** include:
- **Files changed** -- list of all files created, modified, or deleted. This section is **required** -- it serves as a lightweight index for future planning, allowing prior plans to be found by scanning file lists without reading full plan contents.
- **Summary** -- what was actually implemented (noting any deviations from the plan)
- **Verification** -- steps taken to verify the implementation is correct (tests run, manual checks, build confirmation)
- **Follow-ups** -- any remaining work, known limitations, or future improvements identified during implementation

If the implementation added or changed user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Post-Implementation Audit

After finishing implementation of a plan, run the following subagents **in parallel** to audit all changed files.

> **Scope directive for all subagents:** Only flag issues in the changed code and its immediate dependents. Do not audit the entire codebase.

> **Output directive:** After all subagents complete, write a single consolidated audit report to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/audit.md`, using the same directory as the corresponding `plan.md`. The audit report **must** include a **Files changed** section listing all files where findings were flagged. This section is **required** -- it serves as a lightweight index for future planning, covering files affected by audit findings (including immediate dependents not in the original implementation).

### 1. QA Audit (subagent)
Review changes for:
- **Functional correctness**: broken workflows, missing error/loading states, unreachable code paths, logic that doesn't match spec
- **Edge cases**: empty/null/undefined inputs, zero-length collections, off-by-one errors, race conditions, boundary values (min/max/overflow)
- **Infinite loops**: unbounded `while`/recursive calls, callbacks triggering themselves, retry logic without max attempts or backoff
- **Performance**: unnecessary computation in hot paths, O(n^2) or worse in loops over growing data, unthrottled event handlers, expensive operations blocking main thread or interrupt context

### 2. Security Audit (subagent)
Review changes for:
- **Injection / input trust**: unsanitized external input used in commands, queries, or output rendering; format string vulnerabilities; untrusted data used in control flow
- **Overflows**: unbounded buffer writes, unguarded index access, integer overflow/underflow in arithmetic, unchecked size parameters
- **Memory leaks**: allocated resources not freed on all exit paths, event/interrupt handlers not deregistered on cleanup, growing caches or buffers without eviction or bounds
- **Hard crashes**: null/undefined dereferences without guards, unhandled exceptions in async or interrupt context, uncaught error propagation across module boundaries

### 3. Interface Contract Audit (subagent)
Review changes for:
- **Data shape mismatches**: caller assumptions that diverge from actual API/protocol schema, missing fields treated as present, incorrect type coercion or endianness
- **Error handling**: no distinction between recoverable and fatal errors, swallowed failures, missing retry/backoff on transient faults, no timeout or watchdog configuration
- **Auth / privilege flows**: credential or token lifecycle issues, missing permission checks, race conditions during handshake or session refresh
- **Data consistency**: optimistic state updates without rollback on failure, stale cache served after mutation, sequence counters or cursors not invalidated after writes

### 4. State Management Audit (subagent)
Review changes for:
- **Mutation discipline**: shared state modified outside designated update paths, state transitions that skip validation, side effects hidden inside getters or read operations
- **Reactivity / observation pitfalls**: mutable updates that bypass change detection or notification mechanisms, deeply nested state triggering unnecessary cascading updates
- **Data flow**: excessive pass-through of context across layers where a shared store or service belongs, sibling modules communicating via parent state mutation, event/signal spaghetti without cleanup
- **Sync issues**: local copies shadowing canonical state, multiple sources of truth for the same entity, concurrent writers without arbitration (locks, atomics, or message ordering)

### 5. Resource & Concurrency Audit (subagent)
Review changes for:
- **Concurrency**: data races on shared memory, missing locks/mutexes/atomics around critical sections, deadlock potential from lock ordering, priority inversion in RTOS or threaded contexts
- **Resource lifecycle**: file handles, sockets, DMA channels, or peripherals not released on error paths; double-free or use-after-free; resource exhaustion under sustained load
- **Timing**: assumptions about execution order without synchronization, spin-waits without yield or timeout, interrupt latency not accounted for in real-time constraints
- **Power & hardware**: peripherals left in active state after use, missing clock gating or sleep transitions, watchdog not fed on long operations, register access without volatile or memory barriers

### 6. Testing Coverage Audit (subagent)
Review changes for:
- **Missing tests**: new public functions/modules without corresponding unit tests, modified branching logic without updated assertions, deleted tests not replaced
- **Test quality**: assertions on implementation details instead of behavior, tests coupled to internal structure, mocked so heavily the test proves nothing
- **Integration gaps**: cross-module flows tested only with mocks and never with integration or contract tests, initialization/shutdown sequences untested, error injection paths uncovered
- **Flakiness risks**: tests dependent on timing or sleep, shared mutable state between test cases, non-deterministic data (random IDs, timestamps), hardware-dependent tests without abstraction layer

### 7. DX & Maintainability Audit (subagent)
Review changes for:
- **Readability**: functions exceeding ~50 lines, boolean parameters without named constants, magic numbers/strings without explanation, nested ternaries or conditionals deeper than one level
- **Dead code**: unused includes/imports, unreachable branches behind stale feature flags, commented-out blocks with no context, exported symbols with zero consumers
- **Naming & structure**: inconsistent naming conventions, business/domain logic buried in UI or driver layers, utility functions duplicated across modules
- **Documentation**: public API changes without updated doc comments, non-obvious workarounds missing a `// WHY:` comment, breaking changes without migration notes

---

## Audit Post-Implementation

After audit findings have been addressed, update the `implementation.md` file in the corresponding `docs/CLAUDE.md/plans/{epoch}-{plan_name}/` directory:

1. **Flag fixed items** -- In the audit report (`docs/CLAUDE.md/plans/{epoch}-{plan_name}/audit.md`), mark each finding that was fixed with a `[FIXED]` prefix so it is visually distinct from unresolved items.

2. **Append a fixes summary** -- Add an `## Audit Fixes` section at the end of `implementation.md` containing:
   - **Fixes applied** -- a numbered list of each fix, referencing the audit finding it addresses (e.g., "Fixed unchecked index access flagged by Security Audit S2")
   - **Verification checklist** -- a `- [ ]` checkbox list of specific tests or manual checks to confirm each fix is correct (e.g., "Verify bounds check on `configIndex` with out-of-range input returns fallback")

3. **Leave unresolved items as-is** -- Any audit findings intentionally deferred or accepted as-is should remain unmarked in the audit report. Add a brief note in the fixes summary explaining why they were not addressed.

4. **Update testing checklist** -- If any audit fixes changed user-facing behavior, add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Common Modifications

### Version bumps
Version string appears in 4 files:
1. `CLAUDE.md` -- "Current Version" in Project Overview section
2. `CHANGELOG.md` -- add a new `## [x.y.z]` section at top with bullet points
3. `docs/CLAUDE.md/version-history.md` -- append a new row to the table
4. `firmware/src/config.h` -- `SPLASH_VERSION_STR` (boot splash footer text)

**Keep all version references in sync.** Always bump all files together during any version bump.

### Add a new board variant
1. Add a new `[env:board-name]` section in `firmware/platformio.ini` with board-specific build_flags
2. Add `#if defined(BOARD_XXX)` conditionals in `firmware/src/config.h` for grid dimensions, workstation layout, and any board-specific pin definitions
3. If the board has unique peripherals (e.g., touch), add conditional compilation in `main.cpp` and create a new driver module
4. Update the Hardware section of this file
5. Add hardware testing items to `docs/CLAUDE.md/testing-checklist.md`

### Add a new protocol message type
1. Define `MSG_NEW_TYPE` constant in `firmware/src/config.h` (next available hex value after 0x05)
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

| File / Directory | Purpose |
|------------------|---------|
| `firmware/` | ESP32 PlatformIO project |
| `firmware/platformio.ini` | Build configuration (three board environments) |
| `firmware/partitions_sr_16MB.csv` | Custom partition table for CYD-S3 with ESP-SR model storage |
| `firmware/src/main.cpp` | Entry point: setup, main loop, callbacks |
| `firmware/src/config.h` | Constants, enums, structs, board-specific layouts |
| `firmware/src/protocol.h/.cpp` | Serial protocol parser (state machine) |
| `firmware/src/office_state.h/.cpp` | Game state, character FSM, BFS pathfinding, idle activities |
| `firmware/src/renderer.h/.cpp` | Display rendering (double-buffered or fallback) |
| `firmware/src/splash.h/.cpp` | Animated boot splash screen |
| `firmware/src/thermal_mgr.h/.cpp` | ESP32 junction temperature monitoring and thermal soak |
| `firmware/src/transport.h` | Transport abstraction (base class, SerialTransport, BleTransport, RingBuffer) |
| `firmware/src/transport.cpp` | SerialTransport implementation |
| `firmware/src/ble_service.h/.cpp` | NimBLE BLE NUS server (CYD and CYD-S3) |
| `firmware/src/touch_input.h/.cpp` | Touch driver: XPT2046 resistive (CYD) or FT6336G capacitive (CYD-S3) |
| `firmware/src/led_ambient.h/.cpp` | RGB LED ambient indicator (CYD PWM + CYD-S3 NeoPixel) |
| `firmware/src/sound.h/.cpp` | Event-driven sound system (CYD-S3 I2S + ES8311) |
| `firmware/src/wakeword.h/.cpp` | ESP-SR WakeNet9 wake word detection (CYD-S3 only) |
| `firmware/src/codec/es8311/` | ES8311 codec driver (Apache-2.0) |
| `firmware/src/sounds/startup_sound_pcm.h` | Startup chime PCM data (PROGMEM) |
| `firmware/src/sounds/dog_bark_pcm.h` | Dog bark PCM data (PROGMEM) |
| `firmware/src/sounds/keyboard_type_pcm.h` | Keyboard typing PCM data (PROGMEM) |
| `firmware/src/sounds/notification_click_pcm.h` | Notification click PCM data (PROGMEM) |
| `firmware/src/sounds/minimal_pop_pcm.h` | Minimal pop PCM data (PROGMEM) |
| `firmware/src/sprites/characters.h` | Generated character sprite data — direct RGB565 (PROGMEM) |
| `firmware/src/sprites/furniture.h` | Generated furniture sprite data (PROGMEM) |
| `firmware/src/sprites/tiles.h` | Generated floor/wall tile data from tileset (PROGMEM, optional) |
| `firmware/src/sprites/bubbles.h` | Generated speech bubble sprite data (PROGMEM) |
| `firmware/src/sprites/dog.h` | Generated master dog sprite include (all colors, PROGMEM) |
| `firmware/src/sprites/dog_black.h` | Generated dog sprites — black variant (PROGMEM) |
| `firmware/src/sprites/dog_brown.h` | Generated dog sprites — brown variant (PROGMEM) |
| `firmware/src/sprites/dog_gray.h` | Generated dog sprites — gray variant (PROGMEM) |
| `firmware/src/sprites/dog_tan.h` | Generated dog sprites — tan variant (PROGMEM) |
| `companion/` | Python bridge service |
| `companion/pixel_agents_bridge.py` | JSONL watcher + serial sender (Claude Code + Codex CLI) |
| `companion/ble_transport.py` | BLE client transport using bleak |
| `companion/requirements.txt` | Python dependencies (`pyserial>=3.5`, `bleak>=0.21.0`) |
| `macos/PixelAgents/` | Native macOS menu bar companion app (Xcode project) |
| `tools/sprite_converter.py` | Furniture/bubbles/tiles --> C header generator |
| `tools/convert_characters.py` | Character PNG sprite sheets --> C header generator |
| `tools/convert_dog.py` | Dog pet PNG sprite sheet --> C header generator |
| `tools/convert_sound.py` | MP3 --> 24kHz mono s16le PCM C header generator (ffmpeg) |
| `tools/sprite_validation.html` | Visual sprite verification (browser, generated) |
| `tools/layout_editor.html` | Office layout visual editor (generates C code) |
| `tools/firmware_update.html` | Browser-based firmware flasher (Web Serial + esptool-js) |
| `assets/` | Source artwork: character PNGs, dog sprite sheets, office tileset |
| `run_companion.py` | Cross-platform companion launcher (auto-creates venv, installs deps) |
| `CLAUDE.md` | This file |
| `README.md` | User-facing project documentation |
| `CHANGELOG.md` | User-facing changelog (Keep a Changelog format) |
| `LICENSE` | Project license |
| `.github/workflows/release.yml` | GitHub Actions release workflow |
| `docs/CLAUDE.md/plans/` | Plan, implementation, and audit records (epoch-prefixed directories) |
| `docs/CLAUDE.md/testing-checklist.md` | QA testing checklist |
| `docs/CLAUDE.md/version-history.md` | Version history table |
| `docs/CLAUDE.md/future-improvements.md` | Ideas backlog |

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

See `docs/CLAUDE.md/testing-checklist.md` for the full QA testing checklist.

---

## Future Improvements

See `docs/CLAUDE.md/future-improvements.md` for the ideas backlog.

---

## Maintaining This File

### Keep CLAUDE.md in sync with the codebase
**Every plan that adds, removes, or changes a feature must include CLAUDE.md updates as part of the implementation.** Treat CLAUDE.md as a living spec -- if the code and this file disagree, this file is wrong and must be fixed before the work is considered complete. During plan post-implementation, verify that all sections affected by the change are accurate. If a feature is removed, delete its documentation here rather than leaving stale references.

### When to update CLAUDE.md
- **Adding a new subsystem or module** -- add it to Architecture (Core Files + Key Subsystems) and File Inventory
- **Removing a subsystem or module** -- remove it from Architecture and File Inventory; remove or update any cross-references in other sections
- **Adding a new setting or config field** -- update the relevant subsystem section and Common Modifications
- **Discovering a new bug class** -- add a Development Rule to prevent recurrence
- **Changing the build process** -- update Build Instructions and/or Build Configuration
- **Adding/changing build defines** -- update Build Configuration > Environment Variables
- **Adding a new board variant** -- update Hardware, Build Configuration, and follow Common Modifications recipe
- **Integrating a new third-party service or SDK** -- add to External Integrations and Dependencies
- **Removing an integration or dependency** -- remove from External Integrations and Dependencies
- **Bumping the version** -- update the version in Project Overview
- **Adding/removing files** -- update File Inventory
- **Finding a new limitation** -- add to Known Issues
- **Resolving a known limitation** -- remove from Known Issues
- **Adding a new protocol message** -- update Serial Protocol table and follow Common Modifications recipe

### Supplementary docs
For sections that grow large (display layouts, testing checklists, changelogs), move them to separate files under `docs/` and link from here. This keeps the main CLAUDE.md scannable while preserving detail.

### Future improvements tracking
When a new feature is added and related enhancements or follow-up ideas are suggested but declined, add them as `- [ ]` items to `docs/CLAUDE.md/future-improvements.md`. This preserves good ideas for later without cluttering the current task.

### Version history maintenance
When making changes that are committed to the repository, add a row to the version history table in `docs/CLAUDE.md/version-history.md`. Each entry should include:

- **Ver** -- A semantic version identifier (e.g., `v0.1.0`, `v0.2.0`). Follow semver: MAJOR.MINOR.PATCH. Use the most recent entry in the table to determine the next version number.
- **Changes** -- A brief summary of what changed.

Append new rows to the bottom of the table. Do not remove or rewrite existing entries.

### Testing checklist maintenance
When adding or modifying user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

### What belongs here vs. in code comments
- **Here:** Architecture decisions, cross-cutting concerns, "how things fit together," gotchas, recipes
- **In code:** Implementation details, function-level docs, inline explanations of tricky logic

---

## Origin

Created with Claude (Anthropic)
