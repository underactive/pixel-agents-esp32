#!/usr/bin/env python3
"""
render_office_bg.py - Render the office background (floor + furniture) to PNG.

Parses firmware/src/sprites/tiles.h for RGB565 sprite data and tile map,
then renders the 320x240 office scene (floor tiles + furniture) to a PNG
for use as the static background in the macOS companion app's Software tab.

Usage:
    python3 tools/render_office_bg.py

Output:
    macos/PixelAgents/PixelAgents/Resources/office_background.png

Requires Pillow: pip install Pillow
"""

import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow is required. Install with: pip install Pillow")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
TILES_H = PROJECT_ROOT / "firmware" / "src" / "sprites" / "tiles.h"
OUTPUT_DIR = PROJECT_ROOT / "macos" / "PixelAgents" / "PixelAgents" / "Resources"
OUTPUT_PATH = OUTPUT_DIR / "office_background.png"

SCREEN_W = 320
SCREEN_H = 224  # Grid area only (14 rows * 16px), no status bar
TILE_SIZE = 16
GRID_ROWS = 14
GRID_COLS = 20


def rgb565_to_rgba(val: int) -> tuple:
    """Convert RGB565 uint16 to (R, G, B, A) tuple."""
    if val == 0x0000:
        return (0, 0, 0, 0)  # transparent
    r5 = (val >> 11) & 0x1F
    g6 = (val >> 5) & 0x3F
    b5 = val & 0x1F
    r8 = (r5 << 3) | (r5 >> 2)
    g8 = (g6 << 2) | (g6 >> 4)
    b8 = (b5 << 3) | (b5 >> 2)
    return (r8, g8, b8, 255)


def parse_tiles_h(path: Path) -> dict:
    """Parse tiles.h to extract RGB565 arrays, dimensions, and tile map."""
    text = path.read_text()

    # Extract #define NAME value
    defines = {}
    for m in re.finditer(r'#define\s+(\w+)\s+(\d+)', text):
        defines[m.group(1)] = int(m.group(2))

    # Extract RGB565 arrays: static const uint16_t NAME[SIZE] PROGMEM = { ... };
    arrays = {}
    pattern = r'static\s+const\s+uint16_t\s+(\w+)\[(\d+)\]\s+PROGMEM\s*=\s*\{([^}]+)\}'
    for m in re.finditer(pattern, text, re.DOTALL):
        name = m.group(1)
        values = [int(v.strip(), 16) for v in re.findall(r'0x[0-9A-Fa-f]+', m.group(3))]
        arrays[name] = values

    # Extract TILE_MAP[14][20] references
    tile_map = []
    map_match = re.search(
        r'static\s+const\s+uint16_t\*\s+TILE_MAP\[14\]\[20\]\s+PROGMEM\s*=\s*\{(.*?)\};',
        text, re.DOTALL
    )
    if map_match:
        inner = map_match.group(1)
        for row_match in re.finditer(r'\{([^}]+)\}', inner):
            row_names = [n.strip() for n in row_match.group(1).split(',') if n.strip()]
            tile_map.append(row_names)

    return arrays, defines, tile_map


def draw_sprite(img: Image.Image, sprite_data: list, x: int, y: int, w: int, h: int):
    """Draw an RGB565 sprite onto the image with transparency."""
    for py in range(h):
        for px in range(w):
            idx = py * w + px
            if idx >= len(sprite_data):
                continue
            val = sprite_data[idx]
            if val == 0x0000:
                continue  # transparent
            dx, dy = x + px, y + py
            if 0 <= dx < SCREEN_W and 0 <= dy < SCREEN_H:
                img.putpixel((dx, dy), rgb565_to_rgba(val))


def main():
    if not TILES_H.exists():
        print(f"Error: {TILES_H} not found. Run layout_editor first.")
        sys.exit(1)

    print("Parsing tiles.h...")
    arrays, defines, tile_map = parse_tiles_h(TILES_H)
    print(f"  Found {len(arrays)} sprite arrays, {len(defines)} defines, "
          f"{len(tile_map)} tile map rows")

    # Create RGBA image
    img = Image.new("RGBA", (SCREEN_W, SCREEN_H), (0, 0, 0, 255))

    # 1. Draw floor tiles from TILE_MAP
    print("Drawing floor tiles...")
    for r in range(min(GRID_ROWS, len(tile_map))):
        for c in range(min(GRID_COLS, len(tile_map[r]))):
            tile_name = tile_map[r][c]
            if tile_name in arrays:
                draw_sprite(img, arrays[tile_name], c * TILE_SIZE, r * TILE_SIZE,
                            TILE_SIZE, TILE_SIZE)

    # 2. Draw furniture (exact same order as renderer.cpp drawFurniture())
    print("Drawing furniture...")
    furniture_placements = [
        # Desks
        ("SPRITE_DESK_D", 1, 12), ("SPRITE_DESK_D", 6, 12),
        ("SPRITE_DESK_D", 1, 7), ("SPRITE_DESK_D", 6, 7),
        ("SPRITE_DESK_VERT", 3, 4), ("SPRITE_DESK_VERT", 6, 4),
        # Chairs
        ("SPRITE_CHAIR_A", 2, 11), ("SPRITE_CHAIR_A", 7, 11),
        ("SPRITE_CHAIR_B", 2, 8), ("SPRITE_CHAIR_B", 7, 8),
        ("SPRITE_CHAIR_C", 2, 4), ("SPRITE_CHAIR_D", 7, 4),
        # Seats
        ("SPRITE_SEAT_1", 17, 8), ("SPRITE_SEAT_1", 15, 8),
        ("SPRITE_SEAT_2", 15, 12), ("SPRITE_SEAT_2", 17, 12),
        ("SPRITE_SEAT_4", 19, 9), ("SPRITE_SEAT_4", 19, 11),
        ("SPRITE_STOOL", 18, 3),
        # Static decorations
        ("SPRITE_WATER_COOLER", 12, 0),
        ("SPRITE_COUNTER_TOP", 16, 1), ("SPRITE_COUNTER_TOP", 14, 1),
        ("SPRITE_COUNTER_BOTTOM_A", 14, 2), ("SPRITE_COUNTER_BOTTOM_A", 16, 2),
        ("SPRITE_VENDING_MACHINE", 18, 0),
        ("SPRITE_PLANT_BOTTOM_BROWN", 9, 13), ("SPRITE_PLANT_BOTTOM_BROWN", 0, 13),
        ("SPRITE_PLANT_TOP_C", 0, 12), ("SPRITE_PLANT_TOP_D", 9, 12),
        ("SPRITE_BOOKSHELF_A", 12, 5), ("SPRITE_BOOKSHELF_A", 16, 5),
        ("SPRITE_BOOKSHELF_B", 14, 5), ("SPRITE_BOOKSHELF_B", 18, 5),
        ("SPRITE_TABLE", 19, 3),
        ("SPRITE_COFFEE_MAKER", 16, 0), ("SPRITE_COFFEE_MAKER", 17, 0),
        ("SPRITE_PLANT_TOP_E", 13, 1),
        ("SPRITE_PLANT_BOTTOM_WHITE", 13, 2),
        ("SPRITE_PLANT_TOP_G", 11, 5),
        ("SPRITE_PLANT_BOTTOM_WHITE", 11, 6),
        ("SPRITE_PLANT_TOP_2", 18, 12),
        ("SPRITE_PLANT_BOTTOM_WHITE", 18, 13),
        ("SPRITE_PLANT_BOTTOM_WHITE", 14, 13),
        ("SPRITE_PLANT_TOP_2", 14, 12),
        ("SPRITE_BOOKSHELF_WOOD_1", 1, 0), ("SPRITE_BOOKSHELF_WOOD_1", 6, 0),
        ("SPRITE_BOOKSHELF_WOOD_2", 4, 0),
        ("SPRITE_PLANT_TOP_C", 0, 0), ("SPRITE_PLANT_TOP_D", 9, 0),
        ("SPRITE_PLANT_BOTTOM_BROWN", 0, 1), ("SPRITE_PLANT_BOTTOM_BROWN", 9, 1),
        ("SPRITE_LAPTOP_B", 2, 6),
        ("SPRITE_COMPUTER_B", 7, 6),
        ("SPRITE_PLANT_TOP_H", 11, 6),
        ("SPRITE_PLANT_BOTTOM_WHITE", 11, 7),
        ("SPRITE_MICROWAVE", 14, 1),
        ("SPRITE_TRASH", 11, 1),
        ("SPRITE_COMPUTER_E", 1, 12),
        ("SPRITE_COMPUTER_G", 7, 12),
        ("SPRITE_LAPTOP_C", 6, 4),
        ("SPRITE_LAPTOP_D", 3, 4),
        ("SPRITE_BOX", 8, 3),
        ("SPRITE_BOXES_2", 6, 2),
        ("SPRITE_BOXES_1", 1, 2),
    ]

    for sprite_name, tile_col, tile_row in furniture_placements:
        if sprite_name not in arrays:
            print(f"  WARNING: {sprite_name} not found in tiles.h, skipping")
            continue
        w_key = f"{sprite_name}_W"
        h_key = f"{sprite_name}_H"
        w = defines.get(w_key, TILE_SIZE)
        h = defines.get(h_key, TILE_SIZE)
        draw_sprite(img, arrays[sprite_name],
                    tile_col * TILE_SIZE, tile_row * TILE_SIZE, w, h)

    # 3. Save output
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    img.save(OUTPUT_PATH)
    print(f"Saved: {OUTPUT_PATH}")
    print(f"  Size: {SCREEN_W}x{SCREEN_H}")


if __name__ == "__main__":
    main()
