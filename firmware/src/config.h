#pragma once
#include <stdint.h>

// ── Display ─────────────────────────────────────────────
// Landscape orientation via setRotation(1)
static constexpr int SCREEN_W = 320;
static constexpr int SCREEN_H = 170;

// ── Tile Grid ───────────────────────────────────────────
static constexpr int TILE_SIZE = 16;
static constexpr int GRID_COLS = 20;  // 320 / 16
static constexpr int GRID_ROWS = 10;  // 170 / 16 = 10 (with 10px for status bar)

// ── Character Sprites ───────────────────────────────────
static constexpr int CHAR_W = 16;
static constexpr int CHAR_H = 24;
static constexpr int NUM_PALETTES = 6;
static constexpr int PALETTE_COLORS = 6;  // hair, skin, shirt, pants, shoes, eyes(white)
static constexpr int FRAMES_PER_DIR = 7;  // walk1, walk2, walk3, type1, type2, read1, read2
static constexpr int NUM_DIRS_STORED = 3; // DOWN, UP, RIGHT (LEFT = flip RIGHT)

// ── Template Pixel Values ───────────────────────────────
static constexpr uint8_t PX_TRANSPARENT = 0;
static constexpr uint8_t PX_HAIR = 1;
static constexpr uint8_t PX_SKIN = 2;
static constexpr uint8_t PX_SHIRT = 3;
static constexpr uint8_t PX_PANTS = 4;
static constexpr uint8_t PX_SHOES = 5;
static constexpr uint8_t PX_EYES = 6;

// ── Animation Timing ────────────────────────────────────
static constexpr float WALK_SPEED_PX_PER_SEC = 48.0f;
static constexpr float WALK_FRAME_DURATION_SEC = 0.15f;
static constexpr float TYPE_FRAME_DURATION_SEC = 0.3f;
static constexpr float SPAWN_DURATION_SEC = 0.3f;
static constexpr float WANDER_PAUSE_MIN_SEC = 2.0f;
static constexpr float WANDER_PAUSE_MAX_SEC = 20.0f;
static constexpr int   WANDER_MOVES_MIN = 3;
static constexpr int   WANDER_MOVES_MAX = 6;

// ── Rendering ───────────────────────────────────────────
static constexpr int TARGET_FPS = 15;
static constexpr int FRAME_MS = 1000 / TARGET_FPS;  // ~66ms
static constexpr int STATUS_BAR_H = 10;  // pixels at bottom
static constexpr int SITTING_OFFSET_PX = 6;

// ── Serial Protocol ─────────────────────────────────────
static constexpr uint8_t SYNC_BYTE_1 = 0xAA;
static constexpr uint8_t SYNC_BYTE_2 = 0x55;
static constexpr int SERIAL_BUF_SIZE = 256;
static constexpr int HEARTBEAT_TIMEOUT_MS = 6000;

// ── Protocol Message Types ──────────────────────────────
static constexpr uint8_t MSG_AGENT_UPDATE = 0x01;
static constexpr uint8_t MSG_AGENT_COUNT  = 0x02;
static constexpr uint8_t MSG_HEARTBEAT    = 0x03;
static constexpr uint8_t MSG_STATUS_TEXT  = 0x04;

// ── Agent Limits ────────────────────────────────────────
static constexpr int MAX_AGENTS = 6;
static constexpr int MAX_TOOL_NAME_LEN = 24;
static constexpr int MAX_STATUS_TEXT_LEN = 32;

// ── Character States ────────────────────────────────────
enum class CharState : uint8_t {
    OFFLINE = 0,
    IDLE    = 1,
    WALK    = 2,
    TYPE    = 3,
    READ    = 4,
    SPAWN   = 5,
    DESPAWN = 6
};

// ── Directions ──────────────────────────────────────────
enum class Dir : uint8_t {
    DOWN  = 0,
    UP    = 1,
    RIGHT = 2,
    LEFT  = 3
};

// ── Tile Types ──────────────────────────────────────────
enum class TileType : uint8_t {
    FLOOR    = 0,
    WALL     = 1,
    BLOCKED  = 2  // non-walkable furniture tile (BFS allows as destination only)
};

// ── Floor Color ─────────────────────────────────────────
// RGB565 colors
static constexpr uint16_t COLOR_FLOOR    = 0x4208;  // dark gray
static constexpr uint16_t COLOR_FLOOR_ALT = 0x4228; // slightly lighter for checkerboard
static constexpr uint16_t COLOR_WALL     = 0x3186;  // slightly different gray
static constexpr uint16_t COLOR_BG       = 0x0000;  // black background
static constexpr uint16_t COLOR_STATUS   = 0x18E3;  // dark status bar
static constexpr uint16_t COLOR_TEXT     = 0xFFFF;  // white text
static constexpr uint16_t COLOR_ACTIVE   = 0x07E0;  // green dot
static constexpr uint16_t COLOR_INACTIVE = 0x7BEF;  // gray dot
static constexpr uint16_t COLOR_DISCONNECTED = 0xF800; // red

// ── Office Layout ───────────────────────────────────────
// Desk workstation positions (tile col, row for seat)
struct Workstation {
    int deskCol, deskRow;   // top-left of 2x2 desk
    int seatCol, seatRow;   // where character sits
    Dir facingDir;          // direction character faces when seated
};

static constexpr Workstation WORKSTATIONS[] = {
    {3, 2, 3, 4, Dir::UP},     // desk at (3,2), seat at (3,4), face up
    {7, 2, 7, 4, Dir::UP},     // desk at (7,2), seat at (7,4), face up
    {3, 6, 3, 5, Dir::DOWN},   // desk at (3,6), seat at (3,5), face down
    {7, 6, 7, 5, Dir::DOWN},   // desk at (7,6), seat at (7,5), face down
    {13, 2, 13, 4, Dir::UP},   // extra stations for more agents
    {17, 2, 17, 4, Dir::UP},
};
static constexpr int NUM_WORKSTATIONS = sizeof(WORKSTATIONS) / sizeof(WORKSTATIONS[0]);
