#!/usr/bin/env python3
"""
Pixel Agents Bridge — transcript watcher + ESP32 serial sender.

Watches Claude Code, OpenAI Codex CLI, and Google Gemini CLI transcript files
and sends binary protocol messages to the ESP32 display over USB serial or BLE.

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
MSG_DEVICE_SETTINGS = 0x07
MSG_SETTINGS_STATE = 0x08

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
PERMISSION_DETECT_SEC = 1.0  # seconds after tool_use with no new records → assume permission prompt
SERIAL_BAUD = 115200
MAX_TOOL_NAME_LEN = 24
USAGE_STATS_INTERVAL_SEC = 10.0

# Tools that indicate reading behavior (vs typing/writing)
READING_TOOLS = {"Read", "Grep", "Glob", "WebFetch", "WebSearch"}

# Transcript directories
CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"
CODEX_SESSIONS_DIR = Path.home() / ".codex" / "sessions"
GEMINI_TMP_DIR = Path.home() / ".gemini" / "tmp"
RATE_LIMITS_CACHE = Path.home() / ".claude" / "rate-limits-cache.json"

# Transcript sources
SOURCE_CLAUDE = "claude"
SOURCE_CODEX = "codex"
SOURCE_GEMINI = "gemini"

# Codex commands that indicate reading behavior
CODEX_READING_COMMANDS = {"cat", "head", "tail", "less", "more", "grep", "rg",
                          "find", "ls", "tree", "wc", "file", "stat", "diff"}

# Gemini CLI tools that indicate reading behavior
GEMINI_READING_TOOLS = {"web_fetch", "google_web_search", "read_file", "list_directory"}


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


def build_device_settings(dog_enabled: bool, dog_color: int,
                          screen_flip: bool, sound_enabled: bool,
                          dog_bark_enabled: bool = True) -> bytes:
    """Build DEVICE_SETTINGS message: dog_enabled(1) + dog_color(1) + screen_flip(1) + sound_enabled(1) + dog_bark_enabled(1)."""
    payload = bytes([
        1 if dog_enabled else 0,
        max(0, min(3, dog_color)),
        1 if screen_flip else 0,
        1 if sound_enabled else 0,
        1 if dog_bark_enabled else 0,
    ])
    return build_message(MSG_DEVICE_SETTINGS, payload)


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
        self._recycled_ids: List[int] = []

    def get_or_create(self, project_key: str) -> dict:
        if project_key not in self.agents:
            if self._recycled_ids:
                agent_id = self._recycled_ids.pop()
            else:
                agent_id = self._next_id % 256
                self._next_id += 1
            agent = {
                "id": agent_id,
                "state": STATE_IDLE,
                "tool_name": "",
                "last_seen": time.time(),
                "active_tools": set(),
                "had_tool_in_turn": False,
                "tool_use_ts": 0,  # timestamp of last tool_use with stop_reason=="tool_use"
            }
            self.agents[project_key] = agent
        return self.agents[project_key]

    def prune_stale(self, timeout: float) -> List[dict]:
        """Remove agents not seen for `timeout` seconds. Returns removed agent info."""
        now = time.time()
        stale_keys = [k for k, v in self.agents.items() if now - v["last_seen"] > timeout]
        removed = []
        for k in stale_keys:
            removed.append({"key": k, "id": self.agents[k]["id"]})
            self._recycled_ids.append(self.agents[k]["id"])
            del self.agents[k]
        return removed

    def count(self) -> int:
        return len(self.agents)


class TranscriptWatcher:
    """Watches transcript files for state changes."""

    def __init__(self):
        self.file_offsets: Dict[str, int] = {}  # filepath -> byte offset (JSONL)
        self.gemini_msg_counts: Dict[str, int] = {}  # filepath -> last-seen message count
        self.gemini_file_sizes: Dict[str, int] = {}  # filepath -> last-known file size

    def find_active_transcripts(self) -> List[tuple]:
        """Find active transcript files from all supported sources.

        Returns list of (path, source) tuples.
        """
        transcripts = []
        transcripts.extend(self._find_claude_transcripts())
        transcripts.extend(self._find_codex_transcripts())
        transcripts.extend(self._find_gemini_transcripts())
        return transcripts

    def _find_claude_transcripts(self) -> List[tuple]:
        """Find JSONL files in Claude projects directory."""
        if not CLAUDE_PROJECTS_DIR.exists():
            return []
        results = []
        for project_dir in CLAUDE_PROJECTS_DIR.iterdir():
            if not project_dir.is_dir():
                continue
            for jsonl_file in project_dir.glob("*.jsonl"):
                try:
                    mtime = jsonl_file.stat().st_mtime
                    if time.time() - mtime < 300:
                        results.append((jsonl_file, SOURCE_CLAUDE))
                except OSError:
                    continue
        return results

    def _find_codex_transcripts(self) -> List[tuple]:
        """Find rollout JSONL files in Codex sessions directory.

        Codex stores sessions at ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl
        """
        if not CODEX_SESSIONS_DIR.exists():
            return []
        results = []
        # Walk date-structured directories
        try:
            year_dirs = list(CODEX_SESSIONS_DIR.iterdir())
        except OSError:
            return []
        for year_dir in year_dirs:
            if not year_dir.is_dir():
                continue
            try:
                month_dirs = list(year_dir.iterdir())
            except OSError:
                continue
            for month_dir in month_dirs:
                if not month_dir.is_dir():
                    continue
                try:
                    day_dirs = list(month_dir.iterdir())
                except OSError:
                    continue
                for day_dir in day_dirs:
                    if not day_dir.is_dir():
                        continue
                    for jsonl_file in day_dir.glob("rollout-*.jsonl"):
                        try:
                            mtime = jsonl_file.stat().st_mtime
                            if time.time() - mtime < 300:
                                results.append((jsonl_file, SOURCE_CODEX))
                        except OSError:
                            continue
        return results

    def _find_gemini_transcripts(self) -> List[tuple]:
        """Find session JSON files in Gemini CLI tmp directory.

        Gemini stores sessions at ~/.gemini/tmp/{project-slug}/chats/session-*.json
        """
        if not GEMINI_TMP_DIR.exists():
            return []
        results = []
        try:
            project_dirs = list(GEMINI_TMP_DIR.iterdir())
        except OSError:
            return []
        for project_dir in project_dirs:
            if not project_dir.is_dir():
                continue
            chats_dir = project_dir / "chats"
            if not chats_dir.is_dir():
                continue
            for session_file in chats_dir.glob("session-*.json"):
                try:
                    mtime = session_file.stat().st_mtime
                    if time.time() - mtime < 300:
                        results.append((session_file, SOURCE_GEMINI))
                except OSError:
                    continue
        return results

    def read_new_gemini_messages(self, filepath: Path) -> List[dict]:
        """Read new messages from a Gemini CLI session JSON file.

        Gemini sessions are monolithic JSON (not JSONL) with a messages array.
        We track the last-seen message count and only return new messages.
        """
        str_path = str(filepath)
        try:
            file_size = filepath.stat().st_size
        except OSError:
            return []

        # Skip re-parsing if file hasn't changed
        if file_size == self.gemini_file_sizes.get(str_path, -1):
            return []
        self.gemini_file_sizes[str_path] = file_size

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError):
            return []

        messages = data.get("messages", [])
        last_count = self.gemini_msg_counts.get(str_path, 0)
        if len(messages) <= last_count:
            return []

        self.gemini_msg_counts[str_path] = len(messages)
        return messages[last_count:]

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
            # Track when model emits tool_use and ends its turn (waiting for results)
            if stop_reason == "tool_use":
                agent["tool_use_ts"] = time.time()
            if tool_name in READING_TOOLS:
                return (STATE_READ, tool_name)
            else:
                return (STATE_TYPE, tool_name)

        if stop_reason == "end_turn":
            agent["had_tool_in_turn"] = False
            agent["active_tools"].clear()
            agent["tool_use_ts"] = 0
            return (STATE_IDLE, "")

    elif rec_type == "user":
        message = record.get("message", {})
        content = message.get("content", [])

        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_result":
                agent["tool_use_ts"] = 0  # tool executed, no longer waiting
                break

    elif rec_type == "system":
        # Check for turn completion
        if "turn_duration" in record:
            agent["had_tool_in_turn"] = False
            agent["active_tools"].clear()
            agent["tool_use_ts"] = 0
            return (STATE_IDLE, "")

    return None


def derive_codex_state(record: dict, agent: dict) -> Optional[tuple]:
    """
    Derive agent state from a Codex CLI rollout JSONL record.
    Returns (state, tool_name) or None if no change.

    Handles three formats:
    - codex exec --json events: type is "item.started", "turn.completed", etc.
    - Current rollout format (snake_case): type is "response_item", "event_msg", etc.
    - Legacy RolloutLine envelopes (PascalCase): type is "ResponseItem", "EventMsg", etc.
    """
    rec_type = record.get("type", "")

    # ── codex exec --json format ──────────────────────────────
    if rec_type == "item.started" or rec_type == "item.completed":
        item = record.get("item", {})
        item_type = item.get("type", "")

        if item_type == "command_execution":
            command = item.get("command", "")
            tool_label = _codex_tool_label(command)
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add(tool_label)
            if _is_codex_read_command(command):
                return (STATE_READ, tool_label)
            return (STATE_TYPE, tool_label)

        if item_type == "file_change":
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add("Edit")
            return (STATE_TYPE, "Edit")

        if item_type == "mcp_tool_call":
            tool = item.get("tool", "tool")
            tool_label = tool[:MAX_TOOL_NAME_LEN]
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add(tool_label)
            return (STATE_TYPE, tool_label)

        if item_type == "web_search":
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add("WebSearch")
            return (STATE_READ, "WebSearch")

        # agent_message, reasoning, todo_list — no state change
        return None

    if rec_type == "turn.completed":
        agent["had_tool_in_turn"] = False
        agent["active_tools"].clear()
        return (STATE_IDLE, "")

    if rec_type == "turn.started":
        # Turn beginning — no state change yet, wait for items
        return None

    # ── Current rollout format (snake_case) ───────────────────
    if rec_type == "response_item":
        payload = record.get("payload", record)
        payload_type = payload.get("type", "")

        if payload_type == "function_call":
            name = payload.get("name", "tool")
            if name == "exec_command":
                # Parse arguments JSON string for the actual command
                args_str = payload.get("arguments", "")
                command = ""
                if isinstance(args_str, str) and args_str:
                    try:
                        args = json.loads(args_str)
                        command = args.get("cmd", "") if isinstance(args, dict) else ""
                    except (json.JSONDecodeError, ValueError):
                        command = ""
                elif isinstance(args_str, dict):
                    command = args_str.get("cmd", "")
                tool_label = _codex_tool_label(command) if command else "exec_command"
                agent["had_tool_in_turn"] = True
                agent["active_tools"].add(tool_label)
                if command and _is_codex_read_command(command):
                    return (STATE_READ, tool_label)
                return (STATE_TYPE, tool_label)
            else:
                tool_label = (name or "tool")[:MAX_TOOL_NAME_LEN]
                agent["had_tool_in_turn"] = True
                agent["active_tools"].add(tool_label)
                return (STATE_TYPE, tool_label)

        if payload_type == "custom_tool_call":
            name = payload.get("name", "tool")
            tool_label = (name or "tool")[:MAX_TOOL_NAME_LEN]
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add(tool_label)
            return (STATE_TYPE, tool_label)

        if payload_type == "web_search_call":
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add("WebSearch")
            return (STATE_READ, "WebSearch")

        # reasoning, message, *_output — no state change
        return None

    if rec_type == "event_msg":
        payload = record.get("payload", record)
        payload_type = payload.get("type", "")
        if payload_type == "task_complete" or payload_type == "turn_aborted":
            agent["had_tool_in_turn"] = False
            agent["active_tools"].clear()
            return (STATE_IDLE, "")
        # task_started, agent_reasoning, token_count, etc. — no state change
        return None

    # session_meta, turn_context, compacted — no state change
    if rec_type in ("session_meta", "turn_context", "compacted"):
        return None

    # ── Legacy RolloutLine envelope format (PascalCase) ───────
    if rec_type == "ResponseItem":
        payload = record.get("payload", record)
        # Look for function_call items in the payload
        item_type = payload.get("type", "")
        if item_type == "function_call":
            name = payload.get("name", "tool")
            tool_label = name[:MAX_TOOL_NAME_LEN] if name else "tool"
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add(tool_label)
            return (STATE_TYPE, tool_label)
        return None

    if rec_type == "EventMsg":
        payload = record.get("payload", record)
        # token_count events may indicate turn completion
        if "token_count" in payload or "token_count" in record:
            return None
        msg_type = payload.get("type", "")
        if msg_type == "turn_complete" or msg_type == "turn.completed":
            agent["had_tool_in_turn"] = False
            agent["active_tools"].clear()
            return (STATE_IDLE, "")
        return None

    return None


def _strip_codex_command(command: str) -> str:
    """Strip bash prefix and quotes from a Codex shell command."""
    cmd = command
    if cmd.startswith("bash "):
        parts = cmd.split(None, 2)
        cmd = parts[-1] if len(parts) > 1 else cmd
    # Strip surrounding quotes (e.g. 'grep foo' or "cat bar")
    cmd = cmd.strip()
    if len(cmd) >= 2 and cmd[0] in ("'", '"') and cmd[-1] == cmd[0]:
        cmd = cmd[1:-1]
    return cmd


def _codex_tool_label(command: str) -> str:
    """Extract a short label from a Codex shell command for display."""
    cmd = _strip_codex_command(command)
    # Get the first word (the actual command)
    first = cmd.strip().split()[0] if cmd.strip() else "shell"
    # Remove path prefix
    first = first.rsplit("/", 1)[-1]
    return first[:MAX_TOOL_NAME_LEN]


def _is_codex_read_command(command: str) -> bool:
    """Check if a Codex shell command is a read-like operation."""
    cmd = _strip_codex_command(command)
    first_word = cmd.strip().split()[0] if cmd.strip() else ""
    first_word = first_word.rsplit("/", 1)[-1]  # remove path
    return first_word in CODEX_READING_COMMANDS


def derive_gemini_state(record: dict, agent: dict) -> Optional[tuple]:
    """
    Derive agent state from a Gemini CLI session message record.
    Returns (state, tool_name) or None if no change.

    Gemini messages have type "user" or "gemini". Tool calls appear in the
    toolCalls array within gemini-type messages.
    """
    msg_type = record.get("type", "")

    if msg_type == "gemini":
        tool_calls = record.get("toolCalls", [])
        if tool_calls and isinstance(tool_calls, list):
            # Use the last tool call for display
            last_tool = tool_calls[-1]
            tool_name = (last_tool.get("displayName") or
                         last_tool.get("name") or "Tool")
            tool_name = tool_name[:MAX_TOOL_NAME_LEN]

            raw_name = last_tool.get("name", "")
            agent["had_tool_in_turn"] = True
            agent["active_tools"].add(raw_name)

            if raw_name in GEMINI_READING_TOOLS:
                return (STATE_READ, tool_name)
            return (STATE_TYPE, tool_name)

        # Gemini message without tool calls — agent is generating text
        agent["had_tool_in_turn"] = True
        return (STATE_TYPE, "Gemini")

    if msg_type == "user":
        agent["had_tool_in_turn"] = False
        agent["active_tools"].clear()
        agent["tool_use_ts"] = 0
        return (STATE_IDLE, "")

    return None


class PixelAgentsBridge:
    """Main bridge between Claude Code transcripts and ESP32 display."""

    def __init__(self, port: Optional[str] = None, transport: str = "serial",
                 ble_name: str = "PixelAgents", ble_pin: Optional[int] = None):
        self.serial_port = port
        self.transport_mode = transport
        self.ble_name = ble_name
        self.ble_pin = ble_pin
        self.ser: Optional[serial.Serial] = None
        self._ble = None  # BleTransport instance (lazy import)
        self.tracker = AgentTracker()
        self.watcher = TranscriptWatcher()
        self.last_heartbeat = 0.0
        self.last_usage_send = 0.0
        self.last_usage_data: Optional[tuple] = None
        self.last_states: Dict[str, tuple] = {}  # project_key -> (state, tool)
        self._last_count: int = -1

    def _reset_session_state(self):
        """Reset connection-scoped tracking state on connect/reconnect."""
        self.last_states.clear()
        self.last_usage_data = None
        self._last_count = -1
        self.tracker._recycled_ids.clear()

    def _is_connected(self) -> bool:
        if self.transport_mode == "ble":
            return self._ble is not None and self._ble.is_connected
        return self.ser is not None

    def connect(self) -> bool:
        """Connect to ESP32 via configured transport."""
        if self.transport_mode == "ble":
            return self._connect_ble()
        return self._connect_serial()

    def _connect_serial(self) -> bool:
        """Connect to ESP32 serial port."""
        port = self.serial_port or find_esp32_port()
        if not port:
            print("No ESP32 serial port found.")
            return False

        try:
            self.ser = serial.Serial(port, SERIAL_BAUD, timeout=0.1)
            self._reset_session_state()
            print(f"Connected to {port}")
            return True
        except serial.SerialException as e:
            print(f"Failed to connect to {port}: {e}")
            return False

    def _connect_ble(self) -> bool:
        """Connect to ESP32 via BLE, using PIN for device selection."""
        if self._ble is None:
            from ble_transport import BleTransport
            self._ble = BleTransport(device_name=self.ble_name)

        try:
            pin = self.ble_pin
            if pin is None and sys.stdin.isatty():
                # Interactive mode: scan and prompt for PIN
                devices = self._ble.scan_devices()
                if not devices:
                    return False
                if len(devices) == 1 and devices[0][2] is None:
                    # Single device without PIN — connect directly (legacy)
                    connected = self._ble.connect(address=devices[0][0])
                else:
                    try:
                        pin_input = input("Enter PIN from device display: ").strip()
                        pin = int(pin_input)
                    except (ValueError, EOFError):
                        print("Invalid PIN.")
                        return False
                    # Find matching device from already-scanned results
                    addr = None
                    for d_addr, d_name, d_pin in devices:
                        if d_pin == pin:
                            print(f"PIN {pin} matched: {d_name} at {d_addr}")
                            addr = d_addr
                            break
                    if addr is None:
                        print(f"No device found with PIN {pin}")
                        return False
                    connected = self._ble.connect(address=addr)
                    if connected:
                        self.ble_pin = pin  # Persist for auto-reconnect
            elif pin is not None:
                connected = self._ble.connect_by_pin(pin)
            else:
                # Non-interactive, no PIN — connect to first device found
                connected = self._ble.connect()
        except Exception as e:
            print(f"BLE connect error: {e}")
            return False

        if connected:
            self._reset_session_state()
        return connected

    def send(self, data: bytes) -> bool:
        """Send data over the active transport, handling disconnection."""
        if self.transport_mode == "ble":
            return self._send_ble(data)
        return self._send_serial(data)

    def _send_serial(self, data: bytes) -> bool:
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

    def _send_ble(self, data: bytes) -> bool:
        if not self._ble or not self._ble.is_connected:
            return False
        if not self._ble.send(data):
            print("BLE send failed. Reconnecting...")
            return False
        return True

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

        for filepath, source in transcripts:
            project_key = str(filepath)
            agent = self.tracker.get_or_create(project_key)
            agent["last_seen"] = time.time()

            if source == SOURCE_GEMINI:
                records = self.watcher.read_new_gemini_messages(filepath)
            else:
                records = self.watcher.read_new_lines(filepath)

            if records:
                for record in records:
                    if source == SOURCE_CODEX:
                        result = derive_codex_state(record, agent)
                    elif source == SOURCE_GEMINI:
                        result = derive_gemini_state(record, agent)
                    else:
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
            else:
                # No new records — check if agent is waiting for tool permission
                tool_use_ts = agent.get("tool_use_ts", 0)
                if tool_use_ts and time.time() - tool_use_ts > PERMISSION_DETECT_SEC:
                    state_key = (STATE_TYPE, "PERMISSION")
                    if self.last_states.get(project_key) != state_key:
                        self.last_states[project_key] = state_key
                        agent["state"] = STATE_TYPE
                        agent["tool_name"] = "PERMISSION"
                        msg = build_agent_update(agent["id"], STATE_TYPE, "PERMISSION")
                        self.send(msg)
                    agent["tool_use_ts"] = 0  # sent once, don't re-trigger

        # Prune stale agents and notify firmware
        removed = self.tracker.prune_stale(STALE_AGENT_TIMEOUT_SEC)
        for entry in removed:
            self.send(build_agent_update(entry["id"], STATE_OFFLINE))
            self.last_states.pop(entry["key"], None)

        # Send agent count only if it changed
        count = self.tracker.count()
        if self._last_count != count:
            self._last_count = count
            self.send(build_agent_count(count))

    def run(self):
        """Main loop."""
        print("Pixel Agents Bridge starting...")
        print(f"Transport: {self.transport_mode}")
        print(f"Watching: {CLAUDE_PROJECTS_DIR}")
        print(f"Watching: {CODEX_SESSIONS_DIR}")
        print(f"Watching: {GEMINI_TMP_DIR}")

        use_keyboard = sys.stdin.isatty()
        old_settings = None
        screenshots_available = self.transport_mode == "serial"

        if use_keyboard:
            import tty
            import termios
            import atexit
            old_settings = termios.tcgetattr(sys.stdin)
            tty.setcbreak(sys.stdin.fileno())
            atexit.register(lambda: termios.tcsetattr(
                sys.stdin, termios.TCSADRAIN, old_settings))
            if screenshots_available:
                print("Press 's' for screenshot, Ctrl+C to quit")
            else:
                print("Ctrl+C to quit (screenshots not available over BLE)")

        try:
            while True:
                # Reconnect if needed
                if not self._is_connected():
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
                        if ch == 's' and screenshots_available:
                            self.handle_screenshot()
                else:
                    time.sleep(POLL_INTERVAL_SEC)
        finally:
            if old_settings is not None:
                import termios
                termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
            if self._ble:
                self._ble.close()


def main():
    parser = argparse.ArgumentParser(description="Pixel Agents Bridge - Claude Code, Codex CLI & Gemini CLI to ESP32")
    parser.add_argument("--port", type=str, default=None,
                        help="Serial port (auto-detected if not specified)")
    parser.add_argument("--transport", type=str, default="serial",
                        choices=["serial", "ble"],
                        help="Transport mode: serial (default) or ble")
    parser.add_argument("--ble-name", type=str, default="PixelAgents",
                        help="BLE device name to scan for (default: PixelAgents)")
    parser.add_argument("--ble-pin", type=int, default=None,
                        help="BLE device PIN for multi-device pairing (prompted if omitted)")
    args = parser.parse_args()

    if args.ble_pin is not None and not (1000 <= args.ble_pin <= 9999):
        parser.error("--ble-pin must be a 4-digit number (1000-9999)")

    bridge = PixelAgentsBridge(port=args.port, transport=args.transport,
                               ble_name=args.ble_name, ble_pin=args.ble_pin)
    try:
        bridge.run()
    except KeyboardInterrupt:
        print("\nShutting down.")
        if bridge.ser:
            bridge.ser.close()
        if bridge._ble:
            bridge._ble.close()


if __name__ == "__main__":
    main()
