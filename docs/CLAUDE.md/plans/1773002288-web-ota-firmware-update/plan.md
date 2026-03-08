# Plan: Web Serial Firmware Flasher (Browser-Based, Like Ghost-Operator)

## Context

The project requires USB flashing via PlatformIO CLI for firmware updates. The user wants a browser-based flasher like their ghost-operator project: plug in USB, open a web page, select firmware, click flash. No WiFi AP on the device, no firmware changes — the browser talks directly to the ESP32 ROM bootloader via Web Serial API.

This is the same pattern as ghost-operator (Web Serial + Nordic DFU), but for ESP32 (Web Serial + esptool protocol). The ESP32 ROM bootloader is always present and can't be bricked, making this approach inherently safe.

## Approach

**Standalone HTML page using esptool-js (Espressif's official JS esptool) + Web Serial API.** Reuse ghost-operator's UI patterns (state machine, terminal log, progress bar, dark theme styling) adapted from Vue to vanilla HTML/JS.

### Key Decisions

1. **Zero firmware changes** — The ESP32 ROM bootloader handles everything. No WiFi, WebServer, OTA partitions, or conditional compilation needed on the device side.

2. **esptool-js for protocol** — Espressif's official JavaScript implementation of the esptool serial protocol. Handles SLIP framing, bootloader sync, chip detection, flash erase/write, compression, and reset. Loaded from CDN (`https://esm.sh/esptool-js`).

3. **Standalone HTML** — Single file at `tools/firmware_update.html`, consistent with existing `tools/sprite_validation.html` and `tools/layout_editor.html`. No build tooling needed.

4. **Ghost-operator UI reuse** — Same state machine flow, terminal log with timestamps, progress bar, dark theme, copy-log button. Converted from Vue to vanilla JS.

5. **Board-aware flashing** — User selects board (CYD or LILYGO) which determines flash offsets. For "full flash" (first time or partition change), flashes bootloader + partitions + firmware at correct offsets. For "update only", flashes just firmware.bin at 0x10000.

## Ghost-Operator Code Reuse

### Directly reused (adapted from Vue to vanilla JS):
| Ghost-Operator File | What's Reused |
|---------------------|---------------|
| `FirmwareUpdate.vue` (template + styles) | State machine flow, HTML structure, all CSS (dark theme, progress bar, terminal log, spinner, buttons, file input styling) |
| `FirmwareUpdate.vue` (script) | `onFileSelect()` validation, `confirmUpdate()` orchestration, `reset()`, `copyLog()`, `scrollIfAtBottom()`, terminal log data model |
| `dfu/serial.js` | `isWebSerialAvailable()` check (one-liner) |

### Replaced by esptool-js:
| Ghost-Operator File | Replacement |
|---------------------|-------------|
| `dfu/dfu.js` | `ESPLoader.writeFlash()` — esptool-js handles the entire flash protocol |
| `dfu/serial.js` | `Transport` class from esptool-js wraps Web Serial |
| `dfu/slip.js` | esptool-js handles SLIP framing internally |
| `dfu/crc16.js` | esptool-js handles checksums internally |
| `dfu/zip.js` | Not needed — ESP32 uses `.bin` files, not `.zip` DFU packages |
| `store.js` `startSerialDfu()` | Simplified — no "reboot to DFU" command needed, ESP32 auto-enters bootloader via DTR/RTS |

## State Machine

Simplified from ghost-operator (no "rebooting" or "waiting-port" states needed):

```
idle → parsed → confirm → connecting → flashing → complete
                                ↘        ↘
                                 error ←←←←
```

| State | UI | Ghost-Operator Equivalent |
|-------|-----|--------------------------|
| `idle` | File picker + board selector | Same |
| `parsed` | File info + "Start Flash" button | Same |
| `confirm` | Warning + "Confirm" button | Same |
| `connecting` | Spinner + "Connecting to bootloader..." | `rebooting` + `waiting-port` (combined — esptool handles port selection + bootloader entry in one step) |
| `flashing` | Progress bar + terminal log | `transferring` |
| `complete` | Success message | Same |
| `error` | Error message + "Try Again" | Same |

## Flash Flow

```
1. User opens tools/firmware_update.html in Chrome/Edge
2. Selects board type (CYD or LILYGO) from dropdown
3. Selects flash mode: "Full Flash" or "Update Firmware Only"
4. Picks .bin file(s) via file picker
5. Clicks "Start Flash"
6. Confirms warning dialog
7. Browser prompts for serial port selection (Web Serial API)
8. esptool-js:
   a. Opens port, toggles DTR/RTS to enter ROM bootloader
   b. Syncs with bootloader (sends sync frame)
   c. Detects chip type
   d. Erases flash regions
   e. Writes firmware in compressed chunks
   f. Verifies MD5
   g. Hard resets device
9. Terminal log shows each step with timestamps
10. Progress bar shows 0-100%
11. Device boots new firmware
```

## Changes

### New Files

| File | Purpose |
|------|---------|
| `tools/firmware_update.html` | Standalone browser-based firmware flasher |

**That's it.** One file. No firmware changes, no companion changes, no partition table changes, no build config changes.

### File Structure (inside `firmware_update.html`)

Single self-contained HTML file (~500-600 lines) with:

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    /* Ghost-operator dark theme CSS — adapted from FirmwareUpdate.vue scoped styles */
    /* Terminal log, progress bar, buttons, file input, spinner, etc. */
  </style>
</head>
<body>
  <!-- Ghost-operator HTML structure — adapted from FirmwareUpdate.vue template -->
  <!-- Board selector (CYD / LILYGO dropdown) -->
  <!-- Flash mode selector (Full Flash / Update Only) -->
  <!-- File picker (.bin) -->
  <!-- State-driven UI (idle/parsed/confirm/connecting/flashing/complete/error) -->
  <!-- Terminal log with timestamps + copy button -->

  <script type="module">
    import { ESPLoader, Transport } from 'https://esm.sh/esptool-js';

    // Ghost-operator patterns: state machine, terminal log, progress callbacks
    // esptool-js: connect, detect chip, flash, reset
  </script>
</body>
</html>
```

### Board Configuration (embedded in HTML)

```javascript
const BOARDS = {
  'cyd': {
    name: 'CYD (ESP32-2432S028R)',
    chip: 'ESP32',
    flashSize: '4MB',
    // Full flash offsets
    bootloaderOffset: 0x1000,
    partitionsOffset: 0x8000,
    bootApp0Offset: 0xe000,
    firmwareOffset: 0x10000,
  },
  'lilygo': {
    name: 'LILYGO T-Display S3',
    chip: 'ESP32-S3',
    flashSize: '16MB',
    bootloaderOffset: 0x0,
    partitionsOffset: 0x8000,
    bootApp0Offset: 0xe000,
    firmwareOffset: 0x10000,
  }
};
```

### Flash Modes

**"Update Firmware Only"** (default, most common):
- User picks one file: `firmware.bin` from `.pio/build/<env>/`
- Flashed at offset 0x10000
- Fast — only writes the app partition

**"Full Flash"** (first time or partition table change):
- User picks up to 4 files: bootloader.bin, partitions.bin, boot_app0.bin, firmware.bin
- Each flashed at its correct offset
- Or: pick a single merged binary, flashed at offset 0x0

## JavaScript Implementation (key functions)

### Flash orchestration (replaces ghost-operator's `startSerialDfu`)

```javascript
async function flashFirmware(files, boardConfig, onProgress, onLog) {
  // 1. Request serial port (replaces ghost-operator's separate port selection step)
  onLog('Requesting serial port...', 'info');
  const port = await navigator.serial.requestPort();

  // 2. Create esptool transport + loader
  const transport = new Transport(port);
  const esploader = new ESPLoader({
    transport,
    baudrate: 115200,
    terminal: {
      clean() {},
      writeLine(data) { onLog(data, 'info'); },
      write(data) { /* partial line — buffer or ignore */ }
    }
  });

  // 3. Connect to bootloader (auto DTR/RTS reset)
  onLog('Connecting to bootloader...', 'info');
  onProgress(2, 'Connecting...');
  const chip = await esploader.main();
  onLog(`Detected ${chip}`, 'success');

  // 4. Flash each file at its offset
  onProgress(5, 'Flashing...');
  onLog('Starting flash...', 'info');

  await esploader.writeFlash({
    fileArray: files.map(f => ({ data: f.data, address: f.address })),
    flashSize: boardConfig.flashSize,
    compress: true,
    reportProgress: (fileIndex, written, total) => {
      const pct = 5 + Math.round((written / total) * 90);
      onProgress(pct, `Writing file ${fileIndex + 1}/${files.length}...`);
    }
  });

  // 5. Reset device
  onProgress(98, 'Resetting device...');
  onLog('Resetting device...', 'info');
  await esploader.hardReset();
  await transport.disconnect();

  onProgress(100, 'Flash complete!');
  onLog('Flash complete! Device is rebooting.', 'success');
}
```

### Terminal log (from ghost-operator `FirmwareUpdate.vue`)

```javascript
const startTime = performance.now();

function addLog(msg, level = 'info') {
  const elapsed = ((performance.now() - startTime) / 1000).toFixed(1);
  const line = document.createElement('div');
  line.className = 'dfu-terminal-line';
  line.innerHTML = `<span class="dfu-terminal-time">[${elapsed}s]</span>` +
                   `<span class="dfu-terminal-text dfu-log-${level}">${msg}</span>`;
  logContainer.appendChild(line);
  scrollIfAtBottom(logContainer);
}
```

## Risks

1. **esptool-js CDN availability** — If `esm.sh` is down, the page won't work. Mitigation: could vendor the library locally as a fallback, or note the CDN dependency in the page.

2. **esptool-js API stability** — The npm package API may change between versions. Mitigation: pin a specific version in the import URL (`https://esm.sh/esptool-js@0.5.0`).

3. **Browser compatibility** — Web Serial API only works in Chromium browsers (Chrome, Edge, Opera). Firefox and Safari do not support it. This is the same limitation as ghost-operator.

4. **DTR/RTS auto-reset** — Some ESP32 boards don't support auto-reset into bootloader via DTR/RTS. On these boards, the user must manually hold BOOT and press RESET. The CYD and LILYGO boards both support auto-reset.

5. **esptool-js module resolution from CDN** — If the ESM import doesn't work cleanly from CDN (some packages have Node.js-specific imports), we may need to bundle it or use an alternative like the Adafruit WebSerial ESPTool. Verify during implementation.

## Verification

1. Open `tools/firmware_update.html` in Chrome
2. Select "CYD" board, "Update Firmware Only" mode
3. Pick `.pio/build/cyd-2432s028r/firmware.bin`
4. Click "Start Flash" → "Confirm"
5. Select serial port when prompted
6. Verify terminal log shows: connect → chip detect → erase → write → verify → reset
7. Verify progress bar advances 0-100%
8. Verify device reboots and runs the new firmware
9. Repeat for LILYGO board
10. Test "Full Flash" mode with all 4 binary files
11. Test error cases: wrong file type, disconnect during flash, no serial port
