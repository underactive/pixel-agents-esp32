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

    void drawFloor();
    void drawFurniture();
    void drawCharacter(const Character& ch);
    void drawBubble(const Character& ch);
    void drawStatusBar(OfficeState& office);
    void drawSpawnEffect(const Character& ch);

    // Sprite rendering helpers
    void drawIndexedSprite(int x, int y, const uint8_t* tmpl, int w, int h,
                          const uint16_t* palette, bool flipH = false);
    void drawRGB565Sprite(int x, int y, const uint16_t* data, int w, int h);

    // Get local frame index (0-6) for animation state
    int getFrameIndex(CharState state, uint8_t frame) const;
};
