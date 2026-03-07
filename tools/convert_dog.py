#!/usr/bin/env python3
"""
convert_dog.py - Generate French Bulldog sprite header for ESP32 firmware.

32x24 Chibi Anime Frenchie (bat ears, proportional profile)
Includes:
- idle breathing
- blink
- sit
- happy (tongue out)
- walk (down / up / right)
- tail wag
- nap + sleep Z

Output: firmware/src/sprites/dog.h
"""

from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_PATH = SCRIPT_DIR.parent / "firmware" / "src" / "sprites" / "dog.h"

# ---------------------------------------------------------------------------
# Color palette (RGB565)
# ---------------------------------------------------------------------------

def rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)

COLORS = {
    '.': 0x0000,                    # transparent
    'F': rgb565(200, 152, 80),      # fawn body
    'D': rgb565(136, 96, 48),       # dark fawn
    'L': rgb565(224, 200, 152),     # light belly
    'K': rgb565(24, 24, 24),        # black (eyes / nose)
    'W': rgb565(216, 208, 192),     # white
    'P': rgb565(220, 120, 140),     # tongue / pink
}

WIDTH = 32
HEIGHT = 24

# ---------------------------------------------------------------------------
# SPRITE FRAMES
# ---------------------------------------------------------------------------

# ---------------- FRONT IDLE ----------------

IDLE1 = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFFWWWWWWWWWWWWWFFD.......",
"....DFFFWWKKWWWWWWWKKWWWFFD.....",
"....DFFFWWWWWWWWWWWWWWWWWFFD....",
"....DFFFFLLLLLLLLLLLLLLLFFD.....",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
".....DFFFFFFFFFFFFFFFFFFD.......",
"......DFFFFFFFFFFFFFFFFD........",
".......FFFFFFFFFFFFFFF..........",
".......FFFFF.......FFFFF........",
".......FFFFF.......FFFFF........",
".......KKKK.........KKKK........",
".......KKKK.........KKKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
]

IDLE2 = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFFWWWWWWWWWWWWWFFD.......",
"....DFFFWWKKWWWWWWWKKWWWFFD.....",
"....DFFFWWWWWWWWWWWWWWWWWFFD....",
"....DFFFFLLLLLLLLLLLLLLLFFD.....",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
".....DFFFFFFFFFFFFFFFFFFD.......",
"......DFFFFFFFFFFFFFFFFD........",
".......FFFFFFFFFFFFFFFF.........",
"........FFFFFFFFFFFFFF..........",
".......FFFFF.......FFFFF........",
".......KKKK.........KKKK........",
".......KKKK.........KKKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

BLINK = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFWWDDDDDDDDDDDWWFFD......",
"....DFFFWWWWWWWWWWWWWWWFFD......",
"....DFFFWWWWWWWWWWWWWWWFFD......",
"....DFFFFLLLLLLLLLLLLLLLFFD.....",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
".....DFFFFFFFFFFFFFFFFFFD.......",
"......DFFFFFFFFFFFFFFFFD........",
".......FFFFFFFFFFFFFFF..........",
".......FFFFF.......FFFFF........",
".......KKKK.........KKKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

HAPPY = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFFWWWWWWWWWWWWWFFD.......",
"....DFFFWWKKWWWWWWWKKWWWFFD.....",
"....DFFFWWWWWWWWWWWWWWWWWFFD....",
"....DFFFFLLLLLLLLLLLLLLLFFD.....",
"....DFFFFFPPPPPPPPPFFFFFD.......",
"....DFFFFFPPPPPPPPPFFFFFD.......",
".....DFFFFFFFFFFFFFFFFFFD.......",
"......DFFFFFFFFFFFFFFFFD........",
".......FFFFFFFFFFFFFFF..........",
".......FFFFF.......FFFFF........",
".......KKKK.........KKKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

# ---------------- SIT ----------------

SIT = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFFWWWWWWWWWWWWWFFD.......",
"....DFFFWWKKWWWWWWWKKWWWFFD.....",
"....DFFFWWWWWWWWWWWWWWWWWFFD....",
".....DFFFFLLLLLLLLLLLLLFFD......",
"......DFFFFFFFFFFFFFFFFD........",
".......FFFFFFFFFFFFFFF..........",
".......FFFFFFFFFFFFFFF..........",
".......FFFFF.......FFFFF........",
".......KKKK.........KKKK........",
".......KKKK.........KKKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

# ---------------- WALK DOWN ----------------

DOWN_STAND = IDLE1
DOWN_WALK1 = IDLE2
DOWN_WALK3 = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFFWWWWWWWWWWWWWFFD.......",
"....DFFFWWKKWWWWWWWKKWWWFFD.....",
"....DFFFWWWWWWWWWWWWWWWWWFFD....",
"....DFFFFLLLLLLLLLLLLLLLFFD.....",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
".....DFFFFFFFFFFFFFFFFFFD.......",
"......DFFFFFFFFFFFFFFFFD........",
".......FFFFFFFFFFFFFFF..........",
"......FFFFF.........FFFFF.......",
"......FFFFF.........FFFFF.......",
".......KKK...........KKK........",
".......KKK...........KKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
]

# ---------------- WALK UP ----------------

UP_STAND = [
".....DD.................DD......",
"....DFFD...............DFFD.....",
"....DFFFFD.............DFFFFD...",
"....DFFFFFD...........DFFFFFD...",
"....DFFFFFFDDDDDDDDDDDFFFFFFD...",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
"....DFFFFFFFFFFFFFFFFFFFFD......",
".....DFFFFFFFFFFFFFFFFFFD.......",
"......DFFFFFFFFFFF..FFFD........",
".......FFFFFFFFFFF..FFF.........",
".......FFFFF......FF..FF........",
".......FFFFF......FF..FF........",
".......KKKK.........KKKK........",
".......KKKK.........KKKK........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

UP_WALK1 = UP_STAND
UP_WALK3 = UP_STAND

# ---------------- RIGHT PROFILE ----------------

RIGHT_STAND = [
".....DD.........................",
"....DFFD.....DD.................",
"....DFFD....DFFD................",
"....DFFD...DFFFFD...............",
"...DFFDDDDDDFFFFFD..............",
"DFFFFFFFFFFFFFFFFFDDDDDDDDDDDDDD",
"DFFFFWWWWWWWWFFFFFFFFFFFFFFFFFFD",
"DFWWKKWWWWWWWWFFFFFFFFFFFFFFFFFD",
"DFWWWWWWWWWWWWFFFFFFFFFFFFFFFFFD",
"DFWLLLLLLLLLLLFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
".DFFFFFFFFFFFFFFFFFFFFFFFFFFFFD.",
"..DFFFFFFFFFFFFFFFFFFFFFFFFFFD..",
"..DFFFFFFF............FFFFFFF...",
"..DFFFFFFF............FFFFFFF...",
"..KKKKKKK..............KKKKKK...",
"..KKKKKKK..............KKKKKK...",
"................................",
"................................",
"................................",
"................................",
"................................",
]

RIGHT_WALK1 = [
".....DD.........................",
"....DFFD.....DD.................",
"....DFFD....DFFD................",
"....DFFD...DFFFFD...............",
"...DFFDDDDDDFFFFFD..............",
"DFFFFFFFFFFFFFFFFFDDDDDDDDDDDDDD",
"DFFFFWWWWWWWWFFFFFFFFFFFFFFFFFFD",
"DFWWKKWWWWWWWWFFFFFFFFFFFFFFFFFD",
"DFWWWWWWWWWWWWFFFFFFFFFFFFFFFFFD",
"DFWLLLLLLLLLLLFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
".DFFFFFFFFFFFFFFFFFFFFFFFFFFFFD.",
".....DFFFFFFF........DFFFFFF....",
".....DFFFFFFF........DFFFFFF....",
".......KKKKKK.........KKKKKK....",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

RIGHT_WALK3 = [
".....DD.........................",
"....DFFD.....DD.................",
"....DFFD....DFFD................",
"....DFFD...DFFFFD...............",
"...DFFDDDDDDFFFFFD..............",
"DFFFFFFFFFFFFFFFFFDDDDDDDDDDDDDD",
"DFFFFWWWWWWWWFFFFFFFFFFFFFFFFFFD",
"DFWWKKWWWWWWWWFFFFFFFFFFFFFFFFFD",
"DFWWWWWWWWWWWWFFFFFFFFFFFFFFFFFD",
"DFWLLLLLLLLLLLFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
"DFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFD",
".DFFFFFFFFFFFFFFFFFFFFFFFFFFFFD.",
"..DFFFFFFFFFFFFFFFFFFFFFFFFFFD..",
"..DFFFFF................DFFFF...",
"..DFFFFF................DFFFF...",
"..KKKKK..................KKKK...",
"..KKKKK..................KKKK...",
"................................",
"................................",
"................................",
"................................",
"................................",
]

TAIL1 = RIGHT_STAND
TAIL2 = RIGHT_WALK3

# ---------------- SLEEP ----------------

NAP = [
"................................",
"................................",
".........DD..........DD.........",
"........DFFD........DFFD........",
".......DFFFFDDDDDDDDFFFFD.......",
"......DFFFFFFFFFFFFFFFFFFD......",
".....DFFFFWWWWWWWWWWWWFFFFD.....",
".....DFFFFWKKWWWWWWKKWFFFFD.....",
".....DFFFFWWWWWWWWWWWWFFFFD.....",
"......DFFFFFLLLLLLLLFFFFFD......",
".......DFFFFFFFFFFFFFFFFD.......",
".........DFFFFFFFFFFFFD.........",
"...........DDDDDDDDDD...........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

SLEEP_Z = [
"............................KK..",
"...........................K....",
".........DD..........DD.........",
"........DFFD........DFFD........",
".......DFFFFDDDDDDDDFFFFD.......",
"......DFFFFFFFFFFFFFFFFFFD......",
".....DFFFFWWWWWWWWWWWWFFFFD.....",
".....DFFFFWKKWWWWWWKKWFFFFD.....",
".....DFFFFWWWWWWWWWWWWFFFFD.....",
"......DFFFFFLLLLLLLLFFFFFD......",
".......DFFFFFFFFFFFFFFFFD.......",
".........DFFFFFFFFFFFFD.........",
"...........DDDDDDDDDD...........",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
"................................",
]

# ---------------------------------------------------------------------------
# FRAME ORDER
# ---------------------------------------------------------------------------

FRAMES = [

("DOG_IDLE1", IDLE1),
("DOG_IDLE2", IDLE2),
("DOG_BLINK", BLINK),

("DOG_SIT", SIT),
("DOG_HAPPY", HAPPY),

("DOG_DOWN_WALK1", DOWN_WALK1),
("DOG_DOWN_STAND", DOWN_STAND),
("DOG_DOWN_WALK3", DOWN_WALK3),

("DOG_UP_WALK1", UP_WALK1),
("DOG_UP_STAND", UP_STAND),
("DOG_UP_WALK3", UP_WALK3),

("DOG_RIGHT_WALK1", RIGHT_WALK1),
("DOG_RIGHT_STAND", RIGHT_STAND),
("DOG_RIGHT_WALK3", RIGHT_WALK3),

("DOG_TAIL1", TAIL1),
("DOG_TAIL2", TAIL2),

("DOG_NAP", NAP),
("DOG_SLEEP_Z", SLEEP_Z),
]

# ---------------------------------------------------------------------------
# Generator
# ---------------------------------------------------------------------------

def frame_to_rgb565(rows):
    pixels = []
    for row in rows:
        assert len(row) == WIDTH, f"Row width {len(row)} != {WIDTH}: {row!r}"
        for ch in row:
            pixels.append(COLORS[ch])
    return pixels


def format_array(name, pixels):
    lines = [f"static const uint16_t {name}[{len(pixels)}] PROGMEM = {{"]
    for i in range(0, len(pixels), WIDTH):
        row = pixels[i:i+WIDTH]
        vals = ", ".join(f"0x{v:04X}" for v in row)
        comma = "," if i+WIDTH < len(pixels) else ""
        lines.append(f"    {vals}{comma}")
    lines.append("};")
    return "\n".join(lines)


def main():

    frame_data = []
    for name, rows in FRAMES:
        assert len(rows) == HEIGHT, f"{name}: {len(rows)} rows != {HEIGHT}"
        pixels = frame_to_rgb565(rows)
        frame_data.append((name, pixels))

    parts = [
        "#ifndef SPRITES_DOG_H",
        "#define SPRITES_DOG_H",
        "",
        "#include <Arduino.h>",
        "#include <pgmspace.h>",
        "",
        "// 32x24 Chibi French Bulldog Sprites",
        "// Generated by tools/convert_dog.py",
        "",
        f"#define DOG_FRAME_PIXELS ({WIDTH*HEIGHT})",
        f"#define DOG_FRAME_COUNT {len(FRAMES)}",
        "",
    ]

    for name, pixels in frame_data:
        parts.append("")
        parts.append(format_array(name, pixels))

    parts.append("")
    parts.append(f"static const uint16_t* const DOG_SPRITES[{len(FRAMES)}] PROGMEM = {{")
    for name, _ in frame_data:
        parts.append(f"    {name},")
    parts.append("};")

    parts.append("")
    parts.append("#endif")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text("\n".join(parts))

    print(f"Generated {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
