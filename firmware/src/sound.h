#pragma once
#include <stddef.h>
#include <stdint.h>

enum class SoundId : uint8_t {
    STARTUP,
    DOG_BARK,
    KEYBOARD_TYPE,
    NOTIFICATION_CLICK,  // agent finished turn, waiting for user input
    MINIMAL_POP,         // agent waiting for tool permission
    COUNT  // sentinel — not a valid sound
};

class SoundPlayer {
public:
    void begin();
    void play(SoundId id);
    void update();
    bool isPlaying() const { return _playing; }

private:
    void startClip(const uint8_t* data, uint32_t len);
    void endClip();
    bool _ready = false;
    bool _playing = false;
    size_t _byteOffset = 0;
    const uint8_t* _pcm = nullptr;
    uint32_t _pcmLen = 0;
};
