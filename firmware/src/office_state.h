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
    char toolName[MAX_TOOL_NAME_LEN + 1];

    // Speech bubble
    uint8_t bubbleType;       // 0=none, 1=permission, 2=waiting
    float bubbleTimer;

    // Spawn/despawn effect
    float effectTimer;
    bool alive;               // false = slot is free
};

class OfficeState {
public:
    void init();
    void update(float dt);

    // Agent management
    void addAgent(uint8_t id, CharState initialState);
    void removeAgent(uint8_t id);
    void setAgentState(uint8_t id, CharState state, const char* toolName);
    void setAgentCount(uint8_t count);

    // Accessors
    Character* getCharacters() { return _chars; }
    int getCharacterCount() const;
    const TileType* getTileMap() const { return &_tiles[0][0]; }
    bool isConnected() const { return _connected; }
    void setConnected(bool c) { _connected = c; }

    // Heartbeat
    void onHeartbeat();
    bool checkHeartbeat(uint32_t nowMs);

private:
    Character _chars[MAX_AGENTS];
    TileType _tiles[GRID_ROWS][GRID_COLS];
    bool _connected = false;
    uint32_t _lastHeartbeatMs = 0;

    void initTileMap();
    int findFreeSlot() const;
    int findCharById(uint8_t id) const;
    int findFreeSeat() const;

    // Character update
    void updateCharacter(Character& ch, float dt);
    void startWalk(Character& ch, int8_t goalCol, int8_t goalRow);
    void startWander(Character& ch);
    void snapToSeat(Character& ch);

    // BFS pathfinding
    bool findPath(int8_t fromCol, int8_t fromRow, int8_t toCol, int8_t toRow,
                  PathNode* outPath, uint8_t& outLen);
    bool isWalkable(int8_t col, int8_t row) const;

    // Random helpers
    float randomRange(float minVal, float maxVal);
    int randomInt(int minVal, int maxVal);
};
