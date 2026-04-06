# Common Modifications

Step-by-step recipes for frequent changes. Referenced from `AGENTS.md`.

---

## Version bumps

Version string appears in 5 files:
1. `AGENTS.md` -- "Current Version" in Project Overview section
2. `CHANGELOG.md` -- add a new `## [x.y.z]` section at top with bullet points
3. `docs/HISTORY.md` -- append a new entry to the current phase
4. `firmware/src/config.h` -- `SPLASH_VERSION_STR` (boot splash footer text) and `FIRMWARE_VERSION_ENCODED` (identify response, encoded as `major*1000 + minor*10 + patch`)
5. `macos/PixelAgents/project.yml` -- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` (Sparkle update comparison)

**Keep all version references in sync.** Always bump all files together during any version bump.

## Add a new board variant

1. Add a new `[env:board-name]` section in `firmware/platformio.ini` with board-specific build_flags
2. Add `#if defined(BOARD_XXX)` conditionals in `firmware/src/config.h` for grid dimensions, workstation layout, and any board-specific pin definitions
3. If the board has unique peripherals (e.g., touch), add conditional compilation in `main.cpp` and create a new driver module
4. Update the Hardware section of `ARCHITECTURE.md`
5. Add hardware testing items to `docs/references/testing-checklist.md`

## Add a new protocol message type

1. Define `MSG_NEW_TYPE` constant in `firmware/src/config.h` (next available hex value after 0x0A)
2. Add matching constant in `companion/pixel_agents_bridge.py`
3. Add payload struct in `firmware/src/protocol.h`
4. Add callback type and member in `Protocol` class (`protocol.h`)
5. Add `payloadLength()` case and `dispatch()` handler in `firmware/src/protocol.cpp`
6. Add `build_new_type()` function in `companion/pixel_agents_bridge.py`
7. Wire callback in `firmware/src/main.cpp` setup

## Add a new sound effect

1. Place MP3 in `assets/sounds/`
2. Run `python3 tools/convert_sound.py assets/sounds/xxx.mp3` (use `-n name` to override auto-slug)
3. Add enum value to `SoundId` in `firmware/src/sound.h` (before `COUNT`)
4. Add `#include` for the PCM header in `firmware/src/sound.cpp`
5. Add table entry in `CLIPS[]` in `firmware/src/sound.cpp` (order must match enum)
6. Trigger via `queueSound(SoundId::XXX)` in `office_state.cpp`, or `sound.play(SoundId::XXX)` in `main.cpp`

## Add a new character sprite frame

1. Add the new frame to the source PNG sprite sheets in `assets/characters/`
2. Update `FRAMES_PER_DIR` in `firmware/src/config.h` if frame count changed
3. Run `python3 tools/convert_characters.py` to regenerate `firmware/src/sprites/characters.h`
4. Update `getFrameIndex()` in `firmware/src/renderer.cpp` to map the new frame
5. Verify in `tools/sprite_validation.html`

## Add a new furniture sprite

1. Define the sprite as RGB565 data in `tools/sprite_converter.py`
2. Run `python3 tools/sprite_converter.py` to regenerate `firmware/src/sprites/furniture.h`
3. Add placement coordinates in `firmware/src/renderer.cpp` `drawFurniture()`
4. Mark occupied tiles as `TileType::BLOCKED` in `office_state.cpp` `initTileMap()`
5. Verify in `tools/sprite_validation.html`
