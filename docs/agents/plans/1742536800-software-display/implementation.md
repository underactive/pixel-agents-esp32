# Implementation: Software Display Mode + PIP Window

## Files Changed
- `tools/render_office_bg.py` — Created
- `macos/PixelAgents/PixelAgents/Model/OfficeScene.swift` — Created (~830 lines)
- `macos/PixelAgents/PixelAgents/Views/OfficeRenderer.swift` — Created (~310 lines)
- `macos/PixelAgents/PixelAgents/Views/OfficeCanvasView.swift` — Rewritten (simplified to ~17 lines)
- `macos/PixelAgents/PixelAgents/Views/PIPWindowController.swift` — Created (~165 lines)
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — Modified (DisplayMode enum, scene management, PIP)
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift` — Modified (Display Mode picker, layout restructure)
- `macos/PixelAgents/PixelAgents/Views/TransportPicker.swift` — Modified (removed .software case)
- `macos/PixelAgents/PixelAgents/Views/AgentListView.swift` — Modified (dark mode icon fix)
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift` — Modified (header rename)
- `macos/PixelAgents/Makefile` — Modified (sign-install target)
- `macos/PixelAgents/project.yml` — Modified (macOS 14.0 target)
- `macos/PixelAgents/PixelAgents/Resources/*.png` — Created (11 sprite assets)
- `firmware/src/config.h` — Modified (version bump)
- `CLAUDE.md` — Modified (version bump)
- `CHANGELOG.md` — Modified (new entry)
- `docs/CLAUDE.md/version-history.md` — Modified (new row)

## Summary
Implemented a complete software display mode for the macOS companion that renders the same animated pixel-art office as the ESP32 hardware. The architecture uses a shared CGImage frame produced by OfficeRenderer at 15 FPS, consumed by both the menu bar popover and a floating PIP NSPanel window. The office simulation (OfficeScene.swift) is a faithful port of the firmware's OfficeState including BFS pathfinding, character FSM, idle activities, and dog pet AI.

Key architectural decisions:
- Separated DisplayMode (hardware/software) from TransportMode (USB/Bluetooth)
- Single rendering pipeline: BridgeService owns the scene timer, renderer produces one CGImage per frame
- NSPanel (not SwiftUI Window) for PIP to avoid LSUIElement/MenuBarExtra lifecycle conflicts
- Pre-rendered office background PNG from firmware tile data (avoids shipping tileset or parsing at runtime)

## Verification
- `make clean && make build` — compiles without errors or warnings
- Software mode renders office scene in menu bar popover
- PIP window opens/closes via overlay button, floats above other windows
- Characters walk to desks when agents are typing, return to social zones when idle
- Dog wanders, follows characters, naps
- Display Mode picker hidden when hardware transport connected

## Audit Fixes

### Fixes applied
1. Fixed PIP `windowWillClose` not stopping scene timer — added `bridge?.sceneTimerNeedsUpdate()` call (addresses State-S1, IC-8)
2. Fixed stale `lastAppliedStates` dedup cache on mode/session reset — added `resetAppliedStates()` to OfficeScene, called from `resetSessionState()` (addresses State-S4, IC-4)
3. Fixed `SpriteCache.characterFrame` division by zero if no character sheets loaded — added `guard !charSheets.isEmpty` (addresses Q2)
4. Fixed `isInteractionPointFree` unguarded path index — added `pathLen <= path.count` bounds check (addresses S1)
5. Fixed silent `CGContext` allocation failure — added NSLog diagnostic on init failure (addresses S5)

### Verification checklist
- [ ] Verify PIP window close via red traffic light button stops the 15 FPS scene timer (check CPU usage drops)
- [ ] Verify switching from Software to ESP32 Device mode re-applies agent states correctly
- [ ] Verify app launches correctly even if sprite PNGs are missing from bundle (graceful degradation to black)
- [ ] Verify `isInteractionPointFree` with characters that have empty path arrays

### Unresolved items
- RC-1/RC-11 (screenshot data race) — pre-existing, not introduced by this change
- D1/D3 (large functions, duplicated code) — accepted as intentional 1:1 firmware port
- T1/T4 (missing test coverage) — deferred; recommended for future work
- D6 (scattered 320x224 literals) — deferred; shared constant recommended

## Follow-ups
- Add unit tests for `OfficeScene.applyAgentStates`, BFS pathfinding, `isReadingTool`
- Consider injectable random source for deterministic testing
- Move BridgeService extension from MenuBarView.swift to BridgeService.swift
- Extract shared scene dimension constants
