#include "office_state.h"
#include <Arduino.h>
#include <string.h>

// ── Reading tools (show reading animation instead of typing) ──
static bool isReadingTool(const char* tool) {
    if (!tool || tool[0] == '\0') return false;
    return (strcmp(tool, "Read") == 0 || strcmp(tool, "Grep") == 0 ||
            strcmp(tool, "Glob") == 0 || strcmp(tool, "WebFetch") == 0 ||
            strcmp(tool, "WebSearch") == 0);
}

void OfficeState::init() {
    memset(_chars, 0, sizeof(_chars));
    for (int i = 0; i < MAX_AGENTS; i++) {
        _chars[i].alive = false;
        _chars[i].seatIdx = -1;
    }
    initTileMap();
    _connected = false;
    _lastHeartbeatMs = 0;
}

void OfficeState::initTileMap() {
    // Initialize all as floor
    for (int r = 0; r < GRID_ROWS; r++) {
        for (int c = 0; c < GRID_COLS; c++) {
            if (r == 0) {
                _tiles[r][c] = TileType::WALL;
            } else {
                _tiles[r][c] = TileType::FLOOR;
            }
        }
    }
    // Mark desk tiles as blocked (2x2 desks)
    for (int i = 0; i < NUM_WORKSTATIONS; i++) {
        const auto& ws = WORKSTATIONS[i];
        for (int dr = 0; dr < 2; dr++) {
            for (int dc = 0; dc < 2; dc++) {
                int r = ws.deskRow + dr;
                int c = ws.deskCol + dc;
                if (r >= 0 && r < GRID_ROWS && c >= 0 && c < GRID_COLS) {
                    _tiles[r][c] = TileType::BLOCKED;
                }
            }
        }
    }
    // Mark decorative furniture as blocked
    // Plant at col 11, row 1
    _tiles[1][11] = TileType::BLOCKED;
    // Bookshelf at col 0, rows 1-2 (against wall)
    _tiles[1][0] = TileType::BLOCKED;
    _tiles[2][0] = TileType::BLOCKED;
#if defined(BOARD_CYD)
    // Water cooler at col 18, rows 10-11
    _tiles[10][18] = TileType::BLOCKED;
    _tiles[11][18] = TileType::BLOCKED;
    // Extra plant at col 17, row 1
    _tiles[1][17] = TileType::BLOCKED;
#else
    // Water cooler at col 18, rows 7-8
    _tiles[7][18] = TileType::BLOCKED;
    _tiles[8][18] = TileType::BLOCKED;
#endif
}

int OfficeState::findFreeSlot() const {
    for (int i = 0; i < MAX_AGENTS; i++) {
        if (!_chars[i].alive) return i;
    }
    return -1;
}

int OfficeState::findCharById(uint8_t id) const {
    for (int i = 0; i < MAX_AGENTS; i++) {
        if (_chars[i].alive && _chars[i].id == id) return i;
    }
    return -1;
}

int OfficeState::findFreeSeat() const {
    for (int s = 0; s < NUM_WORKSTATIONS; s++) {
        bool taken = false;
        for (int i = 0; i < MAX_AGENTS; i++) {
            if (_chars[i].alive && _chars[i].seatIdx == s) {
                taken = true;
                break;
            }
        }
        if (!taken) return s;
    }
    return -1;
}

int OfficeState::getCharacterCount() const {
    int count = 0;
    for (int i = 0; i < MAX_AGENTS; i++) {
        if (_chars[i].alive) count++;
    }
    return count;
}

void OfficeState::addAgent(uint8_t id, CharState initialState) {
    // Check if already exists
    if (findCharById(id) >= 0) return;

    int slot = findFreeSlot();
    if (slot < 0) return;

    Character& ch = _chars[slot];
    memset(&ch, 0, sizeof(Character));
    ch.alive = true;
    ch.id = id;
    ch.palette = id % NUM_PALETTES;
    ch.state = CharState::SPAWN;
    ch.effectTimer = 0;
    ch.isActive = (initialState == CharState::TYPE || initialState == CharState::READ);

    // Assign a seat
    int seat = findFreeSeat();
    ch.seatIdx = (int8_t)seat;

    if (seat >= 0) {
        const auto& ws = WORKSTATIONS[seat];
        ch.tileCol = (int8_t)ws.seatCol;
        ch.tileRow = (int8_t)ws.seatRow;
        ch.x = ws.seatCol * TILE_SIZE + TILE_SIZE / 2.0f;
        ch.y = ws.seatRow * TILE_SIZE + TILE_SIZE / 2.0f;
        ch.dir = ws.facingDir;
    } else {
        // No seat available, spawn at a walkable tile
        ch.tileCol = 10;
        ch.tileRow = 5;
        ch.x = 10 * TILE_SIZE + TILE_SIZE / 2.0f;
        ch.y = 5 * TILE_SIZE + TILE_SIZE / 2.0f;
        ch.dir = Dir::DOWN;
    }

    ch.frame = 0;
    ch.frameTimer = 0;
    ch.wanderTimer = randomRange(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC);
    ch.wanderCount = 0;
    ch.wanderLimit = (uint8_t)randomInt(WANDER_MOVES_MIN, WANDER_MOVES_MAX);
    ch.pathLen = 0;
    ch.pathIdx = 0;
    ch.bubbleType = 0;
    ch.bubbleTimer = 0;
}

void OfficeState::removeAgent(uint8_t id) {
    int idx = findCharById(id);
    if (idx < 0) return;
    Character& ch = _chars[idx];
    if (ch.state == CharState::DESPAWN) return;
    ch.state = CharState::DESPAWN;
    ch.effectTimer = 0;
    ch.bubbleType = 0;
}

void OfficeState::setAgentState(uint8_t id, CharState state, const char* toolName) {
    int idx = findCharById(id);
    if (idx < 0) {
        // Auto-add agent if not found
        addAgent(id, state);
        idx = findCharById(id);
        if (idx < 0) return;
    }

    Character& ch = _chars[idx];

    // Store tool name
    if (toolName && toolName[0] != '\0') {
        strncpy(ch.toolName, toolName, MAX_TOOL_NAME_LEN);
        ch.toolName[MAX_TOOL_NAME_LEN] = '\0';
    } else {
        ch.toolName[0] = '\0';
    }

    ch.isActive = (state == CharState::TYPE || state == CharState::READ);

    // Determine actual animation state from protocol state
    if (state == CharState::TYPE || state == CharState::READ) {
        // Active: go to desk
        if (ch.seatIdx >= 0) {
            const auto& ws = WORKSTATIONS[ch.seatIdx];
            if (ch.tileCol == ws.seatCol && ch.tileRow == ws.seatRow) {
                // Already at seat
                ch.state = isReadingTool(ch.toolName) ? CharState::READ : CharState::TYPE;
                ch.dir = ws.facingDir;
                ch.frame = 0;
                ch.frameTimer = 0;
            } else if (ch.state != CharState::WALK && ch.state != CharState::SPAWN) {
                // Walk to seat
                startWalk(ch, (int8_t)ws.seatCol, (int8_t)ws.seatRow);
            }
        } else {
            ch.state = isReadingTool(ch.toolName) ? CharState::READ : CharState::TYPE;
            ch.frame = 0;
            ch.frameTimer = 0;
        }
    } else if (state == CharState::IDLE) {
        if (ch.state == CharState::TYPE || ch.state == CharState::READ) {
            // Was working, now idle
            ch.state = CharState::IDLE;
            ch.frame = 0;
            ch.frameTimer = 0;
            ch.wanderTimer = randomRange(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC);
            ch.wanderCount = 0;
            ch.wanderLimit = (uint8_t)randomInt(WANDER_MOVES_MIN, WANDER_MOVES_MAX);
        }
    } else if (state == CharState::OFFLINE) {
        removeAgent(id);
    }

    // Handle bubble for special states
    if (state == CharState::TYPE && toolName && strcmp(toolName, "PERMISSION") == 0) {
        ch.bubbleType = 1; // permission
        ch.bubbleTimer = 10.0f; // timeout after 10 seconds
    } else if (state == CharState::IDLE) {
        ch.bubbleType = 2; // waiting
        ch.bubbleTimer = 2.0f;
    } else {
        ch.bubbleType = 0;
    }
}

void OfficeState::setAgentCount(uint8_t count) {
    // If count is less than current active agents, remove excess
    int current = getCharacterCount();
    if ((int)count < current) {
        // Remove from the end
        for (int i = MAX_AGENTS - 1; i >= 0 && current > (int)count; i--) {
            if (_chars[i].alive) {
                removeAgent(_chars[i].id);
                current--;
            }
        }
    }
}

void OfficeState::onHeartbeat() {
    _lastHeartbeatMs = millis();
    _connected = true;
}

bool OfficeState::checkHeartbeat(uint32_t nowMs) {
    if (_lastHeartbeatMs == 0) return false;
    if (nowMs - _lastHeartbeatMs > HEARTBEAT_TIMEOUT_MS) {
        _connected = false;
        return false;
    }
    return true;
}

int OfficeState::hitTestCharacter(int screenX, int screenY) const {
    for (int i = 0; i < MAX_AGENTS; i++) {
        if (!_chars[i].alive) continue;
        if (_chars[i].state == CharState::SPAWN || _chars[i].state == CharState::DESPAWN) continue;

        int sittingOffset = (_chars[i].state == CharState::TYPE || _chars[i].state == CharState::READ) ? SITTING_OFFSET_PX : 0;
        // Character center: x, y+sittingOffset shifted up by half height
        float cx = _chars[i].x;
        float cy = _chars[i].y + sittingOffset - CHAR_H / 2.0f;

        float dx = screenX - cx;
        float dy = screenY - cy;
#if defined(HAS_TOUCH)
        if (dx * dx + dy * dy <= TOUCH_CHAR_RADIUS_PX * TOUCH_CHAR_RADIUS_PX) {
            return i;
        }
#else
        (void)dx; (void)dy;
#endif
    }
    return -1;
}

void OfficeState::showInfoBubble(int agentIndex) {
    if (agentIndex < 0 || agentIndex >= MAX_AGENTS) return;
    Character& ch = _chars[agentIndex];
    if (!ch.alive) return;
    ch.bubbleType = 3;
#if defined(HAS_TOUCH)
    ch.bubbleTimer = INFO_BUBBLE_DURATION_SEC;
#else
    ch.bubbleTimer = 3.0f;
#endif
}

bool OfficeState::hitTestStatusBar(int screenY) const {
    return screenY >= SCREEN_H - STATUS_BAR_H;
}

void OfficeState::cycleStatusMode() {
    _statusMode = static_cast<StatusMode>((static_cast<uint8_t>(_statusMode) + 1) % STATUS_MODE_COUNT);
}

void OfficeState::update(float dt) {
    for (int i = 0; i < MAX_AGENTS; i++) {
        if (!_chars[i].alive) continue;
        updateCharacter(_chars[i], dt);
    }
}

void OfficeState::updateCharacter(Character& ch, float dt) {
    ch.frameTimer += dt;

    // Handle spawn/despawn effects
    if (ch.state == CharState::SPAWN) {
        ch.effectTimer += dt;
        if (ch.effectTimer >= SPAWN_DURATION_SEC) {
            // Spawn complete
            if (ch.isActive && ch.seatIdx >= 0) {
                ch.state = isReadingTool(ch.toolName) ? CharState::READ : CharState::TYPE;
                ch.dir = WORKSTATIONS[ch.seatIdx].facingDir;
            } else {
                ch.state = CharState::IDLE;
            }
            ch.frame = 0;
            ch.frameTimer = 0;
        }
        return;
    }

    if (ch.state == CharState::DESPAWN) {
        ch.effectTimer += dt;
        if (ch.effectTimer >= SPAWN_DURATION_SEC) {
            ch.alive = false;
        }
        return;
    }

    switch (ch.state) {
        case CharState::TYPE:
        case CharState::READ: {
            if (ch.frameTimer >= TYPE_FRAME_DURATION_SEC) {
                ch.frameTimer -= TYPE_FRAME_DURATION_SEC;
                ch.frame = (ch.frame + 1) % 2;
            }
            if (!ch.isActive) {
                ch.state = CharState::IDLE;
                ch.frame = 0;
                ch.frameTimer = 0;
                ch.bubbleType = 0;
                ch.bubbleTimer = 0;
                ch.wanderTimer = randomRange(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC);
                ch.wanderCount = 0;
                ch.wanderLimit = (uint8_t)randomInt(WANDER_MOVES_MIN, WANDER_MOVES_MAX);
            }
            break;
        }

        case CharState::IDLE: {
            ch.frame = 0;

            // If became active, go to seat
            if (ch.isActive && ch.seatIdx >= 0) {
                const auto& ws = WORKSTATIONS[ch.seatIdx];
                if (ch.tileCol == ws.seatCol && ch.tileRow == ws.seatRow) {
                    ch.state = CharState::TYPE;
                    ch.dir = ws.facingDir;
                } else {
                    startWalk(ch, (int8_t)ws.seatCol, (int8_t)ws.seatRow);
                }
                ch.frame = 0;
                ch.frameTimer = 0;
                break;
            }

            // Wander timer
            ch.wanderTimer -= dt;
            if (ch.wanderTimer <= 0) {
                startWander(ch);
                ch.wanderTimer = randomRange(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC);
            }
            break;
        }

        case CharState::WALK: {
            // Walk animation
            if (ch.frameTimer >= WALK_FRAME_DURATION_SEC) {
                ch.frameTimer -= WALK_FRAME_DURATION_SEC;
                ch.frame = (ch.frame + 1) % 4;
            }

            if (ch.pathIdx >= ch.pathLen) {
                // Path complete
                float cx = ch.tileCol * TILE_SIZE + TILE_SIZE / 2.0f;
                float cy = ch.tileRow * TILE_SIZE + TILE_SIZE / 2.0f;
                ch.x = cx;
                ch.y = cy;

                if (ch.isActive && ch.seatIdx >= 0) {
                    const auto& ws = WORKSTATIONS[ch.seatIdx];
                    if (ch.tileCol == ws.seatCol && ch.tileRow == ws.seatRow) {
                        ch.state = isReadingTool(ch.toolName) ? CharState::READ : CharState::TYPE;
                        ch.dir = ws.facingDir;
                    } else {
                        ch.state = CharState::IDLE;
                    }
                } else {
                    ch.state = CharState::IDLE;
                    ch.wanderTimer = randomRange(WANDER_PAUSE_MIN_SEC, WANDER_PAUSE_MAX_SEC);
                }
                ch.frame = 0;
                ch.frameTimer = 0;
                break;
            }

            // Move toward next tile
            PathNode next = ch.path[ch.pathIdx];

            // Update direction
            int dc = next.col - ch.tileCol;
            int dr = next.row - ch.tileRow;
            if (dc > 0) ch.dir = Dir::RIGHT;
            else if (dc < 0) ch.dir = Dir::LEFT;
            else if (dr > 0) ch.dir = Dir::DOWN;
            else ch.dir = Dir::UP;

            ch.moveProgress += (WALK_SPEED_PX_PER_SEC / TILE_SIZE) * dt;

            float fromX = ch.tileCol * TILE_SIZE + TILE_SIZE / 2.0f;
            float fromY = ch.tileRow * TILE_SIZE + TILE_SIZE / 2.0f;
            float toX = next.col * TILE_SIZE + TILE_SIZE / 2.0f;
            float toY = next.row * TILE_SIZE + TILE_SIZE / 2.0f;

            float t = ch.moveProgress;
            if (t > 1.0f) t = 1.0f;
            ch.x = fromX + (toX - fromX) * t;
            ch.y = fromY + (toY - fromY) * t;

            if (ch.moveProgress >= 1.0f) {
                ch.tileCol = next.col;
                ch.tileRow = next.row;
                ch.x = toX;
                ch.y = toY;
                ch.pathIdx++;
                ch.moveProgress = 0;
            }
            break;
        }

        default:
            break;
    }

    // Tick bubble timer
    if (ch.bubbleType > 0 && ch.bubbleTimer > 0) {
        ch.bubbleTimer -= dt;
        if (ch.bubbleTimer <= 0) {
            ch.bubbleType = 0;
            ch.bubbleTimer = 0;
        }
    }
}

void OfficeState::startWalk(Character& ch, int8_t goalCol, int8_t goalRow) {
    PathNode pathBuf[64];
    uint8_t pathLen = 0;
    if (findPath(ch.tileCol, ch.tileRow, goalCol, goalRow, pathBuf, pathLen)) {
        memcpy(ch.path, pathBuf, pathLen * sizeof(PathNode));
        ch.pathLen = pathLen;
        ch.pathIdx = 0;
        ch.moveProgress = 0;
        ch.state = CharState::WALK;
        ch.frame = 0;
        ch.frameTimer = 0;
    }
}

void OfficeState::startWander(Character& ch) {
    // Pick a random walkable tile
    // Simple approach: try random tiles until we find a walkable one
    for (int attempt = 0; attempt < 20; attempt++) {
        int8_t col = (int8_t)randomInt(1, GRID_COLS - 2);
        int8_t row = (int8_t)randomInt(1, GRID_ROWS - 1);
        if (isWalkable(col, row)) {
            startWalk(ch, col, row);
            ch.wanderCount++;
            return;
        }
    }
}

void OfficeState::snapToSeat(Character& ch) {
    if (ch.seatIdx < 0) return;
    const auto& ws = WORKSTATIONS[ch.seatIdx];
    ch.tileCol = (int8_t)ws.seatCol;
    ch.tileRow = (int8_t)ws.seatRow;
    ch.x = ws.seatCol * TILE_SIZE + TILE_SIZE / 2.0f;
    ch.y = ws.seatRow * TILE_SIZE + TILE_SIZE / 2.0f;
    ch.dir = ws.facingDir;
}

bool OfficeState::isWalkable(int8_t col, int8_t row) const {
    if (col < 0 || col >= GRID_COLS || row < 0 || row >= GRID_ROWS) return false;
    return _tiles[row][col] == TileType::FLOOR;
}

// BFS pathfinding
bool OfficeState::findPath(int8_t fromCol, int8_t fromRow, int8_t toCol, int8_t toRow,
                           PathNode* outPath, uint8_t& outLen) {
    if (fromCol == toCol && fromRow == toRow) {
        outLen = 0;
        return true;
    }

    // BFS with parent tracking
    static const int8_t DX[] = {0, 0, 1, -1};
    static const int8_t DY[] = {1, -1, 0, 0};

    bool visited[GRID_ROWS][GRID_COLS];
    int8_t parentCol[GRID_ROWS][GRID_COLS];
    int8_t parentRow[GRID_ROWS][GRID_COLS];
    memset(visited, 0, sizeof(visited));
    memset(parentCol, -1, sizeof(parentCol));
    memset(parentRow, -1, sizeof(parentRow));

    // BFS queue (fixed size)
    struct QNode { int8_t col, row; };
    QNode queue[GRID_ROWS * GRID_COLS];
    int qHead = 0, qTail = 0;

    visited[fromRow][fromCol] = true;
    queue[qTail++] = {fromCol, fromRow};

    bool found = false;
    while (qHead < qTail) {
        QNode cur = queue[qHead++];

        if (cur.col == toCol && cur.row == toRow) {
            found = true;
            break;
        }

        for (int d = 0; d < 4; d++) {
            int8_t nc = cur.col + DX[d];
            int8_t nr = cur.row + DY[d];
            if (nc < 0 || nc >= GRID_COLS || nr < 0 || nr >= GRID_ROWS) continue;
            if (visited[nr][nc]) continue;
            // Allow walking to destination even if it's "blocked" (e.g., seat tile)
            if (!isWalkable(nc, nr) && !(nc == toCol && nr == toRow)) continue;
            if (qTail >= GRID_ROWS * GRID_COLS) break;
            visited[nr][nc] = true;
            parentCol[nr][nc] = cur.col;
            parentRow[nr][nc] = cur.row;
            queue[qTail++] = {nc, nr};
        }
    }

    if (!found) {
        outLen = 0;
        return false;
    }

    // Reconstruct path (reverse)
    PathNode revPath[64];
    int len = 0;
    int8_t cc = toCol, cr = toRow;
    while (cc != fromCol || cr != fromRow) {
        if (len >= 64) { outLen = 0; return false; }
        revPath[len++] = {cc, cr};
        int8_t pc = parentCol[cr][cc];
        int8_t pr = parentRow[cr][cc];
        cc = pc;
        cr = pr;
    }

    // Reverse into output
    outLen = (uint8_t)len;
    for (int i = 0; i < len; i++) {
        outPath[i] = revPath[len - 1 - i];
    }
    return true;
}

float OfficeState::randomRange(float minVal, float maxVal) {
    return minVal + ((float)random(10000) / 10000.0f) * (maxVal - minVal);
}

int OfficeState::randomInt(int minVal, int maxVal) {
    return minVal + random(maxVal - minVal + 1);
}

void OfficeState::setUsageStats(uint8_t curPct, uint8_t wkPct, uint16_t curResetMin, uint16_t wkResetMin) {
    _usage.currentPct = curPct > 100 ? 100 : curPct;
    _usage.weeklyPct = wkPct > 100 ? 100 : wkPct;
    _usage.currentResetMin = curResetMin;
    _usage.weeklyResetMin = wkResetMin;
    _usage.valid = true;
}
