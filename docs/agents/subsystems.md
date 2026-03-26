# Key Subsystems

Detailed specs for each subsystem in the Pixel Agents ESP32 project. Referenced from `CLAUDE.md`.

---

## 1. Rendering Pipeline (`renderer.cpp`)
- Landscape via `tft.setRotation(1)` -- 320x170 (LILYGO) or 320x240 (CYD)
- Full-frame double buffer with `TFT_eSprite` in PSRAM -- `pushSprite(0,0)`
- CYD (no PSRAM): strip-buffer fallback (`_stripMode`, 320x30 bands) or direct-draw (`_directMode`)
- Render order: floor --> walls --> depth-sorted entities (furniture + characters by Y) --> speech bubbles --> status bar
- 15 FPS target (~66ms/frame)
- Character sprites: template index --> palette lookup --> RGB565 --> `fillRect` per pixel
- LEFT-facing sprites rendered by horizontally flipping RIGHT sprites

## 2. Character State Machine (`office_state.cpp`)
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

## 3. Serial Protocol (`protocol.cpp`)
Binary framing: `[0xAA][0x55][MSG_TYPE][PAYLOAD...][XOR_CHECKSUM]`

| Message | Type | Payload |
|---------|------|---------|
| AGENT_UPDATE | 0x01 | agent_id(1) + state(1) + tool_name_len(1) + tool_name(0-24) |
| AGENT_COUNT | 0x02 | count(1) |
| HEARTBEAT | 0x03 | timestamp(4, big-endian) |
| STATUS_TEXT | 0x04 | agent_id(1) + text_len(1) + text(0-32) |
| USAGE_STATS | 0x05 | current_pct(1) + weekly_pct(1) + current_reset_min(2, big-endian) + weekly_reset_min(2, big-endian) |
| SCREENSHOT_REQ | 0x06 | (none) |
| DEVICE_SETTINGS | 0x07 | dog_enabled(1) + dog_color(1) + screen_flip(1) + sound_enabled(1) + dog_bark_enabled(1) |
| SETTINGS_STATE | 0x08 | dog_enabled(1) + dog_color(1) + screen_flip(1) + sound_enabled(1) + dog_bark_enabled(1) |
| IDENTIFY_REQ | 0x09 | (none) |
| IDENTIFY_RSP | 0x0A | magic("PXAG", 4) + protocol_version(1) + board_type(1) + firmware_version(2, BE) |

`DEVICE_SETTINGS` (0x07) is companion → device. `SETTINGS_STATE` (0x08) is device → companion, sent on first heartbeat after connect, after applying received settings, and after on-device touch menu changes.

`IDENTIFY_REQ` (0x09) is companion → device. `IDENTIFY_RSP` (0x0A) is device → companion, sent in response to an identify request and proactively on first heartbeat after connect (for backwards compatibility with companions that don't send identify requests). Board type: 0=CYD, 1=CYD-S3, 2=LILYGO. Firmware version encoded as `major*1000 + minor*10 + patch`.

Screenshot response (ESP32 → companion) uses distinct sync bytes `[0xBB][0x66]` followed by a 10-byte header and RLE pixel data. Not part of the standard framing protocol.

Non-blocking state machine parser. Per-transport heartbeat watchdog: serial and BLE tracked independently, each times out after 6s of no heartbeats.

## 4. Companion Bridge (`companion/pixel_agents_bridge.py`)
- Watches `~/.claude/projects/`, `~/.codex/sessions/`, and `~/.gemini/tmp/` for active transcript files (modified within 5 minutes)
- Supports Claude Code, OpenAI Codex CLI, and Google Gemini CLI simultaneously -- each active session gets its own agent
- Supports `--transport serial` (default) or `--transport ble` for untethered operation
- Polls at 4Hz, sends HEARTBEAT every 2s
- Derives agent state from JSONL records:
  - **Claude Code:** `tool_use` in assistant message --> TYPE (or READ if tool in `READING_TOOLS` set: Read, Grep, Glob, WebFetch, WebSearch); `turn_duration` / `end_turn` --> IDLE
  - **Codex CLI (3 formats):**
    - *Current rollout (snake_case):* `response_item` with `function_call`/`custom_tool_call` --> TYPE (or READ for read commands via `exec_command`); `web_search_call` --> READ; `event_msg` with `task_complete`/`turn_aborted` --> IDLE; `session_meta`/`turn_context`/`compacted` ignored
    - *codex exec --json:* `item.started`/`item.completed` with `command_execution` --> TYPE/READ; `turn.completed` --> IDLE
    - *Legacy RolloutLine (PascalCase):* `ResponseItem`/`EventMsg` envelopes (backward compat)
  - **Gemini CLI:** `derive_gemini_state()` parses monolithic JSON session files (not JSONL):
    - `type == "gemini"` with `toolCalls` array --> TYPE (or READ if tool in `GEMINI_READING_TOOLS`: web_fetch, google_web_search, read_file, list_directory)
    - `type == "gemini"` without `toolCalls` --> TYPE (agent generating text)
    - `type == "user"` --> IDLE
- Sends binary AGENT_UPDATE on state change only
- Prunes stale agents after 30s, auto-reconnects on disconnect
- BLE mode: scans for device by name using bleak, writes to NUS RX characteristic, resets tracking state on reconnect
- Screenshots only available over serial (disabled over BLE)
- Reads `~/.claude/rate-limits-cache.json` every 10s, sends USAGE_STATS on change

## 5. Sprite System
- Characters: direct RGB565 (16x32 pixels/frame, 512 pixels = 1024 bytes/frame), 6 variants
- 0x0000 = transparent. Art is bottom-aligned with top padding in the 16x32 frame.
- 21 frames per character: 7 frames x 3 directions (DOWN, UP, RIGHT). LEFT = flip RIGHT.
- Frames per direction: walk1, walk2 (standing), walk3, type1, type2, read1, read2
- Dog: 23 direct RGB565 frames (25x19), 4 color variants (black, brown, gray, tan). LEFT = flip RIGHT.
- Furniture/bubbles: direct RGB565 uint16_t arrays
- All sprite data in PROGMEM (flash)
- Generated by `tools/convert_characters.py` (characters), `tools/sprite_converter.py` (furniture/bubbles/tiles), and `tools/convert_dog.py` (dog)

## 6. BLE Transport (`ble_service.cpp`, CYD and CYD-S3)
- NimBLE Nordic UART Service (NUS) — standard BLE serial profile
- ESP32 acts as BLE peripheral (server), companion as central (client)
- RX characteristic receives protocol messages from companion
- TX characteristic sends device → companion messages (settings state, identify response)
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
- BLE Battery Service (BAS, UUID `0x180F`): exposes battery level as standard GATT characteristic (`0x2A19`, READ + NOTIFY) when `HAS_BATTERY` is defined. macOS shows battery natively in System Settings → Bluetooth. Companion app reads it via CoreBluetooth for in-app display.
- Battery level characteristic updated from main loop after `battery_update()`, notifies connected central only on change
- Memory overhead: ~312KB flash + 15KB RAM (NimBLE with central/observer roles disabled)

## 7. Touch Input (`touch_input.cpp`, CYD and CYD-S3)
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

## 8. Status Bar
Layout: `[USB][BT] [status text...] [bolt XX%] [hamburger]`

Left side: transport connection icons (5x8px monochrome bitmaps)
- USB icon: green when serial connected, dim gray when not (all boards)
- BT icon: blue when BLE connected, dim gray when not (CYD/CYD-S3 only, `HAS_BLE`)

Right side: battery indicator (CYD-S3/LILYGO only, `HAS_BATTERY`)
- Color-coded percentage: green >50%, yellow 20-50%, red <20%
- Lightning bolt icon when charging (USB connected + voltage > 4.1V)

Connection state tracked per-transport: `isSerialConnected()`, `isBleConnected()`, `isConnected()` (either)

5 display modes, cycled via touch (CYD/CYD-S3) or auto on LILYGO:

| Mode | Content |
|------|---------|
| OVERVIEW | Transport icons + agent count |
| USAGE_STATS | Current + weekly usage percentage bars |
| AGENT_LIST | Per-agent ID:state |
| PERFORMANCE | FPS counter |
| UPTIME | Device uptime |

## 9. LED Ambient (`led_ambient.cpp`, CYD and CYD-S3)
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

## 10. Audio / Sound System (`sound.cpp`, CYD and CYD-S3)
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

## 11. macOS Companion App (`macos/PixelAgents/`)
- Native Swift/SwiftUI menu bar app (alternative to Python companion bridge)
- Runs as menu bar extra (hidden from dock, `LSUIElement`)
- Connects via Serial (POSIX file descriptors) or BLE (CoreBluetooth NUS client)
- FSEvents-based transcript watching (`~/.claude/projects/`, `~/.codex/sessions/`, `~/.gemini/tmp/`, and `~/.cursor/projects/`)
- Reads OAuth token from macOS Keychain, fetches usage stats from Anthropic API directly
- Writes `~/.claude/rate-limits-cache.json` (same format as Python bridge reads)
- Screenshot capture: decodes RLE response, saves PNG to `~/Pictures/PixelAgents/`
- IOKit-based serial port auto-detection with USB device notifications
- Launch at login via `SMAppService` (in Settings window)
- Settings window: Launch at Login toggle, Claude/Codex usage stats visibility toggles (`@AppStorage` in `UserDefaults`), auto-update toggle (Sparkle `automaticallyChecksForUpdates`)
- About window: app icon, version (`CFBundleShortVersionString`), GitHub link
- Right-click context menu on menu bar icon via `NSEvent.addLocalMonitorForEvents` (About, Check for Updates, Quit)
- Auto-updates via Sparkle framework: `SPUStandardUpdaterController` in AppDelegate, EdDSA-signed appcast on GitHub Pages (`SUFeedURL` in Info.plist)
- `AppDelegate` (`@NSApplicationDelegateAdaptor`): manages right-click menu, Settings/About windows, Sparkle updater controller, lifecycle observers
- UI: connection status dot, transport picker (serial/BLE), agent list with state indicators, usage bars with reset timers, gear button for settings
- Codex CLI support: `CodexStateDeriver` parses rollout JSONL alongside Claude's `StateDeriver` (supports current snake_case, codex exec --json, and legacy PascalCase formats)
- Gemini CLI support: `GeminiStateDeriver` parses monolithic JSON session files (not JSONL) from `~/.gemini/tmp/*/chats/session-*.json`; `GeminiUsageFetcher` reads OAuth creds and fetches quota from Google Cloud API
- Unit tests: StateDeriverTests, CodexStateDeriverTests, GeminiStateDeriverTests, ProtocolBuilderTests, AgentTrackerTests

## 12. Wake Word Detection (`wakeword.cpp`, CYD-S3 only)
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

## 13. Battery Monitor (`battery.cpp`, CYD-S3 + LILYGO)
- Reads battery voltage via ADC through built-in PCB voltage divider (2:1 ratio)
- CYD-S3: GPIO 9, LILYGO: GPIO 4 — no external wiring required
- EMA-smoothed readings (`BATTERY_SMOOTH_ALPHA=0.15`) sampled every 5s to reduce noise
- LiPo discharge curve lookup table (~15 breakpoints) with linear interpolation for voltage-to-percent
- Charging heuristic: voltage > 4.1V (no dedicated charging detection pin; under load, an unpowered battery drops below 4.1V quickly)
- Displayed in status bar: color-coded percentage (green >50%, yellow 20-50%, red <20%) + lightning bolt icon when charging
- Compile-time gated by `#if defined(HAS_BATTERY)` — auto-defined for CYD-S3 and LILYGO (not CYD, which has no battery support)
- Free-function API: `battery_begin()`, `battery_update()`, `battery_getPercent()`, `battery_isCharging()`
