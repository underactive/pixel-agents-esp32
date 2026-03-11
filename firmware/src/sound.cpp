#include "sound.h"
#include "config.h"

#if defined(HAS_SOUND)
#include <Arduino.h>
#include <Wire.h>
#include <pgmspace.h>
#include "driver/i2s.h"
#include "codec/es8311/es8311.h"
#include "sounds/startup_sound_pcm.h"
#include "sounds/dog_bark_pcm.h"
#include "sounds/keyboard_type_pcm.h"
#include "sounds/notification_click_pcm.h"
#include "sounds/minimal_pop_pcm.h"

namespace {

// ── Amp GPIO helpers ────────────────────────────────────
static constexpr uint8_t AMP_ON  = SOUND_AMP_ENABLE_ACTIVE_LOW ? LOW  : HIGH;
static constexpr uint8_t AMP_OFF = SOUND_AMP_ENABLE_ACTIVE_LOW ? HIGH : LOW;

// ── Clip table ──────────────────────────────────────────
struct SoundClip {
    const uint8_t* data;
    uint32_t len;
};

static const SoundClip CLIPS[] = {
    { STARTUP_SOUND_PCM,       STARTUP_SOUND_PCM_LEN       },  // SoundId::STARTUP
    { DOG_BARK_PCM,            DOG_BARK_PCM_LEN            },  // SoundId::DOG_BARK
    { KEYBOARD_TYPE_PCM,       KEYBOARD_TYPE_PCM_LEN       },  // SoundId::KEYBOARD_TYPE
    { NOTIFICATION_CLICK_PCM,  NOTIFICATION_CLICK_PCM_LEN  },  // SoundId::NOTIFICATION_CLICK
    { MINIMAL_POP_PCM,         MINIMAL_POP_PCM_LEN         },  // SoundId::MINIMAL_POP
};
static_assert(sizeof(CLIPS) / sizeof(CLIPS[0]) == static_cast<uint8_t>(SoundId::COUNT),
              "CLIPS table must have one entry per SoundId");

// ── I2S / codec state ───────────────────────────────────
static constexpr i2s_port_t SOUND_I2S_PORT = I2S_NUM_0;
static constexpr size_t PCM_BYTES_PER_SAMPLE = 2;
static int16_t stereoBuf[SOUND_PCM_CHUNK_SAMPLES * 2];
static es8311_handle_t codecHandle = nullptr;

static bool initI2S() {
    i2s_config_t cfg = {};
    cfg.mode = static_cast<i2s_mode_t>(I2S_MODE_MASTER | I2S_MODE_TX);
    cfg.sample_rate = SOUND_SAMPLE_RATE;
    cfg.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
    cfg.channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT;
    cfg.communication_format = I2S_COMM_FORMAT_I2S;
    cfg.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
    cfg.dma_buf_count = SOUND_I2S_DMA_BUF_COUNT;
    cfg.dma_buf_len = SOUND_I2S_DMA_BUF_LEN;
    cfg.use_apll = true;
    cfg.tx_desc_auto_clear = true;
    cfg.fixed_mclk = 0;
    cfg.mclk_multiple = I2S_MCLK_MULTIPLE_256;

    if (i2s_driver_install(SOUND_I2S_PORT, &cfg, 0, nullptr) != ESP_OK) {
        return false;
    }

    i2s_pin_config_t pins = {};
    pins.bck_io_num = SOUND_I2S_BCK;
    pins.ws_io_num = SOUND_I2S_WS;
    pins.data_out_num = SOUND_I2S_DOUT;
    pins.data_in_num = I2S_PIN_NO_CHANGE;
    pins.mck_io_num = SOUND_I2S_MCK;
    if (i2s_set_pin(SOUND_I2S_PORT, &pins) != ESP_OK) {
        return false;
    }

    return true;
}
} // namespace

void SoundPlayer::begin() {
    if (_ready) return;

    // Amp off until first clip plays
    pinMode(SOUND_AMP_ENABLE, OUTPUT);
    digitalWrite(SOUND_AMP_ENABLE, AMP_OFF);

    Wire.begin(SOUND_I2C_SDA, SOUND_I2C_SCL);
    Wire.setClock(SOUND_I2C_FREQ);

    if (!initI2S()) {
        Serial.println("Audio init failed: I2S setup");
        return;
    }

    codecHandle = es8311_create(I2C_NUM_0, ES8311_ADDRESS_0);
    if (!codecHandle) {
        Serial.println("Audio init failed: ES8311 create");
        return;
    }

    es8311_clock_config_t clk = {};
    clk.mclk_from_mclk_pin = true;
    clk.mclk_frequency = SOUND_SAMPLE_RATE * SOUND_MCLK_MULT;
    clk.sample_frequency = SOUND_SAMPLE_RATE;

    if (es8311_init(codecHandle, &clk, ES8311_RESOLUTION_16, ES8311_RESOLUTION_16) != ESP_OK) {
        Serial.println("Audio init failed: ES8311 init");
        return;
    }

    es8311_voice_volume_set(codecHandle, SOUND_VOLUME_PCT, nullptr);
    es8311_voice_mute(codecHandle, false);
    i2s_zero_dma_buffer(SOUND_I2S_PORT);

    _ready = true;
}

void SoundPlayer::play(SoundId id) {
    uint8_t idx = static_cast<uint8_t>(id);
    if (idx >= static_cast<uint8_t>(SoundId::COUNT)) return;
    startClip(CLIPS[idx].data, CLIPS[idx].len);
}

void SoundPlayer::startClip(const uint8_t* data, uint32_t len) {
    if (!_ready || data == nullptr || len == 0) return;
    // Enable amp
    digitalWrite(SOUND_AMP_ENABLE, AMP_ON);
    delay(10);
    _pcm = data;
    _pcmLen = len & ~1u;  // truncate to even (16-bit PCM samples)
    _byteOffset = 0;
    _playing = true;
    i2s_zero_dma_buffer(SOUND_I2S_PORT);
}

void SoundPlayer::endClip() {
    _playing = false;
    _pcm = nullptr;
    _pcmLen = 0;
    digitalWrite(SOUND_AMP_ENABLE, AMP_OFF);
}

void SoundPlayer::update() {
    if (!_ready || !_playing || _pcm == nullptr || _pcmLen == 0) return;
    for (int attempt = 0; attempt < SOUND_I2S_PREFILL_CHUNKS && _playing; attempt++) {
        if (_byteOffset >= _pcmLen) {
            endClip();
            break;
        }

        size_t remainingBytes = _pcmLen - _byteOffset;
        size_t remainingSamples = remainingBytes / PCM_BYTES_PER_SAMPLE;
        size_t chunkSamples = remainingSamples;
        if (chunkSamples > SOUND_PCM_CHUNK_SAMPLES) chunkSamples = SOUND_PCM_CHUNK_SAMPLES;

        for (size_t i = 0; i < chunkSamples; i++) {
            uint16_t lo = pgm_read_byte(&_pcm[_byteOffset + i * 2]);
            uint16_t hi = pgm_read_byte(&_pcm[_byteOffset + i * 2 + 1]);
            int16_t sample = static_cast<int16_t>((hi << 8) | lo);
            stereoBuf[i * 2] = sample;
            stereoBuf[i * 2 + 1] = sample;
        }

        size_t bytesToWrite = chunkSamples * 2 * sizeof(int16_t);
        size_t bytesWritten = 0;
        i2s_write(SOUND_I2S_PORT, stereoBuf, bytesToWrite, &bytesWritten, 0);

        if (bytesWritten == 0) {
            break;
        }

        size_t samplesWritten = bytesWritten / (2 * sizeof(int16_t));
        _byteOffset += samplesWritten * PCM_BYTES_PER_SAMPLE;
        if (_byteOffset >= _pcmLen) {
            endClip();
            break;
        }
    }
}
#else
void SoundPlayer::begin() {}
void SoundPlayer::play(SoundId) {}
void SoundPlayer::update() {}
#endif
