#!/usr/bin/env python3
"""
Pixel Agents Bridge — JSONL transcript watcher + ESP32 serial sender.

Watches Claude Code JSONL transcript files and sends binary protocol
messages to the ESP32 display over USB serial.

Usage:
    python3 pixel_agents_bridge.py [--port /dev/cu.usbmodemXXXX]
"""

import argparse
import glob
import json
import os
import select
import struct
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Set

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("Error: pyserial is required. Install with: pip install pyserial")
    sys.exit(1)

# Optional: PIL for PNG output (falls back to BMP)
try:
    from PIL import Image as PILImage
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

# ── Protocol Constants ───────────────────────────────────────
SYNC_BYTE_1 = 0xAA
SYNC_BYTE_2 = 0x55

MSG_AGENT_UPDATE = 0x01
MSG_AGENT_COUNT = 0x02
MSG_HEARTBEAT = 0x03
MSG_STATUS_TEXT = 0x04
MSG_USAGE_STATS = 0x05
MSG_SCREENSHOT_REQ = 0x06

# Screenshot response sync bytes (ESP32 → companion)
SCREENSHOT_SYNC1 = 0xBB
SCREENSHOT_SYNC2 = 0x66
SCREENSHOT_TIMEOUT_SEC = 15.0

# ── Agent States (must match firmware CharState enum) ────────
STATE_OFFLINE = 0
STATE_IDLE = 1
STATE_WALK = 2
STATE_TYPE = 3
STATE_READ = 4
STATE_SPAWN = 5
STATE_DESPAWN = 6

# ── Configuration ────────────────────────────────────────────
POLL_INTERVAL_SEC = 0.25  # 4 Hz
HEARTBEAT_INTERVAL_SEC = 2.0
STALE_AGENT_TIMEOUT_SEC = 30.0
SERIAL_BAUD = 115200
MAX_TOOL_NAME_LEN = 24
USAGE_STATS_INTERVAL_SEC = 10.0

# Tools that indicate reading behavior (vs typing/writing)
READING_TOOLS = {"Read", "Grep", "Glob", "WebFetch", "WebSearch"}

# Claude Code transcript directories
CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"
RATE_LIMITS_CACHE = Path.home() / ".claude" / "rate-limits-cache.json"


def find_esp32_port() -> Optional[str]:
    """Auto-detect ESP32 serial port on macOS."""
    patterns = [
        "/dev/cu.usbmodem*",
        "/dev/cu.usbserial*",
        "/dev/cu.wchusbserial*",
        "/dev/ttyUSB*",
        "/dev/ttyACM*",
    ]
    for pattern in patterns:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    # Fall back to pyserial detection
    ports = serial.tools.list_ports.comports()
    for port in ports:
        if "USB" in port.description or "CP210" in port.description:
            return port.device
    return None


def build_message(msg_type: int, payload: bytes) -> bytes:
    """Build a framed protocol message: [0xAA][0x55][TYPE][PAYLOAD][XOR_CHECK]"""
    checksum = msg_type
    for b in payload:
        checksum ^= b
    return bytes([SYNC_BYTE_1, SYNC_BYTE_2, msg_type]) + payload + bytes([checksum & 0xFF])


def build_agent_update(agent_id: int, state: int, tool_name: str = "") -> bytes:
    """Build AGENT_UPDATE message."""
    tool_bytes = tool_name.encode("utf-8")[:MAX_TOOL_NAME_LEN]
    payload = bytes([agent_id, state, len(tool_bytes)]) + tool_bytes
    return build_message(MSG_AGENT_UPDATE, payload)


def build_agent_count(count: int) -> bytes:
    """Build AGENT_COUNT message."""
    return build_message(MSG_AGENT_COUNT, bytes([count]))


def build_heartbeat() -> bytes:
    """Build HEARTBEAT message with current timestamp."""
    ts = int(time.time()) & 0xFFFFFFFF
    payload = struct.pack(">I", ts)
    return build_message(MSG_HEARTBEAT, payload)


def build_screenshot_req() -> bytes:
    """Build SCREENSHOT_REQ message (no payload)."""
    return build_message(MSG_SCREENSHOT_REQ, b"")


def rgb565_to_rgb888(pixel: int) -> tuple:
    """Convert a 16-bit RGB565 value to (R, G, B) tuple."""
    r = ((pixel >> 11) & 0x1F) << 3
    g = ((pixel >> 5) & 0x3F) << 2
    b = (pixel & 0x1F) << 3
    # Fill low bits for full range
    r |= r >> 5
    g |= g >> 6
    b |= b >> 5
    return (r, g, b)


def save_bmp(filepath: Path, width: int, height: int, pixels: list):
    """Save pixels as a 24-bit uncompressed BMP file.

    pixels is a flat list of (R, G, B) tuples, row-major, top-to-bottom.
    """
    row_bytes = width * 3
    row_padding = (4 - (row_bytes % 4)) % 4
    pixel_data_size = (row_bytes + row_padding) * height
    file_size = 14 + 40 + pixel_data_size

    with open(filepath, "wb") as f:
        # File header (14 bytes)
        f.write(b"BM")
        f.write(struct.pack("<I", file_size))
        f.write(struct.pack("<HH", 0, 0))  # reserved
        f.write(struct.pack("<I", 14 + 40))  # pixel data offset

        # BITMAPINFOHEADER (40 bytes)
        f.write(struct.pack("<I", 40))  # header size
        f.write(struct.pack("<i", width))
        f.write(struct.pack("<i", height))
        f.write(struct.pack("<HH", 1, 24))  # planes, bpp
        f.write(struct.pack("<I", 0))  # no compression
        f.write(struct.pack("<I", pixel_data_size))
        f.write(struct.pack("<i", 2835))  # ~72 DPI horizontal
        f.write(struct.pack("<i", 2835))  # ~72 DPI vertical
        f.write(struct.pack("<I", 0))  # colors used
        f.write(struct.pack("<I", 0))  # important colors

        # Pixel data (bottom-to-top, BGR order)
        pad = b"\x00" * row_padding
        for row in range(height - 1, -1, -1):
            row_start = row * width
            for col in range(width):
                r, g, b = pixels[row_start + col]
                f.write(bytes([b, g, r]))
            f.write(pad)


def build_usage_stats(current_pct: int, weekly_pct: int,
                      current_reset_min: int, weekly_reset_min: int) -> bytes:
    """Build USAGE_STATS message (6-byte payload)."""
    current_pct = max(0, min(100, current_pct))
    weekly_pct = max(0, min(100, weekly_pct))
    current_reset_min = max(0, min(0xFFFF, current_reset_min))
    weekly_reset_min = max(0, min(0xFFFF, weekly_reset_min))
    payload = struct.pack(">BBHH", current_pct, weekly_pct, current_reset_min, weekly_reset_min)
    return build_message(MSG_USAGE_STATS, payload)


def read_usage_cache() -> Optional[dict]:
    """Read rate-limits-cache.json and compute minutes until reset."""
    try:
        if not RATE_LIMITS_CACHE.exists():
            return None
        data = json.loads(RATE_LIMITS_CACHE.read_text())
        now = time.time()

        def parse_reset_minutes(iso_str: str) -> int:
            from datetime import datetime, timezone
            try:
                dt = datetime.fromisoformat(iso_str)
                delta = (dt - datetime.now(timezone.utc)).total_seconds()
                return max(0, int(delta / 60))
            except (ValueError, TypeError):
                return 0

        return {
            "current_pct": int(data.get("current_pct", 0)),
            "weekly_pct": int(data.get("weekly_pct", 0)),
            "current_reset_min": parse_reset_minutes(data.get("current_resets_at", "")),
            "weekly_reset_min": parse_reset_minutes(data.get("weekly_resets_at", "")),
        }
    except (json.JSONDecodeError, OSError, KeyError):
        return None


class AgentTracker:
    """Tracks state of Claude Code agents from JSONL transcripts."""

    def __init__(self):
        self.agents: Dict[str, dict] = {}  # project_key -> agent_info
        self._next_id: int = 0

    def get_or_create(self, project_key: str) -> dict:
        if project_key not in self.agents:
            agent = {
                "id": self._next_id % 256,
                "state": STATE_IDLE,
                "tool_name": "",
                "last_seen": time.time(),
                "active_tools": set(),
                "had_tool_in_turn": False,
            }
            self._next_id += 1
            self.agents[project_key] = agent
        return self.agents[project_key]

    def prune_stale(self, timeout: float) -> List[dict]:
        """Remove agents not seen for `timeout` seconds. Returns removed agent info."""
        now = time.time()
        stale_keys = [k for k, v in self.agents.items() if now - v["last_seen"] > timeout]
        removed = []
        for k in stale_keys:
            removed.append({"key": k, "id": self.agents[k]["id"]})
            del self.agents[k]
        return removed

    def count(self) -> int:
        return len(self.agents)


class TranscriptWatcher:
    """Watches JSONL transcript files for state changes."""

    def __init__(self):
        self.file_offsets: Dict[str, int] = {}  # filepath -> byte offset

    def find_active_transcripts(self) -> List[Path]:
        """Find JSONL files in Claude projects directory."""
        if not CLAUDE_PROJECTS_DIR.exists():
            return []
        transcripts = []
        for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
            if not project_dir.is_dir():
                continue
            for jsonl_file in project_dir.glob("*.jsonl"):
                # Only watch files modified recently (within 5 minutes)
                try:
                    mtime = jsonl_file.stat().st_mtime
                    if time.time() - mtime < 300:
                        transcripts.append(jsonl_file)
                except OSError:
                    continue
        return transcripts

    def read_new_lines(self, filepath: Path) -> List[dict]:
        """Read new JSONL lines from a file since last read."""
        str_path = str(filepath)
        try:
            file_size = filepath.stat().st_size
        except OSError:
            return []

        offset = self.file_offsets.get(str_path, 0)
        if file_size <= offset:
            return []

        lines = []
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                f.seek(offset)
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        record = json.loads(line)
                        lines.append(record)
                    except json.JSONDecodeError:
                        continue
                self.file_offsets[str_path] = f.tell()
        except OSError:
            pass
        return lines


def derive_state(record: dict, agent: dict) -> Optional[tuple]:
    """
    Derive agent state from a JSONL record.
    Returns (state, tool_name) or None if no change.
    """
    rec_type = record.get("type", "")

    if rec_type == "assistant":
        message = record.get("message", {})
        content = message.get("content", [])
        stop_reason = message.get("stop_reason", "")

        has_tool_use = False
        tool_name = ""

        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                has_tool_use = True
                tool_name = block.get("name", "")
                break

        if has_tool_use:
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add(tool_name)
            if tool_name in READING_TOOLS:
                return (STATE_READ, tool_name)
            else:
                return (STATE_TYPE, tool_name)

        if stop_reason == "end_turn":
            agent["had_tool_in_turn"] = False
            agent["active_tools"].clear()
            return (STATE_IDLE, "")

    elif rec_type == "user":
        message = record.get("message", {})
        content = message.get("content", [])

        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_result":
                pass  # Tool results processed; state derived from next assistant message

    elif rec_type == "system":
        # Check for turn completion
        if "turn_duration" in record:
            agent["had_tool_in_turn"] = False
            agent["active_tools"].clear()
            return (STATE_IDLE, "")

    return None


class PixelAgentsBridge:
    """Main bridge between Claude Code transcripts and ESP32 display."""

    def __init__(self, port: Optional[str] = None):
        self.serial_port = port
        self.ser: Optional[serial.Serial] = None
        self.tracker = AgentTracker()
        self.watcher = TranscriptWatcher()
        self.last_heartbeat = 0.0
        self.last_usage_send = 0.0
        self.last_usage_data: Optional[tuple] = None
        self.last_states: Dict[str, tuple] = {}  # project_key -> (state, tool)

    def connect(self) -> bool:
        """Connect to ESP32 serial port."""
        port = self.serial_port or find_esp32_port()
        if not port:
            print("No ESP32 serial port found.")
            return False

        try:
            self.ser = serial.Serial(port, SERIAL_BAUD, timeout=0.1)
            print(f"Connected to {port}")
            return True
        except serial.SerialException as e:
            print(f"Failed to connect to {port}: {e}")
            return False

    def send(self, data: bytes) -> bool:
        """Send data over serial, handling disconnection."""
        if not self.ser:
            return False
        try:
            self.ser.write(data)
            return True
        except serial.SerialException:
            print("Serial disconnected. Reconnecting...")
            try:
                self.ser.close()
            except Exception:
                pass
            self.ser = None
            return False

    def send_heartbeat(self):
        """Send periodic heartbeat."""
        now = time.time()
        if now - self.last_heartbeat >= HEARTBEAT_INTERVAL_SEC:
            self.send(build_heartbeat())
            self.last_heartbeat = now

    def send_usage_stats(self):
        """Send usage stats periodically, only on change."""
        now = time.time()
        if now - self.last_usage_send < USAGE_STATS_INTERVAL_SEC:
            return
        self.last_usage_send = now

        usage = read_usage_cache()
        if usage is None:
            return

        data_key = (usage["current_pct"], usage["weekly_pct"],
                    usage["current_reset_min"], usage["weekly_reset_min"])
        if data_key != self.last_usage_data:
            self.last_usage_data = data_key
            msg = build_usage_stats(*data_key)
            self.send(msg)

    def handle_screenshot(self):
        """Request and receive a screenshot from the ESP32."""
        if not self.ser:
            print("Not connected to ESP32.")
            return
        print("Requesting screenshot...")
        self.send(build_screenshot_req())
        self.receive_screenshot()

    def receive_screenshot(self):
        """Receive screenshot data from ESP32 and save to file."""
        if not self.ser:
            return

        try:
            self._receive_screenshot_inner()
        except serial.SerialException as e:
            print(f"Screenshot failed — serial error: {e}")

    def _receive_screenshot_inner(self):
        """Inner screenshot receive logic (may raise serial.SerialException)."""
        # Scan for sync bytes with timeout
        deadline = time.time() + SCREENSHOT_TIMEOUT_SEC
        found_sync = False
        while time.time() < deadline:
            b = self.ser.read(1)
            if not b:
                continue
            if b[0] == SCREENSHOT_SYNC1:
                b2 = self.ser.read(1)
                if b2 and b2[0] == SCREENSHOT_SYNC2:
                    found_sync = True
                    break

        if not found_sync:
            print("Screenshot timeout — no response from ESP32.")
            return

        # Read 10-byte header (after sync bytes)
        hdr = self._read_exact(10, deadline)
        if hdr is None:
            print("Screenshot timeout reading header.")
            return

        width = (hdr[0] << 8) | hdr[1]
        height = (hdr[2] << 8) | hdr[3]
        total_pixels = (hdr[4] << 24) | (hdr[5] << 16) | (hdr[6] << 8) | hdr[7]

        if width == 0 or height == 0:
            print("Screenshot not available (no full framebuffer — CYD half/direct mode).")
            return

        # Sanity checks on dimensions
        MAX_DIM = 1024  # no supported board exceeds this
        if width > MAX_DIM or height > MAX_DIM:
            print(f"Screenshot error: invalid dimensions {width}x{height}.")
            return
        if total_pixels != width * height:
            print(f"Screenshot error: total_pixels ({total_pixels}) != {width}x{height}.")
            return

        print(f"Receiving {width}x{height} screenshot ({total_pixels} pixels)...")

        # Read RLE data
        pixels = []
        while len(pixels) < total_pixels and time.time() < deadline:
            entry = self._read_exact(4, deadline)
            if entry is None:
                print("Screenshot timeout reading pixel data.")
                return

            count = (entry[0] << 8) | entry[1]
            pixel = (entry[2] << 8) | entry[3]

            if count == 0:
                break  # end marker

            rgb = rgb565_to_rgb888(pixel)
            pixels.extend([rgb] * count)

        if len(pixels) < total_pixels:
            # Pad with black if we got fewer pixels than expected
            pixels.extend([(0, 0, 0)] * (total_pixels - len(pixels)))
        elif len(pixels) > total_pixels:
            pixels = pixels[:total_pixels]

        # Save to file
        script_dir = Path(__file__).parent.resolve()
        screenshots_dir = script_dir / "screenshots"
        screenshots_dir.mkdir(exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")

        if HAS_PIL:
            filepath = screenshots_dir / f"pixel-agents-{timestamp}.png"
            img = PILImage.new("RGB", (width, height))
            img.putdata(pixels)
            img.save(filepath)
        else:
            filepath = screenshots_dir / f"pixel-agents-{timestamp}.bmp"
            save_bmp(filepath, width, height, pixels)

        print(f"Screenshot saved: {filepath}")

    def _read_exact(self, count: int, deadline: float) -> Optional[bytes]:
        """Read exactly `count` bytes from serial with deadline."""
        data = b""
        while len(data) < count:
            if time.time() >= deadline:
                return None
            chunk = self.ser.read(count - len(data))
            if chunk:
                data += chunk
        return data

    def process_transcripts(self):
        """Scan transcripts and send state updates."""
        transcripts = self.watcher.find_active_transcripts()

        for filepath in transcripts:
            project_key = str(filepath)
            agent = self.tracker.get_or_create(project_key)
            agent["last_seen"] = time.time()

            records = self.watcher.read_new_lines(filepath)
            if not records:
                continue

            for record in records:
                result = derive_state(record, agent)
                if result is None:
                    continue

                new_state, tool_name = result
                state_key = (new_state, tool_name)

                # Only send if state actually changed
                if self.last_states.get(project_key) != state_key:
                    self.last_states[project_key] = state_key
                    agent["state"] = new_state
                    agent["tool_name"] = tool_name
                    msg = build_agent_update(agent["id"], new_state, tool_name)
                    self.send(msg)

        # Prune stale agents and notify firmware
        removed = self.tracker.prune_stale(STALE_AGENT_TIMEOUT_SEC)
        for entry in removed:
            self.send(build_agent_update(entry["id"], STATE_OFFLINE))
            self.last_states.pop(entry["key"], None)

        # Send agent count only if it changed
        count = self.tracker.count()
        if not hasattr(self, '_last_count') or self._last_count != count:
            self._last_count = count
            self.send(build_agent_count(count))

    def run(self):
        """Main loop."""
        print("Pixel Agents Bridge starting...")
        print(f"Watching: {CLAUDE_PROJECTS_DIR}")

        use_keyboard = sys.stdin.isatty()
        old_settings = None

        if use_keyboard:
            import tty
            import termios
            import atexit
            old_settings = termios.tcgetattr(sys.stdin)
            tty.setcbreak(sys.stdin.fileno())
            atexit.register(lambda: termios.tcsetattr(
                sys.stdin, termios.TCSADRAIN, old_settings))
            print("Press 's' for screenshot, Ctrl+C to quit")

        try:
            while True:
                # Reconnect if needed
                if not self.ser:
                    if not self.connect():
                        time.sleep(2.0)
                        continue

                self.send_heartbeat()
                self.send_usage_stats()
                self.process_transcripts()

                if use_keyboard:
                    readable, _, _ = select.select([sys.stdin], [], [], POLL_INTERVAL_SEC)
                    if readable:
                        ch = sys.stdin.read(1)
                        if ch == 's':
                            self.handle_screenshot()
                else:
                    time.sleep(POLL_INTERVAL_SEC)
        finally:
            if old_settings is not None:
                import termios
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)


def main():
    parser = argparse.ArgumentParser(description="Pixel Agents Bridge - Claude Code to ESP32")
    parser.add_argument("--port", type=str, default=None,
                        help="Serial port (auto-detected if not specified)")
    args = parser.parse_args()

    bridge = PixelAgentsBridge(port=args.port)
    try:
        bridge.run()
    except KeyboardInterrupt:
        print("\nShutting down.")
        if bridge.ser:
            bridge.ser.close()


if __name__ == "__main__":
    main()
