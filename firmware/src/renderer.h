#pragma once
#include <TFT_eSPI.h>
#include "config.h"
#include "office_state.h"

class Renderer {
public:
    void begin(TFT_eSPI& tft);
    void renderFrame(OfficeState& office);

private:
    TFT_eSPI* _tft = nullptr;
    TFT_eSprite* _canvas = nullptr;
    bool _directMode = false;
    bool _halfMode = false;
    int _halfHeight = 0;
    int _yOffset = 0;
    uint32_t _lastRenderMs = 0;
    float _fps = 0;

    void drawScene(OfficeState& office);
    void drawFloor(const TileType* tiles);
    void drawFurniture();
    void drawCharacter(const Character& ch);
    void drawBubble(const Character& ch);
    void drawStatusBar(OfficeState& office);
    void drawSpawnEffect(const Character& ch);

    // Sprite rendering helpers
    void drawRGB565Sprite(int x, int y, const uint16_t* data, int w, int h);
    void drawRGB565SpriteFlip(int x, int y, const uint16_t* data, int w, int h, bool flipH);

    // Get local frame index (0-6) for animation state
    int getFrameIndex(CharState state, uint8_t frame) const;

    // Drawing wrappers — dispatch to _canvas or _tft, applying _yOffset
    inline void gfxFillRect(int32_t x, int32_t y, int32_t w, int32_t h, uint32_t c);
    inline void gfxDrawPixel(int32_t x, int32_t y, uint32_t c);
    inline void gfxFillCircle(int32_t cx, int32_t cy, int32_t r, uint32_t c);
    inline void gfxSetTextColor(uint32_t c);
    inline void gfxSetTextSize(uint8_t s);
    inline void gfxDrawString(const char* str, int32_t x, int32_t y);
};
