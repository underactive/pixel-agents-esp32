# Implementation Record: Pixel Agents ESP32-S3

## Summary

Ported the pixel-agents VS Code extension to a standalone ESP32-S3 (LILYGO T-Display S3) with 1.9" IPS ST7789 TFT (320x170). The system renders Claude Code agents as animated 16x24 pixel art characters in a virtual office, driven by a Python companion script that watches JSONL transcripts and sends state updates over USB serial.

## Files Created

### Tools
| File | Purpose | Size |
|------|---------|------|
| `tools/sprite_converter.py` | Generates C PROGMEM headers from hardcoded sprite definitions | ~15KB |
| `tools/sprite_validation.html` | Generated HTML for browser-based visual sprite verification | ~65KB |

### Generated Sprite Headers
| File | Purpose | Size |
|------|---------|------|
| `firmware/src/sprites/characters.h` | 21 indexed templates (uint8_t[384]) + 6 RGB565 palettes | ~55KB |
| `firmware/src/sprites/furniture.h` | Desk (32x32), Chair (16x16), Plant, Bookshelf, Cooler, PC, Lamp, Whiteboard | ~32KB |
| `firmware/src/sprites/bubbles.h` | Permission and Waiting speech bubbles (11x13 each) | ~3KB |

### Firmware
| File | Purpose |
|------|---------|
| `firmware/platformio.ini` | PlatformIO build config: espressif32, TFT_eSPI, ST7789 pin config |
| `firmware/src/config.h` | All constants, enums (CharState, Dir, TileType), workstation layout |
| `firmware/src/protocol.h` | Binary serial protocol structs and parser class declaration |
| `firmware/src/protocol.cpp` | Non-blocking state machine parser with XOR checksum verification |
| `firmware/src/office_state.h` | Character struct, OfficeState class with BFS pathfinding |
| `firmware/src/office_state.cpp` | Character FSM (SPAWN/IDLE/WALK/TYPE/READ/DESPAWN), BFS, wander |
| `firmware/src/renderer.h` | Renderer class: double-buffered TFT_eSprite rendering |
| `firmware/src/renderer.cpp` | Floor, furniture, depth-sorted characters, bubbles, status bar, spawn FX |
| `firmware/src/main.cpp` | Arduino setup/loop: serial processing, frame limiting, subsystem init |

### Companion
| File | Purpose |
|------|---------|
| `companion/pixel_agents_bridge.py` | JSONL watcher + binary serial sender, auto-detect ESP32 port |
| `companion/requirements.txt` | `pyserial>=3.5` |

### Documentation
| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project context: architecture, subsystems, protocol spec, build instructions |
| `README.md` | Setup instructions, hardware requirements, project structure |
| `docs/CLAUDE.md/plans/1741222000-pixel-agents-esp32/plan.md` | Plan document |

## Architecture

```
[Claude Code CLI] -> JSONL transcripts -> [companion/pixel_agents_bridge.py]
                                                    |
                                              USB Serial (115200)
                                              Binary Protocol
                                                    |
                                          [ESP32-S3 + TFT Display]
                                          firmware/src/main.cpp
                                                    |
                        +---------------------------+---------------------------+
                        |                           |                           |
                  protocol.cpp              office_state.cpp             renderer.cpp
                  (serial parser)           (FSM, pathfinding)          (TFT rendering)
```

### Binary Protocol
- Framing: `[0xAA][0x55][MSG_TYPE][PAYLOAD...][XOR_CHECKSUM]`
- Messages: AGENT_UPDATE (0x01), AGENT_COUNT (0x02), HEARTBEAT (0x03), STATUS_TEXT (0x04)
- Heartbeat timeout: 6 seconds -> "Disconnected" indicator

### Rendering Pipeline (15 FPS)
1. Fill background
2. Draw floor tiles (checkerboard pattern)
3. Draw furniture (desks, chairs, decorations)
4. Depth-sort characters by Y position
5. Draw characters (indexed template + palette lookup)
6. Draw speech bubbles
7. Draw status bar (connection dot, agent count)
8. Push sprite buffer to display

### Character State Machine
- SPAWN: column-by-column matrix reveal (300ms, green tint)
- IDLE: standing, periodic random wandering via BFS pathfinding
- WALK: 4-frame cycle at 0.15s/frame, BFS path following at 48px/s
- TYPE: 2-frame typing animation at 0.3s/frame, seated at assigned desk
- READ: 2-frame reading animation at 0.3s/frame, for Read/Grep/Glob/WebFetch/WebSearch tools
- DESPAWN: reverse column reveal (300ms)

## Verification

### Interface Consistency
- All sprite names in renderer.cpp match generated header defines (SPRITE_DESK, SPRITE_CHAIR, etc.)
- Character template access uses `CHAR_TEMPLATES[enumIdx]` pointer array (not flat array)
- Character palette access uses `CHAR_PALETTES[paletteIdx]` pointer array
- `characters.h` includes `../config.h` for shared constants (no duplicate defines)
- Protocol constants match between firmware (`config.h`) and companion (`pixel_agents_bridge.py`)
- CharState enum values match between firmware and companion STATE_* constants

### Not Yet Verified (Requires Hardware)
- PlatformIO compilation (requires ESP32 toolchain)
- TFT display output (requires LILYGO T-Display S3)
- Serial communication end-to-end (requires both devices)
- PSRAM allocation for frame buffer
- Actual FPS performance

## Audit Fixes

Post-implementation audit by 7 parallel agents identified 7 High and 16 Medium findings across security, state management, and resource domains. All High and actionable Medium findings were fixed:

### protocol.cpp
- Added buffer overflow guard: reset parser to WAIT_SYNC1 when `_bufIdx >= SERIAL_BUF_SIZE`
- Added bounds checks on memcpy in dispatch() for AGENT_UPDATE and STATUS_TEXT
- Added CharState enum range validation before cast

### office_state.cpp
- Spawn completion now uses `isReadingTool()` to choose TYPE vs READ
- Permission bubbles now have 10-second timeout (was infinite)
- Internal TYPE→IDLE transition now clears bubble state
- BFS queue enqueue now has overflow guard
- Removed dead `wasActive` variable

### renderer.cpp / renderer.h
- Check `createSprite()` return value, cleanup on failure
- Removed dead `_usePSRAM` member and psramFound() call

### config.h
- Fixed misleading TileType::BLOCKED comment

### companion/pixel_agents_bridge.py
- Send OFFLINE for pruned stale agents (prevents ghost characters)
- Only send agent_count when count changes (was every poll cycle)
- Close serial port before setting to None on disconnect
- Removed broken `active_tools.discard()` dead code path

### Round 2 — QA, Interface Contract, Testing Coverage, DX Audits

#### main.cpp
- Removed unused `lastUpdateMs` variable

#### office_state.cpp
- Water cooler now blocks both tiles (7,18) and (8,18) — was only blocking row 8
- Spawn duration uses `SPAWN_DURATION_SEC` constant (was `0.3f` magic number)

#### renderer.cpp
- `drawSpawnEffect()` now has screen bounds checks on `drawPixel` calls
- Floor alt color uses `COLOR_FLOOR_ALT` constant (was `0x4228` magic number)
- Spawn duration reference uses `SPAWN_DURATION_SEC` constant

#### config.h
- Added `SPAWN_DURATION_SEC = 0.3f` constant
- Added `COLOR_FLOOR_ALT = 0x4228` constant

#### tools/sprite_converter.py
- Removed pre-byte-swap from RGB565 conversion — `setSwapBytes(true)` handles SPI byte order at push time, preventing double-swap

#### Regenerated sprites
- `firmware/src/sprites/characters.h`, `furniture.h`, `bubbles.h` regenerated with standard (non-swapped) RGB565

See `audit.md` for full findings and rationale for accepted low-risk items.

## Follow-ups
- Test with PlatformIO compilation once toolchain is available
- End-to-end integration test with hardware
- Consider WiFi mode as future alternative to USB serial
- Touch input support (if using CYD board variant)
- OTA firmware updates
- Theme/color scheme customization
