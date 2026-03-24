# Plan: Software Display Mode + PIP Window

## Objective
Add a software-only display mode to the macOS companion app that renders the same animated pixel-art office scene as the ESP32 hardware, plus a Picture-in-Picture floating window for persistent desktop visibility.

## Changes
- **tools/render_office_bg.py** — New Python tool that parses tiles.h RGB565 data and renders a 320x224 office background PNG (floor tiles + furniture)
- **OfficeScene.swift** — New Swift port of firmware OfficeState: tile map, BFS pathfinding, 6-character FSM, dog pet AI, idle activities
- **OfficeRenderer.swift** — New CGBitmapContext renderer producing CGImage at 15 FPS, with SpriteCache singleton
- **OfficeCanvasView.swift** — Simplified to display pre-rendered CGImage from BridgeService
- **PIPWindowController.swift** — New NSPanel floating window with hover titlebar, aspect-ratio lock, position persistence
- **BridgeService.swift** — Added DisplayMode enum, officeScene, officeRenderer, scene timer, PIP state management
- **MenuBarView.swift** — Display Mode picker, conditional hardware/software content layout, PIP overlay button
- **TransportPicker.swift** — Removed .software case (now handled by DisplayMode)
- **AgentListView.swift** — Fixed dark mode icon color
- **UsageStatsView.swift** — Renamed header to "Claude Usage"
- **Makefile** — Added sign-install target
- **project.yml** — Bumped deployment target to macOS 14.0

## Dependencies
- tools/render_office_bg.py must run before build to generate office_background.png
- Sprite PNGs (char_0-5, doggy-*) must be in Resources/

## Risks / Open Questions
- CGContext Y-coordinate flipping may cause subtle rendering bugs (bottom-left vs top-left origin)
- OfficeScene simulation may drift from firmware behavior over time as firmware evolves
- NSPanel titlebar button superview hierarchy may vary across macOS versions
