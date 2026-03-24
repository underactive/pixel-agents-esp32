# Implementation: Cross-Platform Companion Launcher Script

## Files Changed

- `run_companion.py` -- Created: cross-platform launcher script
- `README.md` -- Updated section 4 "Start the Companion Bridge"
- `CLAUDE.md` -- Updated Quick Start block and File Inventory table
- `companion/requirements.txt` -- No permanent changes (temporarily modified for testing)

## Summary

Created `run_companion.py` at project root that:
1. Checks Python >= 3.8
2. Creates venv at `companion/.venv/` if missing (with corrupted venv detection/recreation)
3. Detects missing `python3-venv` on Debian/Ubuntu and prints install instructions
4. Installs deps only when `requirements.txt` hash changes (stamp file at `.deps-stamp`)
5. Uses `os.execvp` on Unix (replaces process for clean stdin/stdout) and `subprocess.run` on Windows
6. Forwards all CLI args to `pixel_agents_bridge.py`

No deviations from plan.

## Verification

1. Fresh run (deleted `.venv/`): venv created, deps installed, bridge `--help` output shown
2. Subsequent run: no "Creating" or "Installing" messages, instant launch
3. Args passthrough: `--help` correctly forwarded to bridge
4. Changed deps: modified `requirements.txt`, pip re-ran automatically
5. Script is executable (`chmod +x`)

## Follow-ups

None identified.

## Audit Fixes

### Fixes applied

1. **Added `requirements.txt` existence check** — addresses QA-1, IC-1, DX-1. Added guard with clear error message before `deps_up_to_date()` is called, consistent with existing `bridge_script.exists()` check.
2. **Added pip install error handling** — addresses QA-3, IC-2. Wrapped `subprocess.run(..., check=True)` in try/except with a friendly message, consistent with venv creation error handling.
3. **Updated CLAUDE.md prerequisites** — addresses DX-2. Removed stale `pyserial (pip install pyserial)` manual instruction, replaced with note that deps are installed automatically.

### Unresolved (accepted)

- QA-2: `shutil.rmtree` PermissionError on Windows — primarily macOS/Linux project
- QA-4: `os.execvp` OSError — extremely unlikely after venv module creates the binary
- SM-1/SM-2: Non-atomic stamp write and TOCTOU — benign failure modes (redundant pip install)
- SM-3: Concurrent run race — single-user CLI launcher, not an expected scenario

### Verification checklist

- [ ] Run `python3 run_companion.py` with `requirements.txt` deleted — should print clear error and exit
- [ ] Run `python3 run_companion.py` with a broken package in `requirements.txt` — should print friendly error after pip output
