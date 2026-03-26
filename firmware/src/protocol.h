#pragma once
#include <stdint.h>
#include "config.h"
#include "transport.h"

struct AgentUpdate {
    uint8_t agentId;
    CharState state;
    char toolName[MAX_TOOL_NAME_LEN + 1];
};

struct StatusText {
    uint8_t agentId;
    char text[MAX_STATUS_TEXT_LEN + 1];
};

struct UsageStatsMsg {
    uint8_t currentPct;
    uint8_t weeklyPct;
    uint16_t currentResetMin;
    uint16_t weeklyResetMin;
};

struct DeviceSettingsMsg {
    uint8_t dogEnabled;
    uint8_t dogColor;
    uint8_t screenFlip;
    uint8_t soundEnabled;
    uint8_t dogBarkEnabled;
};

// Callback types
using AgentUpdateCb  = void(*)(const AgentUpdate&);
using AgentCountCb   = void(*)(uint8_t count);
using HeartbeatCb    = void(*)(uint32_t timestamp);
using StatusTextCb   = void(*)(const StatusText&);
using UsageStatsCb   = void(*)(const UsageStatsMsg&);
using ScreenshotReqCb = void(*)();
using DeviceSettingsCb = void(*)(const DeviceSettingsMsg&);
using IdentifyReqCb   = void(*)();

class Protocol {
public:
    void begin(AgentUpdateCb onUpdate, AgentCountCb onCount,
               HeartbeatCb onHeartbeat, StatusTextCb onStatus,
               UsageStatsCb onUsage = nullptr,
               ScreenshotReqCb onScreenshotReq = nullptr,
               DeviceSettingsCb onDeviceSettings = nullptr,
               IdentifyReqCb onIdentifyReq = nullptr);
    void process(Transport& transport);  // call each loop iteration — reads available bytes from transport

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
    UsageStatsCb  _onUsage = nullptr;
    ScreenshotReqCb _onScreenshotReq = nullptr;
    DeviceSettingsCb _onDeviceSettings = nullptr;
    IdentifyReqCb   _onIdentifyReq = nullptr;

    int payloadLength(uint8_t msgType) const;
    void dispatch();
};
