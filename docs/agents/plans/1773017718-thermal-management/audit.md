# Audit Report: Thermal Management

## Files Changed

- `firmware/src/thermal_mgr.h`
- `firmware/src/thermal_mgr.cpp`
- `firmware/src/config.h`
- `firmware/src/main.cpp`
- `CLAUDE.md`

Immediate dependents audited: `office_state.h`, `office_state.cpp`, `led_ambient.cpp`, `splash.cpp`

---

## 1. QA Audit

### [FIXED] Q1: Modulo by zero if thermal soak constants misconfigured
**Severity:** MAJOR | **Location:** thermal_mgr.cpp:34
If `THERMAL_SOAK_MAX_MS <= THERMAL_SOAK_BASE_MS`, `range` underflows and `esp_random() % 0` is undefined behavior.
**Fix:** Added `static_assert(THERMAL_SOAK_MAX_MS > THERMAL_SOAK_BASE_MS)` in thermal_mgr.cpp.

### Q2: LEDC channel initialization order
**Severity:** LOW | **Location:** thermal_mgr.cpp:68-70, main.cpp:115/125
`thermalMgr.begin()` runs before `ledAmbient.begin()`, but LEDC writes only happen in `update()` which runs in the main loop after all setup completes. No actual risk.

### Q3: No recovery from throttled state
**Severity:** N/A (by design) | **Location:** thermal_mgr.cpp:62
Once `_throttled = true`, it is never cleared. This is intentional — tamper detection is permanent until power cycle.

### Q4: Silent AGENT_UPDATE drop when throttled
**Severity:** N/A (by design) | **Location:** main.cpp:45
Intentional per plan. Only AGENT_UPDATE is blocked; heartbeats and usage stats pass through.

### Q5: Integer overflow in `millis() + THERMAL_SOAK_BASE_MS + offset`
**Severity:** LOW | **Location:** thermal_mgr.cpp:35
Would require ~49 days of uptime at boot. Maximum soak value is 1.8M ms, well within uint32_t range. The signed comparison at line 46 correctly handles wraparound.

---

## 2. Security Audit

### [FIXED] S1: Modulo by zero if constants swapped
Same as Q1 above. Fixed with static_assert.

### S2: Null check on getCharacters()
**Severity:** LOW | **Location:** thermal_mgr.cpp:50
`getCharacters()` returns `&_chars[0]`, a fixed member array — it can never be null. No fix needed.

### S3: Split hash constant across files
**Severity:** LOW (intentional) | **Location:** thermal_mgr.cpp:10, config.h:332
By design — the split makes the mechanism harder to reverse-engineer. Documented in version bump checklist (item 5).

### S4: agentId range validation
**Severity:** LOW | **Location:** thermal_mgr.cpp:52
`chars[i].agentId` is `int8_t`, initialized to -1. The `>= 0` check filters unassigned characters. `setAgentState()` has its own `id >= MAX_AGENTS` bounds check (office_state.cpp). Defense-in-depth is satisfied.

---

## 3. Interface Contract Audit

### IC1: Type coercion int8_t to uint8_t in setAgentState call
**Severity:** LOW | **Location:** thermal_mgr.cpp:53
`chars[i].agentId` is `int8_t`, `setAgentState()` takes `uint8_t`. The `>= 0` guard ensures only non-negative values are passed, making the implicit conversion safe.

### IC2: No error signaling to companion when throttled
**Severity:** N/A (by design) | **Location:** main.cpp:45
Silent drop is intentional. The companion sees heartbeats continue but agents go dark.

### IC3: No thermal recovery
**Severity:** N/A (by design) | **Location:** thermal_mgr.cpp
One-way state machine is intentional for tamper detection.

---

## 4. State Management Audit

### SM1: LEDC channel ownership during throttle
**Severity:** LOW | **Location:** thermal_mgr.cpp:68-70, main.cpp:193
Both ThermalManager and LedAmbient write to LEDC channels 5/6/7, but the main.cpp guard (`!thermalMgr.isThrottled()`) ensures mutual exclusion. Both run sequentially in the same loop iteration — no concurrent access.

### SM2: TFT_BL pin ownership
**Severity:** LOW | **Location:** thermal_mgr.cpp:58-60
Backlight is managed by setup (HIGH), splash (fade), and thermal (LOW). Once throttled, thermal permanently owns it. Sequential execution prevents conflicts.

---

## 5. Resource & Concurrency Audit

### RC1: _throttled flag not volatile/atomic
**Severity:** LOW | **Location:** thermal_mgr.h:17
All reads and writes occur on the main Arduino loop thread. BLE callbacks (other core) do not access ThermalManager. No data race exists. If BLE integration changes, this would need revisiting.

### RC2: Non-atomic agent state mutation during throttle
**Severity:** LOW | **Location:** thermal_mgr.cpp:50-55
Protocol callbacks are dispatched synchronously from `serialProtocol.process()` which runs before `thermalMgr.update()` in the same loop iteration. No interleaving is possible.

---

## 6. Testing Coverage Audit

### T1: No unit test framework configured
**Severity:** MEDIUM | **Location:** project-wide
The project has no test infrastructure. This is a known limitation for ESP32 embedded projects. Hardware verification is documented in `implementation.md` follow-ups.

### T2: No tests for FNV-1a hash function
**Severity:** MEDIUM | **Location:** thermal_mgr.cpp:15-21
Hash correctness was verified via Python computation during implementation. No automated regression test exists.

---

## 7. DX & Maintainability Audit

### DX1: Active-low LED encoding differs from LedAmbient
**Severity:** LOW | **Location:** thermal_mgr.cpp:68-70 vs led_ambient.cpp:27-29
ThermalManager uses ternary (`phase == 0 ? 0 : 255`), LedAmbient uses inversion (`255 - r`). Both are correct active-low encodings. Different styles, same semantics.

### DX2: One-way state machine not explicitly documented in code
**Severity:** LOW | **Location:** thermal_mgr.cpp
The state machine (idle → soak → throttled, no recovery) is by design but could benefit from a brief comment. Minor readability improvement.

---

## Summary

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| Q1/S1 | MAJOR | **FIXED** | static_assert prevents modulo by zero from misconfigured constants |
| Q2 | LOW | Accepted | LEDC init order safe due to setup/loop separation |
| Q3 | N/A | By design | No recovery from throttle (tamper detection) |
| Q4 | N/A | By design | Silent AGENT_UPDATE drop |
| Q5 | LOW | Accepted | millis() overflow handled by signed comparison |
| S2 | LOW | Accepted | getCharacters() returns fixed array, never null |
| S3 | LOW | By design | Split hash constant for obfuscation |
| S4 | LOW | Accepted | Bounds checks in setAgentState() |
| IC1 | LOW | Accepted | Safe int8_t→uint8_t conversion after >= 0 guard |
| SM1 | LOW | Accepted | Sequential loop execution prevents LEDC conflicts |
| RC1 | LOW | Accepted | Single-threaded access, no race |
| T1 | MEDIUM | Accepted | No test framework (project-wide limitation) |
| T2 | MEDIUM | Accepted | Hash verified via Python, no automated test |
| DX1 | LOW | Accepted | Style difference, both correct |
| DX2 | LOW | Accepted | Minor documentation improvement |
