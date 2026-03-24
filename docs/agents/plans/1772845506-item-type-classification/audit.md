# Audit: Item Type Classification

## Files Changed

- `tools/layout_editor.html`

---

## QA Audit

1. **[Medium] `tileAt()` returns `-1` (integer) for out-of-bounds but tile system now uses string keys (line 411).** Not currently called by changed code. `tileCategory(-1)` silently returns `'floor'`. Deferred — function is unused.

2. **[Medium] Drag-move undo captures post-move state, not pre-move (lines 826, 834, 866).** Pre-existing bug. `dragMoved` is set `true` before the `if (!dragMoved) pushUndo()` check. Not introduced by this change.

3. **[Medium] `Array.fill([0,0])` shares a single reference across all slots (lines 1754, 1778, 1861).** Latent bug — currently safe because assignments replace entries wholesale. Pre-existing pattern.

4. **[Low] V1 import migration maps all non-wall tiles to `DEFAULT_FLOOR` (loses checkerboard).** Cosmetic only. Acceptable tradeoff for simple migration.

5. **[FIXED] [Low] Redundant ternary in `loadCustomItems()` — both branches return `'furniture'` (line 1775).**

6. **[Low] `tileCategory()` defaults to `'floor'` for unknown keys (line 376).** Safe fallback — render path falls through to `TILESET_TILES[DEFAULT_FLOOR]`. Unknown keys in grid are cosmetic-only.

7. **[FIXED] [Low] `exportTileConfig()` JS section missing guard for undefined `TILESET_TILES` entry (line 1831).**

8. **[Low] New custom floor/wall items default to tileset position (0,0).** UX concern, not functional bug. User must assign a position via the tile picker.

9. **[Low] `render()` called on every `mousemove` during tile painting — `isFloorTile()`/`isWallTile()` adds incremental cost via linear scan.** Pre-existing hot path. Current item count (~8) makes this negligible.

10. **[FIXED] [Low] Missing `updateUI()` after wall tool removes furniture on mousedown (line 787).**

## Security Audit

1. **[FIXED] [Medium] HTML injection via `innerHTML` with user-derived labels in `buildVariantToolbar()` and `buildPickerItemList()`.** Labels from user input and localStorage interpolated into `innerHTML`. Fixed by using `textContent`/`createTextNode` DOM construction.

2. **[Low] Imported JSON `furniture[].type` not validated against `FURN_CATALOG` (lines 1107-1109).** Pre-existing — would cause `TypeError` on unknown type. Not introduced by this change.

3. **[Low] Imported JSON tile array dimensions not validated against `gridRows`/`gridCols`.** Pre-existing — try/catch around import provides partial protection.

4. **[Low] Imported JSON `board` value not validated against `BOARDS`.** Pre-existing.

5. **[Low] `loadCustomItems` silently swallows all parse errors (line 1788).** Pre-existing pattern. Prevents partial corruption from crashing the app.

## Interface Contract Audit

1. **[FIXED] [Medium] Legacy `customFurniture` migration does not re-save under new `customItems` key.** Every load re-processed legacy data. Fixed by calling `saveCustomItems()` after successful legacy load.

2. **[Medium] JSON import (v2) does not validate tile key values against `TILE_PICKER_ITEMS`.** Unknown keys silently treated as floor. Render fallback is safe. Deferred — would require schema validation on import.

3. **[Low] `clipboard.writeText` failure silently swallowed for main copy button (line 1125).** Pre-existing inconsistency with tile config copy button.

## State Management Audit

1. **[Medium] Furniture placement tool bypasses `setTool()`, directly mutating `tool`/`furnType`/`selectedVariant` (lines 989-996).** Pre-existing pattern. The furniture handler correctly nulls `selectedVariant` and updates all relevant DOM state.

2. **[Medium] Undo/redo `snapshot()` does not capture `selectedVariant` or `tool` state (lines 532-534).** Acceptable — `selectedVariant` is UI state (which tool variant is active), not document state. Undo/redo correctly captures tile grid and furniture data.

3. **[Medium] `tileCategory()` falls back to `'floor'` for unknown keys, masking data corruption.** Same as QA #6. Safe fallback for rendering; unknown keys are cosmetic-only.

4. **[Low] `TILESET_TILES`, `TILESET_FURN`, `FURN_CATALOG`, `PICKER_KEY_TO_PYTHON` mutated from multiple locations.** Inherent to the registry pattern. All mutation paths are add/delete item operations that keep registries in sync.

## Resource & Concurrency Audit

1. **[Medium] `updateHoverPreview()` creates a new canvas on every mousemove (lines 1686-1711).** Pre-existing. Browser GCs orphaned canvases. Minor inefficiency.

2. **[Medium] `renderTilesetCanvas()` fully redraws on every mousemove over tile picker.** Pre-existing. Dirty check helps; not a blocking issue for current tileset sizes.

3. **[Low] `render()` calls `detectWorkstations()` twice per frame (once directly, once via `updateExportCode`).** Pre-existing.

4. **[Low] Data URLs in `renderTileVariantSwatch()` not cached between `buildVariantToolbar()` calls.** Not a hot path — only called on tool switch. Acceptable.

## DX & Maintainability Audit

1. **[FIXED] [Medium] Duplicated toolbar-building logic for floor/wall variants.** Consolidated into a single `if (tool === 'floor' || tool === 'wall')` branch parameterized by type.

2. **[FIXED] [Low] Redundant ternary in `loadCustomItems()`.** Simplified to `item.type || 'furniture'`.

3. **[Low] Magic numbers 16/32 as fallback tileset dimensions (lines 1651-1652).** Pre-existing.

4. **[Low] Hardcoded tileset path duplicated (lines 341, 1481).** Pre-existing.

5. **[Low] `drawItemPreview()` parameter `ctx` shadows module-level `ctx`.** Pre-existing. Works correctly due to scoping.

6. **[Info] Duplicate `.tp-item` CSS rule (lines 72, 86).** Pre-existing.

## Testing Coverage Audit

No automated tests exist for this tool (browser-based HTML tool). Manual testing checklist updated in `docs/CLAUDE.md/testing-checklist.md` with 15 new verification items covering all changed behavior.
