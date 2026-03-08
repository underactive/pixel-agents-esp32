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
- [ ] Screen orientation is landscape (320x170)
- [ ] Backlight is on

### Boot Splash Screen
- [ ] "PIXEL AGENTS" title appears centered at top of screen in chunky pixel font
- [ ] A character sprite renders at 2x scale (32x64 pixels), centered below the title
- [ ] Character is randomly selected (different character on different boots)
- [ ] Character plays walk-down animation in place (4-frame cycle, ~150ms/frame)
- [ ] Boot log lines appear sequentially in green terminal-style text with ">" prefix
- [ ] Log shows subsystem init messages: "Display initialized", "Office state ready", etc.
- [ ] "Waiting for companion..." appears as last log line before connection
- [ ] Starting companion → "Connected!" appears in the boot log
- [ ] Splash holds for ~3 seconds after "Connected!" while character keeps animating
- [ ] Screen fades to black (backlight dims), then fades back in showing the office scene
- [ ] Office scene renders correctly after fade-in (characters visible, status bar active)
- [ ] CYD: splash layout accommodates taller screen (320x240), more log lines visible
- [ ] Footer text with version string appears centered at bottom of splash screen in gray
- [ ] Requesting screenshot during splash captures splash screen content (title, character, log, footer)
- [ ] Serial messages (heartbeat, agent updates) received during fade transition are not lost

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

### French Bulldog Pet
- [ ] Dog appears on screen after boot, positioned on a walkable floor tile
- [ ] Dog walk animation cycles smoothly (4-frame cycle visible during movement)
- [ ] Dog faces correct direction when moving (down, up, right, left-flip)
- [ ] Dog stands still with standing frame when not walking
- [ ] Dog idle animation cycles through 8 frames smoothly when standing still
- [ ] Dog run animation plays (8-frame cycle, faster movement) occasionally during WANDER walks
- [ ] Dog pee animation displays (single frame, ~3s) occasionally during WANDER idle pauses
- [ ] Dog sit frame renders when sitting near a seated follow target
- [ ] Dog lay down frame renders during NAP behavior (no Z overlay)
- [ ] Dog facing LEFT is a horizontal flip of the RIGHT sprite (no separate LEFT sprites)
- [ ] Dog moving UP/DOWN continues the current walk/run animation frame (no direction-specific sprites)
- [ ] Dog does not display pee frame while following a character (pee only during WANDER)
- [ ] Dog does not run at fast speed during FOLLOW phase (run only during WANDER)
- [ ] Dog depth-sorts correctly with characters (behind higher-Y characters, in front of lower-Y)
- [ ] Dog wanders to random tiles during WANDER phase (2-6s pauses between moves)
- [ ] Dog follows a character during FOLLOW phase (stays within ~5 tiles)
- [ ] Dog does not walk through walls or furniture (respects BFS pathfinding)
- [ ] Dog walks smoothly between tiles (no teleporting or jittering)
- [ ] `python3 tools/convert_dog.py` generates 4 color headers + master `firmware/src/sprites/dog.h` without errors

### Connected Scene (Companion Running)
- [ ] Status bar shows green dot when companion sends heartbeats
- [ ] Agent count updates as Claude Code sessions start/stop
- [ ] Characters walk smoothly between tiles (4-frame animation)
- [ ] Characters sit at desks when typing/reading
- [ ] Sitting offset visually places character on chair
- [ ] LEFT-facing characters are horizontal flips (not separate sprites)
- [ ] Speech bubbles appear above characters for permission/waiting states
- [ ] Multiple characters depth-sort correctly (lower Y = further back)

### Hamburger Menu (CYD Only)
- [ ] Hamburger icon (three white bars) visible in rightmost area of status bar
- [ ] Tap hamburger icon — settings menu opens above status bar
- [ ] Menu shows "Settings" title, "Dog: ON/OFF" toggle, and 4 color swatches
- [ ] Tap "Dog: ON/OFF" row — toggles dog visibility (green ON / red OFF text)
- [ ] Dog disappears immediately when toggled off
- [ ] Dog respawns at random tile when toggled back on
- [ ] Tap color swatch — dog sprite color changes immediately
- [ ] Selected color swatch has green highlight border
- [ ] Color swatches dimmed (dark) when dog is disabled
- [ ] Tapping color swatch while dog disabled has no effect
- [ ] Tap outside menu — menu closes
- [ ] Reboot device — dog enabled/disabled and color persist from NVS
- [ ] LILYGO build compiles without touch/menu code (no hamburger icon, no menu)

### RGB LED Ambient Lighting (CYD Only)
- [ ] LED is off when companion is disconnected
- [ ] LED breathes dim cyan when connected with no active agents (~4s cycle)
- [ ] LED glows steady green with 1-3 active agents (brightness increases with count)
- [ ] LED glows amber/orange with 4+ active agents
- [ ] LED pulses red when usage stats reach 90%+ current usage (~2s cycle)
- [ ] LED transitions smoothly between modes (no flicker on mode change)
- [ ] LED breathe/pulse animation remains smooth after 1+ hour in same mode
- [ ] LILYGO build compiles without LED code (no compilation errors, no LED references)

### Screenshot Capture
- [ ] LILYGO: press 's' in companion terminal — prints "Requesting screenshot..." and "Receiving 320x170 screenshot..."
- [ ] CYD: press 's' in companion terminal — prints "Requesting screenshot..." and "Receiving 320x240 screenshot..."
- [ ] Screenshot BMP/PNG file appears in `companion/screenshots/` with timestamp filename
- [ ] Open saved image — content matches what was on the ESP32 display, colors are correct
- [ ] CYD screenshot colors are correct (no red-blue swap from byte order issues)
- [ ] Take multiple screenshots in succession — no serial errors or desync
- [ ] Companion with stdin not a TTY (e.g., `< /dev/null`) — runs normally without keyboard input, no crash
- [ ] Ctrl+C exits companion cleanly, terminal is restored to normal mode

### BLE Transport (CYD)
- [ ] `python3 companion/pixel_agents_bridge.py --transport ble` — scans for "PixelAgents" device
- [ ] BLE connects to CYD — prints "BLE connected to XX:XX:XX:XX:XX:XX"
- [ ] Status bar shows green dot when companion sends heartbeats over BLE
- [ ] Agent state updates work over BLE (characters walk to desks, sit, return)
- [ ] Usage stats display correctly when received over BLE
- [ ] BLE disconnect — companion prints "BLE disconnected." and rescans
- [ ] BLE reconnect — companion resends full state (agent count, usage stats)
- [ ] Screenshot shortcut ('s') is disabled over BLE with explanatory message
- [ ] Simultaneous serial + BLE — both transports process messages without corruption
- [ ] `--ble-name` flag with wrong name — prints "Device 'WrongName' not found."
- [ ] Boot splash shows "BLE advertising" log line (CYD only)

### BLE PIN Pairing (CYD)
- [ ] CYD boot splash "Waiting for companion..." log line shows "BLE PIN: XXXX" suffix in white text
- [ ] PIN is a 4-digit number (1000-9999)
- [ ] Rebooting CYD generates a different PIN (verify across 3+ reboots)
- [ ] `--transport ble` scan output lists each device with its PIN (e.g., "Found: PixelAgents at XX:XX, PIN=1234")
- [ ] `--ble-pin 1234` connects to the device advertising PIN 1234
- [ ] `--ble-pin 9999` with no matching device prints "No device found with PIN 9999" and retries
- [ ] `--ble-pin 0` or `--ble-pin 99999` — prints error about valid range and exits
- [ ] Interactive mode (no --ble-pin, tty): prompts "Enter PIN from device display:", entering correct PIN connects
- [ ] Interactive mode: entering wrong PIN prints error and does not connect
- [ ] Interactive mode: entering non-numeric input prints "Invalid PIN." and does not connect
- [ ] Non-interactive mode (no --ble-pin, no tty): connects to first NUS device without prompting
- [ ] Two CYDs in range: each shows a different PIN; `--ble-pin` connects to the correct one
- [ ] Screenshot during splash (CYD) captures PIN text in saved image
- [ ] PIN logged to serial output: "[BLE] PIN: XXXX" visible in serial monitor
- [ ] BLE reconnect after disconnect reuses entered PIN without re-prompting

### Companion BLE Script
- [ ] `python3 companion/pixel_agents_bridge.py --transport ble --help` — shows transport/ble-name/ble-pin options
- [ ] Without ESP32 in range: prints scan failure and retries after 2 seconds
- [ ] Ctrl+C exits cleanly, BLE event loop shut down

### Stress Testing
- [ ] 6 agents simultaneously — all render, no crashes
- [ ] Rapid state changes (TYPE→IDLE→TYPE) — smooth transitions
- [ ] Serial disconnect/reconnect — status changes to red, recovers on reconnect
- [ ] Long-running session (1+ hour) — no memory leaks, stable FPS

### Performance
- [ ] Frame rate is smooth (~15 FPS, no visible stuttering)
- [ ] Walk animation is fluid (not jerky)
- [ ] Spawn effect renders progressively (not all-at-once)
