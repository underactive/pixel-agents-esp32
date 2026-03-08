# Implementation: Web Serial Firmware Flasher

## Files Changed

- **`tools/firmware_update.html`** — Created. Standalone browser-based firmware flasher (~1060 lines).

## Summary

Implemented the plan as designed — a single self-contained HTML file that uses Web Serial API + esptool-js (Espressif's official JS library) to flash firmware to ESP32 devices directly from the browser.

### What was implemented:

- **State machine UI**: idle → parsed → confirm → connecting → flashing → complete → error
- **Board selection**: CYD (ESP32) and LILYGO (ESP32-S3) with correct flash offsets per board
- **Two flash modes**: "Update Firmware Only" (firmware.bin at 0x10000) and "Full Flash" (bootloader + partitions + boot_app0 + firmware at respective offsets)
- **File handling**: Drag-and-drop + click-to-select, auto-detects file slot by name (bootloader, partitions, boot_app0, firmware), shows file list with addresses
- **Baud rate selection**: 115200 (default), 230400, 460800, 921600
- **Terminal log**: Timestamped log output from esptool-js connection, chip detection, flash progress, and errors
- **Progress bar**: 0-100% with status text showing per-file progress
- **Confirmation dialog**: Shows board, mode, file count, total size before flashing
- **Copy log button**: Copies terminal log text to clipboard
- **Error handling**: Graceful handling of port cancellation, disconnect during flash, and esptool-js errors
- **Browser compatibility check**: Shows warning if Web Serial API is not available
- **Dark theme**: Catppuccin-inspired styling consistent with layout_editor.html

### Deviations from plan:

- File is ~1014 lines instead of estimated 500-600 (CSS styling and robust file handling added more code)
- Added baud rate selector (not in original plan, but useful for power users)
- esptool-js loaded from `unpkg.com` instead of `esm.sh` (unpkg provides the ESM lib build directly; esm.sh was mentioned in plan but unpkg is more reliable for this package)
- Version pinned to v0.5.6 (latest stable at implementation time)
- `flashMode: 'keep'` used in writeFlash to preserve existing flash mode setting
- Hard reset implemented via DTR toggle (same pattern as esptool-js example) rather than `esploader.hardReset()` which may not exist in all versions

## Verification

1. File created at `tools/firmware_update.html`
2. HTML structure validates (proper nesting, all IDs unique)
3. All state transitions covered (idle → parsed → confirm → connecting → flashing → complete/error)
4. esptool-js import URL resolves (`https://unpkg.com/esptool-js@0.5.6/lib/index.js`)
5. File data converted to binary string format expected by esptool-js `writeFlash`
6. Board offsets match PlatformIO configuration in `platformio.ini`

### Hardware verification pending:
- [ ] Flash CYD via Chrome with "Update Firmware Only" mode
- [ ] Flash LILYGO via Chrome with "Update Firmware Only" mode
- [ ] Test "Full Flash" mode with all 4 binary files
- [ ] Test error recovery (disconnect during flash, wrong file)
- [ ] Verify baud rates > 115200 work reliably

## Follow-ups

- Consider vendoring esptool-js locally for offline use (currently CDN-dependent)
- Could add firmware version detection (read flash and parse version string)
- Could add a "Download from CI" option to fetch latest firmware builds
- Consider adding flash verification (read-back and compare)

## Audit Fixes

Fixes applied after 7-subagent audit (QA, Security, Interface Contract, State Management, Resource & Concurrency, DX & Maintainability, Testing Coverage).

### Fixes applied

1. **Multi-file progress bar regression** (Q1/M6) — Progress bar now distributes the 90% flash range evenly across files using `fileIndex`, preventing sawtooth jumps.
2. **O(n^2) string concatenation** (Q2) — `binaryToEsptoolString` now collects chunks in an array and joins at the end.
3. **File size validation** (Q5/S6) — Added 16MB max file size cap with user-facing error message.
4. **Concurrent flash guard** (Q7/M1/R1) — Added `flashing` boolean with early return in `doFlash()` and `finally` cleanup.
5. **File input `multiple` attribute** (Q3) — Removed `multiple` from HTML default (matches "Update Firmware Only" default mode).
6. **Port cleanup on error** (S8) — Added `port.close()` to error path alongside `transport.disconnect()`.
7. **Port cleanup on success** (I6) — Added `port.close()` to success path after `transport.disconnect()`.
8. **Stale terminal cleanup** (M2) — `resetAll()` now clears `complete-terminal` and `error-terminal` innerHTML.
9. **Config change guard during flash** (M3) — Board and mode change handlers now early-return if `flashing` is true.
10. **Board change validation** (M4) — Added `validateFiles()` call to board change handler.
11. **Cancel button re-validation** (M5) — Cancel handler now calls `validateFiles()` instead of `setState('parsed')`.
12. **Bootloader connection timeout** (R4) — `esploader.main()` wrapped in `Promise.race` with 30-second timeout.
13. **Page unload cleanup** (R2) — Added `beforeunload` handler with module-level `activeTransport`/`activePort` refs.
14. **Removed unnecessary callback** (D5) — Removed `calculateMD5Hash` callback from `writeFlash` call.

### Verification checklist

- [ ] Multi-file flash (Full Flash mode with 4 files): progress bar advances smoothly from 5% to 95% without jumping back
- [ ] Large file (2MB+): no browser freeze during binary string conversion
- [ ] File > 16MB: rejected with error message
- [ ] Double-click "Confirm & Flash": only one flash operation starts
- [ ] Change board/mode during flash: changes are ignored (no crash)
- [ ] Cancel from confirmation: returns to correct state (idle if no files, parsed if files present)
- [ ] Disconnect during flash: error shown, serial port released (can re-select port)
- [ ] Successful flash: serial port released (companion bridge can connect immediately after)
- [ ] Bootloader not responding (wrong port): times out after 30s with helpful message
- [ ] "Flash Another" after completion: terminal panels cleared, ready for fresh flash
