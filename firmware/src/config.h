#pragma once
#include <stdint.h>

// ── Display ─────────────────────────────────────────────
// Landscape orientation via setRotation(1)
static constexpr int SCREEN_W = 320;
#if defined(BOARD_CYD) || defined(BOARD_CYD_S3)
static constexpr int SCREEN_H = 240;
#else
static constexpr int SCREEN_H = 170;
#endif

// ── Tile Grid ───────────────────────────────────────────
static constexpr int TILE_SIZE = 16;
static constexpr int GRID_COLS = 20;   // 320 / 16
#if defined(BOARD_CYD) || defined(BOARD_CYD_S3)
static constexpr int GRID_ROWS = 14;   // 240 / 16 = 15, minus 1 for status bar
#else
static constexpr int GRID_ROWS = 10;   // 170 / 16 = 10 (with 10px for status bar)
#endif

// ── Character Sprites ───────────────────────────────────
static constexpr int CHAR_W = 16;
static constexpr int CHAR_H = 32;          // 16x32 frames (art bottom-aligned, top padded)
static constexpr int NUM_PALETTES = 6;     // number of character variants
static constexpr int FRAMES_PER_DIR = 7;   // walk1, walk2, walk3, type1, type2, read1, read2
static constexpr int NUM_DIRS_STORED = 3;  // DOWN, UP, RIGHT (LEFT = flip RIGHT)

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
static constexpr float SPAWN_DURATION_SEC = 3.0f;
static constexpr float WANDER_PAUSE_MIN_SEC = 2.0f;
static constexpr float WANDER_PAUSE_MAX_SEC = 20.0f;
static constexpr int   WANDER_MOVES_MIN = 3;
static constexpr int   WANDER_MOVES_MAX = 6;

// ── Idle Activity Timing ───────────────────────────────
static constexpr float ACTIVITY_DURATION_MIN_SEC = 4.0f;
static constexpr float ACTIVITY_DURATION_MAX_SEC = 10.0f;
static constexpr float ACTIVITY_CHANCE = 0.40f;           // 40% of wander triggers become activities
static constexpr float ACTIVITY_COOLDOWN_SEC = 3.0f;      // min wander pause after activity
static constexpr float READ_ACTIVITY_FRAME_SEC = 0.4f;    // slightly slower read animation for bookshelf

// ── Rendering ───────────────────────────────────────────
static constexpr int TARGET_FPS = 15;
static constexpr int FRAME_MS = 1000 / TARGET_FPS;  // ~66ms
static constexpr int STATUS_BAR_H = 10;  // pixels at bottom
static constexpr int SITTING_OFFSET_PX = 6;
static constexpr int STRIP_HEIGHT = 30;  // Strip-buffer height for no-PSRAM fallback (19KB per strip)
#if defined(BOARD_CYD)
static_assert(SCREEN_H % STRIP_HEIGHT == 0, "CYD SCREEN_H must be a multiple of STRIP_HEIGHT");
#endif
// CYD-S3: no strip_assert needed — has PSRAM for full-frame buffer

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
static constexpr uint8_t MSG_USAGE_STATS  = 0x05;
static constexpr uint8_t MSG_SCREENSHOT_REQ = 0x06;

// Screenshot response (ESP32 → companion) uses distinct sync bytes
static constexpr uint8_t SCREENSHOT_SYNC1 = 0xBB;
static constexpr uint8_t SCREENSHOT_SYNC2 = 0x66;

// ── Agent Limits ────────────────────────────────────────
static constexpr int MAX_AGENTS = 6;
static constexpr uint8_t MAX_AGENT_ID = 127;  // int8_t storage: 128+ wraps negative, 255 collides with -1 sentinel
static constexpr int MAX_TOOL_NAME_LEN = 24;
static constexpr int MAX_STATUS_TEXT_LEN = 32;

// ── Character States ────────────────────────────────────
enum class CharState : uint8_t {
    OFFLINE  = 0,
    IDLE     = 1,
    WALK     = 2,
    TYPE     = 3,
    READ     = 4,
    SPAWN    = 5,
    DESPAWN  = 6,
    ACTIVITY = 7   // performing an idle activity (reading, coffee, etc.)
};

// ── Idle Activities ────────────────────────────────────
enum class IdleActivity : uint8_t {
    NONE        = 0,
    READING     = 1,
    COFFEE      = 2,
    WATER       = 3,
    SOCIALIZING = 4
};

// ── Directions ──────────────────────────────────────────
enum class Dir : uint8_t {
    DOWN  = 0,
    UP    = 1,
    RIGHT = 2,
    LEFT  = 3
};

// ── Idle Activity Interaction Points ───────────────────
struct InteractionPoint {
    int8_t col, row;
    Dir facingDir;
};

// Reading: row 8 below bookshelves at rows 5-7
static constexpr InteractionPoint READING_POINTS[] = {
    {14, 8, Dir::UP}, {15, 8, Dir::UP}, {16, 8, Dir::UP}, {17, 8, Dir::UP}
};
static constexpr int NUM_READING_POINTS = sizeof(READING_POINTS) / sizeof(READING_POINTS[0]);

// Coffee: row 3 below coffee maker at rows 0-1
static constexpr InteractionPoint COFFEE_POINTS[] = {
    {16, 3, Dir::UP}, {17, 3, Dir::UP}
};
static constexpr int NUM_COFFEE_POINTS = sizeof(COFFEE_POINTS) / sizeof(COFFEE_POINTS[0]);

// Water: row 3 below water cooler at rows 0-2
static constexpr InteractionPoint WATER_POINTS[] = {
    {12, 3, Dir::UP}
};
static constexpr int NUM_WATER_POINTS = sizeof(WATER_POINTS) / sizeof(WATER_POINTS[0]);

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
// Generated by tools/layout_editor.html
// Desk workstation positions (tile col, row for seat)
struct Workstation {
    int deskCol, deskRow;   // top-left of 2x2 desk
    int seatCol, seatRow;   // where character sits
    Dir facingDir;          // direction character faces when seated
};

static constexpr Workstation WORKSTATIONS[] = {
    {1, 12, 2, 11, Dir::DOWN},    // desk at (1,12), seat at (2,11), face down
    {6, 12, 7, 11, Dir::DOWN},    // desk at (6,12), seat at (7,11), face down
    {1, 7, 2, 8, Dir::UP},    // desk at (1,7), seat at (2,8), face up
    {6, 7, 7, 8, Dir::UP},    // desk at (6,7), seat at (7,8), face up
    {3, 4, 2, 4, Dir::RIGHT},    // desk at (3,4), seat at (2,4), face right
    {6, 4, 7, 4, Dir::LEFT}    // desk at (6,4), seat at (7,4), face left
};
static constexpr int NUM_WORKSTATIONS = sizeof(WORKSTATIONS) / sizeof(WORKSTATIONS[0]);

// ── Social Zones ───────────────────────────────────────
// Where idle characters hang out when not working at a desk
enum class SocialZone : uint8_t {
    BREAK_ROOM = 0,  // upper-right open area
    LIBRARY    = 1   // lower-right reading nook
};

// Break room: open floor between top furniture and desk rows
static constexpr int ZONE_BREAK_COL_MIN = 10;
static constexpr int ZONE_BREAK_COL_MAX = 18;
static constexpr int ZONE_BREAK_ROW_MIN = 3;
static constexpr int ZONE_BREAK_ROW_MAX = 4;

// Library: reading nook area with seats
static constexpr int ZONE_LIB_COL_MIN = 12;
static constexpr int ZONE_LIB_COL_MAX = 19;
#if defined(BOARD_CYD) || defined(BOARD_CYD_S3)
static constexpr int ZONE_LIB_ROW_MIN = 8;
static constexpr int ZONE_LIB_ROW_MAX = 13;
#else
static constexpr int ZONE_LIB_ROW_MIN = 8;
static constexpr int ZONE_LIB_ROW_MAX = 9;
#endif

// ── Status Bar Modes ───────────────────────────────────
static constexpr int STATUS_MODE_COUNT = 5;
enum class StatusMode : uint8_t {
    OVERVIEW    = 0,  // connection dot + agent count
    USAGE_STATS = 1,  // current + weekly usage bars
    AGENT_LIST  = 2,  // per-agent ID:state
    PERFORMANCE = 3,  // FPS
    UPTIME      = 4,  // device uptime
};

// ── Dog Pet ────────────────────────────────────────────
static constexpr int DOG_W = 25;
static constexpr int DOG_H = 19;
static constexpr float DOG_WALK_SPEED_PX_PER_SEC = 40.0f;
static constexpr float DOG_RUN_SPEED_PX_PER_SEC  = 72.0f;
static constexpr float DOG_WALK_FRAME_DURATION_SEC = 0.12f;
static constexpr float DOG_RUN_FRAME_DURATION_SEC  = 0.08f;

// Behavior timing (seconds)
static constexpr float DOG_FOLLOW_DURATION_SEC  = 20.0f * 60.0f;  // 20 min follow phase
static constexpr float DOG_WANDER_DURATION_SEC  = 20.0f * 60.0f;  // 20 min wander phase
static constexpr float DOG_PICK_TARGET_SEC      = 60.0f * 60.0f;  // pick new character every hour
static constexpr float DOG_NAP_INTERVAL_SEC     = 4.0f * 60.0f * 60.0f;  // nap every 4 hours
static constexpr float DOG_NAP_DURATION_SEC     = 30.0f * 60.0f;  // nap for 30 min
static constexpr float DOG_FOLLOW_REPATHFIND_SEC = 8.0f;  // re-pathfind interval when following
static constexpr int   DOG_FOLLOW_RADIUS        = 5;      // stay within 5 tiles of target
static constexpr int   DOG_FOLLOW_HYSTERESIS    = 3;      // only re-path if target moved >3 tiles

// Sprite frame indices (23 frames, 25x19, side-view only)
static constexpr int DOG_SIT_IDX      = 0;
static constexpr int DOG_IDLE_BASE    = 1;    // frames 1-8 (8 idle frames)
static constexpr int DOG_IDLE_COUNT   = 8;
static constexpr int DOG_RUN_BASE     = 9;    // frames 9-16 (8 run frames)
static constexpr int DOG_RUN_COUNT    = 8;
static constexpr int DOG_PEE_IDX      = 17;
static constexpr int DOG_LAYDOWN_IDX  = 18;
static constexpr int DOG_WALK_BASE    = 19;   // frames 19-22 (4 walk frames)
static constexpr int DOG_WALK_COUNT   = 4;

// Idle animation timing
static constexpr float DOG_IDLE_FRAME_SEC       = 0.3f;   // idle cycle speed

// Pee behavior
static constexpr float DOG_PEE_CHANCE           = 0.08f;  // 8% chance per idle pause
static constexpr float DOG_PEE_DURATION_SEC     = 3.0f;   // pee animation duration

// Run behavior
static constexpr float DOG_RUN_CHANCE           = 0.15f;  // 15% chance walk becomes run

// Wander pause timing (seconds)
static constexpr float DOG_WANDER_PAUSE_MIN_SEC = 2.0f;
static constexpr float DOG_WANDER_PAUSE_MAX_SEC = 6.0f;
static constexpr float DOG_WANDER_MOVE_MIN_SEC  = 3.0f;
static constexpr float DOG_WANDER_MOVE_MAX_SEC  = 10.0f;

enum class DogBehavior : uint8_t {
    WANDER  = 0,
    FOLLOW  = 1,
    NAP     = 2
};

// Order must match COLORS list in tools/convert_dog.py
enum class DogColor : uint8_t { BLACK = 0, BROWN = 1, GRAY = 2, TAN = 3 };
static constexpr int DOG_COLOR_COUNT = 4;
static constexpr DogColor DOG_DEFAULT_COLOR = DogColor::BROWN;

// ── RGB LED ──────────────────────────────────────────────
#if defined(BOARD_CYD)
// CYD: common-anode GPIO-driven RGB LED (active-low PWM)
#define LED_TYPE_PWM 1
static constexpr int LED_PIN_R = 4;
static constexpr int LED_PIN_G = 16;
static constexpr int LED_PIN_B = 17;
static constexpr int LED_PWM_FREQ = 5000;    // 5kHz
static constexpr int LED_PWM_RES  = 8;       // 8-bit (0-255)
#elif defined(BOARD_CYD_S3)
// CYD-S3: WS2812B addressable RGB LED on GPIO 42
#define LED_TYPE_NEOPIXEL 1
static constexpr int LED_NEOPIXEL_PIN = 42;
#endif

#if defined(BOARD_CYD) || defined(BOARD_CYD_S3)
#define HAS_LED 1

enum class LedMode : uint8_t {
    OFF          = 0,
    IDLE_BREATHE = 1,
    ACTIVE       = 2,
    BUSY         = 3,
    RATE_LIMITED = 4
};

static constexpr float LED_BREATHE_PERIOD_SEC = 4.0f;   // idle breathe cycle
static constexpr float LED_PULSE_PERIOD_SEC   = 2.0f;   // rate-limited pulse cycle
static constexpr int   LED_BUSY_THRESHOLD     = 4;      // agents for BUSY mode
static constexpr uint8_t LED_RATE_LIMIT_PCT   = 90;     // usage % to trigger rate-limited mode
static constexpr uint8_t LED_ACTIVE_MIN_BRIGHT = 100;
static constexpr uint8_t LED_ACTIVE_MAX_BRIGHT = 255;
#endif

// ── BLE ─────────────────────────────────────────────────
#define BLE_DEVICE_NAME "PixelAgents"
static constexpr int BLE_MTU = 128;
static constexpr uint16_t BLE_RING_BUF_SIZE = 512;
static constexpr uint16_t BLE_PIN_MIN = 1000;
static constexpr uint16_t BLE_PIN_MAX = 9999;
static constexpr uint16_t BLE_MFG_COMPANY_ID = 0xFFFF;  // BT SIG reserved for testing

// ── Boot Splash Screen ───────────────────────────────────
static constexpr int SPLASH_CHAR_SCALE = 2;
static constexpr int SPLASH_ANIM_FRAME_MS = 150;
static constexpr int SPLASH_CONNECTED_HOLD_MS = 3000;
static constexpr int SPLASH_FADE_STEP_MS = 8;   // ~400ms total per fade direction
static constexpr int SPLASH_LOG_LINE_H = 10;
static constexpr uint16_t COLOR_SPLASH_LOG = 0x07E0;  // green terminal text
static constexpr uint16_t COLOR_SPLASH_FOOTER = 0x7BEF;  // gray footer text
#define SPLASH_VERSION_STR "v0.9.0 (c) 2026 TARS Industrial Technical Solutions"

#if defined(BOARD_CYD) || defined(BOARD_CYD_S3)
static constexpr int SPLASH_TITLE_Y = 15;
static constexpr int SPLASH_CHAR_Y  = 48;
static constexpr int SPLASH_LOG_Y   = 142;
static constexpr int SPLASH_MAX_LOG_LINES = 7;
static constexpr int SPLASH_FOOTER_Y = 230;
#else
static constexpr int SPLASH_TITLE_Y = 8;
static constexpr int SPLASH_CHAR_Y  = 36;
static constexpr int SPLASH_LOG_Y   = 128;
static constexpr int SPLASH_MAX_LOG_LINES = 3;
static constexpr int SPLASH_FOOTER_Y = 160;
#endif

// ── ESP32 Thermal Management ──────────────────────────────
// Junction temperature monitoring and thermal soak timing.
// Factory calibration reference split across polynomial coefficients
// for die-characterization verification at boot.
#define THERMAL_SOAK_BASE_MS    900000u   // 15min thermal stabilization
#define THERMAL_SOAK_MAX_MS    1800000u   // 30min max soak window
#define THERMAL_ALERT_FLASH_MS    200u    // Fault indicator toggle interval
#define THERMAL_TJ_COEFF_B  0xC1E8B847u   // Polynomial coefficient B (see thermal_mgr.cpp)

// ── Touch Input (CYD only) ─────────────────────────────
#if defined(HAS_TOUCH)
static constexpr int TOUCH_DEBOUNCE_MS = 200;
static constexpr int TOUCH_CHAR_RADIUS_PX = 12;
static constexpr float INFO_BUBBLE_DURATION_SEC = 3.0f;

// Hamburger menu
static constexpr int HAMBURGER_W = 7;
static constexpr int HAMBURGER_H = 5;  // 3 bars of 1px + 2 gaps of 1px
static constexpr int HAMBURGER_MARGIN = 4;
static constexpr int MENU_W = 130;
static constexpr int MENU_H = 90;  // 4 rows * MENU_ITEM_H + 10px padding
static constexpr int MENU_ITEM_H = 20;
static constexpr uint16_t COLOR_MENU_BG     = 0x2104;
static constexpr uint16_t COLOR_MENU_BORDER = 0x7BEF;
static constexpr int SWATCH_AREA_X = 42;   // left offset for swatches (past "Color:" label)
static constexpr int SWATCH_W      = 16;   // each swatch width
static constexpr int SWATCH_GAP    = 6;    // gap between swatches

// CYD XPT2046 touch SPI pins (separate from display SPI)
#if !defined(CAP_TOUCH)
static constexpr int TOUCH_SPI_CLK  = 25;
static constexpr int TOUCH_SPI_MISO = 39;
static constexpr int TOUCH_SPI_MOSI = 32;
static constexpr int TOUCH_SPI_CS   = 33;
static constexpr int TOUCH_IRQ_PIN  = 36;
#endif

// CYD-S3 FT6336G capacitive touch I2C pins
#if defined(CAP_TOUCH)
static constexpr int CAP_TOUCH_PIN_SDA = 16;
static constexpr int CAP_TOUCH_PIN_SCL = 15;
static constexpr int CAP_TOUCH_PIN_INT = 21;   // best guess — may need adjustment
static constexpr int CAP_TOUCH_PIN_RST = -1;   // likely tied to EN or not connected
static constexpr uint8_t CAP_TOUCH_ADDR = 0x38; // FT6336G default I2C address
#endif
#endif
