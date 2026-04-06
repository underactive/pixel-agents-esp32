# Audit Report: Web Serial Firmware Flasher

## Files Changed

- `tools/firmware_update.html`

---

## 1. QA Audit

**Q1. [FIXED] [Medium] `reportProgress` callback does not track multi-file offset correctly (lines 864-871)**
In "Full Flash" mode with 4 files, the progress bar jumped back to ~5% at the start of each file. Fixed by distributing the 90% flash range evenly across files using `fileIndex`.

**Q2. [FIXED] [Medium] `binaryToEsptoolString` builds string via O(n^2) concatenation**
For large firmware images (16MB), repeated `str +=` causes quadratic work. Fixed by collecting chunks in an array and joining at the end.

**Q3. [FIXED] [Low] `fileInput.multiple` not initialized to match default mode**
The HTML had `multiple` attribute set while default mode is "Update Firmware Only" (single file). Fixed by removing the `multiple` attribute from the HTML default.

**Q4. [Low] `validateFiles` calls `setState('idle')` when files are removed**
The state variable accurately reflects the UI. No functional bug — cosmetic only.

**Q5. [FIXED] [Low] No maximum file size validation**
Files of arbitrary size could exhaust browser memory. Fixed by adding a 16MB cap with user-facing error.

**Q6. [Low] `escapeHtml` creates a DOM element on every call**
Performance impact negligible at expected log volume. Accepted as-is.

**Q7. [FIXED] [Low] No guard against double-click on "Confirm & Flash"**
Fixed by adding a `flashing` boolean guard with early return in `doFlash()`.

**Q8. [Low] CDN dependency means the tool fails silently if offline**
Acknowledged in plan risks. The page won't function without the CDN-loaded esptool-js module. A visible error state for module load failure would be a future improvement.

---

## 2. Security Audit

**S1. [Low] XSS via `innerHTML` in `setState` — terminal log propagation**
The defense is indirect (`escapeHtml` in `addLog`). Currently safe, but fragile if future code appends raw HTML. Accepted — current code is safe.

**S2. [Low] XSS via `innerHTML` in `confirmSummary`**
All user-controlled values are escaped. Hardcoded constants are safe. Accepted.

**S3. [Low] `parseInt` without radix on `data-index`**
Values are always decimal integers from loop. Accepted.

**S4. [Low] Unbounded `logLines` array growth**
For a short-lived page session, unlikely to cause issues. Accepted.

**S5. [Low] `binaryToEsptoolString` chunking**
8192 is well within safe limits. O(n^2) concatenation fixed (see Q2).

**S6. [FIXED] [Medium] No file size validation**
Fixed by adding 16MB cap (see Q5).

**S7. [Low] No validation that `selectedBoard` maps to valid `BOARDS` key**
Only settable from hardcoded `<option>` values. Accepted.

**S8. [FIXED] [Low] Transport resource leak on partial connect failure**
Fixed by adding `port.close()` to the error path cleanup.

---

## 3. Interface Contract Audit

**I1. [Low] `flashFreq` omitted from `writeFlash` call**
Defaults to existing flash frequency (equivalent to `'keep'`). Accepted — correct behavior.

**I2-I5. [None] API usage verified correct**
Transport constructor, ESPLoader constructor, `writeFlash` shape, `binaryToEsptoolString` format, and board flash offsets all match esptool-js v0.5.6 API.

**I6. [FIXED] [Medium] `port.close()` not called on success path**
Serial port could remain locked after successful flash. Fixed by adding `port.close()` after `transport.disconnect()` on the success path.

**I7. [Low] `beforeunload` handler calls async methods synchronously**
Inherent browser limitation — `beforeunload` doesn't support async. Best-effort cleanup. Accepted.

**I8. [Low] Connect timeout race leaves orphaned `esploader.main()` promise**
No cancellation mechanism available. The `transport.disconnect()` in the catch block should eventually cause it to fail. Accepted.

**I9. [Low] `fileInput.multiple` not managed in `resetAll()`**
Minor UX inconsistency. After "Flash Another", dropdowns retain values (reasonable UX). The `addFiles` function handles single/multiple correctly regardless. Accepted.

---

## 4. State Management Audit

**M1. [FIXED] [High] Concurrent flash operations not guarded**
No lock prevented double-click or re-entry. Fixed by adding `flashing` boolean guard with `finally` cleanup.

**M2. [FIXED] [Low] Stale terminal innerHTML in complete/error panels after reset**
Fixed by clearing `complete-terminal` and `error-terminal` innerHTML in `resetAll()`.

**M3. [FIXED] [Medium] Board/mode selection changes not guarded by state check**
Config mutations during flash could corrupt state. Fixed by adding `if (flashing) return` guard to both change handlers.

**M4. [FIXED] [Low] Board change handler missing `validateFiles()` call**
Added `validateFiles()` to the board change handler for consistency.

**M5. [FIXED] [Low] `btnCancel` returns to `parsed` unconditionally**
Changed cancel handler to call `validateFiles()` instead of `setState('parsed')` for proper re-validation.

**M6. [FIXED] [Low] Multi-file progress tracking**
Same as Q1. Fixed by weighting progress by file index.

---

## 5. Resource & Concurrency Audit

**R1. [FIXED] [Medium] No guard against concurrent flash operations**
Same as M1. Fixed.

**R2. [FIXED] [Medium] Serial port not closed on `beforeunload`**
Added `beforeunload` handler that attempts to disconnect transport and close port. Module-level `activeTransport` and `activePort` refs enable cleanup.

**R3. [Low] Transport disconnect error swallowed without logging**
On both success and error paths, disconnect failures are caught and ignored. Adding warn-level logging would be marginal improvement. Accepted — the comment explains rationale.

**R4. [FIXED] [Medium] No timeout on bootloader connection**
`esploader.main()` could hang indefinitely. Fixed by wrapping in `Promise.race` with a 30-second timeout and actionable error message.

**R5. [FIXED] [Low] `btnConfirm` not disabled after click**
Addressed by the `flashing` guard (R1/M1) — `doFlash()` returns immediately on re-entry.

---

## 6. Testing Coverage Audit

**T1. [Medium] Missing test: baud rate selection behavior**
The baud rate selector exists but no checklist item verifies it affects flash or shows in confirmation.

**T2. [Medium] Missing test: full flash mode file slot auto-detection for all slots**
Only `bootloader.bin` and `firmware.bin` mentioned. Missing: `partitions.bin` → 0x08000, `boot_app0.bin` → 0x0e000, unrecognized name → firmware offset.

**T3. [Medium] Missing test: full flash mode slot deduplication**
Adding two files matching the same slot should replace, not duplicate.

**T4. [Medium] Missing test: switching from full flash to update mode truncates file list**

**T5. [Medium] Missing test: switching board re-assigns flash offsets for existing files**

**T6. [Low] Missing test: non-.bin file rejection via drag-and-drop**

**T7. [Low] Missing test: large file handling (2MB+)**

**T8. [Low] Test quality: file offset checklist item combines two boards in one item**

**T9. [Low] Missing test: terminal auto-scroll behavior**

**T10. [Low] Missing test: progress bar percentages during multi-file flash**

**T11. [Medium] Missing test: esptool-js CDN dependency / offline behavior**

**T12. [Low] Missing test: confirmation summary shows total file size**

**T13. [Medium] Integration gap: board flash offsets not validated against platformio.ini**

**T14. [Low] Missing test: update mode restricts to single file**

**T15. [Low] Missing test: copy log with empty log**

---

## 7. DX & Maintainability Audit

**D1. [Medium] `doFlash()` is ~120 lines long**
Could be decomposed into sub-functions. Accepted for now — the linear flow is clear and this is a single-file tool.

**D2. [Low] Magic number `8192` in chunk size without constant name**
Accepted — comment explains purpose (stack overflow avoidance).

**D3. [Low] Magic number `30` in auto-scroll threshold**
Accepted — standard scroll detection threshold.

**D4. [Low] Magic numbers in progress scaling (5, 90, 97)**
Accepted — inline values are clear in context.

**D5. [FIXED] [Low] `calculateMD5Hash` callback returns undefined**
Removed the unnecessary callback entirely.

**D6. [Low] `$` function shadows jQuery/console convention**
Accepted — no jQuery in this file, standard pattern in standalone tools.

**D7. [Low] `terminalAutoScroll` coupling not documented**
Accepted — the coupling is straightforward.

**D8. [Medium] `setState` mixes state transitions with DOM cloning**
Accepted — minor coupling in a single-file tool.

**D9. [Low] Mode change handler does multiple things**
Accepted — each step is a single line.

**D10. [FIXED] [Low] File inventory not updated in CLAUDE.md**
Already addressed during implementation — `tools/firmware_update.html` added to File Inventory.
