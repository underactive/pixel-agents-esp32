# Future Improvements (Ideas)

## High Priority
- [ ] WiFi mode: send agent state over WebSocket instead of USB serial (untethered operation)
- [ ] Strip-buffer fallback: render in 320x30 bands if PSRAM unavailable
- [ ] Boot animation: animated pixel-art logo on startup

## Medium Priority
- [ ] Touch input (CYD variant): tap character to show tool name, tap status bar to toggle info
- [ ] OTA firmware updates: push new firmware over WiFi
- [ ] Multiple display support: daisy-chain ESP32 boards for wider scenes
- [ ] Sound effects: piezo buzzer for spawn/despawn events
- [ ] Night mode: dimmer palette + reduced backlight on schedule

## Low Priority
- [ ] Theme system: swappable color palettes for floor/wall/furniture
- [ ] Custom office layouts: JSON-defined room layouts uploaded via serial
- [ ] Agent name labels: tiny text below characters showing project name
- [ ] Idle screensaver: characters do random activities when no real agents active
- [ ] Statistics overlay: show total tool calls, active time, etc.
- [ ] CYD board variant: alternative pin config and 240x320 layout
