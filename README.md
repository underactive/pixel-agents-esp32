# Pixel Agents ESP32

A standalone hardware display that renders Claude Code agents as animated pixel art characters in a virtual office scene. Runs on an ESP32-S3 with a small color TFT display.

## How It Works

```
Claude Code CLI  -->  JSONL transcripts  -->  Python bridge  -->  USB Serial  -->  ESP32 + TFT
```

1. **Claude Code** writes JSONL transcript files as you work
2. **Companion bridge** (Python) watches those files and detects agent state changes
3. **ESP32 firmware** receives state updates over USB serial and animates the office scene

Characters walk to their desks when active, sit and type/read while tools run, wander around the office when idle, and spawn/despawn with a matrix effect.

## Hardware

**Recommended:** [LILYGO T-Display S3](https://www.lilygo.cc/products/t-display-s3) (~$15)
- ESP32-S3 with built-in 1.9" IPS display (170x320, ST7789)
- USB-C, no wiring needed
- 320x170 landscape fits 20x10 tile grid

**Alternative:** ESP32-S3 CYD (Cheap Yellow Display, ~$12)
- 2.8" ILI9341 (240x320), touch included
- Requires different pin config in `platformio.ini`

## Setup

### Prerequisites

- [PlatformIO](https://platformio.org/) (CLI or VS Code extension)
- Python 3.8+ with pip
- LILYGO T-Display S3 (or compatible ESP32-S3 board)

### 1. Generate Sprite Headers

```bash
python3 tools/sprite_converter.py
```

This creates C header files in `firmware/src/sprites/` from the built-in sprite definitions. Open `tools/sprite_validation.html` in a browser to visually verify the sprites.

### 2. Build & Flash Firmware

```bash
cd firmware
pio run --target upload
```

PlatformIO will download the ESP32 toolchain and TFT_eSPI library automatically on first build.

### 3. Start the Companion Bridge

```bash
cd companion
pip install -r requirements.txt
python3 pixel_agents_bridge.py
```

The bridge auto-detects the ESP32 serial port. To specify manually:

```bash
python3 pixel_agents_bridge.py --port /dev/cu.usbmodemXXXX
```

### 4. Use Claude Code

Start using Claude Code as normal. The display will show your agents in the office scene.

## What You'll See

- **Agent spawns** with a matrix-style column reveal effect
- **Active agent** walks to its desk and sits down to type or read
- **Idle agent** stands up and wanders around the office
- **Speech bubbles** show tool names while running, permission/waiting indicators
- **Status bar** at bottom shows connection status and agent count
- **Multiple agents** each get their own desk and color palette

## Serial Protocol

Binary framing: `[0xAA][0x55][MSG_TYPE][PAYLOAD...][XOR_CHECKSUM]`

| Message | Code | Payload |
|---------|------|---------|
| Agent Update | 0x01 | agent_id + state + tool_name_len + tool_name |
| Agent Count | 0x02 | count |
| Heartbeat | 0x03 | timestamp (4 bytes, big-endian) |
| Status Text | 0x04 | agent_id + text_len + text |

## Project Structure

```
pixel-agents/
  firmware/              # ESP32 PlatformIO project
    platformio.ini
    src/
      main.cpp           # Entry point
      config.h           # Constants, enums, layout
      protocol.h/.cpp    # Serial protocol parser
      office_state.h/.cpp # Character FSM, pathfinding
      renderer.h/.cpp    # Display rendering
      sprites/           # Generated PROGMEM sprite data
        characters.h
        furniture.h
        bubbles.h
  companion/             # Python bridge service
    pixel_agents_bridge.py
    requirements.txt
  tools/                 # Build tools
    sprite_converter.py
    sprite_validation.html  # Generated visual check
```

## License

MIT
