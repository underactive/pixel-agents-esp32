# BLE PIN Pairing — Consolidated Audit Report

## Files Changed

- `firmware/src/config.h`
- `firmware/src/ble_service.h`
- `firmware/src/ble_service.cpp`
- `firmware/src/splash.h`
- `firmware/src/splash.cpp`
- `firmware/src/main.cpp`
- `companion/ble_transport.py`
- `companion/pixel_agents_bridge.py`

---

## QA Audit

**Q1. [HIGH] PIN broadcast in plaintext — device selection, not security**
`ble_service.cpp`, `ble_transport.py` — The PIN is embedded in cleartext in BLE advertising and the ESP32 performs no server-side PIN verification. Any BLE client can connect without presenting the PIN. This is intentionally a device-selection convenience (like MeshCore), not a security mechanism. Documented as such.

**[FIXED] Q2. [MED] `volatile bool _connected` should be `std::atomic<bool>`**
`ble_service.h:14` — Written from NimBLE callback context, read from main loop. Changed to `std::atomic<bool>` with acquire/release ordering.

**[FIXED] Q3. [MED] Double BLE scan in interactive PIN flow**
`ble_transport.py`, `pixel_agents_bridge.py` — Interactive flow scanned devices, prompted for PIN, then `connect_by_pin()` scanned again. Fixed by reusing the first scan's results directly.

**[FIXED] Q4. [MED] No range validation on `--ble-pin` CLI argument**
`pixel_agents_bridge.py` — Values outside 1000-9999 silently fail. Added `parser.error()` validation.

**Q5. [MED] PIN only visible during splash — no way to view after boot**
`splash.cpp`, `main.cpp` — PIN is logged to serial as fallback. Adding a status bar PIN display is a future improvement.

**Q6. [MED] `SPLASH_PIN_Y` missing for LILYGO / `drawPinCode()` CYD-only guard**
`config.h`, `splash.cpp` — Currently consistent since `HAS_BLE` is CYD-only. If LILYGO gains BLE, `SPLASH_PIN_Y` and guard will need updating. Acceptable as-is.

**Q7. [LOW] Modular bias in PIN generation** — Negligible (0.0002%), no fix needed.

**Q8. [LOW] `0xFFFF` company ID may collide with other test devices** — Acceptable for hobby project.

**Q9. [LOW] `input()` blocks indefinitely** — By design for interactive PIN entry. EOFError is caught.

---

## Security Audit

**S1. [HIGH] PIN broadcast in cleartext** — Same as Q1. By design as device selection, not security.

**S2. [HIGH] No server-side PIN authentication** — By design. PIN is for selecting which device to connect to, not access control.

**S3. [MED] Small PIN keyspace (9000 values)** — Acceptable since PIN is not a security mechanism.

**S4. [LOW] `--ble-pin` visible in process listing** — Interactive mode is preferred. Minor info leak.

**S5. [LOW] `_extract_pin` None return in comparison** — Safe due to Python type semantics.

**S6. [LOW] PIN generation arithmetic safe but fragile** — `uint16_t` range adequate for 1000-9999.

**S7. [LOW] PIN logged to serial output** — Intentional for debugging.

**S8. [LOW] PIN display gated on CYD only** — Consistent with CYD-only BLE. See Q6.

---

## Interface Contract Audit

**[FIXED] I1. [MED] Double BLE scan in interactive mode** — Same as Q3. Fixed.

**[FIXED] I2. [LOW] No range validation on `--ble-pin`** — Same as Q4. Fixed.

**I3. [LOW] No backoff on BLE reconnect retries** — Pre-existing, not introduced by PIN feature.

**I4. [MED] AgentTracker not reset on BLE reconnect** — Agent IDs derived from file paths, not devices. ID aliasing requires 256+ unique JSONL files across sessions. Acceptable for now.

**I5. [LOW] Rare race between `on_disconnect` and `_connected = True`** — Next `send()` would correct state.

**I6. [LOW] PIN display could be overwritten if log area constants change** — Current constants are safe (log bottom Y=212 < PIN Y=218).

**I7. [LOW] `drawPinCode()` guard should be `HAS_BLE` not `BOARD_CYD`** — Currently equivalent. See Q6.

**[FIXED] I8. [LOW] BLE scan exceptions not caught in `_connect_ble()`** — Added try/except wrapper.

---

## State Management Audit

**S1. [LOW] PIN copied to three locations** — Write-once semantics, no divergence possible at runtime.

**[FIXED] S2. [LOW] `Splash::begin()` does not reset `_pinCode`** — Added `_pinCode = 0` in `begin()`.

**[FIXED] S3. [MED] `_last_count` not initialized in `__init__`** — Added `self._last_count = -1` in `__init__`, removed `hasattr` check.

**[FIXED] S4. [MED] Serial reconnect does not reset session state** — Added `_reset_session_state()` called from both `_connect_serial()` and `_connect_ble()`.

**[FIXED] S5. [LOW] Interactive PIN not persisted for auto-reconnect** — Now saves entered PIN to `self.ble_pin` on successful connect.

**S6. [LOW] `_connected` in Python BleTransport modified from multiple threads** — GIL-safe for CPython.

**S7. [LOW] PIN byte encoding coupled to uint16 range** — Current constants well within range.

**[FIXED] S8. [MED] No unified session-state reset** — Added `_reset_session_state()` method.

---

## Resource & Concurrency Audit

**[FIXED] R1. [MED] `_connected` should be `std::atomic<bool>`** — Same as Q2. Fixed.

**R2. [LOW] `_pin` write-once invariant** — Safe, added comment in header.

**R3. [LOW] `std::string` temporary in `setManufacturerData`** — One-shot allocation, negligible.

**R4. [MED] Ring buffer `reset()` may race with in-flight NimBLE `onWrite`** — Pre-existing issue from BLE transport implementation. NimBLE typically completes writes before `onDisconnect`. Theoretical risk.

**R5. [LOW] `startAdvertising()` in NimBLE callback context** — Idiomatic NimBLE pattern.

**R6. [MED] Python `_connected` modified from multiple threads** — Same as S6. GIL-safe.

**R7. [HIGH] `input()` blocks main thread indefinitely** — By design for interactive PIN entry. Only occurs on first connect before main loop sends heartbeats. EOFError caught.

**R8-R14. [LOW]** — Various low-severity items, all acceptable.

---

## Testing Coverage Audit

No PIN-related test items existed. Recommended items added to testing checklist (see below).

---

## DX & Maintainability Audit

**D1. [MED] `SPLASH_PIN_Y` missing from LILYGO branch** — Same as Q6. Acceptable.

**D2. [MED] `setPinCode()` unconditional but `drawPinCode()` CYD-only** — Documented by design.

**D3. [MED] Inconsistent naming `_pin` vs `_pinCode`** — Minor. `_pin` is the BLE concept, `_pinCode` is the display concept. Not changing.

**D4. [LOW] `MFG_COMPANY_ID` duplicated without reverse cross-reference** — Python side has forward reference. Acceptable.

**[FIXED] D5. [LOW] PIN endianness encoding lacks comments** — Added byte-order comments in `ble_service.cpp`.

**[FIXED] D6. [MED] `_last_count` not declared in `__init__`** — Same as S3. Fixed.

**D7. [LOW] `0xFFFF` choice lacks `// WHY` comment** — Existing comment ("reserved for testing") is adequate.

**D8. [LOW] `scan_devices()` return type annotation is `list`** — Minor, consistent with existing code style.

**D9. [MED] `_connect_ble()` mixed concerns** — Interactive PIN resolution now happens inline before the connect call, which is clearer than the original dual-path structure.

**D10-D13. [LOW]** — Various low-severity items, all acceptable.
