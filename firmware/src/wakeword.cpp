#include "wakeword.h"

#if defined(HAS_WAKEWORD)
#include <Arduino.h>
#include "driver/i2s.h"
#include "esp_wn_iface.h"
#include "esp_wn_models.h"
#include "model_path.h"
#include "esp_heap_caps.h"

// ── File-scope state (single instance) ──────────────────
namespace {
WakeWord* s_instance = nullptr;
const esp_wn_iface_t* s_wn = nullptr;
model_iface_data_t* s_wnData = nullptr;
int s_chunkSize = 0;    // 16kHz samples per detect() call
constexpr i2s_port_t WW_I2S_PORT = I2S_NUM_0;

// Detection task constants
constexpr int WW_TASK_STACK     = 12288;  // bytes (12KB, fits 1KB discard buf + WakeNet inference)
constexpr int WW_TASK_PRIORITY  = 5;
constexpr int WW_TASK_CORE      = 0;      // detection on Core 0, main loop on Core 1
constexpr int WW_PAUSE_POLL_MS  = 50;     // how often paused task checks for resume
constexpr int WW_FLUSH_SAMPLES  = 512;    // samples per DMA flush read
constexpr int WW_FLUSH_ITERS    = 16;     // max flush iterations after unpause
constexpr int WW_I2S_TIMEOUT_MS = 100;    // I2S read timeout
} // namespace

// ── Free functions for cross-module access ──────────────
void wakeword_pause()  { if (s_instance) s_instance->pause(); }
void wakeword_resume() { if (s_instance) s_instance->resume(); }

// ── Lifecycle ───────────────────────────────────────────

bool WakeWord::begin() {
    if (_ready) return false;  // prevent duplicate detection tasks

    // Load models from flash partition labeled "model"
    srmodel_list_t* models = esp_srmodel_init("model");
    if (!models) {
        Serial.println("WakeWord: model partition not found (flash srmodels.bin)");
        return false;
    }

    // Find WakeNet model in the partition
    char* wnName = esp_srmodel_filter(models, ESP_WN_PREFIX, NULL);
    if (!wnName) {
        Serial.println("WakeWord: no WakeNet model in partition");
        return false;
    }

    // Get WakeNet interface vtable
    s_wn = esp_wn_handle_from_name(wnName);
    if (!s_wn) {
        Serial.println("WakeWord: handle lookup failed");
        return false;
    }

    // Create WakeNet instance (loads model weights into PSRAM)
    s_wnData = s_wn->create(wnName, DET_MODE_90);
    if (!s_wnData) {
        Serial.println("WakeWord: model creation failed");
        return false;
    }

    s_chunkSize = s_wn->get_samp_chunksize(s_wnData);
    if (s_chunkSize <= 0) {
        Serial.println("WakeWord: invalid chunk size");
        return false;
    }
    int sampleRate = s_wn->get_samp_rate(s_wnData);
    Serial.printf("WakeWord: '%s' ready (chunk=%d, rate=%dHz)\n",
                  wnName, s_chunkSize, sampleRate);

    s_instance = this;
    _ready = true;

    // Start detection on Core 0 (main loop runs on Core 1)
    xTaskCreatePinnedToCore(detectTask, "ww_detect", WW_TASK_STACK, this,
                            WW_TASK_PRIORITY, nullptr, WW_TASK_CORE);

    return true;
}

bool WakeWord::poll() {
    if (!_ready) return false;
    return _detected.exchange(false);
}

void WakeWord::pause() {
    _paused = true;
}

void WakeWord::resume() {
    if (!_ready) return;
    // Just flip the flag — the detection task on Core 0 handles
    // I2S flush and WakeNet clean on the pause→unpause transition
    // to avoid cross-core data races on s_wnData.
    _paused = false;
}

// ── Detection task ──────────────────────────────────────
// Runs on Core 0. Reads 24kHz stereo from I2S RX, extracts
// left-channel mono, downsamples 3:2 to 16kHz, runs WakeNet.

void WakeWord::detectTask(void* param) {
    WakeWord* self = static_cast<WakeWord*>(param);

    // Compute buffer sizes from WakeNet chunk size.
    // WakeNet expects s_chunkSize samples at 16kHz.
    // To produce N samples at 16kHz from 24kHz: need N * 3/2 samples at 24kHz.
    // Each 24kHz sample is a stereo frame (2 x int16_t = 4 bytes).
    const int out16k   = s_chunkSize;           // e.g. 480
    const int in24k    = out16k * 3 / 2;        // e.g. 720
    const int stereoBytes = in24k * 2 * sizeof(int16_t);  // e.g. 2880

    // Allocate buffers in PSRAM (never freed — task runs for device lifetime)
    int16_t* stereoBuf = static_cast<int16_t*>(
        heap_caps_malloc(stereoBytes, MALLOC_CAP_SPIRAM));
    int16_t* mono24k = static_cast<int16_t*>(
        heap_caps_malloc(in24k * sizeof(int16_t), MALLOC_CAP_SPIRAM));
    int16_t* feed16k = static_cast<int16_t*>(
        heap_caps_malloc(out16k * sizeof(int16_t), MALLOC_CAP_SPIRAM));

    if (!stereoBuf || !mono24k || !feed16k) {
        Serial.println("WakeWord: buffer allocation failed");
        if (stereoBuf) heap_caps_free(stereoBuf);
        if (mono24k)   heap_caps_free(mono24k);
        if (feed16k)   heap_caps_free(feed16k);
        vTaskDelete(nullptr);
        return;
    }

    bool wasPaused = false;

    for (;;) {
        // ── Pause gate ──────────────────────────────────
        if (self->_paused) {
            wasPaused = true;
            vTaskDelay(pdMS_TO_TICKS(WW_PAUSE_POLL_MS));
            continue;
        }

        // ── Post-pause cleanup (runs on Core 0, same as detect) ─
        if (wasPaused) {
            wasPaused = false;

            // Flush stale I2S RX DMA data accumulated while paused.
            // Note: s_wn->clean() is intentionally NOT called here —
            // it crashes on wakenet9l models (buggy dl_convq_queue_bzero).
            // The DMA flush is sufficient; stale audio won't match a
            // wake word pattern across multiple WakeNet chunks.
            int16_t discard[WW_FLUSH_SAMPLES];
            size_t bytes;
            for (int i = 0; i < WW_FLUSH_ITERS; i++) {
                i2s_read(WW_I2S_PORT, discard, sizeof(discard), &bytes, 0);
                if (bytes == 0) break;
            }
        }

        // ── Read 24kHz stereo from I2S RX ───────────────
        size_t bytesRead = 0;
        esp_err_t err = i2s_read(WW_I2S_PORT, stereoBuf, stereoBytes,
                                 &bytesRead, pdMS_TO_TICKS(WW_I2S_TIMEOUT_MS));
        if (err != ESP_OK || bytesRead < (size_t)stereoBytes) {
            continue;  // partial read or error, skip frame
        }

        // ── Extract left channel (mono 24kHz) ──────────
        for (int i = 0; i < in24k; i++) {
            mono24k[i] = stereoBuf[i * 2];  // left channel of each stereo frame
        }

        // ── Downsample 24kHz → 16kHz (3:2 ratio) ──────
        // WHY: Simple integer-ratio resampler chosen over a proper polyphase
        // filter because WakeNet is tolerant of aliasing artifacts — it only
        // needs to recognize a keyword, not produce hi-fi audio.
        // For every 2 output samples, consume 3 input samples.
        // Even output j: take input directly at position j*3/2
        // Odd output j:  average two adjacent inputs at j*3/2
        // Note: safe for WakeNet chunk sizes (480, 512) which are always even.
        for (int j = 0; j < out16k; j++) {
            int idx = j * 3 / 2;
            if (j & 1) {
                feed16k[j] = static_cast<int16_t>(
                    (static_cast<int32_t>(mono24k[idx]) + mono24k[idx + 1]) / 2);
            } else {
                feed16k[j] = mono24k[idx];
            }
        }

        // ── Run WakeNet detection ──────────────────────
        wakenet_state_t state = s_wn->detect(s_wnData, feed16k);
        if (state == WAKENET_DETECTED) {
            self->_detected.store(true);
        }
    }
}

#endif
