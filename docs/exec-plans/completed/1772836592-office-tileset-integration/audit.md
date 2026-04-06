# Audit: Office Tileset Integration

## Files Changed

Findings were flagged in the following files:

- `tools/sprite_converter.py`
- `firmware/src/renderer.cpp`
- `firmware/src/sprites/tiles.h`
- `firmware/src/sprites/furniture.h`
- `tools/layout_editor.html`

## QA Audit

[FIXED] **Q1** - HIGH - `tools/sprite_converter.py` - Stale `tiles.h` not cleaned up when tileset is unavailable. If a user previously ran the converter with the tileset, then later runs with `--no-tileset` or removes the tileset PNG, the old `tiles.h` persists on disk. The renderer's `__has_include` will still find it, and the firmware uses stale tile sprites that may clash with fallback furniture sprites.

**Q2** - MEDIUM - `firmware/src/renderer.cpp:180-186` - Significant per-pixel rendering overhead for floor tiles. With `HAS_TILESET_TILES`, every tile uses `drawRGB565Sprite` (256 pixel calls per tile). For 200-280 tiles, that's 51,200-71,680 individual pixel draws per frame just for the floor, vs 200-280 `gfxFillRect` calls in the fallback. May drop FPS below 15 on CYD.

**Q3** - MEDIUM - `tools/sprite_converter.py:73-116` - Mixed data types in `TILESET_TILE_MAP` (lists vs dicts) with naming convention (`TILE_` prefix) as the only discriminator. A misnaming would cause a `TypeError`/`KeyError` at runtime.

**Q4** - LOW - `firmware/src/sprites/furniture.h` - `SPRITE_PC`, `SPRITE_LAMP`, `SPRITE_WHITEBOARD` generated but never referenced in firmware. ~2KB wasted flash.

**Q5** - LOW - `firmware/src/renderer.cpp:180-186` - Floor tile transparent pixels (0x0000) would show as black holes. Current tiles have no transparent pixels, but a different tileset could.

**Q6** - LOW - `tools/layout_editor.html:1022-1051` - Generated code has redundant wall row initialization.

## Security Audit

**S1** - LOW - `tools/layout_editor.html:930-935` - JSON import accepts unvalidated grid dimensions and tile data. Local-only dev tool.

**S2** - LOW - `tools/layout_editor.html:932` - Imported `board` value not validated against known board set.

**S3** - LOW - `tools/sprite_converter.py:136-138` - No validation of tileset image dimensions before crop. Failure mode is a build error, not runtime.

[FIXED] **S4** - MEDIUM - `tools/sprite_converter.py:1665` - `TILESET_PATH.relative_to(PROJECT_ROOT)` could raise unhandled `ValueError` if paths diverge due to symlinks.

## Interface Contract Audit

**I1** - MEDIUM - `tools/layout_editor.html:201` / `tools/layout_editor.html:110` - Plant footprint mismatch: editor catalog says 1x1 but tileset sprite is 1x2. Character could walk through bottom half of plant.

**I2** - MEDIUM - `tools/sprite_converter.py` - Fallback plant (16x24) and cooler (16x24) dimensions differ from tileset versions (16x32). Renderer placement doesn't account for height difference.

**I3** - LOW - `firmware/src/renderer.cpp:6-8` / `firmware/src/sprites/tiles.h` - No runtime detection of stale tiles.h. Build-time only.

**I4** - LOW - `tools/sprite_converter.py:1666-1669` - Global state mutation in main() could cause issues if execution model changes.

**I5** - LOW - `tools/layout_editor.html:286-298` - Layout editor tileset furniture Y-offset calculation diverges from renderer's approach.

**I6** - LOW - `tools/sprite_converter.py:73-116` - TILESET_TILE_MAP uses two different data formats without a unifying type.

## State Management Audit

**M1** - MEDIUM - `tools/sprite_converter.py:1651,1669` - In-place mutation of module-level `FURNITURE_SPRITES` global dict. Works for single-pass execution but fragile.

**M2** - LOW - `tools/sprite_converter.py:1666-1669` - Partial overwrite of `FURNITURE_SPRITES` without logging which sprites were replaced.

**M3** - LOW - `firmware/src/renderer.cpp:180-194` - Compile-time feature flag creates two distinct rendering paths with no runtime toggle.

**M4** - LOW - `tools/layout_editor.html` / `tools/sprite_converter.py` - Duplicated tileset coordinate mappings between files.

**M5** - LOW - `tools/layout_editor.html:504` / `firmware/src/renderer.cpp:184` - Floor checkerboard alternation logic duplicated.

## Resource & Concurrency Audit

[FIXED] **R1** - LOW - `tools/sprite_converter.py:125` - PIL Image file handle not explicitly closed.

**R2** - LOW - `firmware/src/sprites/tiles.h` - PROGMEM arrays accessed without `pgm_read_word()`. Safe on ESP32 (memory-mapped flash).

**R3** - LOW - `firmware/src/renderer.cpp:175-197` - Increased per-frame workload from pixel-level tile rendering (same as Q2).

**R4** - LOW - `firmware/src/renderer.cpp:6-8` - `__has_include` guard noted as sound.

## Testing Coverage Audit

[FIXED] **T1** - MEDIUM - `tools/sprite_converter.py:1403-1427` - No validation that extracted tile data is exactly 256 entries before writing hardcoded `[256]` array size.

**T2** - MEDIUM - `tools/sprite_converter.py:1447` - Validation HTML does not include floor/wall tiles from tiles.h.

**T3** - LOW - `firmware/src/renderer.cpp:180-194` - Two conditional compilation branches cannot both be tested in a single build.

[FIXED] **T4** - MEDIUM - `tools/sprite_converter.py:1650-1715` - Stale tiles.h not cleaned by `--no-tileset` (same as Q1).

**T5** - LOW - `tools/layout_editor.html` - No checklist item for cross-tool checkerboard pattern consistency.

**T6** - HIGH - `tools/sprite_converter.py` - No automated tests for tileset extraction functions. These are pure functions amenable to unit testing.

**T7** - LOW - `firmware/src/renderer.cpp:175-197` - No specific performance checklist item for tileset vs flat-color rendering.

**T8** - MEDIUM - `firmware/src/renderer.cpp:6-8` - No build verification checklist item for both compilation paths across both board targets.

## DX & Maintainability Audit

[FIXED] **D1** - MEDIUM - `tools/sprite_converter.py:1434` - Dead code: `_palette_to_css_colors()` function defined but never called.

**D2** - MEDIUM - `tools/sprite_converter.py:1447,1237` - Functions exceeding ~50 lines (`generate_validation_html` ~196 lines, `generate_characters_header` ~94 lines).

[FIXED] **D3** - MEDIUM - `tools/sprite_converter.py` / `tools/layout_editor.html` - Duplicated tileset coordinate definitions without cross-reference comments.

**D4** - LOW - `firmware/src/sprites/furniture.h` - Unused sprite exports (`SPRITE_PC`, `SPRITE_LAMP`, `SPRITE_WHITEBOARD`).

[FIXED] **D5** - LOW - `firmware/src/renderer.cpp:6-8` - Missing `// WHY:` comment on `__has_include` conditional.

**D6** - LOW - `firmware/src/renderer.cpp:371-487` - `drawStatusBar()` at 116 lines (pre-existing).

**D7** - LOW - `tools/sprite_converter.py:186-204` - Lossy RGB565 round-trip via hex intermediate without explanation.

**D8** - LOW - `tools/layout_editor.html:288` - Comment direction inverted for `yOffsetTiles` calculation.

**D9** - LOW - `tools/layout_editor.html` - `render()` and `generateOfficeStateCode()` exceed ~50 lines.
