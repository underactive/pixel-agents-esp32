#pragma once
#include <stdint.h>
#include <atomic>
#include "config.h"

#if defined(HAS_WAKEWORD)

// Free functions for cross-module pause/resume (called from sound.cpp)
void wakeword_pause();
void wakeword_resume();

class WakeWord {
public:
    bool begin();       // Load model, start detection task
    bool poll();        // Returns true if wake word detected since last poll
    void pause();       // Pause I2S reading (for sound playback)
    void resume();      // Resume I2S reading

private:
    bool _ready = false;
    std::atomic<bool> _detected{false};
    std::atomic<bool> _paused{false};

    static void detectTask(void* param);
};

#else
inline void wakeword_pause() {}
inline void wakeword_resume() {}
#endif
