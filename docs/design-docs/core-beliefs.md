# Core Beliefs

Foundational development principles for Pixel Agents ESP32. These are non-negotiable rules that apply to all changes.

---

## 1. Validate all external input at the boundary

**Belief:** Every value arriving from serial or BLE must be validated and clamped before use.

**Rationale:** The ESP32 runs a binary protocol over serial/BLE. Corrupt bytes, version mismatches, or malicious input could cause array overflows, invalid state transitions, or crashes. Validation at the boundary means interior code can trust its data.

**Enforcement:** Code review. Any `onXxx()` callback that receives protocol data must validate before assigning.

---

## 2. Guard all array-indexed lookups

**Belief:** Any value used as an index into an array must have a bounds check before access: `(val < COUNT) ? ARRAY[val] : fallback`.

**Rationale:** Defense-in-depth against corrupt or unvalidated values. Even after boundary validation, an off-by-one or enum change could cause an out-of-bounds read. Array guards are cheap insurance.

**Enforcement:** Code review. No bare `ARRAY[val]` without a preceding bounds check.

---

## 3. Reset connection-scoped state on disconnect

**Belief:** Buffers, flags, and session variables that accumulate state during a connection must be reset on disconnect.

**Rationale:** Cross-session corruption caused a hard-to-reproduce bug early in development where stale buffer data from a previous session was interpreted as a new message. Serial buffer state and heartbeat timer now reset on reconnect.

**Enforcement:** The `onDisconnect()` handler in `main.cpp` must clear all session state. New session-scoped variables must be added to this handler.

---

## 4. Avoid memory-fragmenting patterns in long-running code

**Belief:** Use fixed-size arrays for characters, paths, tool names. No dynamic allocation in the main loop.

**Rationale:** ESP32 has limited heap (especially CYD with no PSRAM). Heap fragmentation in a device that runs 24/7 will eventually cause allocation failures. Fixed-size arrays with compile-time limits prevent this entirely.

**Enforcement:** Code review. `new`, `malloc`, `String` concatenation in the main loop are red flags. Reserve dynamic allocation for short-lived, one-shot operations (e.g., boot-time setup).

---

## 5. Use symbolic constants, not magic numbers

**Belief:** All values defined in `config.h`. Never hardcode index values or numeric constants.

**Rationale:** Magic numbers cause silent bugs when data structures are reordered. Named defines and enums create compile-time safety — if a constant is removed, all references fail to compile rather than silently using the wrong value.

**Enforcement:** Code review. Any numeric literal in firmware code (other than 0, 1, or -1) should have a named constant.

---

## 6. Throttle event-driven output

**Belief:** Agent count messages sent only on change. Frame rate capped at 15 FPS. Usage stats sent only when values change.

**Rationale:** The display updates at 15 FPS. Sending data faster than the display can render wastes serial bandwidth and CPU. The companion should batch updates and the firmware should skip redundant renders.

**Enforcement:** All periodic outputs must have a "changed since last send" guard or a fixed-interval cap.

---

## 7. Use bounded string formatting

**Belief:** Always `snprintf(buf, sizeof(buf), ...)` for text rendering.

**Rationale:** `sprintf` with a growing format string (e.g., adding a new status field) can silently overflow the buffer. `snprintf` truncates instead of corrupting memory. This is particularly important for status bar text which changes based on display mode.

**Enforcement:** Code review. No `sprintf` in firmware code — always `snprintf` with `sizeof`.

---

## 8. Report errors, don't silently fail

**Belief:** Invalid protocol messages are discarded with state reset, not silently consumed. When input exceeds limits or operations fail, provide actionable error feedback.

**Rationale:** Silent failures mask bugs. During development, a "consumed but not processed" protocol message took days to track down. Explicit discard with state reset makes the failure visible in debug output.

**Enforcement:** Protocol parser logs discarded messages via `Serial.printf` in debug builds. Companion logs unrecognized transcript records.
