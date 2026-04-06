# Product Sense

User personas and product principles for Pixel Agents ESP32.

---

## User Profile

**Primary user:** Developer who uses AI coding assistants (Claude Code, Codex CLI, Gemini CLI, Cursor) daily and wants a physical, ambient display of their agent activity.

**Priorities:**
1. Delight — the display should spark joy, not just inform
2. Zero friction — plug in, run companion, forget about it
3. Ambient awareness — glanceable info without demanding attention
4. Customization — dog color, sound, display mode, but always optional

**Expertise:** Comfortable with CLI tools, serial ports, and flashing firmware. Not necessarily an embedded systems expert.

---

## Product Principles

### 1. Ambient awareness over active monitoring
The device sits on a desk and provides a gentle sense of what your agents are doing. It should never demand attention or interrupt flow. Animations are subtle. Sound effects are brief and toggleable.

### 2. Delight through pixel art
The retro pixel art aesthetic is the core of the product identity. Every visual decision should reinforce this — no modern UI chrome, no gradients, no transparency effects on the ESP32. The office scene should feel like a tiny world.

### 3. Zero-config by default
The device should work out of the box with sensible defaults. Dog is on (tan), sound depends on hardware (on for CYD-S3, off for CYD's weaker DAC), overview status mode. Every setting is optional.

### 4. Hardware as art
The physical device is part of the experience. The CYD's compact form factor, the retro display, the tiny speaker — these are features, not limitations. Design for the hardware, not despite it.

### 5. Respect human attention
Never show notifications that require action. Never play sounds that can't be silenced. Never display text that needs reading during focus time. The display is for peripheral vision.

### 6. Support multiple workflows
Some users have one agent at a time. Some run 6+ across multiple CLIs. The display should gracefully handle 0 to 18 agents without mode changes or manual intervention.

### 7. External input is untrusted
Transcript formats, rate limit caches, and OAuth tokens may change without notice. The system should gracefully degrade (show "Loading...", skip unrecognized records) rather than crash or show incorrect data.
