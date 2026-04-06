# Planning Framework

When and how to create execution plans for Pixel Agents ESP32 development.

---

## When to Create a Plan

Create a formal plan when the work:
- Touches **3+ domains** (see [ARCHITECTURE.md](../ARCHITECTURE.md) § Domains)
- Requires **multiple dependent steps** with ordering constraints
- Involves **architectural choices** with trade-offs
- Will span **multiple sessions** and needs continuity
- Changes the **protocol, transport layer, or companion interfaces**

Skip planning for: single-file fixes, typo corrections, simple renames, documentation-only changes.

---

## Plan Lifecycle

```
1. Plan    →  docs/exec-plans/active/{epoch}-{name}/plan.md
2. Implement  →  docs/exec-plans/active/{epoch}-{name}/implementation.md
3. Audit      →  docs/exec-plans/active/{epoch}-{name}/audit.md
4. Fix        →  Apply HIGH/CRITICAL audit fixes, update implementation.md
5. Complete   →  Move directory to docs/exec-plans/completed/
```

### Directory Naming

`{epoch}-{plan_name}` where:
- `{epoch}` is the Unix timestamp at the time of writing
- `{plan_name}` is a short kebab-case description (e.g., `1709142000-add-user-auth`)

The epoch prefix ensures chronological ordering — newer plans visibly supersede earlier ones.

---

## Plan Template (`plan.md`)

```markdown
# Plan: {Title}

## Objective
What is being implemented and why.

## Changes
Files to modify/create, with descriptions of each change.

## Dependencies
Prerequisites or ordering constraints between changes.

## Risks / Open Questions
Anything flagged during planning that needs attention.
```

## Implementation Record Template (`implementation.md`)

```markdown
# Implementation: {Title}

## Files Changed
- `path/to/file.ext` — Description of change

*(This section is **required** — it serves as a lightweight index for future planning.)*

## Summary
What was actually implemented, noting any deviations from the plan.

## Verification
Steps taken to verify (builds, tests, manual checks).

## Follow-ups
Remaining work, known limitations, or future improvements.
```

## Audit Report Template (`audit.md`)

Run 7 audit subagents in parallel per [docs/references/audit-checklist.md](references/audit-checklist.md):
1. QA
2. Security
3. Interface Contract
4. State Management
5. Resource & Concurrency
6. Testing Coverage
7. DX & Maintainability

Write consolidated findings to `audit.md` in the plan directory. See the audit checklist for full scope, output format, and post-audit fix process.

---

## Before Planning

Check `docs/exec-plans/completed/` for prior plans that touched the same areas. Scan the **Files changed** lists in `implementation.md` and `audit.md` files to find relevant plans without reading every file — then read the full `plan.md` only for matches.

---

## Completed Plans

| Plan | Goal |
|------|------|
| `1741222000-pixel-agents-esp32` | Initial project: firmware, companion, sprite system |
| `1741290000-tileset-tile-picker` | Office tileset integration with tile picker tool |
| `1741369200-update-dog-sprites` | Replace hand-drawn dog sprites with pixel art |
| `1741427200-companion-launcher` | Auto-venv companion launcher script |
| `1741619100-fix-agent-id-rejection` | Fix agent IDs >= 6 silently rejected |
| `1741718400-sound-extensibility-refactor` | Table-driven sound system with multiple clips |
| `1742536800-software-display` | Software Display mode in macOS companion |
| `1772836592-office-tileset-integration` | Extract tiles from PNG spritesheet for floor/wall |
| `1772845506-item-type-classification` | Classify sprite items by type |
| `1772869782-always-visible-characters` | All 6 characters idle at boot in social zones |
| `1772928000-french-bulldog-pet` | Animated French Bulldog with WANDER/FOLLOW/NAP FSM |
| `1772932904-hamburger-menu-dog-colors` | Touch menu + 4 dog color variants |
| `1772932955-cyd-rgb-led-ambient` | PWM RGB LED ambient indicator |
| `1772943173-screenshot-capture` | Serial screenshot capture (BMP/PNG) |
| `1772946447-boot-splash-screen` | Animated boot splash with character walk-down |
| `1772952748-ble-transport` | BLE NUS transport with ring buffer |
| `1772996846-ble-pin-pairing` | 4-digit PIN for multi-device BLE selection |
| `1773000879-idle-screensaver-activities` | Random activities when no agents active |
| `1773002288-web-ota-firmware-update` | Browser-based firmware flasher (Web Serial) |
| `1773017718-thermal-management` | Junction temperature monitoring and throttling |
| `1773031949-strip-buffer-fallback` | Strip-buffer rendering for no-PSRAM CYD |
| `1773033981-flip-screen` | 180° display rotation toggle |
| `1773076943-macos-companion-app` | Native macOS menu bar companion (Swift/SwiftUI) |
| `1773177809-simplify-agent-list-ui` | Black source icons, hide offline agents |
| `1773196489-codex-cli-support` | OpenAI Codex CLI transcript watching |
| `1773267785-fix-codex-state-derivation` | Fix Codex snake_case JSONL format support |
| `1773272540-cyd-sound-support` | CYD audio via ESP32 internal DAC |
| `1773298152-mic-loopback-poc` | Microphone loopback proof-of-concept |
| `1773598133-battery-transport-icons` | Battery indicator + USB/BT transport icons |
| `1773600114-ble-battery-service` | BLE Battery Service for native macOS display |
| `1774284078-remote-device-settings` | Remote device settings over serial/BLE |
| `1774383082-optimize-macos-cpu` | FSEvents-driven processing to fix high CPU |
| `1774392696-tabbed-usage-stats` | Tabbed usage stats UI reorganization |
| `1774405872-cursor-heatmap` | Cursor IDE activity heatmap |
| `1774415763-activity-heatmaps` | Claude/Codex/Gemini activity heatmaps (SQLite) |
| `1774447959-icloud-activity-sync` | iCloud Drive sync for heatmap data |
| `1774493503-device-fingerprinting` | MSG_IDENTIFY protocol for device verification |
| `1774501488-agent-list-brand-icons` | Provider brand icons in agent list |
