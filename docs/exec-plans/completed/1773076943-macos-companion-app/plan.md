# Plan: Native macOS Companion App

## Objective

Create a native macOS menu bar app that replaces the Python companion bridge for macOS users. End users download a `.app` bundle instead of cloning the repo, installing Python, and running scripts. Full feature parity with `companion/pixel_agents_bridge.py`.

## Changes

### New files (all under `macos/PixelAgents/`)

- **`project.yml`** — XcodeGen project spec (macOS 13+, Swift 5.9, non-sandboxed)
- **`PixelAgents/PixelAgentsApp.swift`** — @main entry, MenuBarExtra with .window style
- **`PixelAgents/Info.plist`** — LSUIElement=YES, Bluetooth usage description
- **`PixelAgents/PixelAgents.entitlements`** — app-sandbox=false
- **`PixelAgents/Assets.xcassets/`** — App icon, menu bar icon placeholders

#### Model layer
- **`Model/AgentState.swift`** — CharState enum, Agent struct
- **`Model/AgentTracker.swift`** — Agent lifecycle, ID assignment, pruning
- **`Model/ProtocolBuilder.swift`** — Binary message construction (port of Python build_message)
- **`Model/StateDeriver.swift`** — JSONL record → agent state mapping
- **`Model/TranscriptWatcher.swift`** — FSEvents JSONL file monitoring
- **`Model/UsageStats.swift`** — Rate limits cache reader

#### Transport layer
- **`Transport/TransportProtocol.swift`** — Protocol interface
- **`Transport/SerialTransport.swift`** — POSIX serial I/O with fd locking
- **`Transport/SerialPortDetector.swift`** — IOKit USB plug/unplug notifications
- **`Transport/BLETransport.swift`** — CoreBluetooth NUS client

#### Services
- **`Services/BridgeService.swift`** — Main orchestrator (ObservableObject)
- **`Services/ScreenshotService.swift`** — Serial screenshot capture + PNG save

#### Views
- **`Views/MenuBarView.swift`** — Main popover content
- **`Views/ConnectionStatusView.swift`** — Status dot + text
- **`Views/AgentListView.swift`** — Agent rows with state indicators
- **`Views/UsageStatsView.swift`** — Usage bars with reset timers
- **`Views/TransportPicker.swift`** — Serial/BLE mode toggle

#### Tests
- **`PixelAgentsTests/ProtocolBuilderTests.swift`** — 9 tests
- **`PixelAgentsTests/StateDeriverTests.swift`** — 7 tests
- **`PixelAgentsTests/AgentTrackerTests.swift`** — 7 tests

## Dependencies

- macOS 13+ (Ventura) for MenuBarExtra API
- XcodeGen for project generation from project.yml
- No third-party Swift dependencies

## Risks / Open Questions

1. IOKit serial + Hardened Runtime may need additional entitlements
2. CoreBluetooth scanning may throttle without a foreground window
3. JSONL format is not a public API (same risk as Python bridge)
4. App icons and menu bar icon images not yet created
5. Distribution (signing, notarization, DMG) not yet implemented
