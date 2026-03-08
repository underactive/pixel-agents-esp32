# Audit: Screenshot Capture

## Files Changed

- `firmware/src/renderer.cpp` — R5, S5, R2, DM3
- `companion/pixel_agents_bridge.py` — S2, S3, T3a, IC-5, IC-6, IC-9, SM-2, SM-3

## Findings

### R5 — [FIXED] Stack buffer overflow in sendScreenshot() post-loop flush
**Severity:** HIGH
**File:** `firmware/src/renderer.cpp`

The post-loop code appends 8 bytes (last run + end marker) to `buf[256]` without checking remaining capacity. If `bufPos` is 249–252 after the loop, writing 8 more bytes overflows the stack buffer.

**Fix:** Added a flush check (`if (bufPos > 248)`) before the post-loop writes.

### S2/S3 — [FIXED] No bounds validation on width/height from serial
**Severity:** MEDIUM-HIGH
**File:** `companion/pixel_agents_bridge.py`

The companion accepted any width/height values from serial without sanity checking, potentially allocating unbounded memory.

**Fix:** Added `MAX_DIM = 1024` upper bound check on width and height.

### IC-6 — [FIXED] total_pixels not validated against width*height
**Severity:** LOW-MEDIUM
**File:** `companion/pixel_agents_bridge.py`

The header's `total_pixels` field was trusted without verifying it equals `width * height`, which could cause silent data corruption.

**Fix:** Added `total_pixels != width * height` consistency check after dimension validation.

### T3a — [FIXED] SerialException uncaught in receive path
**Severity:** MEDIUM
**File:** `companion/pixel_agents_bridge.py`

If the serial connection drops during screenshot receive, `serial.SerialException` would propagate uncaught and crash the companion.

**Fix:** Wrapped the receive logic in a try/except for `serial.SerialException`, printing an error message instead of crashing.

### S5/R2/IC-5 — sendScreenshot blocks main loop
**Severity:** MEDIUM
**File:** `firmware/src/renderer.cpp`

`sendScreenshot()` blocks for ~1–3s during serial TX. This could trigger the hardware watchdog on some ESP32 configurations.

**Status:** Accepted as-is. This is by design for infrequent manual use. ESP32 Arduino default watchdog timeout is 5s, and the screenshot completes within that window. The plan explicitly documented this as expected behavior.

### IC-9/SM-3 — Companion blocks heartbeats during receive
**Severity:** MEDIUM
**File:** `companion/pixel_agents_bridge.py`

The 15s screenshot timeout exceeds the 6s heartbeat watchdog. During screenshot receive, no heartbeats are sent, which could cause the status bar to flash "Disconnected" briefly.

**Status:** Accepted as-is. The ESP32 is also blocked in `sendScreenshot()` during this time, so it won't process heartbeats anyway. The watchdog will recover automatically after the screenshot completes.

### DM3/SM-2 — Side-effectful getter naming
**Severity:** LOW
**File:** `firmware/src/renderer.cpp`

`isScreenshotPending()` clears the flag as a side effect, which is unexpected for a getter-style name.

**Status:** Accepted as-is. The consume-on-read pattern is common in embedded systems for single-consumer flags. Renaming to `consumeScreenshotRequest()` would be more descriptive but adds churn for minimal benefit. The call site in `main.cpp` makes the intent clear.

### Other LOW findings

- **Volatile qualifier on `_screenshotRequested`**: Not needed since the flag is set and consumed in the same task context (main loop), not across ISR/task boundaries.
- **Terminal restore on hard crash**: Covered by `atexit` handler. Hard crashes (SIGKILL) can't be caught by any program. `stty sane` is the standard recovery.
- **Missing comments on header byte layout**: The plan documents the format; inline comments in the code describe each field.
