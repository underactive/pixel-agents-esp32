# Audit: Always-Visible Characters

## Files changed

- `firmware/src/office_state.cpp` (primary)
- `firmware/src/office_state.h` (primary)
- `firmware/src/config.h` (primary)
- `firmware/src/renderer.cpp` (primary)
- `firmware/src/main.cpp` (primary)

---

## 1. QA Audit

**Q1 (pre-existing):** `initTileMap()` writes to rows 10-13 on LILYGO where `GRID_ROWS=10`. Array out-of-bounds writes. Pre-existing issue, not introduced by this change.

**Q2 (pre-existing):** Some `WORKSTATIONS` entries reference coordinates beyond LILYGO grid dimensions. Pre-existing issue.

**Q3 [FIXED]:** `setAgentState()` accepts `uint8_t id` which is cast to `int8_t agentId`. Values >= 128 become negative, colliding with the -1 sentinel used for "unassigned". Fix: bounds-check `id >= MAX_AGENTS` at entry.

**Q4:** `spawnAllCharacters()` last-resort fallback places character at hardcoded tile (10,3) without verifying walkability. Low risk -- only reached if the entire zone has no walkable tiles.

**Q5:** `findOrAssignChar()` assigns agents to WALK-state characters who may be walking to a zone. This is intentional -- idle-walking characters can be reassigned.

**Q6 [FIXED]:** When `setAgentState()` receives IDLE while character is in WALK state heading to desk, `seatIdx` is not released because the condition only checked `TYPE || READ`. Fix: expanded condition to also handle `WALK && seatIdx >= 0`.

---

## 2. Security Audit

**S1 [FIXED]:** `agentId` truncation -- same as Q3. `uint8_t` values >= 128 become negative `int8_t`, colliding with -1 sentinel. Fixed with bounds check.

**S2 (pre-existing):** `initTileMap()` out-of-bounds array writes. Same as Q1.

**S3 (pre-existing):** Workstation coordinates exceed LILYGO grid bounds. Same as Q2.

**S4 [FIXED]:** Seat index leak -- same as Q6. Character walks to desk, receives IDLE, seat not released.

---

## 3. Interface Contract Audit

**IC-1:** `setAgentCount()` is now a no-op. Companion still sends AGENT_COUNT messages. No issue -- messages are silently consumed, which is correct behavior.

**IC-2 [FIXED]:** `agentId` type mismatch -- same as Q3/S1.

**IC-4 [FIXED]:** Mid-walk reactivation: when agent becomes active while character walks to zone, character continued to old destination instead of redirecting to desk. Fixed by removing the `ch.state != CharState::WALK` guard in the TYPE/READ branch, allowing `startWalk` to override current path.

**IC-6 (pre-existing):** `initTileMap()` out-of-bounds. Same as Q1/S2.

**IC-8 [FIXED]:** Seat leak -- same as Q6/S4.

---

## 4. State Management Audit

**SM-S1 [FIXED]:** Double `walkToZone`: both `setAgentState` IDLE branch and `updateCharacter` TYPE/READ `!isActive` check both called `walkToZone`, causing double path computation. Fixed by removing `walkToZone` from `setAgentState` -- `updateCharacter` is now the sole transition authority for TYPE/READ -> IDLE -> zone walk.

**SM-S2:** Characters in DESPAWN state transition to IDLE but don't call `walkToZone`. This is acceptable -- they resume normal idle wandering from wherever they are.

**SM-S3:** `wanderCount` is never reset, only incremented. This counter is compared against `wanderLimit` but no code actually checks it to stop wandering. Pre-existing behavior, not introduced by this change.

**SM-S4 [FIXED]:** Seat leak -- same as Q6/S4/IC-8.

---

## 5. Resource & Concurrency Audit

**RC-1:** BFS `findPath()` uses large stack-allocated arrays (`visited[GRID_ROWS][GRID_COLS]`, `parentCol/parentRow`, `queue`). On CYD with GRID_ROWS=14 and GRID_COLS=20, this is ~1680 bytes per call. Acceptable for single-threaded Arduino environment.

**RC-2:** `spawnAllCharacters()` calls `randomRange`/`randomInt` which depend on `randomSeed` being called first. The plan correctly moved `randomSeed` before `spawnAllCharacters()` in `main.cpp`.

---

## 6. Testing Coverage Audit

**TC-1:** No unit tests exist for this project (embedded firmware). All testing is manual via hardware verification.

**TC-2:** Testing checklist needs updating with new always-visible character behaviors.

---

## 7. DX & Maintainability Audit

**DX-1:** Zone boundary constants are duplicated in code (3 places read colMin/colMax/rowMin/rowMax from the same constants). A helper function could reduce this, but the current approach is clear and only 3 call sites.

**DX-2:** `setAgentState()` is ~50 lines, at the readability limit. Acceptable given it handles 3 distinct protocol states.

**DX-3:** The `getCharacterCount()` method is now functionally equivalent to "always 6" after `spawnAllCharacters()`. It's still used by some callers, so kept.
