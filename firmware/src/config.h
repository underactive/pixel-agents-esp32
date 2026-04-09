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
static constexpr int MINI_CHAR_W = 13;     // robot mini-agent width
static constexpr int MINI_CHAR_H = 16;     // robot mini-agent height (50% of CHAR_H)
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
// Speech bubbles: 0 means persist until state changes
static constexpr float PERMISSION_BUBBLE_DURATION_SEC = 0.0f;
static constexpr float WAITING_BUBBLE_DURATION_SEC = 0.0f;
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
static constexpr uint8_t MSG_SCREENSHOT_REQ   = 0x06;
static constexpr uint8_t MSG_DEVICE_SETTINGS   = 0x07;
static constexpr uint8_t MSG_SETTINGS_STATE    = 0x08;
static constexpr uint8_t MSG_IDENTIFY_REQ      = 0x09;
static constexpr uint8_t MSG_IDENTIFY_RSP      = 0x0A;
static constexpr uint8_t MSG_REBOOT            = 0x0B;

// Device identification (identify response payload)
static constexpr uint8_t IDENTIFY_MAGIC[4] = {0x50, 0x58, 0x41, 0x47};  // "PXAG"
static constexpr uint8_t IDENTIFY_PROTOCOL_VERSION = 1;
static constexpr uint8_t BOARD_TYPE_CYD    = 0;
static constexpr uint8_t BOARD_TYPE_CYD_S3 = 1;
static constexpr uint8_t BOARD_TYPE_LILYGO = 2;
// Encoded as major*1000 + minor*10 + patch (0.11.2 → 112)
static constexpr uint16_t FIRMWARE_VERSION_ENCODED = 141;

// Screenshot response (ESP32 → companion) uses distinct sync bytes
static constexpr uint8_t SCREENSHOT_SYNC1 = 0xBB;
static constexpr uint8_t SCREENSHOT_SYNC2 = 0x66;

// ── Agent Limits ────────────────────────────────────────
static constexpr int MAX_DESK_AGENTS = 6;     // full-size characters that sit at workstations
static constexpr int MAX_MINI_AGENTS = 12;    // 3/4-scale overflow characters that stand near desks
static constexpr int MAX_AGENTS = 18;         // total character slots (desk + mini)
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
static constexpr uint16_t COLOR_BLE      = 0x04FF;  // blue (BLE icon)
static constexpr uint16_t COLOR_CHARGING = 0xFFE0;  // yellow (charging bolt)
static constexpr uint16_t COLOR_DIM      = 0x3186;  // dim gray (inactive icons)

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

// ── Transport Icons ────────────────────────────────────────
static constexpr int TRANSPORT_ICON_W = 5;
static constexpr int TRANSPORT_ICON_H = 8;

// ── Audio / Speaker ──────────────────────────────────────
#if defined(BOARD_CYD)
// CYD: ESP32 internal 8-bit DAC on GPIO 26 → SC8002B mono amp → speaker header
#define HAS_SOUND 1
#define SOUND_DAC_INTERNAL 1
#define SOUND_HAS_AMP_ENABLE 0
static constexpr int SOUND_DAC_GPIO = 26;
static constexpr int SOUND_SAMPLE_RATE = 24000;
static constexpr int SOUND_VOLUME_SHIFT = 2;          // software attenuation (>>2 = /4)
static constexpr int SOUND_I2S_DMA_BUF_COUNT = 16;
static constexpr int SOUND_I2S_DMA_BUF_LEN = 512;
static constexpr int SOUND_PCM_CHUNK_SAMPLES = 512;
static constexpr int SOUND_I2S_PREFILL_CHUNKS = 8;

#elif defined(BOARD_CYD_S3)
// CYD-S3: Freenove ESP32-S3 (FNK0104) I2S + ES8311 codec + speaker amp
#define HAS_SOUND 1
#define SOUND_HAS_AMP_ENABLE 1
static constexpr int SOUND_I2S_MCK = 4;
static constexpr int SOUND_I2S_BCK = 5;
static constexpr int SOUND_I2S_DINT = 6;   // mic in (ES8311 ADC)
static constexpr int SOUND_I2S_WS  = 7;
static constexpr int SOUND_I2S_DOUT = 8;
static constexpr int SOUND_AMP_ENABLE = 1; // AP_ENABLE
static constexpr bool SOUND_AMP_ENABLE_ACTIVE_LOW = true;
static constexpr int SOUND_I2C_SCL = 15;
static constexpr int SOUND_I2C_SDA = 16;
static constexpr int SOUND_I2C_FREQ = 100000;
static constexpr int SOUND_SAMPLE_RATE = 24000;
static constexpr int SOUND_MCLK_MULT = 256;
static constexpr int SOUND_VOLUME_PCT = 70;
static constexpr int SOUND_I2S_DMA_BUF_COUNT = 12;
static constexpr int SOUND_I2S_DMA_BUF_LEN = 512;
static constexpr int SOUND_PCM_CHUNK_SAMPLES = 512;
static constexpr int SOUND_I2S_PREFILL_CHUNKS = 4;

// Wake word detection (ESP-SR WakeNet9)
#define HAS_WAKEWORD 1
#endif

// ── Wake Word ───────────────────────────────────────────
#if defined(HAS_WAKEWORD)
static constexpr int WAKEWORD_COOLDOWN_MS = 5000;  // min ms between detections
#endif

// ── Battery Monitor ──────────────────────────────────────
#if defined(BOARD_CYD_S3)
#define HAS_BATTERY 1
static constexpr int BATTERY_ADC_PIN = 9;
#elif !defined(BOARD_CYD)
// LILYGO T-Display S3
#define HAS_BATTERY 1
static constexpr int BATTERY_ADC_PIN = 4;
#endif

#if defined(HAS_BATTERY)
static constexpr float BATTERY_VOLTAGE_DIVIDER = 2.0f;
static constexpr uint32_t BATTERY_READ_INTERVAL_MS = 5000;
static constexpr float BATTERY_SMOOTH_ALPHA = 0.15f;
static constexpr uint16_t BATTERY_FULL_MV  = 4200;
static constexpr uint16_t BATTERY_EMPTY_MV = 3000;
static constexpr uint16_t BATTERY_CHARGING_MV = 4100;
static constexpr uint8_t  BATTERY_WARN_PCT  = 50;   // below: yellow status bar text
static constexpr uint8_t  BATTERY_CRIT_PCT  = 20;   // below: red status bar text
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
#define SPLASH_VERSION_STR "v0.14.1 (c) 2026 TARS Industrial Technical Solutions"

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
static constexpr int MENU_W = 160;
#if defined(HAS_SOUND)
static constexpr int MENU_H = 194; // 7 rows * MENU_ITEM_H + 12px padding
#else
static constexpr int MENU_H = 142; // 5 rows * MENU_ITEM_H + 12px padding
#endif
static constexpr int MENU_ITEM_H = 26;
static constexpr uint16_t COLOR_MENU_BG     = 0x2104;
static constexpr uint16_t COLOR_MENU_BORDER = 0x7BEF;
static constexpr int SWATCH_AREA_X = 48;   // left offset for swatches (past "Color:" label)
static constexpr int SWATCH_W      = 20;   // each swatch width
static constexpr int SWATCH_GAP    = 6;    // gap between swatches
static constexpr uint32_t LONG_PRESS_MS = 2000;  // 2s hold → deep sleep

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
