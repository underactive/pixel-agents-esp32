# Plan: Cross-Platform Companion Launcher Script

## Objective

Starting the companion bridge currently requires 5 manual steps (cd, create venv, activate, pip install, run). Create a single `run_companion.py` at the project root that automates all of it cross-platform.

## Changes

| File | Action | Description |
|------|--------|-------------|
| `run_companion.py` | Create | Launcher script that auto-creates venv, installs deps, and runs bridge |
| `README.md` | Edit | Update section 4 to use `run_companion.py` |
| `CLAUDE.md` | Edit | Update Quick Start block and File Inventory table |

## Dependencies

None. Python is already a prerequisite.

## Risks / Open Questions

- The bridge itself uses `termios`/`tty`/`select` which are Unix-only, so full Windows support is a bridge concern, not a launcher concern.
- The launcher handles cross-platform setup correctly regardless.
