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

### Companion Launcher
- [ ] `python3 run_companion.py --help` — creates venv (if needed), installs deps, shows bridge usage
- [ ] Second run of `python3 run_companion.py --help` — skips venv/pip, launches instantly
- [ ] Run from different cwd (`cd /tmp && python3 /path/to/run_companion.py --help`) — works correctly
- [ ] Edit `companion/requirements.txt` (add comment), run again — re-installs deps
- [ ] Delete `companion/.venv/bin/python`, run again — detects corruption, recreates venv
- [ ] Delete `companion/requirements.txt`, run — prints clear error and exits
- [ ] `python3 run_companion.py --port /dev/cu.usbmodemXXXX` — forwards port arg to bridge

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
- [ ] CYD-S3: startup sound plays once when the splash transitions to the office after first connection
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
- [ ] Start 2 Claude Code sessions, let them be pruned (30s timeout), then start 4+ new sessions — all new agents appear on device (agent ID recycling)
- [ ] After companion reconnects, previously recycled IDs do not cause stale agent state on device

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
- [ ] CYD-S3: dog bark sound plays when a new follow target is selected
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
- [ ] Menu shows "Flip: OFF" as 4th row below color swatches
- [ ] Tap "Flip" row — display rotates 180 degrees immediately, menu closes
- [ ] Tap hamburger, tap "Flip" again — display returns to normal orientation
- [ ] After flip: tap status bar, tap characters, tap hamburger — all touch targets are correct
- [ ] After flip: scene content (characters, furniture, status bar) renders correctly
- [ ] Reboot device with flip ON — display boots in flipped orientation from first frame
- [ ] After flipped boot: touch input works correctly without needing to re-flip
- [ ] Screenshot in flipped mode produces correctly oriented image
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

### Device Fingerprinting
- [ ] Python serial connect prints "Pixel Agents device: CYD, firmware vX.Y.Z, protocol 1" after connecting
- [ ] Python BLE connect prints "Pixel Agents device: CYD-S3, firmware vX.Y.Z, protocol 1" after connecting
- [ ] macOS serial connect logs "[Bridge] Pixel Agents device: CYD..." to Console.app
- [ ] macOS BLE connect logs "[Bridge] Pixel Agents device: CYD-S3..." to Console.app
- [ ] Connect to non-Pixel-Agents ESP32: prints "Device did not identify (may be older firmware)" and proceeds
- [ ] Connect to Pixel Agents device running older firmware (pre-identify): timeout after 2s, proceeds normally
- [ ] Old Python companion (pre-identify) + new firmware: connects and operates normally (no errors from unsolicited identify response)
- [ ] Identify response reports correct board type for each variant (0=CYD, 1=CYD-S3, 2=LILYGO)
- [ ] Identify response reports correct firmware version matching SPLASH_VERSION_STR

### Companion BLE Script
- [ ] `python3 companion/pixel_agents_bridge.py --transport ble --help` — shows transport/ble-name/ble-pin options
- [ ] Without ESP32 in range: prints scan failure and retries after 2 seconds
- [ ] Ctrl+C exits cleanly, BLE event loop shut down

### Idle Activities (Screensaver)
- [ ] Idle characters occasionally leave their home zone to perform activities (~40% of wander triggers)
- [ ] Characters walk to bookshelves (row 8) and play reading animation facing UP
- [ ] Characters walk to coffee maker area (row 3) and stand facing UP
- [ ] Characters walk to water cooler (row 3) and stand facing UP
- [ ] Characters walk to another idle character and stand facing them (socializing)
- [ ] Activities last 4-10 seconds, then character walks back to their home zone
- [ ] No back-to-back activities (at least one normal wander between activities)
- [ ] Status bar AGENT_LIST shows "ACT" for characters performing activities
- [ ] Starting a Claude Code session preempts an active activity (character walks to desk)
- [ ] Multiple characters can perform activities simultaneously without overlap at interaction points
- [ ] Characters face correct direction during activities (UP for furniture, toward target for socializing)

### Codex CLI Support
- [ ] With Codex CLI running: rollout file appears in `~/.codex/sessions/YYYY/MM/DD/` and companion picks it up within 5 seconds
- [ ] Codex agent appears as a separate character on the ESP32 display alongside any Claude Code agents
- [ ] Codex `command_execution` events show the shell command name on the status bar (e.g., "grep", "cat")
- [ ] Codex read commands (cat, grep, find, ls, etc.) display character in READ pose
- [ ] Codex write commands display character in TYPE pose
- [ ] Codex turn completion returns character to IDLE (wander) behavior
- [ ] Running Claude Code and Codex CLI simultaneously shows both as separate characters
- [ ] Stopping Codex CLI session causes character to go idle after 30s prune timeout
- [ ] macOS companion correctly watches both `~/.claude/projects/` and `~/.codex/sessions/`
- [ ] Python companion correctly watches both directories

### Stress Testing
- [ ] 6 agents simultaneously — all render, no crashes
- [ ] Rapid state changes (TYPE→IDLE→TYPE) — smooth transitions
- [ ] Serial disconnect/reconnect — status changes to red, recovers on reconnect
- [ ] Long-running session (1+ hour) — no memory leaks, stable FPS

### Web Firmware Flasher
- [ ] Open `tools/firmware_update.html` in Chrome — page loads, no console errors
- [ ] Open in Firefox/Safari — "Web Serial API not available" warning shown
- [ ] Select CYD board, "Update Firmware Only" mode — hint shows firmware offset 0x10000
- [ ] Select LILYGO board — hint updates to reflect LILYGO offsets
- [ ] Select "Full Flash" mode — hint updates to describe full flash
- [ ] Drag-and-drop a .bin file onto drop zone — file appears in file list with name, size, and address
- [ ] Click drop zone to open file picker — file selection works
- [ ] File auto-assigns correct offset (bootloader.bin → 0x01000 CYD / 0x00000 LILYGO, firmware.bin → 0x10000)
- [ ] Remove file via × button — file removed from list
- [ ] "Start Flash" button disabled when no files selected, enabled when files present
- [ ] Click "Start Flash" — confirmation dialog shows board, mode, file count, baud rate
- [ ] Click "Cancel" on confirmation — returns to file selection
- [ ] Click "Confirm & Flash" — browser serial port picker appears
- [ ] Cancel serial port picker — error shown "Serial port selection was cancelled."
- [ ] Select correct serial port — terminal shows "Connecting to bootloader..." and chip detection
- [ ] Progress bar advances during flash write (0% → 100%)
- [ ] Flash completes — success banner shown, terminal log preserved
- [ ] "Copy Log" button copies timestamped log to clipboard
- [ ] "Flash Another" button resets to initial state
- [ ] Disconnect USB during flash — error state shown with descriptive message
- [ ] "Try Again" on error — returns to initial state
- [ ] Full Flash mode: partitions.bin auto-assigns to 0x08000, boot_app0.bin to 0x0e000
- [ ] Full Flash mode: adding second file with same slot name replaces the first (no duplicates)
- [ ] Switch from Full Flash to Update mode with multiple files loaded — only firmware file kept
- [ ] Switch board after files loaded — displayed offsets update (e.g., bootloader 0x01000 → 0x00000)
- [ ] Drag non-.bin file onto drop zone — file is ignored
- [ ] Select file larger than 16MB — rejected with size error
- [ ] Double-click "Confirm & Flash" rapidly — only one flash operation starts
- [ ] Bootloader not responding — times out after 30s with "hold BOOT" message
- [ ] Full Flash mode with 4 files — progress bar advances smoothly without jumping back
- [ ] Baud rate selector — confirmation summary reflects chosen baud rate

### Strip-Buffer Rendering (CYD Only)
- [ ] CYD boots into strip-buffer mode (serial log shows "[renderer] strip-buffer mode (320x30, 8 strips)")
- [ ] Scene renders correctly with no visible horizontal tearing between strips
- [ ] Characters crossing strip boundaries render without clipping artifacts
- [ ] Speech bubbles above characters near strip edges render completely
- [ ] Status bar renders correctly at bottom of screen
- [ ] Floor tiles and furniture span strip boundaries without misalignment
- [ ] Screenshot capture produces correct image matching on-screen content
- [ ] Spawn/despawn matrix effect renders smoothly across strip boundaries
- [ ] Dog pet renders correctly when crossing strip boundaries
- [ ] FPS is acceptable in strip mode (~15 FPS target)

### Sound Effects (CYD and CYD-S3)
- [ ] Startup sound plays on splash-to-office transition (CYD-S3)
- [ ] Dog bark plays when dog picks new follow target (CYD-S3)
- [ ] Short sound (bark) preempts long sound (startup) if triggered during playback
- [ ] No sound output or crash on LILYGO build (no HAS_SOUND)
- [ ] CYD: startup sound plays through speaker on splash-to-office transition
- [ ] CYD: dog bark plays through speaker when dog picks new follow target
- [ ] CYD: keyboard typing sound plays on agent's first TYPE transition per job
- [ ] CYD: notification click plays when agent finishes turn
- [ ] CYD: pop sound plays when agent is waiting for tool permission
- [ ] CYD: no audible pop/click artifacts when no sound is playing (SC8002B always-on amp)
- [ ] CYD: audio volume is reasonable with SOUND_VOLUME_SHIFT=2 (not too loud/quiet)
- [ ] Sound toggle in hamburger menu shows "Sound: ON/OFF" with green/red indicator
- [ ] CYD: sound defaults to OFF on first boot (no NVS key yet)
- [ ] CYD-S3: sound defaults to ON on first boot (no NVS key yet)
- [ ] Toggling sound OFF suppresses all 5 sound events (startup, bark, keyboard, notification, pop)
- [ ] Toggling sound ON resumes sound playback without reboot
- [ ] Sound toggle setting persists across reboots (NVS)
- [ ] `python3 tools/convert_sound.py assets/sounds/dragon-studio-dog-bark-494308.mp3` generates valid header
- [ ] `python3 tools/convert_sound.py assets/sounds/*.mp3` batch mode generates all headers without error
- [ ] `python3 tools/convert_sound.py -n custom_name assets/sounds/dragon-studio-dog-bark-494308.mp3` produces `custom_name_pcm.h`
- [ ] `python3 tools/convert_sound.py` with no args prints usage and exits non-zero
- [ ] Amp is silent (no pop/hiss) when no sound is playing (CYD-S3)
- [ ] Keyboard typing sound plays on agent's first TYPE transition per job (CYD-S3)
- [ ] Keyboard typing sound does NOT replay on TYPE→READ→TYPE within the same job (CYD-S3)
- [ ] Notification click sound plays when agent finishes turn and goes IDLE (CYD-S3)
- [ ] Pop sound plays when agent is waiting for tool permission approval (CYD-S3)
- [ ] Permission bubble appears above character when companion sends TYPE with "PERMISSION" tool name
- [ ] Permission bubble persists until agent state changes (not timed)
- [ ] Waiting bubble appears above character when agent goes IDLE
- [ ] Python companion detects permission prompt after ~1s of no new JSONL records following tool_use with stop_reason="tool_use"
- [ ] Auto-approved tools (tool_result within <1s) do NOT trigger permission detection

### Wake Word Detection (CYD-S3 Only)
- [ ] Boot log shows "Wake word ready" on CYD-S3
- [ ] Saying "Computer" triggers DOG_BARK sound through speaker
- [ ] Wake word does not trigger when sound is toggled OFF in hamburger menu
- [ ] Cooldown prevents re-trigger within 5 seconds of last detection
- [ ] Wake word detection pauses during sound playback and resumes after
- [ ] No false detection immediately after sound playback ends
- [ ] CYD build compiles without wake word code (no `HAS_WAKEWORD`)
- [ ] LILYGO build compiles without wake word code (no `HAS_WAKEWORD`)
- [ ] Wake word init failure is non-fatal (logs message, device continues normally)
- [ ] Hamburger menu no longer shows "Mic Test" row (removed feature)

### macOS Companion App

#### Settings Window
- [ ] Gear button appears in bottom-left of popover, "Quit" button in bottom-right
- [ ] Clicking gear button opens standalone Settings window and popover remains usable
- [ ] Settings window shows "Launch at Login", "Show Claude usage", "Show Codex usage", and "Check for updates automatically" toggles
- [ ] Launch at Login toggle state matches actual system state (SMAppService)
- [ ] Toggling "Show Claude usage" off hides Claude usage section in popover immediately
- [ ] Toggling "Show Codex usage" off hides Codex usage section in popover immediately
- [ ] Toggling both off hides the entire usage section (no "No usage data" message)
- [ ] Toggle states persist across app quit and relaunch
- [ ] Closing and reopening Settings reuses the same window (not recreated)

#### Auto-Updates (Sparkle)
- [ ] "Check for updates automatically" toggle in Settings reflects Sparkle's `automaticallyChecksForUpdates` state on appear
- [ ] Toggling auto-update on/off persists across app relaunch (Sparkle stores in UserDefaults)
- [ ] "Check for Updates..." in right-click menu opens Sparkle's standard update dialog

#### Right-Click Context Menu
- [ ] Right-clicking menu bar icon shows context menu with "About Pixel Agents", "Check for Updates...", and "Quit"
- [ ] Left-clicking menu bar icon still opens the popover normally
- [ ] "About Pixel Agents" opens About window with app icon, "Pixel Agents" title, version, and GitHub link
- [ ] About window version matches MARKETING_VERSION from project.yml
- [ ] "Quit" in context menu terminates the app cleanly
- [ ] About window reuses same window on re-open (not recreated)

#### Activity Heatmaps (Claude/Codex/Gemini)
- [ ] Claude tab shows orange-colored heatmap grid after tool calls are recorded
- [ ] Codex tab shows blue-colored heatmap grid after tool calls are recorded
- [ ] Gemini tab shows pink-colored heatmap grid after tool calls are recorded
- [ ] Heatmap header shows "Tool Calls" with total count for Claude/Codex/Gemini
- [ ] Cursor tab still shows green "AI Line Edits" heatmap from API (unchanged)
- [ ] Heatmap grid displays 53 weeks × 7 days with month labels and M/W/F day labels
- [ ] Legend shows "Less" → 5 color swatches → "More" in the provider's brand color
- [ ] Stats row shows "Most Active" date, "Current" streak, and "Longest" streak
- [ ] Heatmap data persists across app restarts (loads from SQLite on startup)
- [ ] Activity database file created at ~/Library/Application Support/com.pixelagents.companion/activity.db
- [ ] Gemini text-only responses (tool="Gemini") are NOT counted as tool calls
- [ ] Empty heatmap displays all gray cells with "0" total and "-" for most active day

#### iCloud Activity Sync
- [ ] App logs "iCloud sync enabled" when iCloud is available and entitlement is active
- [ ] App logs "iCloud unavailable" and works normally when iCloud is not signed in
- [ ] Device JSON file appears at ~/Library/Mobile Documents/iCloud~com.pixelagents.companion/Documents/activity-{uuid}.json
- [ ] Second Mac imports first Mac's data and shows merged heatmap after iCloud sync
- [ ] MAX merge strategy: higher count wins (no double-counting across devices)
- [ ] App does not crash when iCloud entitlement is commented out (graceful degradation)

#### Usage Stats
- [ ] Usage stats display as "Usage" header with used percentages by default
- [ ] Tapping the "Usage" header toggles to "Remaining" mode — header changes to "Remaining", percentages show 100 minus used value
- [ ] Bar width matches the displayed percentage in both modes
- [ ] Colors reflect warning level based on used percentage: red when used >= 90%, orange when used >= 70%, green otherwise — regardless of display mode
- [ ] Swap icon (arrow.triangle.swap) appears next to the header text
- [ ] Toggle state persists across app quit and relaunch
- [ ] Reset timer text ("Resets in Xh Xm") unchanged in both modes
- [ ] "No usage data" message displays correctly when no stats available (both modes)

#### Provider Status Monitoring
- [ ] No status banner visible when all provider APIs are operational
- [ ] Yellow dot + incident title appears between provider tabs and detail area during a degraded_performance incident
- [ ] Red dot + incident title appears during a partial_outage or major_outage incident
- [ ] Clicking incident title opens provider status page in default browser
- [ ] Hovering over truncated title shows full incident text in tooltip
- [ ] Clicking X dismisses the banner; switching tabs and back keeps it dismissed
- [ ] A new incident (different ID) shows a new banner even after dismissing the previous one
- [ ] Banner only shows for the currently selected provider tab
- [ ] Status is not checked for unconfigured/unauthenticated providers
- [ ] About window shows "last checked" timestamp per configured provider after GitHub link
- [ ] Network failures during status check are silently skipped (no error UI)

### Status Bar: Transport Icons (all boards)
- [ ] USB icon is visible in status bar left side (green when serial companion connected, dim gray when disconnected)
- [ ] BT icon appears next to USB icon on CYD and CYD-S3 (blue when BLE connected, dim gray when disconnected)
- [ ] BT icon does not appear on LILYGO (no `HAS_BLE`)
- [ ] Disconnecting serial causes USB icon to dim (within 6s heartbeat timeout)
- [ ] Connecting BLE causes BT icon to turn blue
- [ ] Status text content (all 5 modes) does not overlap transport icons on the left or battery/hamburger on the right
- [ ] Tapping status bar still cycles through all 5 modes on CYD/CYD-S3

### Status Bar: Battery Indicator (CYD-S3 + LILYGO)
- [ ] Battery percentage is displayed on the right side of status bar (just left of hamburger on CYD-S3)
- [ ] Battery percentage is green when >50%, yellow when 20-50%, red when <20%
- [ ] Lightning bolt icon appears when USB serial connected and battery voltage >4.1V
- [ ] Lightning bolt disappears when serial disconnects
- [ ] Percentage reading is stable (no rapid flickering) due to EMA smoothing
- [ ] No battery indicator appears on CYD (no `HAS_BATTERY`)

### BLE Battery Service (CYD-S3 over BLE)
- [ ] macOS System Settings → Bluetooth shows battery percentage for connected PixelAgents device
- [ ] macOS companion app shows battery icon and percentage next to connection status when connected via BLE
- [ ] Battery icon uses appropriate SF Symbol (battery.100/75/50/25/0) based on level
- [ ] Battery percentage color: green >50%, yellow 20-50%, red <=20%
- [ ] Battery indicator disappears from companion when connected via serial (not available)
- [ ] Battery indicator disappears from companion on BLE disconnect

### Performance
- [ ] Frame rate is smooth (~15 FPS, no visible stuttering)
- [ ] Walk animation is fluid (not jerky)
- [ ] Spawn effect renders progressively (not all-at-once)
- [ ] Software mode with popover closed: CPU drops to ~1-2% in Activity Monitor (was 20%+)
- [ ] Software mode with popover open: scene renders at smooth 15 FPS, characters animate normally
- [ ] Closing popover and reopening after 10s: characters are in correct positions (no teleporting), immediate frame on open (no stale image flash)
- [ ] PIP window open with popover closed: scene renders at 15 FPS in PIP
- [ ] Closing PIP with popover also closed: CPU drops to background level
- [ ] Starting/stopping a Claude Code session while popover is open: character moves correctly (dirty-frame detection does not suppress legitimate redraws)
- [ ] Speech bubbles ("!" and "...") render correctly (cached attributed strings)
