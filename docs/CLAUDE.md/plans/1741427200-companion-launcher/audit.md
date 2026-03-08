# Audit: Cross-Platform Companion Launcher Script

## Files Changed

- `run_companion.py`
- `README.md`
- `CLAUDE.md`

---

## 1. QA Audit

| # | Severity | Finding |
|---|----------|---------|
| QA-1 | Low | [FIXED] Missing `requirements.txt` causes unhandled `FileNotFoundError` at line 73. Added existence check. |
| QA-2 | Low | `shutil.rmtree` on corrupted venv can raise `PermissionError` on Windows. Accepted — primarily macOS/Linux project. |
| QA-3 | Low | [FIXED] `install_deps` pip failure produces raw traceback. Added try/except with friendly message. |
| QA-4 | Low | `os.execvp` failure is unhandled if venv python is not executable. Accepted — extremely unlikely after `venv` module creates it. |
| QA-5 | N/A | False positive — `run_companion.py` was already added to File Inventory. |

## 2. Security Audit

No issues found.

## 3. Interface Contract Audit

| # | Severity | Finding |
|---|----------|---------|
| IC-1 | Medium | [FIXED] Same as QA-1 — missing `requirements.txt` guard. |
| IC-2 | Low | [FIXED] Same as QA-3 — pip failure error handling. |

## 4. State Management Audit

| # | Severity | Finding |
|---|----------|---------|
| SM-1 | Low | Non-atomic stamp file write — worst case is a redundant `pip install`. Accepted. |
| SM-2 | Low | TOCTOU between hash check and hash write — self-corrects on next run. Accepted. |
| SM-3 | Medium | Concurrent runs can corrupt venv/pip state. Accepted — single-user CLI launcher, not expected to be invoked concurrently. |

## 5. Resource & Concurrency Audit

No issues found.

## 6. Testing Coverage Audit

No issues found. Project has no automated test suite; manual testing checklist covers the launcher.

## 7. DX & Maintainability Audit

| # | Severity | Finding |
|---|----------|---------|
| DX-1 | Low | [FIXED] Same as QA-1 — missing `requirements.txt` guard. |
| DX-2 | Low | [FIXED] CLAUDE.md prerequisites still listed `pyserial (pip install pyserial)` as manual step. Updated to reflect automated installation. |
