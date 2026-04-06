# Design

Output conventions and UI patterns for Pixel Agents ESP32.

---

## Display

### ESP32 Hardware Display
- **Resolution:** 320x240 pixels (CYD, CYD-S3) or 170x320 (LILYGO)
- **Tile grid:** 16x16 pixel tiles
- **Character size:** 16x24 pixels (full-size), 10x15 pixels (mini-agents at 60% scale)
- **Frame rate:** 15 FPS, double-buffered (PSRAM) or strip-buffered (no PSRAM)
- **Color depth:** RGB565 (16-bit)
- **Rendering order:** Background tiles → furniture → characters (depth-sorted by Y) → dog → status bar → overlays

### Software Display (macOS)
- **Resolution:** 320x224 pixels, rendered to CGImage
- **Window:** NSPanel with nearest-neighbor scaling, aspect-ratio locked
- **Same rendering logic:** Full character FSM, BFS pathfinding, dog AI — just CGImage output instead of TFT sprites

---

## Status Bar

5 display modes, cycled by tapping the status bar area:

1. **OVERVIEW** — Agent count ("N/6 active"), USB/BT connection icon, battery percentage
2. **USAGE_STATS** — Current/weekly usage percentages with color-coded bars
3. **AGENT_LIST** — List of active agents with provider brand icons
4. **PERFORMANCE** — FPS, free heap, temperature (debug)
5. **UPTIME** — Session uptime counter

---

## Touch Interaction

- **Hamburger menu (☰):** Top-left corner tap. Opens overlay with toggles (dog on/off, dog color, flip screen, sound on/off)
- **Status bar tap:** Cycles through 5 display modes
- **Display sleep:** Touch anywhere to wake from sleep mode

---

## Sound Events

5 event-triggered clips, played via I2S:

| Event | Clip | Trigger |
|-------|------|---------|
| Startup | Chime | Boot complete |
| Agent spawn | Notification click | New agent arrives |
| Typing | Keyboard | Agent is typing (tool_use) |
| Permission | Minimal pop | Permission bubble detected |
| Dog bark | Bark | Wake word trigger or dog interaction |

---

## LED Ambient Modes

5 auto-selected modes based on system state:

| Mode | Trigger | Behavior |
|------|---------|----------|
| OFF | No connection | LED off |
| IDLE_BREATHE | Connected, no agents | Slow breathing pulse |
| ACTIVE | 1+ agents active | Steady glow |
| BUSY | 3+ agents active | Brighter steady |
| RATE_LIMITED | Usage > threshold | Red pulse warning |

---

## Visual Principles

- **Pixel art aesthetic:** All characters, furniture, and UI elements use pixel art at native resolution. No anti-aliasing, no subpixel rendering.
- **Ambient display:** The device is meant to sit on a desk and provide ambient awareness, not demand attention. Animations are gentle, not flashy.
- **Information density:** Status bar packs useful info into a small space; display modes let users choose what matters to them.
- **Zero-config default:** Works out of the box with sensible defaults. Dog on, sound on (CYD-S3) or off (CYD), overview mode.
