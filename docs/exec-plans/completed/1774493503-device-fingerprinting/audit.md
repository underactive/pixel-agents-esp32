# Device Fingerprinting — Audit Report

## Files Changed (with findings)

- `firmware/src/main.cpp` — RC-1 (broadcast to both transports), DX-5 (missing WHY comment)
- `companion/ble_transport.py` — SM-4 (rx_buf clear ordering)
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — SM-1/RC-3 (MainActor dispatch)
- `ARCHITECTURE.md` — DX-1 (stale protocol recipe)

## Findings

### 1. QA Audit
- No actionable bugs. The BLE `_try_identify` early-exit was verified as a false positive (the `else: break` only triggers when `self._ble is None`).

### 2. Security Audit
- S-1 (MEDIUM): Version encoding truncates patch values >= 10. Accepted — current scheme covers expected version range.
- S-12 (HIGH): ThermalManager obfuscated integrity check. **Pre-existing, not part of this change.** Noted for future follow-up.

### 3. Interface Contract Audit
- No issues. All implementations match the protocol spec across firmware, Python, and Swift.

### 4. State Management Audit
- [FIXED] SM-1 (MEDIUM): `handleIdentifyResponse` called from serial background queue without `@MainActor` dispatch. Fixed by wrapping in `Task { @MainActor in }`.
- [FIXED] SM-4 (MEDIUM): BLE `_rx_buf` cleared after `start_notify` subscription. Fixed by reordering: clear first, then subscribe.

### 5. Resource & Concurrency Audit
- [FIXED] RC-3 (MEDIUM): Same as SM-1, confirmed by this audit. Fixed.
- RC-1 (LOW): `sendIdentifyResponse()` broadcasts to both transports. Matches existing `sendSettingsState()` pattern — accepted by design.

### 6. Testing Coverage Audit
- TC-1 (HIGH): No Python test infrastructure exists. Noted as follow-up — out of scope for this feature.
- TC-2 (MEDIUM): No tests for `extractProtocolFrames`. Noted as follow-up.
- TC-6 (LOW): No version encoding boundary tests. Accepted — current test covers the active version.

### 7. DX & Maintainability Audit
- [FIXED] DX-1 (MEDIUM): Protocol recipe referenced stale "after 0x05". Updated to "after 0x0A".
- [FIXED] DX-5 (MEDIUM): Missing WHY comment for proactive identify on heartbeat. Added multi-line explanation.
- DX-2 (LOW): `Protocol::begin()` has 8 positional params. Accepted — refactoring to callback struct deferred to next protocol message addition.
- DX-8 (HIGH): ThermalManager obfuscated integrity check. **Pre-existing, not part of this change.**
- DX-10 (LOW): Duplicated frame parsing across serial/BLE transports. Accepted — matches existing pattern.
