# Plan: Pixel Agents ESP32-S3 Hardware Display

## Objective

Port the [pixel-agents](https://github.com/pablodelucca/pixel-agents) VS Code extension to a standalone ESP32-S3 device with a small color TFT display. The extension renders Claude Code agents as animated 16x24 pixel art characters in a virtual office. The goal is a desk-side hardware display that shows the full office scene — characters walking, sitting at desks typing, speech bubbles — without needing VS Code open.

System architecture:
```
[Claude Code CLI] → writes JSONL transcripts → [Python companion] → USB Serial → [ESP32-S3 + TFT]
```

Target hardware: LILYGO T-Display S3 (1.9" IPS ST7789, 170x320, ESP32-S3).

## Changes

### 1. Project scaffolding
- `CLAUDE.md` — project context
- `docs/exec-plans/completed/` — this plan + implementation + audit
- `docs/references/testing-checklist.md`, `future-improvements.md`, `version-history.md`

### 2. Sprite converter (`tools/sprite_converter.py`)
- Hardcoded sprite definitions (from pixel-agents extension's spriteData.ts)
- Characters: indexed templates (1 byte/pixel) + 6 RGB565 palettes
- Furniture/bubbles: direct RGB565 arrays
- Outputs PROGMEM C headers to `firmware/src/sprites/`
- Generates `tools/sprite_validation.html` for visual verification

### 3. ESP32 firmware (`firmware/`)
- PlatformIO project targeting LILYGO T-Display S3
- `config.h` — all constants, enums, workstation layout
- `protocol.h/.cpp` — binary serial protocol parser
- `office_state.h/.cpp` — character FSM, BFS pathfinding, agent management
- `renderer.h/.cpp` — TFT_eSprite double-buffered rendering
- `main.cpp` — setup, loop, serial callbacks, splash screen

### 4. Companion bridge (`companion/`)
- `pixel_agents_bridge.py` — JSONL watcher + serial sender
- `requirements.txt` — pyserial dependency

### 5. Documentation
- `README.md` — setup instructions, hardware requirements, usage

## Dependencies

1. Sprite converter must run before firmware build (generates headers)
2. Protocol format shared between firmware and companion
3. Firmware and companion are otherwise independent

## Risks / Open Questions

1. Hardware not yet purchased — plan works with either T-Display S3 or CYD
2. JSONL format is not a public API — companion parser is intentionally loose
3. PSRAM availability — 106KB frame buffer needs PSRAM; fallback: strip-buffer rendering
4. USB serial port detection varies by board/OS
