# Pixel Agents ESP32

A standalone hardware display that renders Claude Code agents as animated pixel art characters in a virtual office scene. Runs on an ESP32 with a small color TFT display.

Based on the [pixel-agents](https://github.com/pablodelucca/pixel-agents) VS Code extension by [@pablodelucca](https://github.com/pablodelucca).

## How It Works

```
Claude Code CLI  -->  JSONL transcripts  -->  Python bridge  -->  USB Serial  -->  ESP32 + TFT
```

1. **Claude Code** writes JSONL transcript files as you work
2. **Companion bridge** (Python) watches those files and detects agent state changes
3. **ESP32 firmware** receives state updates over USB serial and animates the office scene

Characters walk to their desks when active, sit and type/read while tools run, wander around the office when idle, and spawn/despawn with a matrix effect.

## Hardware

Either board works out of the box — just pick the right PlatformIO environment.

**Option A:** [LILYGO T-Display S3](https://www.lilygo.cc/products/t-display-s3) (~$15)
- ESP32-S3, built-in 1.9" IPS display (170x320, ST7789), USB-C
- 320x170 landscape → 20x10 tile grid
- Build env: `lilygo-t-display-s3`

**Option B:** ESP32-2432S028R "Cheap Yellow Display" (CYD) (~$12)
- ESP32-WROOM, built-in 2.8" ILI9341 (240x320), resistive touch, micro USB
- 320x240 landscape → 20x14 tile grid (more room for wandering)
- Build env: `cyd-2432s028r`

## Setup

### Prerequisites

- [PlatformIO](https://platformio.org/) (CLI or VS Code extension)
- Python 3.8+ with pip
- One of the supported boards (see Hardware above)

### 1. Generate Sprite Headers

```bash
python3 tools/sprite_converter.py
```

This creates C header files in `firmware/src/sprites/` from the built-in sprite definitions. Open `tools/sprite_validation.html` in a browser to visually verify the sprites.

### 2. Customize the Office Layout (Optional)

The layout editor lets you design the office floor plan, place furniture, assign tileset graphics, and export firmware-ready code.

**Important:** The editor must be served via HTTP — opening the HTML file directly (`file://`) will cause canvas security errors when exporting tile sprites.

```bash
# From the project root:
python3 -m http.server 8000
```

Then open `http://localhost:8000/tools/layout_editor.html` in your browser.

The editor has four export tabs:
- **config.h** — workstation positions
- **office_state** — tile map and furniture blocking
- **renderer** — `drawFurniture()` with all sprite draw calls
- **tiles.h** — RGB565 sprite data for floor, wall, and furniture tiles

Copy each tab's output into the corresponding firmware file, then build and flash.

### 3. Build & Flash Firmware

```bash
cd firmware

# For LILYGO T-Display S3:
pio run -e lilygo-t-display-s3 --target upload

# For CYD (ESP32-2432S028R):
pio run -e cyd-2432s028r --target upload
```

PlatformIO will download the ESP32 toolchain and TFT_eSPI library automatically on first build.

### 4. Start the Companion Bridge

```bash
cd companion
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 pixel_agents_bridge.py
```

The bridge auto-detects the ESP32 serial port. To specify manually:

```bash
python3 pixel_agents_bridge.py --port /dev/cu.usbmodemXXXX
```

### 5. Use Claude Code

Start using Claude Code as normal. The display will show your agents in the office scene.

## What You'll See

- **Agent spawns** with a matrix-style column reveal effect
- **Active agent** walks to its desk and sits down to type or read
- **Idle agent** stands up and wanders around the office
- **Speech bubbles** show tool names while running, permission/waiting indicators
- **Status bar** at bottom shows connection status and agent count
- **Multiple agents** each get their own desk and color palette

## Agent Characters

All 6 characters are always visible on screen. At boot they spawn in two social zones — 3 in the break room and 3 in the library — and wander within their zone until assigned work.

### Lifecycle

```
Boot → appear (matrix reveal) → IDLE (wander in social zone)
                                   ↓ agent activates
                                WALK → desk → TYPE / READ
                                   ↑ agent goes idle
                                WALK → back to social zone → IDLE
```

All 6 characters appear once at boot with a matrix-style column reveal effect and remain on screen permanently. They never despawn — when an agent goes inactive, the character walks back to its social zone rather than disappearing.

When the companion bridge reports an agent becoming active, the nearest unassigned character claims a desk and pathfinds to it. Once seated, the character animates typing or reading depending on the tool in use:

- **TYPE** — tools that write (`Edit`, `Write`, `Bash`, etc.)
- **READ** — tools that read (`Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`)

### State Machine

| State | Animation | Behavior |
|-------|-----------|----------|
| IDLE | Standing frame | Wanders within assigned social zone (2–20s pause, 3–6 moves per burst) |
| WALK | 4-frame cycle (0.15s/frame) | BFS pathfinding at 48 px/s to destination tile |
| TYPE | 2-frame cycle (0.3s/frame) | Seated at desk, typing animation |
| READ | 2-frame cycle (0.3s/frame) | Seated at desk, reading animation |

Characters face 4 directions (DOWN, UP, RIGHT, LEFT). LEFT sprites are rendered by flipping RIGHT horizontally. Each character has a unique color palette (hair, skin, shirt, pants, shoes).

### Rendering

The scene renders at 15 FPS using a double-buffered sprite. Entities (characters, furniture, dog) are depth-sorted by Y position so closer objects draw in front. Characters seated at desks are offset to visually align with the chair sprite.

## Office Dog

A dog roams the office autonomously, cycling through three behaviors:

```
WANDER (20 min) → FOLLOW (20 min) → WANDER → FOLLOW → ...
                         ↑
                 NAP interrupts every 4 hours (lasts 30 min)
```

**WANDER** — The dog picks random tiles and walks to them, pausing 2–6 seconds between moves. Each pause has an 8% chance of triggering a pee animation (3s) and each walk has a 15% chance of becoming a run (faster speed, different sprite cycle).

**FOLLOW** — The dog picks a random character and stays within 5 tiles of them, re-pathfinding every 8 seconds. If the target sits down at a desk (typing or reading), the dog sits beside them. A new follow target is picked every hour.

**NAP** — A global timer counts down regardless of current behavior. Every 4 hours the dog stops everything, lays down, and naps for 30 minutes before returning to WANDER.

### Animations

| Animation | Frames | When |
|-----------|--------|------|
| Idle | 8 frames (0.3s each) | Standing still — default when not walking, sitting, peeing, or napping |
| Walk | 4 frames (0.12s each) | Moving to a tile at 40 px/s |
| Run | 8 frames (0.08s each) | 15% chance a wander walk becomes a run at 72 px/s |
| Sit | 1 frame | Following a character who is seated at a desk |
| Pee | 1 frame | 8% chance during wander pauses, lasts 3 seconds |
| Lay down | 1 frame | Napping (30 minutes every 4 hours) |

The dog sprite is side-view only — LEFT facing is rendered by flipping the RIGHT sprite horizontally. The dog uses BFS pathfinding and depth-sorts with characters.

On the CYD board, the dog can be toggled on/off and its color changed (black, brown, gray, tan) via the hamburger menu. Settings persist across reboots via NVS.

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
  assets/                # External art assets (gitignored)
    Office Tileset/      # 16x16 tileset used by sprite_converter
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
        tiles.h          # Floor/wall/furniture from layout editor
        bubbles.h
  companion/             # Python bridge service
    pixel_agents_bridge.py
    requirements.txt
  tools/                 # Build tools
    sprite_converter.py
    sprite_validation.html  # Generated visual check
    layout_editor.html      # Office layout editor (serve via HTTP)
```

## Third-Party Assets

### Office Tileset

The office tileset used in this project and available via the extension is [Office Interior Tileset (16x16)](https://donarg.itch.io/office-interior-tileset-16x16) by Donarg, available on itch.io for $2 USD.

This is the only part of the project that is not freely available. The tileset is not included in this repository due to its license. To use Pixel Agents locally with the full set of office furniture and decorations, purchase the tileset, unzip the file and move the "Office Tileset" directory from the expanded zip into the `assets/` directory. Otherwise it will fallback to a default tileset.

### Dog Sprites

The dog pet sprites are based on [Dog Animation - 4 Different Dogs](https://nvph-studio.itch.io/dog-animation-4-different-dogs) by [NVPH Studio](https://nvph-studio.itch.io/), licensed under [CC BY-ND 4.0](https://creativecommons.org/licenses/by-nd/4.0/). The sprites were resized to 25x19 pixels for use in the pixel art scene. No other modifications were made to the original artwork.

## License

MIT
