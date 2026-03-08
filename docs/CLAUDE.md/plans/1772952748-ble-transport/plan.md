# Plan: BLE Transport (NimBLE Nordic UART Service)

## Objective

Add Bluetooth Low Energy as an alternative transport to USB serial, allowing the CYD to operate untethered (power-only USB) on a corporate network without exposing any network ports. Uses the Nordic UART Service (NUS) profile over NimBLE-Arduino for point-to-point communication between the companion bridge (Mac) and the ESP32 (CYD).

**Screenshots are serial-only** — the BLE transport does not support `SCREENSHOT_REQ` messages. The existing binary protocol is otherwise unchanged.

## Architecture

```
[Companion Mac]                              [ESP32 CYD]
  pixel_agents_bridge.py                       main.cpp
         |                                        |
    BleTransport (bleak)  --- BLE NUS --->   ble_transport.cpp
         |                                        |
    writes to NUS RX char                   NUS RX callback
         |                                        |
    same binary protocol                    feeds bytes to Protocol
    (0xAA 0x55 framing)                     parser (same as Serial)
```

The ESP32 acts as a BLE **peripheral** (server) advertising a Nordic UART Service. The companion acts as a BLE **central** (client) that discovers and connects to it.

### Transport Abstraction

Currently `protocol.cpp` calls `Serial.available()` / `Serial.read()` directly. We introduce a minimal `Transport` interface so the protocol parser can read bytes from either Serial or BLE without knowing which is active.

```cpp
// transport.h
class Transport {
public:
    virtual int available() = 0;
    virtual int read() = 0;
    virtual ~Transport() = default;
};
```

Two implementations:
- `SerialTransport` — wraps `Serial.available()` / `Serial.read()` (trivial)
- `BleTransport` — reads from a ring buffer filled by the NUS RX characteristic callback

The `Protocol` class receives a `Transport*` instead of calling `Serial` directly. This is the only change to existing code — all parsing, dispatch, and callback logic stays identical.

### BLE NUS (Nordic UART Service)

Standard UUIDs:
- **Service:** `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- **RX Characteristic (write):** `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` — companion writes to this
- **TX Characteristic (notify):** `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` — ESP32 could notify (unused for now, reserved for future bidirectional messages)

### Ring Buffer for BLE → Protocol

BLE characteristic write callbacks run in the NimBLE task context, not the Arduino `loop()` context. Data must be safely transferred between contexts. A fixed-size lock-free ring buffer (single producer / single consumer) handles this:

- **Producer:** NimBLE RX characteristic `onWrite()` callback pushes received bytes
- **Consumer:** `BleTransport::available()` / `read()` called from `loop()` via `protocol.process()`
- **Size:** 256 bytes (matches `SERIAL_BUF_SIZE`) — sufficient for the largest message (~30 bytes)

### Connection State

- BLE connection/disconnection events update a `_bleConnected` flag
- The office state's heartbeat/disconnection logic is transport-agnostic (it already works on heartbeat timeout, not transport state)
- When BLE disconnects, the ring buffer is drained/reset to prevent stale data on reconnect
- BLE and Serial can both be active simultaneously — protocol parser processes bytes from whichever transport has data

### Screenshot Exclusion

- `SCREENSHOT_REQ` (0x06) is **not** filtered at the protocol layer — the protocol still parses it
- The renderer's `sendScreenshot()` and `sendSplashScreenshot()` functions use `Serial.write()` directly — these remain serial-only, which is correct
- The companion's BLE transport simply never sends `SCREENSHOT_REQ` messages
- The 's' key screenshot shortcut is only available when connected via serial

## Changes

### New files

#### `firmware/src/transport.h`
- `Transport` abstract base class: `available()`, `read()`
- `SerialTransport` class wrapping `Serial`
- `RingBuffer` template class (fixed-size, single-producer/single-consumer, ISR-safe)
- `BleTransport` class: owns a `RingBuffer<256>`, exposes `available()`/`read()`, provides `push(const uint8_t*, size_t)` for the NUS callback

#### `firmware/src/ble_service.h` / `firmware/src/ble_service.cpp`
- `BleService` class:
  - `begin(BleTransport& transport)` — initializes NimBLE, creates NUS service/characteristics, starts advertising
  - `isConnected()` — returns connection state
  - NUS RX `onWrite()` callback pushes bytes into the `BleTransport` ring buffer
  - Connection/disconnection server callbacks update state and reset ring buffer on disconnect
- Compiled only when `HAS_BLE` build flag is defined (CYD-only initially, could be extended)
- Device advertises as `"PixelAgents"` (discoverable name)

#### `companion/ble_transport.py`
- `BleTransport` class:
  - `scan()` — discover `"PixelAgents"` device by name using `bleak`
  - `connect()` — connect to discovered device
  - `send(data: bytes)` — write to NUS RX characteristic
  - `disconnect()` — clean disconnect
  - `is_connected` property
- Async internally (bleak is asyncio-based), but exposes synchronous `send()` via `asyncio.run_coroutine_threadsafe()` on a background event loop thread

### Modified files

#### `firmware/src/protocol.h`
- Add `#include "transport.h"`
- Change `process()` to `process(Transport& transport)` — takes a transport reference instead of calling `Serial` directly
- Remove the `void process()` no-arg overload

#### `firmware/src/protocol.cpp`
- In `process()`: replace `Serial.available()` → `transport.available()`, `Serial.read()` → `transport.read()`
- No other changes — parser logic, dispatch, callbacks all identical

#### `firmware/src/main.cpp`
- Add `#include "transport.h"` and conditionally `#include "ble_service.h"`
- Create `SerialTransport serialTransport;` (always)
- Create `BleTransport bleTransport;` and `BleService bleService;` (under `#if defined(HAS_BLE)`)
- In `setup()`: after `Serial.begin()`, conditionally call `bleService.begin(bleTransport)`
- In `loop()`: call `protocol.process(serialTransport)` always, and conditionally `protocol.process(bleTransport)` — both transports processed each iteration
- Update splash log: `"BLE advertising"` after BLE init
- Screenshot sending remains unchanged (serial-only, no transport abstraction needed)

#### `firmware/platformio.ini`
- In `[env:cyd-2432s028r]`:
  - Add `-DHAS_BLE=1` to `build_flags`
  - Add `h2zero/NimBLE-Arduino@^2.1.0` to `lib_deps`
  - Add `-DCONFIG_BT_NIMBLE_MAX_CONNECTIONS=1` to limit BLE memory usage (only one companion connects)
  - Add `-DCONFIG_BT_NIMBLE_ROLE_BROADCASTER=0` and `-DCONFIG_BT_NIMBLE_ROLE_CENTRAL=0` to disable unused BLE roles and save flash/RAM
- LILYGO environment: no BLE changes (ESP32-S3 BLE support can be added later if needed)

#### `companion/pixel_agents_bridge.py`
- Add `--transport` CLI argument: `serial` (default) or `ble`
- Add `--ble-name` CLI argument: device name to scan for (default `"PixelAgents"`)
- When `--transport ble`:
  - Import and use `BleTransport` instead of `serial.Serial`
  - `connect()` scans and connects via BLE
  - `send()` writes to BLE transport
  - Screenshot shortcut ('s' key) is disabled with a message explaining it's serial-only
  - Reconnection logic: on disconnect, re-scan and reconnect
- When `--transport serial`: behavior is unchanged (current code)
- Extract `send()` to use a transport interface so heartbeat/usage/agent update code doesn't care which transport is active

#### `companion/requirements.txt`
- Add `bleak>=0.21.0` (BLE library for Python, asyncio-based, cross-platform)

### Not changed

- `firmware/src/renderer.cpp` — screenshot `Serial.write()` calls stay as-is
- `firmware/src/config.h` — no new protocol constants needed
- `firmware/src/office_state.h/.cpp` — transport-agnostic already
- `firmware/src/splash.h/.cpp` — no changes

## Dependencies

1. `transport.h` must exist before `protocol.h` changes (protocol depends on Transport interface)
2. `ble_service.h/.cpp` depends on `transport.h` (needs BleTransport)
3. `protocol.h/.cpp` changes and `main.cpp` changes can be done together after transport.h
4. `companion/ble_transport.py` is independent of firmware changes
5. `platformio.ini` changes needed before firmware compiles with NimBLE

**Recommended implementation order:**
1. `firmware/src/transport.h` (ring buffer + transport interface)
2. `firmware/platformio.ini` (add NimBLE dependency + build flags)
3. `firmware/src/protocol.h` + `firmware/src/protocol.cpp` (use Transport interface)
4. `firmware/src/ble_service.h` + `firmware/src/ble_service.cpp` (NimBLE NUS setup)
5. `firmware/src/main.cpp` (wire it all together)
6. `companion/ble_transport.py` (Python BLE client)
7. `companion/pixel_agents_bridge.py` (add --transport flag)
8. `companion/requirements.txt` (add bleak)

## Risks / Open Questions

1. **CYD memory under NimBLE** — Research indicates ~150KB total (flash + runtime heap). Current firmware uses 765KB/1311KB flash and 25KB/328KB RAM static. Should fit, but needs verification with an actual build. If tight, consider switching to `min_spiffs.csv` partition table for more app flash.

2. **NimBLE task stack size** — NimBLE runs its own FreeRTOS task. Default stack may need tuning via `CONFIG_BT_NIMBLE_TASK_STACK_SIZE` if callbacks are complex. Our callback is trivial (memcpy into ring buffer), so default should be fine.

3. **BLE MTU and message fragmentation** — Default BLE MTU is 23 bytes (20 bytes payload). Our largest message (AGENT_UPDATE with 24-byte tool name) is ~30 bytes including framing. NimBLE handles L2CAP fragmentation transparently, but we should request a larger MTU (e.g., 128) during connection to avoid fragmentation overhead. This is handled by `NimBLEDevice::setMTU()` on the server side and MTU negotiation on the bleak client side.

4. **Ring buffer overflow** — If the protocol parser can't keep up with incoming BLE data, the ring buffer could overflow. At 4Hz polling with tiny messages, this is extremely unlikely. The ring buffer silently drops bytes on overflow (safe — the protocol parser will discard the partial frame via checksum failure and resync on the next frame).

5. **Bleak on macOS** — bleak uses CoreBluetooth on macOS, which requires the Python process to have Bluetooth permissions. The user may need to grant permission in System Settings > Privacy > Bluetooth. First-run discovery may take a few seconds.

6. **Simultaneous Serial + BLE** — Both transports feed the same protocol parser and office state. Two companions could theoretically connect simultaneously (one serial, one BLE) and both would work. This is intentional — it allows serial debugging while BLE is active.

7. **BLE advertising power** — Default NimBLE TX power should be fine for desk distance (~1-3m). No need to configure unless range issues appear.
