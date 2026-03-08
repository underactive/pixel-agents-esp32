# Audit: CYD RGB LED Ambient Lighting

## Files Changed

- `firmware/src/config.h`
- `firmware/src/led_ambient.h`
- `firmware/src/led_ambient.cpp`
- `firmware/src/main.cpp`
- `docs/CLAUDE.md/testing-checklist.md`

---

## 1. QA Audit

| ID | Severity | Description |
|----|----------|-------------|
| [FIXED] Q1 | Low | `_phase` grows without bound; float precision degrades after days |
| [FIXED] Q2 | Low | Duplicated SINE_LUT halves cause 2x breathe frequency vs. configured period |
| [FIXED] Q3 | Info | Comment says `100..255` but actual range is `100..162` due to BUSY threshold at 4 |
| [FIXED] Q5 | Info | No `default` case in `switch (_mode)` |
| Q6 | N/A | Capped `dt` is consistent with existing pattern |
| Q7 | Info | Uses v2.x LEDC API; will break on Arduino-ESP32 v3.x upgrade |

## 2. Security Audit

| ID | Severity | Description |
|----|----------|-------------|
| [FIXED] S1 | Low | Brightness calc safe for MAX_AGENTS=6 but not future-proof; add `min()` clamp |
| [FIXED] S2 | Low | `_phase` float grows unbounded; precision degrades after weeks of uptime |
| S3 | Info | No LEDC detach — acceptable for global singleton |
| [FIXED] S4 | Info | `LedMode` enum not guarded by `BOARD_CYD` — harmless but inconsistent |
| S5 | None | No external input processed directly |
| S6 | None | No null derefs, array access bounded by bitmask |

## 3. Interface Contract Audit

| ID | Severity | Description |
|----|----------|-------------|
| [FIXED] IC-1 | Low | `_phase` float grows unbounded |
| [FIXED] IC-2 | Low | `LedMode` enum exposed on non-CYD builds |
| [FIXED] IC-3 | Low | ACTIVE brightness comment misleading; uint8_t overflow if threshold changes |
| IC-4 | Low | `ledcSetup`/`ledcAttachPin` return values unchecked |

## 4. State Management Audit

| ID | Severity | Description |
|----|----------|-------------|
| [FIXED] SM-1 | Low | `_phase` accumulates without bound |
| [FIXED] SM-5 | Note | `LedMode` enum defined outside CYD board guard |
| SM-2 | Pass | Mutation discipline is clean |
| SM-3 | Pass | Data flow is appropriate |
| SM-4 | Pass | No sync issues |

## 5. Resource & Concurrency Audit

| ID | Severity | Description |
|----|----------|-------------|
| [FIXED] RC1 | Medium | `_phase` float grows without bound |
| RC2 | Low | LEDC channel avoidance relies on TFT_eSPI internals |
| RC3 | Low | No `ledcDetachPin` — benign given single-init pattern |
| RC4 | None | All access is single-threaded; no races |
| RC5 | Low | LED GPIOs remain LEDC-driven when OFF; negligible for USB power |
| RC6 | Low | `ledcSetup` return value unchecked |

## 6. Testing Coverage Audit

| ID | Severity | Description |
|----|----------|-------------|
| T1 | Low | No unit tests for LedAmbient (consistent with project — no test framework) |
| T2 | Low | No hardware integration tests (standard for embedded) |
| [FIXED] T3 | Medium | Missing testing checklist items for LED ambient feature |
| T4 | Low-Med | `_phase` float accumulation drift (covered by SM-1 fix) |
| T5 | Low | ACTIVE brightness formula fragile if threshold changes (covered by D3 fix) |
| T6 | Low | No contract tests for OfficeState methods consumed by LedAmbient |

## 7. DX & Maintainability Audit

| ID | Severity | Description |
|----|----------|-------------|
| [FIXED] D1 | Low | `LedMode` and constants outside CYD guard — dead code on LILYGO |
| [FIXED] D2 | Low | LUT comment needed explaining the repeated half-wave |
| [FIXED] D3 | Medium | Magic numbers in brightness scaling; violates "symbolic constants" rule |
| D4 | Low | Inline color literals — adequate with comments for 4 cases |
| [FIXED] D5 | Low | Missing doc comment on `breathe()` return semantics |
| [FIXED] D6 | Low | Header includes `office_state.h` — forward declaration suffices |

---

## Unresolved Items

- **Q7/IC-4/RC2/RC6:** LEDC API v2 compatibility, unchecked return values, and channel collision assumptions are accepted as-is. These are informational notes for a future platform upgrade, not bugs in the current code.
- **S3/RC3/RC5:** No LEDC detach and GPIOs remaining driven when OFF are acceptable for a USB-powered global singleton that runs forever.
- **T1/T2/T6:** No unit or integration tests — consistent with the project's embedded testing posture. The testing checklist (T3, now fixed) provides manual verification coverage.
- **D4:** Inline color literals left as-is — the 4-case switch with comments is readable enough without extracting named color constants.
