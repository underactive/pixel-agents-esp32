# Changelog

All notable changes to Pixel Agents are documented here.

## [0.9.4] - 2026-03-19

- Add display sleep mode: screen turns off after 5 minutes of inactivity, touch to wake (CYD and CYD-S3)
- Add battery voltage monitoring via ADC for CYD-S3 and LILYGO with color-coded percentage in status bar and charging indicator
- Add transport connection icons (USB/BT) in status bar showing live serial and BLE connection state
- Add BLE Battery Service (BAS) so macOS shows battery level natively in System Settings → Bluetooth
- Enlarge hamburger menu for easier touch targets
- Cache OAuth token in memory in macOS companion to avoid repeated Keychain authorization prompts
- Add serial connect/disconnect buttons to macOS companion transport picker
- Fix build warnings

## [0.9.3] - 2026-03-12

- Add "Remaining" usage display mode in macOS companion: tap the "Usage" header to toggle between used percentage and remaining percentage (gas gauge style)
- Toggle persists across app restarts via `@AppStorage`
- Color thresholds always based on used percentage so red/orange/green warnings stay correct in both modes

## [0.9.2] - 2026-03-12

- Add ESP-SR WakeNet9 wake word detection on CYD-S3: say "Computer" to trigger DOG_BARK sound effect
- Wake word detection runs on Core 0 via dedicated FreeRTOS task, pauses during sound playback to avoid false triggers
- 24kHz stereo I2S RX → mono left-channel extraction → 3:2 downsample → 16kHz WakeNet feed pipeline
- Custom partition table (`partitions_sr_16MB.csv`) for CYD-S3: drops OTA to fit ESP-SR model in dedicated `srmodels` partition
- Remove microphone loopback test feature (replaced by wake word detection)
- Wake word bark now routes through `queueSound()` to respect sound on/off toggle
- Audit fixes: `std::atomic<bool>` for cross-core sync, double-begin guard, chunk size validation, partial PSRAM allocation cleanup, named constants replacing magic numbers

## [0.9.1] - 2026-03-11

- Add Freenove ESP32-S3 build and artifact packaging to GitHub Actions release workflow

## [0.9.0] - 2026-03-11

- Add OpenAI Codex CLI support: watch `~/.codex/sessions/` rollout files alongside Claude Code transcripts
- Both Python companion and macOS companion support Claude Code + Codex CLI simultaneously
- Each active session (from either source) appears as a separate character on the ESP32 display
- Codex state deriver handles three JSONL formats: current snake_case (`response_item`/`event_msg`), `codex exec --json` events, and legacy PascalCase (`RolloutLine` envelopes)
- Parse `exec_command` function_call's `arguments` JSON string for shell command classification
- Read/write detection uses command-name heuristic for Codex shell commands
- No firmware changes needed — binary protocol is source-agnostic
- Add ESP32-S3 CYD board support (`freenove-s3-28c`): 2.8" ILI9341, FT6336G capacitive touch, BLE, 16MB flash
- Add WS2812B NeoPixel LED support on CYD-S3 (GPIO 42) with Adafruit NeoPixel library
- Unify LED ambient system across CYD (PWM) and CYD-S3 (NeoPixel) with `HAS_LED` abstraction
- Fix TFT_eSPI SPI register address bug on ESP32-S3 with pioarduino (`USE_FSPI_PORT` workaround)
- Fix ILI9341 color inversion on S3 CYD panel variant (`TFT_INVERSION_ON`)
- Add event-driven sound system on CYD-S3 (I2S + ES8311 codec): table-driven SoundId enum with 5 clips
  - Startup chime on splash → office transition
  - Dog bark when dog picks a new follow target
  - Keyboard typing sound on agent's first tool call per job
  - Notification click when agent finishes turn (waiting for user input)
  - Pop sound when agent is waiting for tool permission approval
- Add `tools/convert_sound.py` for MP3 → C PCM header conversion (ffmpeg-based, batch mode)
- Add sound support to CYD board via ESP32 internal DAC (GPIO 26 → SC8002B amp), same 5 sound events as CYD-S3
- Add sound on/off toggle to hamburger menu (CYD defaults off, CYD-S3 defaults on), persisted to NVS
- Switch CYD to `huge_app.csv` partition (3MB app, no OTA) to fit PCM sound data
- Add permission bubble detection in Python companion: timeout-based heuristic detects when an agent is waiting for tool approval
- Simplify agent list UI in macOS companion: use black source icons (sparkle/terminal), hide source icon for offline agents

## [0.8.8] - 2026-03-10

- Fix agent IDs >= 6 silently rejected by firmware (conflated protocol IDs with array indices)
- Add agent ID recycling in macOS and Python companions to keep IDs low across agent lifecycle
- Add MAX_AGENT_ID constant for int8_t storage boundary guard

## [0.8.7] - 2026-03-09

- Add custom pixel art app icon and menu bar silhouette icon for macOS companion
- Improve BLE UX: auto-scan on BLE tab selection, green Connect / red Disconnect buttons per device
- Preserve discovered BLE devices after manual disconnect for easy reconnection
- Fix keepDevicesOnCleanup flag leak causing stale state across disconnect cycles
- Fix zombie CoreBluetooth connections on service/characteristic discovery failure

## [0.8.6] - 2026-03-09

- Fix CI release build: use pioarduino platform URL for Arduino Core 3.x support
- Fix usage stats: fetch on launch, add logging, reduce poll interval to 15 minutes

## [0.8.5] - 2026-03-09

- Add native macOS companion menu bar app (Swift/SwiftUI) with serial and BLE transport
- Add usage stats API fetcher to macOS companion
- Fix BLE reconnection and add explicit Connect button to device list
- Increase spawn effect duration from 0.3s to 3.0s
- Fix README accuracy: speech bubbles show permission/waiting icons, not tool names
- Update future improvements: mark completed items (BLE, touch, web flasher, CYD variant, idle screensaver)

## [0.8.4] - 2026-03-08

- Add flip screen toggle to hamburger menu for CYD
- Replace half-screen buffer with strip-buffer fallback for CYD

## [0.8.3] - 2026-03-08

- Add ESP32 junction temperature monitoring with thermal soak timing
- Add thermal throttling with backlight management and fault indicators

## [0.8.2] - 2026-03-08

- Add browser-based firmware flasher (`tools/firmware_update.html`) using Web Serial API + esptool-js
- Support CYD and LILYGO boards with correct flash offsets per board
- Two flash modes: "Update Firmware Only" (firmware.bin) and "Full Flash" (bootloader + partitions + boot_app0 + firmware)
- Drag-and-drop file selection with auto-detection of file slot by name
- Terminal log, progress bar, baud rate selection, and confirmation dialog
- Add GitHub Actions CI/CD workflow for automated firmware builds and releases

## [0.8.1] - 2026-03-08

- Add `run_companion.py` launcher script: auto-creates venv, installs deps, forwards CLI args
- Single command (`python3 run_companion.py`) replaces 5-step manual setup

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
