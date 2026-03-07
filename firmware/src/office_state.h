#pragma once
#include "config.h"
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

    // Speech bubble
    uint8_t bubbleType;       // 0=none, 1=permission, 2=waiting
    float bubbleTimer;

    // Spawn/despawn effect
    float effectTimer;
    bool alive;               // true once spawnAllCharacters() is called
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
    int getActiveAgentCount() const;   // count of characters at TYPE/READ
    int getCharacterCount() const;     // count of alive characters
    const TileType* getTileMap() const { return &_tiles[0][0]; }
    bool isConnected() const { return _connected; }
    void setConnected(bool c) { _connected = c; }
    StatusMode getStatusMode() const { return _statusMode; }

    // Heartbeat
    void onHeartbeat();
    bool checkHeartbeat(uint32_t nowMs);

private:
    Character _chars[MAX_AGENTS];
    TileType _tiles[GRID_ROWS][GRID_COLS];
    bool _connected = false;
    uint32_t _lastHeartbeatMs = 0;
    StatusMode _statusMode = StatusMode::OVERVIEW;
    UsageStats _usage = {};

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

    // BFS pathfinding
    bool findPath(int8_t fromCol, int8_t fromRow, int8_t toCol, int8_t toRow,
                  PathNode* outPath, uint8_t& outLen);
    bool isWalkable(int8_t col, int8_t row) const;

    // Random helpers
    float randomRange(float minVal, float maxVal);
    int randomInt(int minVal, int maxVal);
};
