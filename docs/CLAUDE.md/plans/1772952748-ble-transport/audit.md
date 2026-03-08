# Audit: BLE Transport (NimBLE Nordic UART Service)

## Files Changed

Findings flagged in the following files:
- `firmware/src/transport.h`
- `firmware/src/ble_service.h`
- `firmware/src/ble_service.cpp`
- `firmware/src/main.cpp`
- `firmware/src/config.h`
- `companion/ble_transport.py`
- `companion/pixel_agents_bridge.py`

---

## 1. QA Audit

### [FIXED] Q1 — Ring buffer volatile insufficient (HIGH)
`volatile` alone does not guarantee memory ordering on dual-core ESP32. Changed to `std::atomic` with acquire/release.

### [FIXED] Q2 — Ring buffer data visibility (HIGH)
Buffer writes could be reordered past head update without proper barriers. Fixed by `memory_order_release` on head store.

### [FIXED] Q3 — Ring buffer size magic number (MED)
`RingBuffer<256>` was a magic number. Now uses `BLE_RING_BUF_SIZE` from config.h (increased to 512).

### Q4 — No ring buffer overflow metric (LOW)
Dropped bytes are silent. Could add a counter for debugging. Accepted as-is — overflow is extremely unlikely at 4Hz polling.

### [FIXED] Q10 — Old BleakClient not disconnected on reconnect (MED)
Previous client leaked if reconnect was attempted. Fixed by disconnecting old client before creating new one.

### [FIXED] Q12 — Substring device name match (MED)
`self._device_name in d.name` could match "PixelAgents2" or similar. Changed to exact equality.

### [FIXED] Q14 — Single Protocol instance shared across transports (HIGH)
Parser state would corrupt when partial messages arrived on different transports. Fixed by separate `serialProtocol` and `bleProtocol` instances.

---

## 2. Security Audit

### [FIXED] S1 — Memory ordering on ring buffer (HIGH)
See Q1. Fixed with std::atomic acquire/release.

### [FIXED] S3 — Ring buffer reset() race condition (HIGH)
`reset()` called from NimBLE disconnect callback raced with `pop()` in main loop. Fixed with deferred `requestReset()` + `drainIfNeeded()` pattern.

### S4 — Ring buffer size vs max message size (LOW)
256 bytes could theoretically overflow if many messages queued. Increased to 512 via named constant. Overflow drops bytes safely (checksum failure + resync).

### S5 — No BLE authentication/pairing (LOW)
BLE connection is unauthenticated. Anyone in range can connect and send protocol messages. Acceptable for this use case (desk display, no sensitive data).

### [FIXED] S7 — NimBLE API null returns unchecked (MED)
`createServer()`, `createService()`, etc. could return nullptr. Fixed with null checks and early returns.

### [FIXED] S9 — Shared protocol parser state (HIGH)
See Q14. Fixed with separate Protocol instances.

---

## 3. Interface Contract Audit

### [FIXED] I2 — Shared parser state corruption (HIGH)
See Q14/S9.

### [FIXED] I5 — Substring device name match (MED)
See Q12.

### I6 — BLE MTU vs protocol message size (LOW)
Largest message (~30 bytes with framing) fits within default BLE ATT MTU (23 bytes payload) via L2CAP fragmentation. MTU negotiation (128) reduces fragmentation overhead. No action needed.

---

## 4. State Management Audit

### [FIXED] M1 — Ring buffer reset race (HIGH)
See S3.

### [FIXED] M2 — Shared Protocol instances (HIGH)
See Q14.

### [FIXED] M5 — Old BleakClient leak on reconnect (MED)
See Q10.

### [FIXED] M7 — Companion state not reset on BLE reconnect (MED)
`last_states`, `last_usage_data`, `_last_count` now cleared on BLE connect to ensure firmware gets full resync.

---

## 5. Resource & Concurrency Audit

### [FIXED] R1 — Ring buffer memory barriers (HIGH)
See Q1/S1.

### [FIXED] R2 — Ring buffer reset race (HIGH)
See S3/M1.

### [FIXED] R3 — Shared Protocol instance (HIGH)
See Q14.

### R4 — BLE advertising after disconnect (LOW)
`NimBLEDevice::startAdvertising()` called in disconnect callback. This is standard NimBLE practice and documented as safe from callback context.

---

## 6. Testing Coverage Audit

### T1 — No unit tests for ring buffer (MED)
Lock-free ring buffer has no automated tests. Template is simple enough for visual inspection but would benefit from a host-side test harness. Accepted as-is — testing checklist covers hardware verification.

### T2 — No BLE integration test (MED)
BLE transport requires hardware. Added items to testing checklist for manual verification.

---

## 7. DX & Maintainability Audit

### [FIXED] D3 — Magic number for BLE MTU (MED)
`128` in `NimBLEDevice::setMTU()`. Now uses `BLE_MTU` from config.h.

### [FIXED] D4 — "PixelAgents" duplicated in 4 places (MED)
Device name appeared in ble_service.cpp (2x), ble_transport.py, and pixel_agents_bridge.py. Firmware now uses `BLE_DEVICE_NAME` from config.h. Python uses constructor parameter with same default.

### [FIXED] D6 — Ring buffer size magic number (MED)
See Q3.

### [FIXED] D8 — BLE send exception swallowed (MED)
Bare `except Exception` in `send()` hid errors. Now logs exception message.

### [FIXED] D13 — "Serial protocol ready" splash log inaccurate (LOW)
Changed to "Protocol ready" since both serial and BLE protocol instances are initialized.

### D14 — No BLE subsystem documentation in CLAUDE.md (MED)
CLAUDE.md needs updating with BLE subsystem, new files, and architecture changes. To be done as part of version bump.

### [FIXED] D16 — Shared Protocol instance (HIGH)
See Q14.
