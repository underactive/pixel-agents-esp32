#include "protocol.h"
#include <Arduino.h>

void Protocol::begin(AgentUpdateCb onUpdate, AgentCountCb onCount,
                     HeartbeatCb onHeartbeat, StatusTextCb onStatus,
                     UsageStatsCb onUsage, ScreenshotReqCb onScreenshotReq) {
    _onUpdate = onUpdate;
    _onCount = onCount;
    _onHeartbeat = onHeartbeat;
    _onStatus = onStatus;
    _onUsage = onUsage;
    _onScreenshotReq = onScreenshotReq;
    _state = State::WAIT_SYNC1;
}

int Protocol::payloadLength(uint8_t msgType) const {
    switch (msgType) {
        case MSG_AGENT_UPDATE: return -1;  // variable: 2 + toolName
        case MSG_AGENT_COUNT:  return 1;
        case MSG_HEARTBEAT:    return 4;
        case MSG_USAGE_STATS: return 6;
        case MSG_SCREENSHOT_REQ: return 0;
        case MSG_STATUS_TEXT:  return -1;  // variable: 2 + text
        default: return -2;  // unknown
    }
}

void Protocol::process(Transport& transport) {
    while (transport.available()) {
        uint8_t b = transport.read();

        switch (_state) {
            case State::WAIT_SYNC1:
                if (b == SYNC_BYTE_1) _state = State::WAIT_SYNC2;
                break;

            case State::WAIT_SYNC2:
                if (b == SYNC_BYTE_2) {
                    _state = State::WAIT_TYPE;
                } else {
                    _state = State::WAIT_SYNC1;
                }
                break;

            case State::WAIT_TYPE: {
                _msgType = b;
                int len = payloadLength(b);
                if (len == -2) {
                    // Unknown message type, reset
                    _state = State::WAIT_SYNC1;
                    break;
                }
                _bufIdx = 0;
                if (len >= 0) {
                    _expectedLen = len;
                    if (len == 0) {
                        _state = State::WAIT_CHECKSUM;
                    } else {
                        _state = State::READ_PAYLOAD;
                    }
                } else {
                    // Variable length — first payload byte is the length indicator
                    // For AGENT_UPDATE: agent_id(1) + state(1) + tool_name_len(1) + tool_name(N)
                    // For STATUS_TEXT:  agent_id(1) + text_len(1) + text(N)
                    // We read the first 2-3 fixed bytes to determine total length
                    _expectedLen = -1; // sentinel: need to determine
                    _state = State::READ_PAYLOAD;
                }
                break;
            }

            case State::READ_PAYLOAD:
                if (_bufIdx >= SERIAL_BUF_SIZE) {
                    _state = State::WAIT_SYNC1; // abort oversized message
                    break;
                }
                _buf[_bufIdx++] = b;

                // Determine expected length for variable messages after reading header bytes
                if (_expectedLen < 0) {
                    if (_msgType == MSG_AGENT_UPDATE && _bufIdx >= 3) {
                        // buf[0]=agentId, buf[1]=state, buf[2]=toolNameLen
                        uint8_t toolLen = _buf[2];
                        if (toolLen > MAX_TOOL_NAME_LEN) toolLen = MAX_TOOL_NAME_LEN;
                        _expectedLen = 3 + toolLen;
                    } else if (_msgType == MSG_STATUS_TEXT && _bufIdx >= 2) {
                        // buf[0]=agentId, buf[1]=textLen
                        uint8_t textLen = _buf[1];
                        if (textLen > MAX_STATUS_TEXT_LEN) textLen = MAX_STATUS_TEXT_LEN;
                        _expectedLen = 2 + textLen;
                    }
                }

                if (_expectedLen >= 0 && _bufIdx >= _expectedLen) {
                    _state = State::WAIT_CHECKSUM;
                }
                break;

            case State::WAIT_CHECKSUM: {
                // Verify XOR checksum
                uint8_t check = _msgType;
                for (int i = 0; i < _bufIdx; i++) {
                    check ^= _buf[i];
                }
                if (check == b) {
                    dispatch();
                }
                _state = State::WAIT_SYNC1;
                break;
            }
        }
    }
}

void Protocol::dispatch() {
    switch (_msgType) {
        case MSG_AGENT_UPDATE: {
            if (_bufIdx < 3) break;
            AgentUpdate upd;
            upd.agentId = _buf[0];
            if (_buf[1] > static_cast<uint8_t>(CharState::DESPAWN)) break;
            upd.state = static_cast<CharState>(_buf[1]);
            uint8_t toolLen = _buf[2];
            if (toolLen > MAX_TOOL_NAME_LEN) toolLen = MAX_TOOL_NAME_LEN;
            if (3 + toolLen > _bufIdx) toolLen = (_bufIdx > 3) ? _bufIdx - 3 : 0;
            memcpy(upd.toolName, &_buf[3], toolLen);
            upd.toolName[toolLen] = '\0';
            if (_onUpdate) _onUpdate(upd);
            break;
        }
        case MSG_AGENT_COUNT:
            if (_bufIdx >= 1 && _onCount) _onCount(_buf[0]);
            break;
        case MSG_HEARTBEAT:
            if (_bufIdx >= 4 && _onHeartbeat) {
                uint32_t ts = ((uint32_t)_buf[0] << 24) | ((uint32_t)_buf[1] << 16) |
                              ((uint32_t)_buf[2] << 8) | _buf[3];
                _onHeartbeat(ts);
            }
            break;
        case MSG_STATUS_TEXT: {
            if (_bufIdx < 2) break;
            StatusText st;
            st.agentId = _buf[0];
            uint8_t textLen = _buf[1];
            if (textLen > MAX_STATUS_TEXT_LEN) textLen = MAX_STATUS_TEXT_LEN;
            if (2 + textLen > _bufIdx) textLen = (_bufIdx > 2) ? _bufIdx - 2 : 0;
            memcpy(st.text, &_buf[2], textLen);
            st.text[textLen] = '\0';
            if (_onStatus) _onStatus(st);
            break;
        }
        case MSG_USAGE_STATS: {
            if (_bufIdx < 6) break;
            UsageStatsMsg us;
            us.currentPct = _buf[0];
            us.weeklyPct = _buf[1];
            us.currentResetMin = ((uint16_t)_buf[2] << 8) | _buf[3];
            us.weeklyResetMin = ((uint16_t)_buf[4] << 8) | _buf[5];
            if (_onUsage) _onUsage(us);
            break;
        }
        case MSG_SCREENSHOT_REQ:
            if (_onScreenshotReq) _onScreenshotReq();
            break;
    }
}
