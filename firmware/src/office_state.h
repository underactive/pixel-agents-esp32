#pragma once
#include "config.h"
#include "sound.h"
#include <stdint.h>

struct PathNode {
    int8_t col, row;
};

struct Character {
    uint8_t id;
    CharState state;
    Dir dir;
    float x, y;              // pixel position (center)
    int8_t tileCol, tileRow;  // current tile

    // Pathfinding
    PathNode path[64];        // BFS path buffer
    uint8_t pathLen;
    uint8_t pathIdx;
    float moveProgress;

    // Animation
    uint8_t palette;
    uint8_t frame;
    float frameTimer;

    // Wander behavior (when idle)
    float wanderTimer;
    uint8_t wanderCount;
    uint8_t wanderLimit;

    // State tracking
    bool isActive;
    int8_t seatIdx;           // index into WORKSTATIONS, -1 if none
    int8_t agentId;           // assigned agent ID, -1 if unassigned
    SocialZone homeZone;      // which social zone this character idles in
    char toolName[MAX_TOOL_NAME_LEN + 1];

    // Idle activities
    IdleActivity idleActivity;   // current or pending activity (NONE when wandering)
    Dir activityDir;              // intended facing direction at activity destination
    float activityTimer;          // countdown while performing activity
    bool activityCooldown;        // force normal wander before next activity

    // Speech bubble
    uint8_t bubbleType;       // 0=none, 1=permission, 2=waiting, 3=info
    float bubbleTimer;

    // Sound
    bool hasPlayedJobSound;   // true once typing sound plays for this active job

    // Spawn/despawn effect
    float effectTimer;
    bool alive;               // true once spawnAllCharacters() is called
};

struct Pet {
    float x, y;              // pixel position (center)
    int8_t tileCol, tileRow;
    Dir dir;

    // Pathfinding
    PathNode path[64];
    uint8_t pathLen;
    uint8_t pathIdx;
    float moveProgress;

    // Walk/run animation
    uint8_t frame;
    float frameTimer;
    bool walking;
    bool isRunning;           // run uses faster speed + run frames

    // Idle animation
    uint8_t idleFrame;        // cycles through 8 idle frames
    float idleFrameTimer;

    // Sit (during FOLLOW near seated character)
    bool isSitting;

    // Pee (idle variant)
    float peeTimer;           // time remaining in pee animation
    bool isPeeing;

    // Behavior FSM
    DogBehavior behavior;
    float phaseTimer;         // time remaining in current FOLLOW/WANDER phase
    float napTimer;           // countdown to next nap
    float napRemaining;       // time left napping
    float targetPickTimer;    // countdown to pick new follow target
    float repathTimer;        // re-pathfind interval during FOLLOW
    int8_t followTarget;      // character index to follow, -1 if none
    SoundId pendingSound;     // SoundId::COUNT = none pending
    int8_t lastTargetCol;     // last known target tile (for hysteresis)
    int8_t lastTargetRow;

    // Wander
    float wanderTimer;
};

struct DogSettings {
    bool enabled;
    DogColor color;
};

struct UsageStats {
    uint8_t currentPct;
    uint8_t weeklyPct;
    uint16_t currentResetMin;
    uint16_t weeklyResetMin;
    bool valid;
};

class OfficeState {
public:
    void init();
    void update(float dt);

    // Character lifecycle
    void spawnAllCharacters();          // called once from setup()

    // Agent management
    void setAgentState(uint8_t id, CharState state, const char* toolName);
    void setAgentCount(uint8_t count);

    // Usage stats
    void setUsageStats(uint8_t curPct, uint8_t wkPct, uint16_t curResetMin, uint16_t wkResetMin);
    const UsageStats& getUsageStats() const { return _usage; }

    // Touch interaction
    int hitTestCharacter(int screenX, int screenY) const;
    bool hitTestStatusBar(int screenY) const;
    void showInfoBubble(int agentIndex);
    void cycleStatusMode();

    // Accessors
    Character* getCharacters() { return _chars; }
    const Character* getCharacters() const { return _chars; }
    const Pet& getPet() const { return _pet; }
    DogSettings getDogSettings() const { return _dogSettings; }
    void setDogEnabled(bool enabled);
    void setDogColor(DogColor color);
    SoundId consumePendingSound();
    void queueSound(SoundId id);  // single-slot, last-writer-wins; consumed once per frame
    bool isMenuOpen() const { return _menuOpen; }
    void toggleMenu() { _menuOpen = !_menuOpen; }
    void closeMenu() { _menuOpen = false; }
    bool hitTestHamburger(int screenX, int screenY) const;
    int hitTestMenuItem(int screenX, int screenY) const;
    bool isScreenFlipped() const { return _screenFlipped; }
    void setScreenFlipped(bool flipped);  // Persists to NVS. Caller must also update TFT and touch rotation.
    int getActiveAgentCount() const;   // count of characters at TYPE/READ
    int getCharacterCount() const;     // count of alive characters
    const TileType* getTileMap() const { return &_tiles[0][0]; }
    bool isConnected() const { return _connected; }
    void setConnected(bool c) { _connected = c; }
    void setBlePin(uint16_t pin) { _blePin = pin; }
    uint16_t getBlePin() const { return _blePin; }
    StatusMode getStatusMode() const { return _statusMode; }

    // Heartbeat
    void onHeartbeat();
    bool checkHeartbeat(uint32_t nowMs);

private:
    Character _chars[MAX_AGENTS];
    Pet _pet;
    TileType _tiles[GRID_ROWS][GRID_COLS];
    bool _connected = false;
    uint16_t _blePin = 0;
    uint32_t _lastHeartbeatMs = 0;
    StatusMode _statusMode = StatusMode::OVERVIEW;
    UsageStats _usage = {};
    DogSettings _dogSettings = { true, DOG_DEFAULT_COLOR };
    bool _menuOpen = false;
    bool _screenFlipped = false;

    void initTileMap();
    int findCharByAgentId(uint8_t agentId) const;
    int findFreeSeat() const;
    int findOrAssignChar(uint8_t agentId);

    // Character update
    void updateCharacter(Character& ch, float dt);
    void startWalk(Character& ch, int8_t goalCol, int8_t goalRow);
    void startWander(Character& ch);
    void startZoneWander(Character& ch);
    void walkToZone(Character& ch);
    void snapToSeat(Character& ch);

    // Idle activities
    void startIdleActivity(Character& ch);
    void pickActivityTarget(Character& ch, IdleActivity activity);
    bool isInteractionPointFree(int8_t col, int8_t row, int excludeIdx) const;
    int findSocializeTarget(int charIdx);

    // BFS pathfinding
    bool findPath(int8_t fromCol, int8_t fromRow, int8_t toCol, int8_t toRow,
                  PathNode* outPath, uint8_t& outLen);
    bool isWalkable(int8_t col, int8_t row) const;

    // Pet (dog)
    void initPet();
    void updatePet(float dt);
    void petStartWalk(int8_t goalCol, int8_t goalRow);
    void petWander();
    void petFollowNear();
    void petPickTarget();

    // Settings persistence (NVS)
    void loadSettings();
    void saveSettings();

    // Random helpers
    float randomRange(float minVal, float maxVal);
    int randomInt(int minVal, int maxVal);
};
