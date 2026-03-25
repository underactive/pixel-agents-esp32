# File Inventory

Complete file and directory listing for the Pixel Agents ESP32 project. Referenced from `CLAUDE.md`.

---

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
| `firmware/src/battery.h/.cpp` | Battery voltage monitoring via ADC (CYD-S3 + LILYGO) |
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
| `companion/pixel_agents_bridge.py` | Transcript watcher + serial sender (Claude Code + Codex CLI + Gemini CLI) |
| `companion/ble_transport.py` | BLE client transport using bleak |
| `companion/requirements.txt` | Python dependencies (`pyserial>=3.5`, `bleak>=0.21.0`) |
| `macos/PixelAgents/` | Native macOS menu bar companion app (Xcode project) |
| `macos/PixelAgents/PixelAgents/AppDelegate.swift` | Menu bar right-click menu, Settings/About windows, Sparkle updater, lifecycle |
| `macos/PixelAgents/PixelAgents/Model/ActivityHeatmapData.swift` | Local activity heatmap data model (tool call counts, streaks, thresholds) |
| `macos/PixelAgents/PixelAgents/Model/GeminiStateDeriver.swift` | Gemini CLI session JSON state deriver |
| `macos/PixelAgents/PixelAgents/Services/ActivityDatabase.swift` | SQLite wrapper for daily tool call persistence (Claude/Codex/Gemini heatmaps) |
| `macos/PixelAgents/PixelAgents/Services/GeminiUsageFetcher.swift` | Gemini CLI OAuth-based usage quota fetcher |
| `macos/PixelAgents/PixelAgents/Views/SettingsView.swift` | Settings window: Launch at Login, usage stats toggles, auto-update toggle |
| `macos/PixelAgents/PixelAgents/Views/AboutView.swift` | About window: app icon, version, GitHub link |
| `tools/sprite_converter.py` | Furniture/bubbles/tiles --> C header generator |
| `tools/convert_characters.py` | Character PNG sprite sheets --> C header generator |
| `tools/convert_dog.py` | Dog pet PNG sprite sheet --> C header generator |
| `tools/convert_sound.py` | MP3 --> 24kHz mono s16le PCM C header generator (ffmpeg) |
| `tools/sprite_validation.html` | Visual sprite verification (browser, generated) |
| `tools/layout_editor.html` | Office layout visual editor (generates C code) |
| `tools/firmware_update.html` | Browser-based firmware flasher (Web Serial + esptool-js) |
| `assets/` | Source artwork: character PNGs, dog sprite sheets, office tileset |
| `run_companion.py` | Cross-platform companion launcher (auto-creates venv, installs deps) |
| `CLAUDE.md` | Project context and development instructions |
| `README.md` | User-facing project documentation |
| `CHANGELOG.md` | User-facing changelog (Keep a Changelog format) |
| `LICENSE` | Project license |
| `.github/workflows/release.yml` | GitHub Actions release workflow |
| `docs/CLAUDE.md/plans/` | Plan, implementation, and audit records (epoch-prefixed directories) |
| `docs/CLAUDE.md/testing-checklist.md` | QA testing checklist |
| `docs/CLAUDE.md/version-history.md` | Version history table |
| `docs/CLAUDE.md/future-improvements.md` | Ideas backlog |
| `docs/CLAUDE.md/subsystems.md` | Detailed subsystem specifications |
| `docs/CLAUDE.md/hardware.md` | Pin assignments and component details |
| `docs/CLAUDE.md/audit-checklist.md` | Post-implementation audit process and checklist |
| `docs/CLAUDE.md/file-inventory.md` | This file |
