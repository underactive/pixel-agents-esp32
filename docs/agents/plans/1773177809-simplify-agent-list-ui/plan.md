# Simplify Agent List UI in macOS Companion

## Objective

Remove implementation-detail noise from the macOS companion's agent list. Instead of showing arbitrary agent IDs (e.g., `#25`) and a count header, always display all 6 character slots with their current state — matching how the firmware renders all 6 characters.

## Changes

### 1. `AgentListView` — Remove count, remove empty state, always render all slots
- **File:** `macos/PixelAgents/PixelAgents/Views/AgentListView.swift`
- Header: `"Agents (\(agents.count))"` → `"Agents"`
- Remove `"No active agents"` empty-state branch
- Always `ForEach(agents)` (caller guarantees 6 elements)

### 2. `AgentRow` — Remove ID column
- **File:** `macos/PixelAgents/PixelAgents/Views/AgentListView.swift`
- Remove `Text("#\(agent.id)")` and its frame
- Row becomes: `[dot] [StateName] [(ToolName)]`

### 3. `BridgeService` — Build fixed 6-slot display array
- **File:** `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- Replace `displayAgents = tracker.sortedAgents` with logic that builds a 6-element array: offline defaults overlaid with active agents in the first N slots

## Dependencies

- No ordering constraints between changes (all three can be made independently).

## Risks / Open Questions

- None significant. The view already handles `.offline` state with a gray dot.
