#!/usr/bin/env python3
"""
sprite_converter.py - Convert pixel-agents sprite data to ESP32 C headers.

Converts the VS Code extension's sprite definitions into:
  - firmware/src/sprites/characters.h  (indexed templates + palettes)
  - firmware/src/sprites/furniture.h   (RGB565 PROGMEM arrays)
  - firmware/src/sprites/bubbles.h     (RGB565 PROGMEM arrays)
  - tools/sprite_validation.html       (visual validation page)

Usage:
    python3 tools/sprite_converter.py

No external dependencies required.
"""

from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ---------------------------------------------------------------------------
# Project paths (relative to this script)
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
FIRMWARE_SPRITES_DIR = PROJECT_ROOT / "firmware" / "src" / "sprites"
VALIDATION_HTML_PATH = SCRIPT_DIR / "sprite_validation.html"

# ---------------------------------------------------------------------------
# RGB565 conversion helpers
# ---------------------------------------------------------------------------

def hex_to_rgb(hex_color: str) -> Tuple[int, int, int]:
    """Convert '#RRGGBB' to (r, g, b)."""
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def rgb_to_rgb565(r: int, g: int, b: int) -> int:
    """Convert (r,g,b) to standard RGB565 value.

    Byte-swapping for SPI is handled by TFT_eSprite::setSwapBytes(true)
    at push time, so we store standard RGB565 here.
    """
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def hex_to_rgb565(hex_color: str) -> int:
    """Convert '#RRGGBB' hex string to standard RGB565."""
    r, g, b = hex_to_rgb(hex_color)
    return rgb_to_rgb565(r, g, b)


# Transparent marker for direct-color sprites.  Pure black (#000000) maps to
# 0x0000 in RGB565; we use 0x0000 as the transparent sentinel.  This is safe
# because no sprite pixel uses pure black -- the darkest color is #111111
# which maps to a non-zero RGB565 value.
TRANSPARENT_RGB565 = 0x0000

# ---------------------------------------------------------------------------
# Palette definitions (6 palettes from the extension)
# ---------------------------------------------------------------------------

PALETTES = [
    {"skin": "#FFCC99", "shirt": "#4488CC", "pants": "#334466", "hair": "#553322", "shoes": "#222222"},
    {"skin": "#FFCC99", "shirt": "#CC4444", "pants": "#333333", "hair": "#FFD700", "shoes": "#222222"},
    {"skin": "#DEB887", "shirt": "#44AA66", "pants": "#334444", "hair": "#222222", "shoes": "#333333"},
    {"skin": "#FFCC99", "shirt": "#AA55CC", "pants": "#443355", "hair": "#AA4422", "shoes": "#222222"},
    {"skin": "#DEB887", "shirt": "#CCAA33", "pants": "#444433", "hair": "#553322", "shoes": "#333333"},
    {"skin": "#FFCC99", "shirt": "#FF8844", "pants": "#443322", "hair": "#111111", "shoes": "#222222"},
]

# Eyes are always white (#FFFFFF).
EYES_COLOR = "#FFFFFF"

# Palette index order for the C array: hair, skin, shirt, pants, shoes, eyes
PALETTE_KEY_ORDER = ["hair", "skin", "shirt", "pants", "shoes"]

# ---------------------------------------------------------------------------
# Character template index mapping
# ---------------------------------------------------------------------------
# Template pixel values:
#   0 = transparent (_)
#   1 = hair        (H)
#   2 = skin        (K)
#   3 = shirt       (S)
#   4 = pants       (P)
#   5 = shoes       (O)
#   6 = eyes/white  (E)

CHAR_PIXEL_MAP = {
    "_": 0,
    "H": 1,
    "K": 2,
    "S": 3,
    "P": 4,
    "O": 5,
    "E": 6,
}

# ---------------------------------------------------------------------------
# Character sprite template data  (16 wide x 24 tall each)
# Each string row must be exactly 16 characters.
# ---------------------------------------------------------------------------

# Key: _ = transparent, H = hair, K = skin, S = shirt, P = pants, O = shoes, E = eyes

CHAR_TEMPLATES_RAW: Dict[str, List[str]] = {
    # ---- DOWN ----
    "CHAR_WALK_DOWN_1": [
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "____PP____PP____",
        "____PP____PP____",
        "____OO_____OO___",
        "____OO_____OO___",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_WALK_DOWN_2": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____PP__PP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "_____OO__OO_____",
        "________________",
        "________________",
    ],
    "CHAR_WALK_DOWN_3": [
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "___OO______PP___",
        "___OO______PP___",
        "__________OO____",
        "__________OO____",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_DOWN_TYPE_1": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "___KKSSSSSSKK___",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_DOWN_TYPE_2": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____KSSSSSSKK___",
        "____KSSSSSS_K___",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_DOWN_READ_1": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_DOWN_READ_2": [
        "________________",
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KEKKEK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],

    # ---- UP ----
    "CHAR_WALK_UP_1": [
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "____PP____PP____",
        "____PP____PP____",
        "___OO______OO___",
        "___OO______OO___",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_WALK_UP_2": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____PP__PP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "_____OO__OO_____",
        "________________",
        "________________",
    ],
    "CHAR_WALK_UP_3": [
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "___OO______PP___",
        "___OO______PP___",
        "__________OO____",
        "__________OO____",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_UP_TYPE_1": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "___KKSSSSSSKK___",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_UP_TYPE_2": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____KSSSSSSKK___",
        "____KSSSSSS_K___",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_UP_READ_1": [
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_UP_READ_2": [
        "________________",
        "________________",
        "________________",
        "______HHHH______",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____HHHHHH_____",
        "_____KKKKKK_____",
        "_____KKKKKK_____",
        "______SSSS______",
        "_____SSSSSS_____",
        "____SSSSSSSS____",
        "____SSSSSSSS____",
        "____KSSSSSSK____",
        "_____SSSSSS_____",
        "______PPPP______",
        "_____PPPPPP_____",
        "_____PP__PP_____",
        "_____OO__OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
        "________________",
    ],

    # ---- RIGHT ----
    "CHAR_WALK_RIGHT_1": [
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSS_____",
        "_____SSSSSS_____",
        "_____KSSSSK_____",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PPPP______",
        "_____PP___PP____",
        "_____PP___PP____",
        "_____OO____OO___",
        "_____OO____OO___",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_WALK_RIGHT_2": [
        "________________",
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSS_____",
        "_____SSSSSS_____",
        "_____KSSSSK_____",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PP_PP_____",
        "______PP_PP_____",
        "______PP_PP_____",
        "______OO_OO_____",
        "______OO_OO_____",
        "________________",
        "________________",
    ],
    "CHAR_WALK_RIGHT_3": [
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSS_____",
        "_____SSSSSS_____",
        "_____KSSSSK_____",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PPPP______",
        "________PPP_____",
        "________PPP_____",
        "_____OO_OO______",
        "_____OO_________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_RIGHT_TYPE_1": [
        "________________",
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSSK____",
        "_____SSSSSK_____",
        "______SSSS______",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PPPP______",
        "______PP_PP_____",
        "______OO_OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_RIGHT_TYPE_2": [
        "________________",
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSS_K___",
        "_____SSSSS__K___",
        "______SSSS______",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PPPP______",
        "______PP_PP_____",
        "______OO_OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_RIGHT_READ_1": [
        "________________",
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSS_____",
        "_____SSSSSS_____",
        "_____KSSSSK_____",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PPPP______",
        "______PP_PP_____",
        "______OO_OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
    "CHAR_RIGHT_READ_2": [
        "________________",
        "________________",
        "________________",
        "_______HHHH_____",
        "______HHHHH_____",
        "______HHHHH_____",
        "______KKKKK_____",
        "______KKKEK_____",
        "______KKKKK_____",
        "______KKKK______",
        "_______SSS______",
        "______SSSSS_____",
        "_____SSSSSS_____",
        "_____SSSSSS_____",
        "_____KSSSSK_____",
        "______SSSS______",
        "_______PP_______",
        "______PPPP______",
        "______PP_PP_____",
        "______OO_OO_____",
        "________________",
        "________________",
        "________________",
        "________________",
    ],
}

# ---------------------------------------------------------------------------
# Furniture sprite definitions (hex color 2D arrays)
# _ = transparent
# ---------------------------------------------------------------------------

def _build_desk_sprite() -> List[List[str]]:
    """Build the 32x32 desk sprite programmatically."""
    W = "#8B6914"  # wood edge
    L = "#A07828"  # lighter wood
    S = "#B8922E"  # surface
    D = "#6B4E0A"  # dark edge
    T = ""         # transparent

    rows: List[List[str]] = []
    for r in range(32):
        if r == 0:
            rows.append([T] * 32)
        elif r == 1:
            rows.append([T] + [W] * 30 + [T])
        elif 2 <= r <= 5:
            fill = L if r == 2 else S
            rows.append([T, W] + [fill] * 28 + [W, T])
        elif r == 6:
            rows.append([T, D] + [W] * 28 + [D, T])
        elif 7 <= r <= 12:
            rows.append([T, W] + [S] * 28 + [W, T])
        elif r == 13:
            rows.append([T, W] + [L] * 28 + [W, T])
        elif 14 <= r <= 19:
            rows.append([T, W] + [S] * 28 + [W, T])
        elif r == 20:
            rows.append([T, D] + [W] * 28 + [D, T])
        elif 21 <= r <= 24:
            fill = S if r <= 22 else L
            rows.append([T, W] + [fill] * 28 + [W, T])
        elif r == 25:
            rows.append([T] + [W] * 30 + [T])
        elif 26 <= r <= 29:
            row = [T] * 32
            row[1] = D
            row[2] = D
            row[29] = D
            row[30] = D
            rows.append(row)
        else:  # 30-31
            rows.append([T] * 32)
    return rows


def _build_chair_sprite() -> List[List[str]]:
    """Build 16x16 chair sprite."""
    W = "#8B6914"
    D = "#6B4E0A"
    B = "#5C3D0A"
    S = "#A07828"
    T = ""
    # Simple wooden chair, front view
    return [
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,D,D,D,D,D,D,D,D,T,T,T,T],
        [T,T,T,D,W,W,W,W,W,W,W,W,D,T,T,T],
        [T,T,T,D,W,S,S,S,S,S,S,W,D,T,T,T],
        [T,T,T,D,W,S,S,S,S,S,S,W,D,T,T,T],
        [T,T,T,D,W,S,S,S,S,S,S,W,D,T,T,T],
        [T,T,T,D,W,W,W,W,W,W,W,W,D,T,T,T],
        [T,T,T,D,D,D,D,D,D,D,D,D,D,T,T,T],
        [T,T,T,T,D,S,S,S,S,S,S,D,T,T,T,T],
        [T,T,T,T,D,S,S,S,S,S,S,D,T,T,T,T],
        [T,T,T,T,D,S,S,S,S,S,S,D,T,T,T,T],
        [T,T,T,T,D,D,D,D,D,D,D,D,T,T,T,T],
        [T,T,T,T,B,T,T,T,T,T,T,B,T,T,T,T],
        [T,T,T,T,B,T,T,T,T,T,T,B,T,T,T,T],
        [T,T,T,T,B,T,T,T,T,T,T,B,T,T,T,T],
        [T,T,T,T,B,T,T,T,T,T,T,B,T,T,T,T],
    ]


def _build_plant_sprite() -> List[List[str]]:
    """Build 16x24 plant sprite."""
    G = "#3D8B37"
    D = "#2D6B27"
    Tr = "#6B4E0A"  # trunk/stem
    P = "#B85C3A"   # pot
    R = "#8B4422"   # pot rim
    T = ""
    return [
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,G,G,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,G,G,G,G,T,T,T,T,T,T],
        [T,T,T,T,T,G,G,G,G,G,G,T,T,T,T,T],
        [T,T,T,T,G,G,D,G,G,D,G,G,T,T,T,T],
        [T,T,T,G,G,D,G,G,G,G,D,G,G,T,T,T],
        [T,T,T,G,G,G,G,G,G,G,G,G,G,T,T,T],
        [T,T,G,G,D,G,G,G,G,G,G,D,G,G,T,T],
        [T,T,G,G,G,G,D,G,G,D,G,G,G,G,T,T],
        [T,T,T,G,G,G,G,G,G,G,G,G,G,T,T,T],
        [T,T,T,T,G,G,G,G,G,G,G,G,T,T,T,T],
        [T,T,T,T,T,G,G,G,G,G,G,T,T,T,T,T],
        [T,T,T,T,T,T,T,Tr,Tr,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,Tr,Tr,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,Tr,Tr,T,T,T,T,T,T,T],
        [T,T,T,T,T,R,R,R,R,R,R,T,T,T,T,T],
        [T,T,T,T,R,P,P,P,P,P,P,R,T,T,T,T],
        [T,T,T,T,R,P,P,P,P,P,P,R,T,T,T,T],
        [T,T,T,T,R,P,P,P,P,P,P,R,T,T,T,T],
        [T,T,T,T,R,P,P,P,P,P,P,R,T,T,T,T],
        [T,T,T,T,R,P,P,P,P,P,P,R,T,T,T,T],
        [T,T,T,T,T,R,R,R,R,R,R,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
    ]


def _build_bookshelf_sprite() -> List[List[str]]:
    """Build 16x32 bookshelf sprite (1x2 tiles)."""
    W = "#8B6914"
    D = "#6B4E0A"
    Re = "#CC4444"
    B = "#4477AA"
    G = "#44AA66"
    Y = "#CCAA33"
    P = "#9955AA"
    T = ""
    return [
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,Re,Re,B,B,G,G,Y,Y,P,P,Re,D,T],
        [T,T,D,Re,Re,B,B,G,G,Y,Y,P,P,Re,D,T],
        [T,T,D,Re,Re,B,B,G,G,Y,Y,P,P,Re,D,T],
        [T,T,D,Re,Re,B,B,G,G,Y,Y,P,P,Re,D,T],
        [T,T,D,Re,Re,B,B,G,G,Y,Y,P,P,Re,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,B,B,Re,Re,P,P,G,G,Y,Y,B,D,T],
        [T,T,D,B,B,Re,Re,P,P,G,G,Y,Y,B,D,T],
        [T,T,D,B,B,Re,Re,P,P,G,G,Y,Y,B,D,T],
        [T,T,D,B,B,Re,Re,P,P,G,G,Y,Y,B,D,T],
        [T,T,D,B,B,Re,Re,P,P,G,G,Y,Y,B,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,G,G,Y,Y,Re,Re,B,B,P,P,G,D,T],
        [T,T,D,G,G,Y,Y,Re,Re,B,B,P,P,G,D,T],
        [T,T,D,G,G,Y,Y,Re,Re,B,B,P,P,G,D,T],
        [T,T,D,G,G,Y,Y,Re,Re,B,B,P,P,G,D,T],
        [T,T,D,G,G,Y,Y,Re,Re,B,B,P,P,G,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,Y,Y,P,P,B,B,Re,Re,G,G,Y,D,T],
        [T,T,D,Y,Y,P,P,B,B,Re,Re,G,G,Y,D,T],
        [T,T,D,Y,Y,P,P,B,B,Re,Re,G,G,Y,D,T],
        [T,T,D,Y,Y,P,P,B,B,Re,Re,G,G,Y,D,T],
        [T,T,D,Y,Y,P,P,B,B,Re,Re,G,G,Y,D,T],
        [T,T,D,W,W,W,W,W,W,W,W,W,W,W,D,T],
        [T,T,D,D,D,D,D,D,D,D,D,D,D,D,D,T],
        [T,T,D,T,T,T,T,T,T,T,T,T,T,D,T,T],
        [T,T,D,T,T,T,T,T,T,T,T,T,T,D,T,T],
    ]


def _build_cooler_sprite() -> List[List[str]]:
    """Build 16x24 water cooler sprite."""
    W = "#CCDDEE"
    L = "#88BBDD"
    D = "#999999"
    B = "#666666"
    T = ""
    return [
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,L,L,L,L,T,T,T,T,T,T],
        [T,T,T,T,T,L,L,L,L,L,L,T,T,T,T,T],
        [T,T,T,T,T,L,L,L,L,L,L,T,T,T,T,T],
        [T,T,T,T,T,L,L,L,L,L,L,T,T,T,T,T],
        [T,T,T,T,T,L,L,L,L,L,L,T,T,T,T,T],
        [T,T,T,T,T,L,L,L,L,L,L,T,T,T,T,T],
        [T,T,T,T,T,D,D,D,D,D,D,T,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,W,W,W,W,W,W,D,T,T,T,T],
        [T,T,T,T,D,D,D,D,D,D,D,D,T,T,T,T],
        [T,T,T,T,T,B,T,T,T,T,B,T,T,T,T,T],
        [T,T,T,T,T,B,T,T,T,T,B,T,T,T,T,T],
        [T,T,T,T,T,B,T,T,T,T,B,T,T,T,T,T],
        [T,T,T,T,B,B,B,T,T,B,B,B,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
    ]


def _build_pc_sprite() -> List[List[str]]:
    """Build 16x16 PC/monitor sprite."""
    F = "#555555"  # frame
    S = "#3A3A5C"  # screen dark
    B = "#6688CC"  # screen bright
    D = "#444444"  # stand
    T = ""
    return [
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,F,F,F,F,F,F,F,F,F,F,F,F,T,T],
        [T,T,F,S,S,S,S,S,S,S,S,S,S,F,T,T],
        [T,T,F,S,B,B,B,B,B,B,B,B,S,F,T,T],
        [T,T,F,S,B,B,B,B,B,B,B,B,S,F,T,T],
        [T,T,F,S,B,B,B,B,B,B,B,B,S,F,T,T],
        [T,T,F,S,B,B,B,B,B,B,B,B,S,F,T,T],
        [T,T,F,S,B,B,B,B,B,B,B,B,S,F,T,T],
        [T,T,F,S,B,B,B,B,B,B,B,B,S,F,T,T],
        [T,T,F,S,S,S,S,S,S,S,S,S,S,F,T,T],
        [T,T,F,F,F,F,F,F,F,F,F,F,F,F,T,T],
        [T,T,T,T,T,T,D,D,D,D,T,T,T,T,T,T],
        [T,T,T,T,T,T,D,D,D,D,T,T,T,T,T,T],
        [T,T,T,T,D,D,D,D,D,D,D,D,T,T,T,T],
        [T,T,T,T,D,D,D,D,D,D,D,D,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
    ]


def _build_lamp_sprite() -> List[List[str]]:
    """Build 16x16 lamp sprite."""
    Y = "#FFDD55"
    L = "#FFEE88"
    D = "#888888"
    B = "#555555"
    G = "#FFFFCC"
    T = ""
    return [
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,G,G,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,G,G,G,G,T,T,T,T,T,T],
        [T,T,T,T,T,L,L,G,G,L,L,T,T,T,T,T],
        [T,T,T,T,L,L,Y,Y,Y,Y,L,L,T,T,T,T],
        [T,T,T,L,L,Y,Y,Y,Y,Y,Y,L,L,T,T,T],
        [T,T,T,L,Y,Y,Y,Y,Y,Y,Y,Y,L,T,T,T],
        [T,T,T,Y,Y,Y,Y,Y,Y,Y,Y,Y,Y,T,T,T],
        [T,T,T,T,Y,Y,Y,Y,Y,Y,Y,Y,T,T,T,T],
        [T,T,T,T,T,D,D,D,D,D,D,T,T,T,T,T],
        [T,T,T,T,T,T,T,D,D,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,D,D,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,D,D,T,T,T,T,T,T,T],
        [T,T,T,T,T,T,T,D,D,T,T,T,T,T,T,T],
        [T,T,T,T,T,B,B,B,B,B,B,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T,T,T,T,T,T],
    ]


def _build_whiteboard_sprite() -> List[List[str]]:
    """Build 32x16 whiteboard sprite (2x1 tiles)."""
    F = "#AAAAAA"
    W = "#EEEEFF"
    M = "#CC4444"
    B = "#4477AA"
    T = ""

    rows: List[List[str]] = []
    for r in range(16):
        if r == 0:
            rows.append([T] * 32)
        elif r == 1:
            rows.append([T] + [F] * 30 + [T])
        elif r == 2:
            rows.append([T, F] + [W] * 28 + [F, T])
        elif 3 <= r <= 11:
            # Board interior with some marker scribbles
            row = [T, F] + [W] * 28 + [F, T]
            if r == 4:
                for c in range(5, 15):
                    row[c] = M
            elif r == 5:
                for c in range(5, 12):
                    row[c] = M
            elif r == 7:
                for c in range(5, 18):
                    row[c] = B
            elif r == 8:
                for c in range(5, 14):
                    row[c] = B
            elif r == 10:
                for c in range(5, 20):
                    row[c] = M
            rows.append(row)
        elif r == 12:
            rows.append([T, F] + [W] * 28 + [F, T])
        elif r == 13:
            rows.append([T] + [F] * 30 + [T])
        elif r == 14:
            row = [T] * 32
            row[3] = F
            row[4] = F
            row[27] = F
            row[28] = F
            rows.append(row)
        elif r == 15:
            rows.append([T] * 32)
    return rows


FURNITURE_SPRITES: Dict[str, dict] = {
    "DESK": {"data": _build_desk_sprite(), "width": 32, "height": 32},
    "CHAIR": {"data": _build_chair_sprite(), "width": 16, "height": 16},
    "PLANT": {"data": _build_plant_sprite(), "width": 16, "height": 24},
    "BOOKSHELF": {"data": _build_bookshelf_sprite(), "width": 16, "height": 32},
    "COOLER": {"data": _build_cooler_sprite(), "width": 16, "height": 24},
    "PC": {"data": _build_pc_sprite(), "width": 16, "height": 16},
    "LAMP": {"data": _build_lamp_sprite(), "width": 16, "height": 16},
    "WHITEBOARD": {"data": _build_whiteboard_sprite(), "width": 32, "height": 16},
}

# ---------------------------------------------------------------------------
# Bubble sprite definitions
# ---------------------------------------------------------------------------

def _build_bubble_permission() -> List[List[str]]:
    """Build 11x13 permission bubble sprite (question mark / key icon)."""
    B = "#555566"
    F = "#EEEEFF"
    A = "#CCA700"
    T = ""
    return [
        [T,T,T,B,B,B,B,B,T,T,T],
        [T,T,B,F,F,F,F,F,B,T,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,F,A,A,A,F,F,B,T],
        [T,B,F,F,F,F,A,F,F,B,T],
        [T,B,F,F,F,A,F,F,F,B,T],
        [T,B,F,F,F,A,F,F,F,B,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,F,F,A,F,F,F,B,T],
        [T,T,B,F,F,F,F,F,B,T,T],
        [T,T,T,B,B,B,B,B,T,T,T],
        [T,T,T,T,T,B,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T],
    ]


def _build_bubble_waiting() -> List[List[str]]:
    """Build 11x13 waiting bubble sprite (ellipsis / loading)."""
    B = "#555566"
    F = "#EEEEFF"
    G = "#44BB66"
    T = ""
    return [
        [T,T,T,B,B,B,B,B,T,T,T],
        [T,T,B,F,F,F,F,F,B,T,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,G,F,G,F,G,F,B,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,B,F,F,F,F,F,F,F,B,T],
        [T,T,B,F,F,F,F,F,B,T,T],
        [T,T,T,B,B,B,B,B,T,T,T],
        [T,T,T,T,T,B,T,T,T,T,T],
        [T,T,T,T,T,T,T,T,T,T,T],
    ]


BUBBLE_SPRITES: Dict[str, dict] = {
    "BUBBLE_PERMISSION": {"data": _build_bubble_permission(), "width": 11, "height": 13},
    "BUBBLE_WAITING": {"data": _build_bubble_waiting(), "width": 11, "height": 13},
}

# ===========================================================================
# Code generation helpers
# ===========================================================================

def _template_to_indices(rows: List[str]) -> List[int]:
    """Convert a character template (list of string rows) to flat index list."""
    indices: List[int] = []
    for row in rows:
        assert len(row) == 16, f"Row length {len(row)} != 16: '{row}'"
        for ch in row:
            indices.append(CHAR_PIXEL_MAP[ch])
    assert len(indices) == 16 * 24
    return indices


def _format_byte_array(data: List[int], values_per_line: int = 16) -> str:
    """Format a list of uint8_t values as C array initializer lines."""
    lines = []
    for i in range(0, len(data), values_per_line):
        chunk = data[i : i + values_per_line]
        lines.append("    " + ", ".join(f"0x{v:02X}" for v in chunk) + ",")
    return "\n".join(lines)


def _format_uint16_array(data: List[int], values_per_line: int = 8) -> str:
    """Format a list of uint16_t values as C array initializer lines."""
    lines = []
    for i in range(0, len(data), values_per_line):
        chunk = data[i : i + values_per_line]
        lines.append("    " + ", ".join(f"0x{v:04X}" for v in chunk) + ",")
    return "\n".join(lines)


def _sprite_2d_to_rgb565(rows: List[List[str]]) -> List[int]:
    """Convert 2D hex-color sprite to flat RGB565 list."""
    result: List[int] = []
    for row in rows:
        for pixel in row:
            if pixel == "" or pixel is None:
                result.append(TRANSPARENT_RGB565)
            else:
                result.append(hex_to_rgb565(pixel))
    return result


# ===========================================================================
# Header file generators
# ===========================================================================

def generate_characters_header() -> str:
    """Generate firmware/src/sprites/characters.h"""
    lines: List[str] = []
    lines.append("#ifndef SPRITES_CHARACTERS_H")
    lines.append("#define SPRITES_CHARACTERS_H")
    lines.append("")
    lines.append("#include <Arduino.h>")
    lines.append("#include <pgmspace.h>")
    lines.append("")
    lines.append("// =============================================================================")
    lines.append("// Character Sprite Templates & Palettes")
    lines.append("// Generated by tools/sprite_converter.py -- DO NOT EDIT BY HAND")
    lines.append("// =============================================================================")
    lines.append("//")
    lines.append("// Each template is 16x24 pixels, stored as uint8_t indices:")
    lines.append("//   0 = transparent")
    lines.append("//   1 = hair")
    lines.append("//   2 = skin")
    lines.append("//   3 = shirt")
    lines.append("//   4 = pants")
    lines.append("//   5 = shoes")
    lines.append("//   6 = eyes (white)")
    lines.append("//")
    lines.append("// LEFT-facing sprites are not stored separately.")
    lines.append("// Render them by horizontally flipping the corresponding RIGHT sprite.")
    lines.append("//")
    lines.append("// Walk animation cycle: frame1, frame2(standing), frame3, frame2(standing)")
    lines.append("//")
    lines.append("// Palettes are stored as RGB565 (standard RGB565, byte-swapped at push time by TFT_eSPI).")
    lines.append("// Palette entry order: [hair, skin, shirt, pants, shoes, eyes]")
    lines.append("")
    lines.append('#include "../config.h"  // CHAR_W, CHAR_H, NUM_PALETTES, PALETTE_COLORS, PX_*')
    lines.append("")
    lines.append("#define CHAR_SPRITE_SIZE (CHAR_W * CHAR_H)  // 384 bytes")
    lines.append("")

    # --- Template enum ---
    lines.append("// Template indices")
    lines.append("enum CharTemplate {")
    template_names = list(CHAR_TEMPLATES_RAW.keys())
    for i, name in enumerate(template_names):
        lines.append(f"    {name} = {i},")
    lines.append(f"    CHAR_TEMPLATE_COUNT = {len(template_names)}")
    lines.append("};")
    lines.append("")

    # --- Direction / action grouping defines ---
    lines.append("// Convenience indices per direction")
    lines.append("// DOWN: walk1=0, walk2=1(standing), walk3=2, type1=3, type2=4, read1=5, read2=6")
    lines.append("// UP:   walk1=7, walk2=8(standing), walk3=9, type1=10, type2=11, read1=12, read2=13")
    lines.append("// RIGHT:walk1=14, walk2=15(standing), walk3=16, type1=17, type2=18, read1=19, read2=20")
    lines.append("// LEFT = horizontally flip RIGHT at render time")
    lines.append("")

    # --- Template arrays ---
    for name, rows in CHAR_TEMPLATES_RAW.items():
        indices = _template_to_indices(rows)
        lines.append(f"static const uint8_t {name}[CHAR_SPRITE_SIZE] PROGMEM = {{")
        lines.append(_format_byte_array(indices))
        lines.append("};")
        lines.append("")

    # --- Array of template pointers ---
    lines.append("// Array of all template pointers for indexed access")
    lines.append("static const uint8_t* const CHAR_TEMPLATES[CHAR_TEMPLATE_COUNT] PROGMEM = {")
    for name in template_names:
        lines.append(f"    {name},")
    lines.append("};")
    lines.append("")

    # --- Palettes ---
    lines.append("// RGB565 palettes (standard RGB565)")
    lines.append("// Order per palette: hair, skin, shirt, pants, shoes, eyes")
    for i, pal in enumerate(PALETTES):
        pal_values: List[int] = []
        for key in PALETTE_KEY_ORDER:
            pal_values.append(hex_to_rgb565(pal[key]))
        pal_values.append(hex_to_rgb565(EYES_COLOR))  # eyes = white
        lines.append(f"static const uint16_t PALETTE_{i}[PALETTE_COLORS] PROGMEM = {{")
        lines.append("    " + ", ".join(f"0x{v:04X}" for v in pal_values))
        lines.append("};")
        lines.append("")

    # --- Array of palette pointers ---
    lines.append("// Array of all palette pointers for indexed access")
    lines.append("static const uint16_t* const CHAR_PALETTES[NUM_PALETTES] PROGMEM = {")
    for i in range(len(PALETTES)):
        lines.append(f"    PALETTE_{i},")
    lines.append("};")
    lines.append("")

    lines.append("#endif // SPRITES_CHARACTERS_H")
    return "\n".join(lines) + "\n"


def generate_furniture_header() -> str:
    """Generate firmware/src/sprites/furniture.h"""
    lines: List[str] = []
    lines.append("#ifndef SPRITES_FURNITURE_H")
    lines.append("#define SPRITES_FURNITURE_H")
    lines.append("")
    lines.append("#include <Arduino.h>")
    lines.append("#include <pgmspace.h>")
    lines.append("")
    lines.append("// =============================================================================")
    lines.append("// Furniture Sprites (RGB565, standard RGB565)")
    lines.append("// Generated by tools/sprite_converter.py -- DO NOT EDIT BY HAND")
    lines.append("// =============================================================================")
    lines.append("//")
    lines.append("// Transparent pixels are stored as 0x0000.")
    lines.append("// The renderer should treat 0x0000 as transparent (skip drawing).")
    lines.append("")

    for name, info in FURNITURE_SPRITES.items():
        w = info["width"]
        h = info["height"]
        data_2d: List[List[str]] = info["data"]
        rgb565_flat = _sprite_2d_to_rgb565(data_2d)

        lines.append(f"#define SPRITE_{name}_W {w}")
        lines.append(f"#define SPRITE_{name}_H {h}")
        lines.append(f"static const uint16_t SPRITE_{name}[{w * h}] PROGMEM = {{")
        lines.append(_format_uint16_array(rgb565_flat))
        lines.append("};")
        lines.append("")

    lines.append("#endif // SPRITES_FURNITURE_H")
    return "\n".join(lines) + "\n"


def generate_bubbles_header() -> str:
    """Generate firmware/src/sprites/bubbles.h"""
    lines: List[str] = []
    lines.append("#ifndef SPRITES_BUBBLES_H")
    lines.append("#define SPRITES_BUBBLES_H")
    lines.append("")
    lines.append("#include <Arduino.h>")
    lines.append("#include <pgmspace.h>")
    lines.append("")
    lines.append("// =============================================================================")
    lines.append("// Speech Bubble Sprites (RGB565, standard RGB565)")
    lines.append("// Generated by tools/sprite_converter.py -- DO NOT EDIT BY HAND")
    lines.append("// =============================================================================")
    lines.append("//")
    lines.append("// Transparent pixels are stored as 0x0000.")
    lines.append("")

    for name, info in BUBBLE_SPRITES.items():
        w = info["width"]
        h = info["height"]
        data_2d: List[List[str]] = info["data"]
        rgb565_flat = _sprite_2d_to_rgb565(data_2d)

        lines.append(f"#define SPRITE_{name}_W {w}")
        lines.append(f"#define SPRITE_{name}_H {h}")
        lines.append(f"static const uint16_t SPRITE_{name}[{w * h}] PROGMEM = {{")
        lines.append(_format_uint16_array(rgb565_flat))
        lines.append("};")
        lines.append("")

    lines.append("#endif // SPRITES_BUBBLES_H")
    return "\n".join(lines) + "\n"


# ===========================================================================
# HTML validation page generator
# ===========================================================================

def _palette_to_css_colors(pal: dict) -> dict:
    """Return dict mapping index -> CSS hex color for a palette."""
    return {
        0: None,  # transparent
        1: pal["hair"],
        2: pal["skin"],
        3: pal["shirt"],
        4: pal["pants"],
        5: pal["shoes"],
        6: EYES_COLOR,
    }


def generate_validation_html() -> str:
    """Generate tools/sprite_validation.html for visual validation."""

    # Collect all character template data as JSON-compatible structures
    char_templates_json = {}
    for name, rows in CHAR_TEMPLATES_RAW.items():
        char_templates_json[name] = _template_to_indices(rows)

    palettes_json = []
    for pal in PALETTES:
        colors = {
            "0": "transparent",
            "1": pal["hair"],
            "2": pal["skin"],
            "3": pal["shirt"],
            "4": pal["pants"],
            "5": pal["shoes"],
            "6": EYES_COLOR,
        }
        palettes_json.append(colors)

    # Collect furniture sprite data as hex color arrays
    furniture_json = {}
    for name, info in FURNITURE_SPRITES.items():
        w = info["width"]
        h = info["height"]
        flat: List[Optional[str]] = []
        for row in info["data"]:
            for pixel in row:
                flat.append(pixel if pixel else None)
        furniture_json[name] = {"width": w, "height": h, "data": flat}

    bubble_json = {}
    for name, info in BUBBLE_SPRITES.items():
        w = info["width"]
        h = info["height"]
        flat: List[Optional[str]] = []
        for row in info["data"]:
            for pixel in row:
                flat.append(pixel if pixel else None)
        bubble_json[name] = {"width": w, "height": h, "data": flat}

    import json
    templates_js = json.dumps(char_templates_json)
    palettes_js = json.dumps(palettes_json)
    furniture_js = json.dumps(furniture_json)
    bubbles_js = json.dumps(bubble_json)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Pixel Agents - Sprite Validation</title>
<style>
body {{
    font-family: monospace;
    background: #1a1a2e;
    color: #eee;
    padding: 20px;
}}
h1 {{ color: #44aaff; }}
h2 {{ color: #88ccff; margin-top: 30px; }}
h3 {{ color: #aaddff; margin-top: 20px; }}
.sprite-row {{
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    margin-bottom: 10px;
}}
.sprite-card {{
    text-align: center;
}}
.sprite-card canvas {{
    border: 1px solid #333;
    image-rendering: pixelated;
    background: #2a2a4e;
}}
.sprite-card p {{
    font-size: 10px;
    margin: 4px 0;
    max-width: 80px;
    word-wrap: break-word;
}}
</style>
</head>
<body>
<h1>Pixel Agents - Sprite Validation</h1>
<p>Generated by <code>tools/sprite_converter.py</code>. All sprites rendered at 4x zoom.</p>

<h2>Character Templates (per palette)</h2>
<div id="characters"></div>

<h2>Furniture Sprites</h2>
<div id="furniture" class="sprite-row"></div>

<h2>Bubble Sprites</h2>
<div id="bubbles" class="sprite-row"></div>

<script>
const SCALE = 4;
const CHAR_W = 16, CHAR_H = 24;

const templates = {templates_js};
const palettes = {palettes_js};
const furnitureSprites = {furniture_js};
const bubbleSprites = {bubbles_js};

function drawIndexedSprite(canvas, indices, w, h, palette) {{
    canvas.width = w * SCALE;
    canvas.height = h * SCALE;
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (let y = 0; y < h; y++) {{
        for (let x = 0; x < w; x++) {{
            const idx = indices[y * w + x];
            const color = palette[String(idx)];
            if (color && color !== 'transparent') {{
                ctx.fillStyle = color;
                ctx.fillRect(x * SCALE, y * SCALE, SCALE, SCALE);
            }}
        }}
    }}
}}

function drawDirectSprite(canvas, data, w, h) {{
    canvas.width = w * SCALE;
    canvas.height = h * SCALE;
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (let y = 0; y < h; y++) {{
        for (let x = 0; x < w; x++) {{
            const color = data[y * w + x];
            if (color) {{
                ctx.fillStyle = color;
                ctx.fillRect(x * SCALE, y * SCALE, SCALE, SCALE);
            }}
        }}
    }}
}}

// Render characters
const charDiv = document.getElementById('characters');
const templateNames = Object.keys(templates);
for (let pi = 0; pi < palettes.length; pi++) {{
    const section = document.createElement('div');
    const heading = document.createElement('h3');
    heading.textContent = 'Palette ' + pi;
    section.appendChild(heading);
    const row = document.createElement('div');
    row.className = 'sprite-row';
    for (const tname of templateNames) {{
        const card = document.createElement('div');
        card.className = 'sprite-card';
        const canvas = document.createElement('canvas');
        drawIndexedSprite(canvas, templates[tname], CHAR_W, CHAR_H, palettes[pi]);
        const label = document.createElement('p');
        label.textContent = tname.replace('CHAR_', '');
        card.appendChild(canvas);
        card.appendChild(label);
        row.appendChild(card);
    }}
    section.appendChild(row);
    charDiv.appendChild(section);
}}

// Render furniture
const furnDiv = document.getElementById('furniture');
for (const [name, info] of Object.entries(furnitureSprites)) {{
    const card = document.createElement('div');
    card.className = 'sprite-card';
    const canvas = document.createElement('canvas');
    drawDirectSprite(canvas, info.data, info.width, info.height);
    const label = document.createElement('p');
    label.textContent = name;
    card.appendChild(canvas);
    card.appendChild(label);
    furnDiv.appendChild(card);
}}

// Render bubbles
const bubDiv = document.getElementById('bubbles');
for (const [name, info] of Object.entries(bubbleSprites)) {{
    const card = document.createElement('div');
    card.className = 'sprite-card';
    const canvas = document.createElement('canvas');
    drawDirectSprite(canvas, info.data, info.width, info.height);
    const label = document.createElement('p');
    label.textContent = name;
    card.appendChild(canvas);
    card.appendChild(label);
    bubDiv.appendChild(card);
}}
</script>
</body>
</html>
"""
    return html


# ===========================================================================
# Main entry point
# ===========================================================================

def main() -> None:
    # Ensure output directories exist
    FIRMWARE_SPRITES_DIR.mkdir(parents=True, exist_ok=True)
    SCRIPT_DIR.mkdir(parents=True, exist_ok=True)

    # Generate and write all files
    files_written: List[Tuple[Path, str]] = [
        (FIRMWARE_SPRITES_DIR / "characters.h", generate_characters_header()),
        (FIRMWARE_SPRITES_DIR / "furniture.h", generate_furniture_header()),
        (FIRMWARE_SPRITES_DIR / "bubbles.h", generate_bubbles_header()),
        (VALIDATION_HTML_PATH, generate_validation_html()),
    ]

    for path, content in files_written:
        path.write_text(content, encoding="utf-8")
        rel = path.relative_to(PROJECT_ROOT)
        size = len(content)
        print(f"  wrote {rel}  ({size:,} bytes)")

    # Summary
    print()
    print("Sprite conversion complete.")
    print(f"  Character templates: {len(CHAR_TEMPLATES_RAW)} x {16}x{24} = "
          f"{len(CHAR_TEMPLATES_RAW) * 384:,} bytes")
    print(f"  Palettes: {len(PALETTES)} x {len(PALETTE_KEY_ORDER) + 1} colors")
    print(f"  Furniture sprites: {len(FURNITURE_SPRITES)}")
    print(f"  Bubble sprites: {len(BUBBLE_SPRITES)}")


if __name__ == "__main__":
    main()
