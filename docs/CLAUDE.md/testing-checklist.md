# Testing Checklist

## Pre-Hardware (Desktop Verification)

### Sprite Converter
- [ ] Run `python3 tools/sprite_converter.py` — generates all 4 output files without errors
- [ ] Open `tools/sprite_validation.html` in browser — all sprites render correctly at 4x zoom
- [ ] Characters have distinct palettes (6 color sets visible)
- [ ] Walk frames show progressive leg/arm motion
- [ ] Type/Read frames show distinct poses
- [ ] Furniture sprites are recognizable (desk, chair, plant, bookshelf, cooler)
- [ ] Bubble sprites show "?" (permission) and "..." (waiting) icons

### Companion Script
- [ ] `python3 companion/pixel_agents_bridge.py --help` — shows usage
- [ ] Without ESP32: prints "No ESP32 serial port found." and retries
- [ ] With `--port /dev/null`: fails gracefully with serial error message
- [ ] Ctrl+C: exits cleanly with "Shutting down."

### Protocol Consistency
- [ ] Protocol constants match: firmware config.h SYNC/MSG values == companion constants
- [ ] CharState enum values (0-6) match companion STATE_* constants (0-6)
- [ ] Agent update message format: companion build_agent_update() matches firmware dispatch()

## Hardware Testing (Requires LILYGO T-Display S3)

### Display Bootstrap
- [ ] Upload firmware via PlatformIO — compiles and uploads without errors
- [ ] Splash screen appears: "Pixel Agents" title, connection instructions
- [ ] Screen orientation is landscape (320x170)
- [ ] Backlight is on

### Idle Scene (No Companion Connected)
- [ ] Status bar shows red dot + "Disconnected"
- [ ] Status bar shows "0 agents"
- [ ] Floor tiles render with checkerboard pattern
- [ ] Wall row (top) renders in different shade
- [ ] Furniture visible: desks (2x2), chairs, plant, bookshelf, cooler

### Connected Scene (Companion Running)
- [ ] Status bar shows green dot when companion sends heartbeats
- [ ] Agent count updates as Claude Code sessions start/stop
- [ ] Characters spawn with matrix column-reveal effect (green tint)
- [ ] Characters walk smoothly between tiles (4-frame animation)
- [ ] Characters sit at desks when typing/reading
- [ ] Sitting offset visually places character on chair
- [ ] LEFT-facing characters are horizontal flips (not separate sprites)
- [ ] Speech bubbles appear above characters for permission/waiting states
- [ ] Characters despawn with reverse matrix effect
- [ ] Multiple characters depth-sort correctly (lower Y = further back)

### Stress Testing
- [ ] 6 agents simultaneously — all render, no crashes
- [ ] Rapid state changes (TYPE→IDLE→TYPE) — smooth transitions
- [ ] Serial disconnect/reconnect — status changes to red, recovers on reconnect
- [ ] Long-running session (1+ hour) — no memory leaks, stable FPS

### Performance
- [ ] Frame rate is smooth (~15 FPS, no visible stuttering)
- [ ] Walk animation is fluid (not jerky)
- [ ] Spawn effect renders progressively (not all-at-once)
