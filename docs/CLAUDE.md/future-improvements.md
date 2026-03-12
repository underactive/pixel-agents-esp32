# Future Improvements (Ideas)

## High Priority
- [x] Wireless mode: BLE NUS transport for untethered operation (v0.8.2)
- [x] Strip-buffer fallback: render in 320x30 bands if PSRAM unavailable (v0.8.4)
- [x] Boot animation: animated pixel-art logo on startup (v0.7.0)

## Medium Priority
- [x] Touch input (CYD variant): tap character to show info bubble, tap status bar to toggle modes (v0.8.0)
- [x] Web-based firmware updates: browser-based flasher via Web Serial API (tools/firmware_update.html)
- [ ] Web config dashboard: ESP32 hosts a tiny AP/mDNS page for WiFi creds, dog color, brightness — no recompile
- [ ] NTP time sync: accurate clock for uptime display and schedule-based night mode
- [ ] Multiple display support: daisy-chain ESP32 boards for wider scenes
- [ ] Multi-device sync: multiple displays showing same scene or different "rooms", one companion broadcasts to all
- [x] Sound effects: piezo buzzer for spawn/despawn events
- [ ] Night mode: dimmer palette + reduced backlight on schedule
- [ ] Voice input via mic: stream mic audio to companion for speech-to-text, send transcribed text as agent input (CYD-S3 only). Deferred during v0.9.2 wake word work — the mic loopback POC validated the audio capture chain but streaming continuous audio over USB serial or BLE requires a transport-layer protocol extension (chunked audio framing, flow control) and companion-side STT integration that are out of scope for the current architecture. Wake word detection was prioritized instead as a self-contained on-device feature with no companion dependency.
- [ ] Custom wake word "Hi Jojo" via microWakeWord: train TFLite model on Mac using [microWakeWord-Trainer-AppleSilicon](https://github.com/TaterTotterson/microWakeWord-Trainer-AppleSilicon), integrate TFLite Micro into firmware alongside or replacing ESP-SR WakeNet (CYD-S3 only)
- [ ] Remote status API: ESP32 exposes REST endpoint for external tools (Home Assistant, Stream Deck) to query agent state

## Low Priority
- [ ] CYD SD card — screenshot storage: save screenshots directly to SD card without companion
- [ ] CYD SD card — custom sprites: load user sprite sheets from SD at boot (swap palettes/furniture without recompiling)
- [ ] CYD SD card — activity logging: write agent activity and usage stats history to SD for later review
- [ ] CYD SD card — portable config: store settings (WiFi creds, display prefs, dog color) as JSON on SD, survives reflashes
- [ ] Theme system: swappable color palettes for floor/wall/furniture
- [ ] Custom office layouts: JSON-defined room layouts uploaded via serial
- [ ] Agent name labels: tiny text below characters showing project name
- [x] Idle screensaver: unassigned characters wander and do random activities when no agents active (v0.8.0)
- [ ] Statistics overlay: show total tool calls, active time, etc.
- [x] CYD board variant: alternative pin config and 240x320 layout (v0.8.0)
- [ ] BLE phone companion: phone app forwards agent state over BLE without needing WiFi infrastructure
- [ ] BLE proximity presence: detect phone via BLE to auto-dim/sleep display when away, wake on return
- [ ] BLE mesh multi-board: synchronized animations across multiple boards via BLE mesh without WiFi
