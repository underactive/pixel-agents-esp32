# Implementation: BLE Transport (NimBLE Nordic UART Service)

## Files Changed

### New files
- `firmware/src/transport.h` — Transport abstract base class, SerialTransport, RingBuffer<SIZE> template, BleTransport
- `firmware/src/transport.cpp` — SerialTransport implementation wrapping Arduino Serial
- `firmware/src/ble_service.h` — BleService class declaration (compiled only with HAS_BLE)
- `firmware/src/ble_service.cpp` — NimBLE NUS server setup with connection/disconnect callbacks
- `companion/ble_transport.py` — Python BLE client using bleak with background asyncio event loop

### Modified files
- `firmware/src/config.h` — Added BLE_DEVICE_NAME, BLE_MTU, BLE_RING_BUF_SIZE constants
- `firmware/src/protocol.h` — Added `#include "transport.h"`, changed `process()` to take `Transport&`
- `firmware/src/protocol.cpp` — Replaced `Serial.available()`/`Serial.read()` with transport calls
- `firmware/src/main.cpp` — Added transport/BLE includes, separate Protocol instances per transport, splash drain lambda processes both transports, transport-neutral splash log
- `firmware/platformio.ini` — CYD env: added HAS_BLE, NimBLE config flags, NimBLE-Arduino lib dep
- `companion/pixel_agents_bridge.py` — Added --transport/--ble-name CLI args, transport-dispatching connect/send, BLE reconnect state reset, screenshot disabled over BLE
- `companion/requirements.txt` — Added bleak>=0.21.0

## Summary

Implemented BLE as an alternative transport to USB serial using NimBLE-Arduino on the ESP32 CYD. Key design decisions:

1. **Transport abstraction** — Introduced `Transport` base class so Protocol parser works identically with Serial or BLE. No changes to parsing/dispatch logic.
2. **Separate Protocol instances** — Each transport gets its own `Protocol` instance to prevent parser state corruption from interleaved partial messages.
3. **Lock-free SPSC ring buffer** — Uses `std::atomic` with acquire/release ordering for multi-core safety (NimBLE callback on one core, main loop on other).
4. **Deferred ring buffer reset** — On BLE disconnect, reset is flagged atomically and executed in main loop context to avoid racing with pop().
5. **NimBLE memory-optimized** — Disabled central/observer roles, limited to 1 connection, bringing total overhead to ~312KB flash + 15KB RAM.
6. **Screenshots remain serial-only** — BLE transport does not support SCREENSHOT_REQ.

### Deviations from plan
- Added separate `Protocol` instances per transport (plan assumed single instance was safe)
- Upgraded ring buffer from `volatile` to `std::atomic` (plan underspecified memory ordering)
- Ring buffer size increased from 256 to 512 bytes via named constant in config.h
- Added BLE_DEVICE_NAME, BLE_MTU, BLE_RING_BUF_SIZE constants to config.h (not in original plan)

## Verification

- CYD build: SUCCESS — Flash 82.2% (1,077,845B), RAM 12.2% (40,132B)
- LILYGO build: SUCCESS — no BLE code compiled (HAS_BLE not defined)
- Both boards build cleanly with all audit fixes applied

## Follow-ups

- LILYGO BLE support: add HAS_BLE to LILYGO environment when needed
- BLE TX characteristic: reserved but unused — could be used for bidirectional messages (e.g., firmware→companion status)
- BLE connection indicator: status bar could show BLE icon when connected via BLE (currently transport-agnostic)
- MTU negotiation logging: companion logs negotiated MTU but doesn't adapt message chunking

## Audit Fixes

### Fixes applied

1. **Separate Protocol instances** (S9/Q14/M2/R3/I2/D16 — HIGH): Created `serialProtocol` and `bleProtocol` in main.cpp to prevent parser state corruption from interleaved partial messages across transports.
2. **Ring buffer memory barriers** (S1/Q1/Q2/R1 — HIGH): Replaced `volatile` with `std::atomic<uint16_t>` using explicit `memory_order_acquire`/`memory_order_release` on all load/store operations for multi-core ESP32 safety.
3. **Ring buffer reset race** (S3/M1/R2 — HIGH): Changed from direct `reset()` in disconnect callback to `requestReset()` flag + deferred `drainIfNeeded()` in main loop context.
4. **NimBLE API null checks** (S7 — MED): Added null checks on `createServer()`, `createService()`, `createCharacteristic()`, `getAdvertising()` with early returns.
5. **Named BLE constants** (D3/D4/D6 — MED): Added `BLE_DEVICE_NAME`, `BLE_MTU`, `BLE_RING_BUF_SIZE` to config.h. Updated ble_service.cpp to use them. Updated transport.h to use `BLE_RING_BUF_SIZE`.
6. **Exact device name match** (Q12/I5 — MED): Changed `self._device_name in d.name` to `d.name == self._device_name` in ble_transport.py.
7. **Disconnect old BleakClient on reconnect** (Q10/M5 — MED): Added `await self._client.disconnect()` before creating new client in `_connect_async()`.
8. **BLE send exception logging** (D8 — MED): Changed bare `except Exception` to `except Exception as e` with `print(f"BLE send error: {e}")`.
9. **Companion state reset on BLE reconnect** (M7 — MED): Clear `last_states`, `last_usage_data`, and `_last_count` in `_connect_ble()` after successful connection.
10. **Transport-neutral splash log** (D13 — LOW): Changed "Serial protocol ready" to "Protocol ready".

### Verification checklist

- [x] Both board environments build successfully after all fixes
- [ ] BLE connection from macOS companion to CYD works (requires hardware)
- [ ] BLE reconnect after disconnect resends full state to firmware
- [ ] Exact device name match doesn't match partial names like "PixelAgents2"
- [ ] Ring buffer handles sustained 4Hz message rate without overflow
- [ ] Simultaneous serial + BLE operation doesn't corrupt protocol state
