# Plan: Always-Visible Characters

## Objective

Make all 6 characters always visible on the display. Instead of spawning/despawning with agent activity, characters idle in social zones (break room, library) and walk to desks when an agent becomes active, then walk back when inactive.

## Changes

### 1. `firmware/src/config.h`
- Add `SocialZone` enum (BREAK_ROOM, LIBRARY)
- Add zone boundary constants (adjusted from original plan to match actual walkable tiles)
  - Break room: cols 10-18, rows 3-4 (rows 1-2 are blocked by counters/furniture)
  - Library: cols 12-19, rows 8-13 (CYD) or 8-9 (LILYGO) (rows 5-7 are blocked by bookshelves)

### 2. `firmware/src/office_state.h`
- Add `agentId` (int8_t, -1 when unassigned) and `homeZone` (SocialZone) to Character struct
- Add `spawnAllCharacters()`, `getActiveAgentCount()` public methods
- Add `findOrAssignChar()`, `startZoneWander()`, `walkToZone()` private methods
- Replace `findFreeSlot()` / `findCharById()` with `findCharByAgentId()`
- Remove `addAgent()` / `removeAgent()` from public interface

### 3. `firmware/src/office_state.cpp`
- `spawnAllCharacters()`: Initialize all 6 characters as IDLE in their home zones
- `findOrAssignChar()`: Dynamic agent-to-character mapping (reuse existing assignment or pick idle char)
- `startZoneWander()`: Constrained wandering within home zone bounds
- `walkToZone()`: Pathfind back to home zone on agent deactivation
- `setAgentState()`: Rewritten to use findOrAssignChar, walk to zone on IDLE/OFFLINE
- `setAgentCount()`: Now a no-op (characters are always visible)
- `updateCharacter()`: Zone wander for unassigned characters, DESPAWN transitions to IDLE instead of alive=false

### 4. `firmware/src/renderer.cpp`
- Status bar OVERVIEW shows "N/6 active" instead of "N agents"

### 5. `firmware/src/main.cpp`
- Call `office.spawnAllCharacters()` after init
- Move `randomSeed()` before `spawnAllCharacters()`

## Dependencies
- `spawnAllCharacters()` must be called after `init()` and after `randomSeed()`

## Risks / open questions
1. Zone walkability verified against tile map -- adjusted bounds to match actual walkable tiles
2. 6 simultaneous characters rendering not tested on CYD (no PSRAM)
3. Long walks from desk to zone are visually fine (natural movement)
