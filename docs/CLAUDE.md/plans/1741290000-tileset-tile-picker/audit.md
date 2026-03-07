# Audit: Tileset Tile Picker

## Files Changed

- `tools/layout_editor.html`

## QA Audit

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| Q1 | LOW | Silent failure when tileset image fails to load on picker open | [FIXED] |
| Q3 | MEDIUM | Hover preview/highlight draws beyond tileset bounds for multi-tile items | [FIXED] |
| Q4 | MEDIUM | `renderTilesetCanvas` called on every mousemove without dirty check | [FIXED] |
| Q5 | LOW | `navigator.clipboard.writeText` rejection not handled | [FIXED] |
| Q6 | LOW | `exportTileConfig` does not guard against missing keys | [FIXED] |
| Q8 | LOW | Full DOM rebuild of item list on every tileset click | Accepted -- only 8 items |

## State Management Audit

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| SM-1 | LOW | Direct mutation of const objects without centralized update path | Accepted -- standard for standalone tools |
| SM-2 | LOW | Negative coordinate edge case | Already mitigated by bounds check |
| SM-3 | MEDIUM | Parallel dimension definitions in TILE_PICKER_ITEMS vs FURN_CATALOG | Accepted -- intentionally different (tileset sprite dims vs layout footprint) |
| SM-4 | LOW | Stale hover state on picker reopen | [FIXED] |
| SM-5 | MEDIUM | Tile picker changes not in undo/redo system | Accepted -- picker operates on tileset mappings, not layout state |
| SM-6 | MEDIUM | Tile selections lost on JSON export/import | Accepted -- "Copy Config" export exists for this purpose |

## DX & Maintainability Audit

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| DX-1 | LOW | `renderTilesetCanvas` exceeds 50 lines | Accepted -- well-sectioned with comments |
| DX-3 | LOW | Magic numbers for preview box sizing | [FIXED] added comment explaining derivation |
| DX-4 | MEDIUM | `TP_TILE` unused; `16` hardcoded throughout | [FIXED] |
| DX-5 | LOW | Repeated linear scan for active picker item | Accepted -- 8 items, negligible cost |
| DX-6 | LOW | Uncached DOM lookups in mousemove handler | Accepted -- negligible cost for dev tool |
| DX-7 | LOW | `innerHTML` where createElement/textContent would suffice | Accepted -- data is hardcoded, no injection risk |
| DX-8 | LOW | Fragile ternary chain for Python key mapping | [FIXED] |
| DX-9 | MEDIUM | Silent failure on tileset load error | [FIXED] |
| DX-10 | LOW | Missing WHY comment on capture-phase Escape handler | [FIXED] |
| DX-11 | LOW | `TP_TILE` constant is dead code | [FIXED] (now used throughout) |
