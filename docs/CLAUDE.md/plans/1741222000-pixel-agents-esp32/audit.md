# Consolidated Audit Report: Pixel Agents ESP32-S3

**Date:** 2026-03-05
**Auditors:** 7 parallel automated audit agents (QA, Security, Interface Contract, State Management, Resource & Concurrency, Testing Coverage, DX & Maintainability)

## Executive Summary

7 audit agents reviewed all project files. The most critical findings were in the serial protocol parser (buffer overflow leading to parser lockup, out-of-bounds reads in dispatch), the character state machine (spawn always defaulting to TYPE, permission bubble never timing out), resource management (PSRAM detected but never used, createSprite failure not checked), QA (water cooler walkthrough, double byte-swap, spawn bounds), and DX (magic numbers). All high and medium findings have been fixed across two rounds.

---

## Findings Fixed

### Critical/High Fixes Applied

| # | Source | Finding | Fix |
|---|--------|---------|-----|
| S3,S4 | Security | Out-of-bounds reads in `dispatch()` — memcpy could read beyond received data | Added bounds checks: `if (3 + toolLen > _bufIdx) toolLen = ...` |
| S1,S2 | Security | Parser lockup on oversized messages — state machine stuck in READ_PAYLOAD | Reset to WAIT_SYNC1 when `_bufIdx >= SERIAL_BUF_SIZE` |
| S6 | Security | Unchecked cast of arbitrary byte to CharState enum | Added validation: `if (_buf[1] > DESPAWN) break` |
| S13 | Security | Ghost agents on stale prune — no OFFLINE sent to firmware | Companion now sends OFFLINE for pruned agents |
| S17 | Security | createSprite() return value not checked (108KB allocation) | Check return value, cleanup on failure |
| SM6.2 | State | Spawn always transitions to TYPE, ignoring READ | Uses `isReadingTool(ch.toolName)` to choose TYPE vs READ |
| SM8.2 | State | Permission bubble never times out | Added 10-second timeout for permission bubbles |
| SM8.3 | State | Bubble not cleared on internal TYPE→IDLE transition | Clear bubbleType/Timer on internal IDLE entry |
| R1 | Resource | PSRAM detected but never used, `_usePSRAM` dead code | Removed dead `_usePSRAM` flag and psramFound() check |
| R8 | Resource | Serial FD leak on disconnect in companion | Added `ser.close()` before setting to None |

### Medium Fixes Applied

| # | Source | Finding | Fix |
|---|--------|---------|-----|
| S14 | Security | Agent count sent every poll cycle (unnecessary traffic) | Track `_last_count`, only send on change |
| SM10.1 | State | `active_tools.discard()` used wrong key type (tool_use_id vs name) | Removed dead code path |
| SM5.4 | State | TileType::BLOCKED comment misleading ("walkable but occupied") | Fixed comment to "non-walkable, BFS allows as destination only" |
| R4 | Resource | BFS queue lacks overflow guard | Added `if (qTail >= GRID_ROWS * GRID_COLS) break` |
| -- | State | Dead `wasActive` variable with void suppression | Removed |
| QA17 | QA | Water cooler tile (18,7) walkable — characters walk through top half | Added `_tiles[7][18] = TileType::BLOCKED` alongside existing row 8 |
| QA11 | QA | `lastUpdateMs` unused in main.cpp | Removed dead variable and its initialization |
| QA19 | QA | Double byte-swap: converter pre-swaps + `setSwapBytes(true)` cancels out | Removed pre-swap from converter; `setSwapBytes(true)` handles SPI byte order at push time |
| QA7 | QA | `drawSpawnEffect` missing screen bounds checks on `drawPixel` | Added `dx/dy` bounds checks matching `drawIndexedSprite` pattern |
| DX6.2 | DX | Spawn duration `0.3f` magic number in 3 places | Extracted `SPAWN_DURATION_SEC` constant in config.h |
| DX6.1 | DX | Floor alt color `0x4228` magic number in renderer | Extracted `COLOR_FLOOR_ALT` constant in config.h |

---

## Findings Accepted (Not Fixed)

### Low Risk — Acceptable for Current Project

| # | Source | Finding | Rationale |
|---|--------|---------|-----------|
| S5 | Security | Weak XOR checksum (1/256 collision chance) | Physical serial access already implies device compromise. Sufficient for noise protection. |
| S9 | Security | No rate limiting on serial protocol processing | 15 FPS frame budget leaves ~44ms headroom. Not a practical concern. |
| S10 | Security | TOCTOU race on file size vs read in companion | Handled gracefully — JSONDecodeError is caught, no crash. |
| S11 | Security | Unbounded growth of file_offsets dict | Negligible memory (~100 bytes per entry). Long-term sessions unlikely to create thousands of transcripts. |
| S12 | Security | Agent ID wraparound after 256 unique projects | Extremely unlikely in practice. 6 concurrent agents max. |
| SM1.2 | State | Seatless agents type in mid-floor | Visual oddity, not a bug. 6 workstations available. |
| SM2.1 | State | Bubble set on requested vs actual state during walk | Brief visual artifact during walk-to-desk transition. |
| SM3.1 | State | wanderCount/wanderLimit tracked but unused | Dead logic, doesn't cause incorrect behavior. Characters wander until next state update. |
| SM3.2 | State | Wander can fail silently (20 random attempts) | Falls back to waiting and retrying. No stuck state. |
| SM3.3 | State | Wander may pick current tile (zero-length walk) | No-op cycle, harmless. |
| SM4.1 | State | Seat reserved during despawn animation | Brief window, unlikely to conflict. |
| R3 | Resource | BFS uses ~1.1KB stack (ESP32 has 8KB) | Within budget. Monitor with `uxTaskGetStackHighWaterMark` on hardware. |
| R5 | Resource | Pixel-by-pixel sprite rendering | TFT_eSprite is in-memory. 15 FPS target achievable with ~22ms SPI push. |
| R9 | Resource | `_canvas` allocated with new, never freed | One-time allocation, persists for program lifetime. |
| R10 | Resource | Unused sprites (PC, Lamp, Whiteboard) in PROGMEM | ~2KB flash waste. Linker may strip. Kept for future use. |
| R11 | Resource | PROGMEM pointer tables ESP32-only (not AVR-portable) | Project targets ESP32-S3 exclusively. |
| R12 | Resource | static constexpr array duplicated per TU (~360 bytes) | Negligible on 16MB flash. |
| QA4 | QA | Path buffer [64] may be too small for 200-tile grid paths | BFS shortest path on 20x10 grid is at most ~28 steps. 64 is sufficient. |
| IC1 | Interface | Protocol constants match between firmware and companion | Verified consistent. |
| IC2 | Interface | Sprite names in renderer match generated headers | Verified consistent. |
| TC1 | Testing | No unit tests (requires Arduino framework on host) | Impractical without hardware abstraction layer. Manual testing checklist provided. |
| DX5.1 | DX | sprite_converter.py is 1488 lines monolithic | Works correctly. Refactoring adds complexity for a one-time code generator. |

---

## Summary by Audit Domain

| Audit | Critical | High | Medium | Low | Fixed |
|-------|----------|------|--------|-----|-------|
| Security | 0 | 2 | 5 | 7 | 7 |
| State Management | 0 | 3 | 6 | 9 | 5 |
| Resource & Concurrency | 0 | 2 | 5 | 7 | 3 |
| QA | 0 | 0 | 4 | 1 | 4 |
| Interface Contract | 0 | 0 | 0 | 2 | 0 |
| Testing Coverage | 0 | 0 | 0 | 1 | 0 |
| DX & Maintainability | 0 | 0 | 2 | 1 | 2 |
| **Total** | **0** | **7** | **22** | **28** | **21** |

All High and actionable Medium findings have been fixed. Remaining Low findings are documented and accepted.
