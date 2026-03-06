#pragma once
#include <stdint.h>
#include "config.h"

struct AgentUpdate {
    uint8_t agentId;
    CharState state;
    char toolName[MAX_TOOL_NAME_LEN + 1];
};

struct StatusText {
    uint8_t agentId;
    char text[MAX_STATUS_TEXT_LEN + 1];
};

// Callback types
using AgentUpdateCb  = void(*)(const AgentUpdate&);
using AgentCountCb   = void(*)(uint8_t count);
using HeartbeatCb    = void(*)(uint32_t timestamp);
using StatusTextCb   = void(*)(const StatusText&);

class Protocol {
public:
    void begin(AgentUpdateCb onUpdate, AgentCountCb onCount,
               HeartbeatCb onHeartbeat, StatusTextCb onStatus);
    void process();  // call each loop iteration — reads available serial bytes

private:
    enum class State : uint8_t {
        WAIT_SYNC1,
        WAIT_SYNC2,
        WAIT_TYPE,
        READ_PAYLOAD,
        WAIT_CHECKSUM
    };

    State _state = State::WAIT_SYNC1;
    uint8_t _msgType = 0;
    uint8_t _buf[SERIAL_BUF_SIZE];
    int _bufIdx = 0;
    int _expectedLen = 0;

    AgentUpdateCb _onUpdate = nullptr;
    AgentCountCb  _onCount = nullptr;
    HeartbeatCb   _onHeartbeat = nullptr;
    StatusTextCb  _onStatus = nullptr;

    int payloadLength(uint8_t msgType) const;
    void dispatch();
};
