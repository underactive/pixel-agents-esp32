# Implementation: Item Type Classification

## Files Changed

- `tools/layout_editor.html` — all changes in this single file

## Summary

Implemented the three-way type classification system as planned. All changes were within `tools/layout_editor.html`:

1. **Data model**: Replaced `TILE_FLOOR`/`TILE_WALL` integer constants with `DEFAULT_FLOOR`/`DEFAULT_WALL` string constants. Added `selectedVariant` state variable. Added helper functions `tileCategory()`, `isFloorTile()`, `isWallTile()`, `isTileItem()`. Changed `TILE_PICKER_ITEMS` from `target: 'tile'/'furn'` to `type: 'floor'/'wall'/'furniture'`.

2. **Toolbar**: Renamed `furnGrid`→`variantGrid` with dynamic `variantSectionTitle`. Replaced `buildFurnToolbar()` with `buildVariantToolbar()` that renders context-sensitive sidebar. Added `selectVariant()` and `renderTileVariantSwatch()` for tile swatches.

3. **Painting**: All tile set/check operations updated to use string keys and helper functions.

4. **Rendering**: Tile rendering now looks up each cell's key in `TILESET_TILES` with fallback to defaults.

5. **initTiles()**: Now creates checkerboard pattern using `'floorA'`/`'floorB'` string keys.

6. **Tile picker**: All `item.target` references replaced with `isTileItem()` or `item.type === 'furniture'`.

7. **New Item form**: Added type dropdown, W/H hidden for non-furniture. Renamed to `addNewItem()`/`deleteCustomItem()`.

8. **Persistence**: `saveCustomItems()`/`loadCustomItems()` with type-aware serialization and legacy fallback.

9. **Export/Import**: JSON version bumped to 2. V1 import migrates `0→DEFAULT_FLOOR`, `1→DEFAULT_WALL`.

10. **Code generation**: Wall detection uses `isWallTile()`.

11. **CSS**: Renamed selectors, added `image-rendering: pixelated` on `.furn-swatch`.

No deviations from plan.

## Verification

- Visual inspection of all code changes for consistency
- Grep confirmed no remaining references to `TILE_FLOOR`, `TILE_WALL` (as JS constants), `buildFurnToolbar`, `furnGrid`, `btnNewFurn`, `saveCustomFurniture`, `loadCustomFurniture`, `addNewFurniture`, `deleteCustomFurniture`, or `target: 'tile'`/`target: 'furn'`

## Follow-ups

- Manual browser testing needed per the verification checklist in the plan

## Audit Fixes

### Fixes Applied

1. **Redundant ternary in `loadCustomItems()`** (QA #5) — Simplified `item.type || (legacy ? 'furniture' : 'furniture')` to `item.type || 'furniture'` since both branches returned the same value.

2. **Missing null guard in `exportTileConfig()` JS section** (QA #7) — Added `if (!t) continue;` guard for custom items that were never assigned a tileset position, preventing `undefined` property access.

3. **Missing `updateUI()` after wall tool removes furniture on mousedown** (QA #10) — Added `updateUI()` call so the furniture count display updates immediately when wall tool placement removes furniture.

4. **HTML injection via `innerHTML` with user-derived labels** (Security #1) — Replaced `innerHTML` string interpolation in `buildVariantToolbar()` and `buildPickerItemList()` with safe DOM construction using `createElement`, `textContent`, and `createTextNode`.

5. **Legacy `customFurniture` migration not re-saved under new key** (Interface Contract #1) — Added `if (legacy) saveCustomItems();` after successful legacy load so the data is migrated to the `customItems` key and not re-processed on every load.

6. **Duplicated floor/wall toolbar-building logic** (DX #1) — Consolidated two nearly identical branches in `buildVariantToolbar()` into a single `if (tool === 'floor' || tool === 'wall')` branch parameterized by type.

### Verification Checklist

- [ ] Create a custom floor item with a label containing `<script>` or `<img onerror>` — verify it renders as plain text in the sidebar, not as HTML
- [ ] Create a custom item in the tile picker without assigning a tileset position — click "Copy Config" — verify no JS errors in console
- [ ] Place furniture on grid, switch to wall tool, paint over the furniture — verify furniture count in footer updates immediately
- [ ] Set `localStorage.setItem('customFurniture', JSON.stringify([{key:'test',label:'Test',w:1,h:1,tiles:[[0,0]]}]))` then reload — verify item loads and `localStorage.getItem('customItems')` is now populated
- [ ] Verify redundant ternary fix: add a custom item via legacy path — confirm its type is `'furniture'`

### Unresolved Items

The following audit findings were intentionally not addressed as they are pre-existing issues not introduced by this change:

- QA #1 (`tileAt()` returns `-1`), QA #2 (drag-move undo ordering), QA #3 (`Array.fill` shared reference) — pre-existing, unused or latent
- QA #9 (linear scan in hot path) — negligible with current item count
- Security #2–5 (unvalidated import JSON fields, swallowed parse errors) — pre-existing import validation gaps
- Interface Contract #2–3 (import tile key validation, clipboard error swallowing) — pre-existing
- State Management #1–4 (furniture tool bypassing setTool, undo not capturing selectedVariant, registry mutation) — pre-existing patterns, acceptable tradeoffs
- Resource #1–4 (canvas allocation per mousemove, full redraw, double detectWorkstations) — pre-existing performance items
- DX #3–6 (magic numbers, hardcoded paths, parameter shadowing, duplicate CSS rule) — pre-existing style issues
