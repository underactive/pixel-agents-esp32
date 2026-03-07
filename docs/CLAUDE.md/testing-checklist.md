# Testing Checklist

## Pre-Hardware (Desktop Verification)

### Sprite Converter
- [ ] Run `python3 tools/sprite_converter.py` — generates all 5 output files without errors (includes tiles.h when tileset present)
- [ ] Run `python3 tools/sprite_converter.py --no-tileset` — generates 4 files without tiles.h, removes stale tiles.h if present
- [ ] Open `tools/sprite_validation.html` in browser — all sprites render correctly at 4x zoom
- [ ] Characters have distinct palettes (6 color sets visible)
- [ ] Walk frames show progressive leg/arm motion
- [ ] Type/Read frames show distinct poses
- [ ] Furniture sprites are recognizable (desk, chair, plant, bookshelf, cooler)
- [ ] Bubble sprites show "?" (permission) and "..." (waiting) icons

### Layout Editor
- [ ] Open `tools/layout_editor.html` in browser (via HTTP server) — tileset artwork renders for floor, walls, and furniture
- [ ] Open `tools/layout_editor.html` without tileset image — falls back to colored rectangles
- [ ] Tileset tiles render crisp (no anti-aliasing blur) at scaled sizes

### Tile Picker
- [ ] Click "Tile Picker" button — modal opens showing tileset at 4x scale with grid overlay
- [ ] Item list shows 8 items (Floor A/B, Wall, Desk, Chair, Plant, Bookshelf, Cooler) with preview thumbnails
- [ ] Clicking an item highlights it and changes the hover cursor size to match (e.g., 2x2 for Desk)
- [ ] Hover cursor snaps to tile grid and does not extend beyond tileset edges for multi-tile items
- [ ] Clicking on tileset updates the item's tile coordinates and refreshes its preview thumbnail
- [ ] "Copy Config" copies Python and JS coordinate config to clipboard (or logs to console if clipboard unavailable)
- [ ] Closing the modal re-renders the layout editor with updated tileset selections
- [ ] Escape key closes the modal without affecting the layout editor's own Escape behavior

### Item Type Classification
- [ ] Default layout shows checkerboard floor pattern (floorA/floorB alternating)
- [ ] Click "Floor" tool — sidebar shows "Floor Variants" with Floor A, Floor B items
- [ ] Select a floor variant — paint on grid places only that variant (no auto-checkerboard)
- [ ] Click "Wall" tool — sidebar shows "Wall Variants" with Wall item
- [ ] Click "Select" or pick furniture — sidebar reverts to "Furniture" list
- [ ] Footer text includes variant name when floor/wall tool is active (e.g., "Floor (Floor A)")
- [ ] Tile Picker "New Item" form shows type dropdown (Furniture/Floor/Wall)
- [ ] Selecting "Floor" or "Wall" type hides W/H dimension inputs
- [ ] Create custom floor item — appears in Floor Variants sidebar when Floor tool active
- [ ] Assign tileset graphic to custom floor item — paint with it on grid
- [ ] Delete custom floor/wall item — grid tiles revert to default, item removed from sidebar
- [ ] Create custom wall variant — appears in Wall Variants when Wall tool active
- [ ] Export JSON produces version 2 with string tile keys
- [ ] Import a v1 JSON (integer tiles) — auto-migrated to string keys
- [ ] Page reload — custom items persist from localStorage

### Companion Script
- [ ] `python3 companion/pixel_agents_bridge.py --help` — shows usage
- [ ] Without ESP32: prints "No ESP32 serial port found." and retries
- [ ] With `--port /dev/null`: fails gracefully with serial error message
- [ ] Ctrl+C: exits cleanly with "Shutting down."

### Protocol Consistency
- [ ] Protocol constants match: firmware config.h SYNC/MSG values == companion constants
- [ ] CharState enum values (0-6) match companion STATE_* constants (0-6)
- [ ] Agent update message format: companion build_agent_update() matches firmware dispatch()

## Hardware Testing (Requires LILYGO T-Display S3)

### Build Verification
- [ ] Both board targets build with tiles.h present (tileset mode)
- [ ] Both board targets build without tiles.h (fallback mode)

### Display Bootstrap
- [ ] Upload firmware via PlatformIO — compiles and uploads without errors
- [ ] Splash screen appears: "Pixel Agents" title, connection instructions
- [ ] Screen orientation is landscape (320x170)
- [ ] Backlight is on

### Idle Scene (No Companion Connected)
- [ ] Status bar shows red dot + "Disconnected"
- [ ] Status bar shows "0/6 active"
- [ ] All 6 characters visible wandering in social zones
- [ ] Floor tiles render with checkerboard pattern
- [ ] Wall row (top) renders in different shade
- [ ] Furniture visible: desks (2x2), chairs, plant, bookshelf, cooler (tileset artwork when generated with tileset)
- [ ] Floor tiles render with tileset artwork (wood panel checkerboard) when tiles.h is present
- [ ] Wall tiles render with tileset artwork when tiles.h is present
- [ ] Floor/wall fall back to solid colors when built without tiles.h

### Always-Visible Characters
- [ ] On boot, all 6 characters appear in social zones (3 in break room, 3 in library)
- [ ] Idle characters wander within their assigned social zone (not across the full map)
- [ ] Status bar OVERVIEW shows "N/6 active" format (e.g., "2/6 active")
- [ ] Starting a Claude Code session causes an idle character to walk to a desk
- [ ] Ending a Claude Code session causes the character to walk back to its social zone
- [ ] Agent going offline (disconnect) causes character to walk back to zone (not despawn)
- [ ] Re-activating an agent while character walks back to zone redirects character to desk
- [ ] All 6 agents active simultaneously -- all 6 characters seated at desks
- [ ] All 6 agents go idle -- all 6 characters walk back to their zones

### Connected Scene (Companion Running)
- [ ] Status bar shows green dot when companion sends heartbeats
- [ ] Agent count updates as Claude Code sessions start/stop
- [ ] Characters walk smoothly between tiles (4-frame animation)
- [ ] Characters sit at desks when typing/reading
- [ ] Sitting offset visually places character on chair
- [ ] LEFT-facing characters are horizontal flips (not separate sprites)
- [ ] Speech bubbles appear above characters for permission/waiting states
- [ ] Multiple characters depth-sort correctly (lower Y = further back)

### Stress Testing
- [ ] 6 agents simultaneously — all render, no crashes
- [ ] Rapid state changes (TYPE→IDLE→TYPE) — smooth transitions
- [ ] Serial disconnect/reconnect — status changes to red, recovers on reconnect
- [ ] Long-running session (1+ hour) — no memory leaks, stable FPS

### Performance
- [ ] Frame rate is smooth (~15 FPS, no visible stuttering)
- [ ] Walk animation is fluid (not jerky)
- [ ] Spawn effect renders progressively (not all-at-once)
