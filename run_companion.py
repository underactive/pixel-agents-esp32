#!/usr/bin/env python3
"""Cross-platform launcher for the Pixel Agents companion bridge.

Creates a virtual environment, installs dependencies, and runs the bridge.
All CLI arguments are forwarded to pixel_agents_bridge.py.

Usage:
    python3 run_companion.py [--port /dev/cu.usbmodemXXXX] [--transport ble] [...]
"""

import hashlib
import os
import platform
import subprocess
import sys
from pathlib import Path

MIN_PYTHON = (3, 8)
VENV_DIR_NAME = ".venv"
DEPS_STAMP_NAME = ".deps-stamp"


def get_venv_python(venv_dir: Path) -> Path:
    """Return the OS-appropriate Python binary path inside a venv."""
    if platform.system() == "Windows":
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def ensure_venv(companion_dir: Path) -> Path:
    """Create a virtual environment if needed. Returns path to venv Python."""
    venv_dir = companion_dir / VENV_DIR_NAME
    venv_python = get_venv_python(venv_dir)

    # Check for corrupted venv (directory exists but python binary is missing/broken)
    if venv_dir.exists():
        if venv_python.exists():
            return venv_python
        print(f"Venv at {venv_dir} appears corrupted (missing python binary). Recreating...")
        import shutil
        shutil.rmtree(venv_dir)

    print(f"Creating virtual environment at {venv_dir}...")
    try:
        subprocess.run(
            [sys.executable, "-m", "venv", str(venv_dir)],
            check=True,
        )
    except subprocess.CalledProcessError:
        # On Debian/Ubuntu, python3-venv may not be installed
        if platform.system() == "Linux":
            print(
                "\nFailed to create venv. On Debian/Ubuntu, install the venv module:\n"
                f"  sudo apt install python{sys.version_info[0]}.{sys.version_info[1]}-venv\n"
            )
        sys.exit(1)

    if not venv_python.exists():
        print(f"Error: venv created but Python not found at {venv_python}")
        sys.exit(1)

    return venv_python


def deps_up_to_date(companion_dir: Path) -> bool:
    """Check if installed deps match the current requirements.txt hash."""
    requirements = companion_dir / "requirements.txt"
    stamp_file = companion_dir / VENV_DIR_NAME / DEPS_STAMP_NAME

    if not stamp_file.exists():
        return False

    current_hash = hashlib.sha256(requirements.read_bytes()).hexdigest()
    stored_hash = stamp_file.read_text().strip()
    return current_hash == stored_hash


def install_deps(venv_python: Path, companion_dir: Path) -> None:
    """Install dependencies from requirements.txt and write a stamp file."""
    requirements = companion_dir / "requirements.txt"
    print("Installing dependencies...")
    try:
        subprocess.run(
            [str(venv_python), "-m", "pip", "install", "-q", "-r", str(requirements)],
            check=True,
        )
    except subprocess.CalledProcessError:
        print("\nError: Failed to install dependencies. Check the output above for details.")
        sys.exit(1)

    # Write stamp file with hash of requirements.txt
    stamp_file = companion_dir / VENV_DIR_NAME / DEPS_STAMP_NAME
    current_hash = hashlib.sha256(requirements.read_bytes()).hexdigest()
    stamp_file.write_text(current_hash)


def main() -> None:
    # Check Python version
    if sys.version_info < MIN_PYTHON:
        print(
            f"Error: Python {MIN_PYTHON[0]}.{MIN_PYTHON[1]}+ is required "
            f"(found {sys.version_info[0]}.{sys.version_info[1]})"
        )
        sys.exit(1)

    # Resolve paths relative to this script, not cwd
    project_root = Path(__file__).resolve().parent
    companion_dir = project_root / "companion"
    bridge_script = companion_dir / "pixel_agents_bridge.py"

    requirements = companion_dir / "requirements.txt"

    if not bridge_script.exists():
        print(f"Error: Bridge script not found at {bridge_script}")
        sys.exit(1)

    if not requirements.exists():
        print(f"Error: Requirements file not found at {requirements}")
        sys.exit(1)

    # Ensure venv exists
    venv_python = ensure_venv(companion_dir)

    # Install/update deps if needed
    if not deps_up_to_date(companion_dir):
        install_deps(venv_python, companion_dir)

    # Build command: venv python + bridge script + forwarded args
    cmd = [str(venv_python), str(bridge_script)] + sys.argv[1:]

    # On Unix, exec replaces this process (preserves stdin/stdout for keyboard input)
    if platform.system() != "Windows":
        os.execvp(str(venv_python), cmd)
    else:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
