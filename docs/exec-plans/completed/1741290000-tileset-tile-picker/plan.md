# Plan: Tileset Tile Picker in Layout Editor

## Objective

Build an interactive modal tile picker overlay in `tools/layout_editor.html` that lets users visually select the correct tileset graphic for each furniture/tile type, replacing manual coordinate guessing. The picker displays the full tileset PNG at 4x scale with a grid overlay, a selection cursor matching the item's tile dimensions, and exports coordinate configs for both Python and JS.

## Changes

### `tools/layout_editor.html`

**HTML:**
- Add "Tile Picker" button in header bar (after Export JSON)
- Add modal overlay `#tilePickerModal` with:
  - Left sidebar: clickable item list with preview thumbnails (Floor A/B, Wall, Desk, Chair, Plant, Bookshelf, Cooler)
  - Main area: tileset PNG at 4x scale on a canvas with grid overlay
  - Bottom bar: hover coordinate display, live preview box, "Copy Config" and "Close" buttons

**CSS:**
- `.tp-modal` -- fixed full-screen overlay with dark backdrop
- `.tp-content` -- centered modal container with header/body layout
- `.tp-sidebar` -- item list with active state highlighting
- `.tp-item` -- clickable item rows with preview canvas thumbnails
- `.tp-preview-bar` -- bottom bar with hover preview

**JS (new functions):**
- `openTilePicker()` -- shows modal, loads tileset if needed, initializes item list
- `closeTilePicker()` -- hides modal, re-renders layout with updated selections
- `buildPickerItemList()` -- generates item list DOM with preview thumbnails
- `drawItemPreview()` -- renders current tile selection into a small canvas
- `selectPickerItem(key)` -- sets active item, updates cursor size
- `renderTilesetCanvas()` -- draws tileset at 4x with grid, highlights all assigned tiles, draws hover cursor
- `tpScreenToTile(e)` -- converts mouse position to tile grid coordinates
- `handleTilesetHover` (mousemove) -- updates hover cursor and live preview
- `handleTilesetClick` (click) -- confirms selection, updates TILESET_TILES/TILESET_FURN
- `updateHoverPreview()` -- renders hovered region at larger scale in preview box
- `exportTileConfig()` -- generates Python TILESET_TILE_MAP and JS TILESET_TILES/TILESET_FURN text

**JS (new state):**
- `TILE_PICKER_ITEMS` array defining all pickable items with key, label, cols, rows, target
- `tpActiveItem` -- currently selected picker item key
- `tpHoverCol`, `tpHoverRow` -- current hover position on tileset grid

## Dependencies

- Requires tileset PNG to be loadable (same path as existing tileset loading)
- Modifies `TILESET_TILES` and `TILESET_FURN` objects in-place (they're `const` but property assignment works)

## Risks / Open Questions

- Tileset must be served via HTTP (not file://) due to CORS -- same constraint as existing tileset loading
- If tileset fails to load, picker button does nothing (graceful degradation)
- Plant has 1x1 footprint in FURN_CATALOG but 1x2 in tileset -- picker uses tileset dimensions which is correct
