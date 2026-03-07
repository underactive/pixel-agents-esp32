# Plan: Office Tileset Integration

## Objective
Integrate the "Office Tileset" PNG spritesheet (`Office Tileset/Office Tileset All 16x16.png`) into the Pixel Agents project, replacing the hand-drawn furniture sprites and solid-color floor/wall tiles with the tileset artwork. The tileset is optional -- when the PNG is absent, the existing hand-drawn fallback sprites are used.

This integration touches three layers:
1. **Sprite converter** (`tools/sprite_converter.py`) -- extract tiles from PNG and generate C headers
2. **Firmware renderer** (`firmware/src/renderer.cpp`) -- render tileset floor/wall tiles and furniture
3. **Layout editor** (`tools/layout_editor.html`) -- load tileset for visual editing

## Changes

### 1. `tools/sprite_converter.py`
- Add PIL-based tileset extraction: load PNG, crop 16x16 tiles by (col, row) position
- Define tile position mappings for:
  - **Floor tiles**: carpet/floor variants (rows 12-13, cols 0-7 -- the colored panels)
  - **Wall tiles**: top wall border (row 0 col 0-3)
  - **Furniture**: desk (2x2 composite from rows 0-1), chair (1x1), bookshelf (2x4 from rows 8-11), plant (1x2 from rows 28-29), water cooler (1x2 from rows 16-17), PC/monitor (2x2 from rows 20-21), whiteboard (2x1 from rows 26-27)
- Generate new `firmware/src/sprites/tiles.h` with floor/wall tile data as RGB565 PROGMEM arrays
- When tileset PNG exists, override `FURNITURE_SPRITES` with extracted tileset data
- When PNG is absent, fall back to existing `_build_*_sprite()` functions
- Add `--no-tileset` flag to force fallback mode

### 2. `firmware/src/sprites/tiles.h` (new file, generated)
- `TILE_FLOOR_A[256]` / `TILE_FLOOR_B[256]` -- two 16x16 floor variants for checkerboard
- `TILE_WALL[256]` -- 16x16 wall tile
- All as `static const uint16_t PROGMEM`

### 3. `firmware/src/renderer.h`
- Add `drawTile()` helper method declaration

### 4. `firmware/src/renderer.cpp`
- `drawFloor()`: When `TILE_FLOOR_A` exists (compile-time `#ifdef HAS_TILESET_TILES`), render floor using tileset tiles instead of solid `gfxFillRect`. Fall back to solid colors if not defined.
- Add `drawTile()` helper: renders a 16x16 RGB565 tile at (x,y) using the same `gfxDrawPixel` or `gfxFillRect` approach as `drawRGB565Sprite`.
- No changes to furniture rendering -- the generated `furniture.h` arrays are already used by `drawRGB565Sprite()`, so swapping the sprite data in the generator is sufficient.

### 5. `firmware/src/config.h`
- No changes needed. `HAS_TILESET_TILES` will be defined in the generated `tiles.h` header.

### 6. `tools/layout_editor.html`
- Add tileset image loading: attempt to load `../Office Tileset/Office Tileset All 16x16.png` as an `Image` element
- When loaded, render floor tiles by drawing the tile image region instead of solid colors
- Render furniture using tileset tile regions instead of colored rectangles
- Fall back to existing colored-rectangle rendering if image fails to load

## Dependencies
- PIL/Pillow must be installed for tileset extraction (`pip install Pillow`)
- Tileset PNG must be at `Office Tileset/Office Tileset All 16x16.png` relative to project root
- No firmware build dependency changes -- generated headers are checked in

## Tile Position Mapping (from tileset analysis)

Key tiles to extract (col, row in 16x16 grid):

**Floor/Wall:**
- Floor A: (1, 13) -- tan/golden wood floor panel
- Floor B: (2, 13) -- lighter variant for checkerboard
- Wall: (0, 12) -- tan wall panel top

**Desk (2x2, wooden):**
- Top-left: (0, 0), Top-right: (1, 0)
- Bottom-left: (0, 1), Bottom-right: (1, 1)

**Chair:** (5, 16) -- gray office chair front-facing

**Bookshelf (2x2, with books):**
- Top-left: (10, 8), Top-right: (11, 8)
- Bottom-left: (10, 9), Bottom-right: (11, 9)

**Plant (1x2):**
- Top: (3, 28), Bottom: (3, 29)

**Water Cooler (1x2):**
- Top: (9, 16), Bottom: (9, 17)

**PC/Monitor (2x2):**
- Top-left: (13, 22), Top-right: (14, 22)
- Bottom-left: (13, 23), Bottom-right: (14, 23)

**Whiteboard (3x2):**
- Use dashboard from rows 26-27, cols 6-8

## Risks / Open Questions
1. The "no shadow" variant may look better at 16x16 on small displays -- use it as the default extraction source
2. Floor tiles may look too busy at the small display resolution -- may need testing
3. Layout editor loads the image via relative path which may fail depending on browser security (file:// protocol). May need a data URL fallback.
