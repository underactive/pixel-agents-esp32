# Plan: Item Type Classification (Floor/Wall/Furniture)

## Objective

Replace the two-way item classification (`target: 'tile'` / `target: 'furn'`) with a three-way `type` classification — **floor**, **wall**, **furniture** — so that custom items can be any type, the toolbar sidebar is context-sensitive (showing floor/wall variants when those tools are active), and the tile grid stores string keys instead of integers.

## Changes

### File: `tools/layout_editor.html`

1. **Data model** — Replace `TILE_FLOOR=0`/`TILE_WALL=1` constants with `DEFAULT_FLOOR='floorA'`/`DEFAULT_WALL='wall'` string keys. `tiles[row][col]` stores string keys. Replace `target` field on `TILE_PICKER_ITEMS` with `type` ('floor'/'wall'/'furniture'). Add `selectedVariant` state variable and helper functions (`tileCategory`, `isFloorTile`, `isWallTile`, `isTileItem`).

2. **Toolbar UI** — Rename `furnGrid`→`variantGrid`, add `variantSectionTitle`. Replace `buildFurnToolbar()` with `buildVariantToolbar()` that shows floor/wall variants or furniture depending on active tool. Add `selectVariant()` and `renderTileVariantSwatch()`.

3. **Painting behavior** — All tile assignments use `selectedVariant || DEFAULT_FLOOR/DEFAULT_WALL`. All tile type checks use `isFloorTile()`/`isWallTile()`.

4. **Rendering** — Look up tile key from grid, resolve via `TILESET_TILES[key]` with fallback.

5. **Tile picker** — Replace `item.target` checks with `isTileItem(item)` / `item.type === 'furniture'`.

6. **New Item form** — Add type dropdown, hide W/H for floor/wall. Rename functions to `addNewItem`/`deleteCustomItem`/`saveCustomItems`/`loadCustomItems`.

7. **Persistence** — New localStorage key `customItems` with type field; legacy `customFurniture` fallback.

8. **Export/Import** — JSON version bumped to 2; v1 import auto-migrates integer tiles.

9. **Code generation** — `isWallTile()` used in wall detection logic.

10. **CSS** — Rename selectors, add `.furn-swatch { image-rendering: pixelated }` for tile swatches.

## Dependencies

None — all changes within a single file.

## Risks / Open Questions

- localStorage migration: existing `customFurniture` data gracefully handled via fallback
- JSON v1 import: integer→string migration is straightforward but one-way
