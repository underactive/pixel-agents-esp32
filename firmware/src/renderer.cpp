#include "renderer.h"
#include "sprites/characters.h"
#include "sprites/furniture.h"
#include "sprites/bubbles.h"

void Renderer::begin(TFT_eSPI& tft) {
    _tft = &tft;

    // Create sprite canvas for double buffering
    _canvas = new TFT_eSprite(&tft);

    void* buf = _canvas->createSprite(SCREEN_W, SCREEN_H);
    if (!buf) {
        delete _canvas;
        _canvas = nullptr;
        return;
    }
    _canvas->setSwapBytes(true);
}

void Renderer::renderFrame(OfficeState& office) {
    if (!_canvas) return;

    _canvas->fillSprite(COLOR_BG);

    // 1. Draw floor tiles
    drawFloor();

    // 2. Draw furniture (static items)
    drawFurniture();

    // 3. Collect and depth-sort characters
    Character* chars = office.getCharacters();

    // Simple insertion sort by Y position for depth ordering
    int indices[MAX_AGENTS];
    int count = 0;
    for (int i = 0; i < MAX_AGENTS; i++) {
        if (chars[i].alive) {
            indices[count++] = i;
        }
    }
    // Sort by Y (characters further down screen are drawn later = in front)
    for (int i = 1; i < count; i++) {
        int key = indices[i];
        int j = i - 1;
        while (j >= 0 && chars[indices[j]].y > chars[key].y) {
            indices[j + 1] = indices[j];
            j--;
        }
        indices[j + 1] = key;
    }

    // 4. Draw characters
    for (int i = 0; i < count; i++) {
        const Character& ch = chars[indices[i]];
        if (ch.state == CharState::SPAWN || ch.state == CharState::DESPAWN) {
            drawSpawnEffect(ch);
        } else {
            drawCharacter(ch);
        }
    }

    // 5. Draw speech bubbles (on top of characters)
    for (int i = 0; i < count; i++) {
        const Character& ch = chars[indices[i]];
        if (ch.bubbleType > 0) {
            drawBubble(ch);
        }
    }

    // 6. Draw status bar
    drawStatusBar(office);

    // Push to display
    _canvas->pushSprite(0, 0);
}

void Renderer::drawFloor() {
    for (int r = 0; r < GRID_ROWS; r++) {
        for (int c = 0; c < GRID_COLS; c++) {
            int x = c * TILE_SIZE;
            int y = r * TILE_SIZE;
            if (r == 0) {
                _canvas->fillRect(x, y, TILE_SIZE, TILE_SIZE, COLOR_WALL);
            } else {
                uint16_t floorColor = ((r + c) % 2 == 0) ? COLOR_FLOOR_ALT : COLOR_FLOOR;
                _canvas->fillRect(x, y, TILE_SIZE, TILE_SIZE, floorColor);
            }
        }
    }
}

void Renderer::drawFurniture() {
    // Draw desks
    for (int i = 0; i < NUM_WORKSTATIONS; i++) {
        const auto& ws = WORKSTATIONS[i];
        int x = ws.deskCol * TILE_SIZE;
        int y = ws.deskRow * TILE_SIZE;
        drawRGB565Sprite(x, y, SPRITE_DESK, SPRITE_DESK_W, SPRITE_DESK_H);
    }

    // Draw chairs at seat positions
    for (int i = 0; i < NUM_WORKSTATIONS; i++) {
        const auto& ws = WORKSTATIONS[i];
        int x = ws.seatCol * TILE_SIZE;
        int y = ws.seatRow * TILE_SIZE;
        drawRGB565Sprite(x, y, SPRITE_CHAIR, SPRITE_CHAIR_W, SPRITE_CHAIR_H);
    }

    // Static decorations
    drawRGB565Sprite(11 * TILE_SIZE, 1 * TILE_SIZE, SPRITE_PLANT, SPRITE_PLANT_W, SPRITE_PLANT_H);
    drawRGB565Sprite(0, 1 * TILE_SIZE, SPRITE_BOOKSHELF, SPRITE_BOOKSHELF_W, SPRITE_BOOKSHELF_H);
#if defined(BOARD_CYD)
    drawRGB565Sprite(18 * TILE_SIZE, 10 * TILE_SIZE, SPRITE_COOLER, SPRITE_COOLER_W, SPRITE_COOLER_H);
    drawRGB565Sprite(17 * TILE_SIZE, 1 * TILE_SIZE, SPRITE_PLANT, SPRITE_PLANT_W, SPRITE_PLANT_H);
#else
    drawRGB565Sprite(18 * TILE_SIZE, 7 * TILE_SIZE, SPRITE_COOLER, SPRITE_COOLER_W, SPRITE_COOLER_H);
#endif
}

void Renderer::drawCharacter(const Character& ch) {
    int localFrame = getFrameIndex(ch.state, ch.frame);
    if (localFrame < 0) return;

    Dir renderDir = ch.dir;
    bool flipH = false;
    if (ch.dir == Dir::LEFT) {
        renderDir = Dir::RIGHT;
        flipH = true;
    }

    // Compute CharTemplate enum index: direction * 7 + local frame
    int templateEnum = static_cast<int>(renderDir) * FRAMES_PER_DIR + localFrame;
    if (templateEnum >= CHAR_TEMPLATE_COUNT) return;
    const uint8_t* tmpl = CHAR_TEMPLATES[templateEnum];

    if (ch.palette >= NUM_PALETTES) return;
    const uint16_t* palette = CHAR_PALETTES[ch.palette];

    // Character anchored at bottom-center
    int sittingOffset = (ch.state == CharState::TYPE || ch.state == CharState::READ) ? SITTING_OFFSET_PX : 0;
    int drawX = (int)(ch.x) - CHAR_W / 2;
    int drawY = (int)(ch.y + sittingOffset) - CHAR_H;

    drawIndexedSprite(drawX, drawY, tmpl, CHAR_W, CHAR_H, palette, flipH);
}

void Renderer::drawSpawnEffect(const Character& ch) {
    float progress = ch.effectTimer / SPAWN_DURATION_SEC;
    if (progress > 1.0f) progress = 1.0f;
    if (ch.state == CharState::DESPAWN) {
        progress = 1.0f - progress;
    }

    Dir renderDir = ch.dir;
    bool flipH = false;
    if (ch.dir == Dir::LEFT) {
        renderDir = Dir::RIGHT;
        flipH = true;
    }

    // Use standing frame (walk2 = index 1 within direction)
    int templateEnum = static_cast<int>(renderDir) * FRAMES_PER_DIR + 1;
    if (templateEnum >= CHAR_TEMPLATE_COUNT) return;
    const uint8_t* tmpl = CHAR_TEMPLATES[templateEnum];

    if (ch.palette >= NUM_PALETTES) return;
    const uint16_t* palette = CHAR_PALETTES[ch.palette];

    int drawX = (int)(ch.x) - CHAR_W / 2;
    int drawY = (int)(ch.y) - CHAR_H;

    // Draw column by column based on progress
    int revealCols = (int)(progress * CHAR_W);

    for (int col = 0; col < revealCols && col < CHAR_W; col++) {
        int srcCol = flipH ? (CHAR_W - 1 - col) : col;
        for (int row = 0; row < CHAR_H; row++) {
            uint8_t px = tmpl[row * CHAR_W + srcCol];
            if (px == PX_TRANSPARENT) continue;

            uint16_t color;
            if (px == PX_EYES) {
                color = 0xFFFF;
            } else if (px >= 1 && px <= 5) {
                color = palette[px - 1];
            } else {
                continue;
            }

            // Green tint for matrix effect
            if (progress < 0.8f) {
                float greenBlend = 1.0f - (progress / 0.8f);
                uint8_t r = ((color >> 11) & 0x1F) << 3;
                uint8_t g = ((color >> 5) & 0x3F) << 2;
                uint8_t b = (color & 0x1F) << 3;
                r = (uint8_t)(r * (1.0f - greenBlend));
                g = (uint8_t)(g + (255 - g) * greenBlend * 0.5f);
                b = (uint8_t)(b * (1.0f - greenBlend));
                color = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
            }

            int dx = drawX + col;
            int dy = drawY + row;
            if (dx >= 0 && dx < SCREEN_W && dy >= 0 && dy < SCREEN_H) {
                _canvas->drawPixel(dx, dy, color);
            }
        }
    }
}

void Renderer::drawBubble(const Character& ch) {
    const uint16_t* bubbleData;
    int bw, bh;

    if (ch.bubbleType == 1) {
        bubbleData = SPRITE_BUBBLE_PERMISSION;
        bw = SPRITE_BUBBLE_PERMISSION_W;
        bh = SPRITE_BUBBLE_PERMISSION_H;
    } else if (ch.bubbleType == 2) {
        bubbleData = SPRITE_BUBBLE_WAITING;
        bw = SPRITE_BUBBLE_WAITING_W;
        bh = SPRITE_BUBBLE_WAITING_H;
    } else {
        return;
    }

    int sittingOffset = (ch.state == CharState::TYPE || ch.state == CharState::READ) ? SITTING_OFFSET_PX : 0;
    int bubbleX = (int)(ch.x) - bw / 2;
    int bubbleY = (int)(ch.y + sittingOffset) - CHAR_H - bh - 2;

    drawRGB565Sprite(bubbleX, bubbleY, bubbleData, bw, bh);
}

void Renderer::drawStatusBar(OfficeState& office) {
    int y = SCREEN_H - STATUS_BAR_H;
    _canvas->fillRect(0, y, SCREEN_W, STATUS_BAR_H, COLOR_STATUS);

    // Connection indicator
    uint16_t dotColor = office.isConnected() ? COLOR_ACTIVE : COLOR_DISCONNECTED;
    _canvas->fillCircle(5, y + STATUS_BAR_H / 2, 3, dotColor);

    // Agent count
    int agentCount = office.getCharacterCount();
    char buf[32];
    snprintf(buf, sizeof(buf), "%d agent%s", agentCount, agentCount != 1 ? "s" : "");
    _canvas->setTextColor(COLOR_TEXT);
    _canvas->setTextSize(1);
    _canvas->drawString(buf, 12, y + 1);

    if (!office.isConnected()) {
        _canvas->drawString("Disconnected", SCREEN_W - 80, y + 1);
    }
}

int Renderer::getFrameIndex(CharState state, uint8_t frame) const {
    switch (state) {
        case CharState::WALK:
            // Walk frames: 0,1,2 stored; animation cycles [0,1,2,1]
            switch (frame % 4) {
                case 0: return 0;
                case 1: return 1;
                case 2: return 2;
                case 3: return 1;
            }
            break;
        case CharState::TYPE:
            return 3 + (frame % 2); // type1, type2
        case CharState::READ:
            return 5 + (frame % 2); // read1, read2
        case CharState::IDLE:
            return 1; // standing frame
        default:
            return 1;
    }
    return 1;
}

void Renderer::drawIndexedSprite(int x, int y, const uint8_t* tmpl, int w, int h,
                                  const uint16_t* palette, bool flipH) {
    for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {
            int srcCol = flipH ? (w - 1 - col) : col;
            uint8_t px = tmpl[row * w + srcCol];
            if (px == PX_TRANSPARENT) continue;

            uint16_t color;
            if (px == PX_EYES) {
                color = 0xFFFF;
            } else if (px >= 1 && px <= 5) {
                color = palette[px - 1];
            } else {
                continue;
            }

            int dx = x + col;
            int dy = y + row;
            if (dx >= 0 && dx < SCREEN_W && dy >= 0 && dy < SCREEN_H) {
                _canvas->drawPixel(dx, dy, color);
            }
        }
    }
}

void Renderer::drawRGB565Sprite(int x, int y, const uint16_t* data, int w, int h) {
    for (int row = 0; row < h; row++) {
        for (int col = 0; col < w; col++) {
            uint16_t px = data[row * w + col];
            if (px == 0x0000) continue; // transparent
            int dx = x + col;
            int dy = y + row;
            if (dx >= 0 && dx < SCREEN_W && dy >= 0 && dy < SCREEN_H) {
                _canvas->drawPixel(dx, dy, px);
            }
        }
    }
}
