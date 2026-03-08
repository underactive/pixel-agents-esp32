#pragma once
#include <stdint.h>
#include <string.h>
#include <atomic>
#include "config.h"

// ── Abstract transport interface ─────────────────────────
// Provides a byte-source API so the protocol parser can read
// from Serial, BLE, or any future transport identically.

class Transport {
public:
    virtual int available() = 0;
    virtual int read() = 0;
    virtual ~Transport() = default;
};

// ── Serial transport ─────────────────────────────────────

class SerialTransport : public Transport {
public:
    int available() override;
    int read() override;
};

// ── Lock-free ring buffer (single producer / single consumer) ──
// Uses std::atomic with acquire/release ordering for multi-core
// safety (ESP32 is dual-core). Exactly one writer and one reader
// may operate concurrently without locks.

template <uint16_t SIZE>
class RingBuffer {
    static_assert((SIZE & (SIZE - 1)) == 0, "RingBuffer SIZE must be a power of 2");
public:
    void push(uint8_t b) {
        uint16_t h = _head.load(std::memory_order_relaxed);
        uint16_t nextHead = (h + 1) & _mask;
        if (nextHead == _tail.load(std::memory_order_acquire)) return; // full — drop byte
        _buf[h] = b;
        _head.store(nextHead, std::memory_order_release);
    }

    void pushBytes(const uint8_t* data, size_t len) {
        for (size_t i = 0; i < len; i++) {
            push(data[i]);
        }
    }

    int pop() {
        uint16_t t = _tail.load(std::memory_order_relaxed);
        if (_head.load(std::memory_order_acquire) == t) return -1; // empty
        uint8_t b = _buf[t];
        _tail.store((t + 1) & _mask, std::memory_order_release);
        return b;
    }

    int count() const {
        return (_head.load(std::memory_order_acquire) -
                _tail.load(std::memory_order_acquire)) & _mask;
    }

    // Only safe when no concurrent push/pop is in progress.
    // Call from a context where the producer is known to be idle
    // (e.g., after BLE disconnect, before re-advertising).
    void reset() {
        _head.store(0, std::memory_order_release);
        _tail.store(0, std::memory_order_release);
    }

private:
    static constexpr uint16_t _mask = SIZE - 1;
    std::atomic<uint16_t> _head{0};
    std::atomic<uint16_t> _tail{0};
    uint8_t _buf[SIZE] = {};
};

// ── BLE transport ────────────────────────────────────────
// Reads from a ring buffer that is filled by the NimBLE
// NUS RX characteristic callback (runs in NimBLE task context).

class BleTransport : public Transport {
public:
    int available() override {
        drainIfNeeded();
        return _ring.count();
    }
    int read() override {
        drainIfNeeded();
        return _ring.pop();
    }

    // Called from NimBLE callback context — pushes received bytes
    void push(const uint8_t* data, size_t len) { _ring.pushBytes(data, len); }

    // Called from NimBLE disconnect callback — flags ring for reset.
    // Actual reset happens in main loop context via drainIfNeeded().
    void requestReset() { _resetPending.store(true, std::memory_order_release); }

private:
    RingBuffer<BLE_RING_BUF_SIZE> _ring;
    std::atomic<bool> _resetPending{false};

    void drainIfNeeded() {
        if (_resetPending.load(std::memory_order_acquire)) {
            _ring.reset();
            _resetPending.store(false, std::memory_order_release);
        }
    }
};
