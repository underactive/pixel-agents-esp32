# Plan: Fix Agent IDs >= 6 silently rejected by firmware

## Objective

Fix a bug where agent IDs >= 6 are silently dropped by the firmware, causing agents to not appear on the display when their IDs exceed `MAX_AGENTS` (6). The root cause is a guard in `setAgentState()` that conflates the protocol agent ID (0-255) with the character array index (0-5). Additionally, add ID recycling in both companions to keep IDs low and prevent long sessions from exhausting the ID space.

## Changes

### 1. Firmware: Relax agent ID guard (`firmware/src/office_state.cpp`)
- Change `if (id >= MAX_AGENTS) return;` to `if (id >= 128) return;`
- 128 is the boundary where `uint8_t` values would wrap negative in `int8_t` storage, colliding with the -1 sentinel

### 2. macOS Companion: Add ID recycling (`macos/PixelAgents/PixelAgents/Model/AgentTracker.swift`)
- Add `recycledIds` array
- On prune, push freed IDs onto recycled list
- On create, pop from recycled list first, then fall back to `nextId` increment
- Clear recycled list on `reset()`

### 3. Python Companion: Add ID recycling (`companion/pixel_agents_bridge.py`)
- Add `_recycled_ids` list to `AgentTracker`
- Same recycle-on-prune, reuse-on-create logic

### 4. Tests: Update macOS unit tests (`macos/PixelAgents/PixelAgentsTests/AgentTrackerTests.swift`)
- Replace `testIdWrapsAt256` with `testPrunedIdsAreRecycled` and `testNewIdAfterRecyclePoolExhausted`

## Dependencies
- No ordering constraints between the three code changes

## Risks / open questions
- Very long sessions (128+ unique agents without any pruning) would still hit the firmware guard — practically impossible given 6 character slots and 30s prune timeout
