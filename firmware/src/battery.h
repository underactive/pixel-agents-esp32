#pragma once
#include "config.h"

#if defined(HAS_BATTERY)

void battery_begin();
void battery_update(uint32_t nowMs);
uint8_t battery_getPercent();
bool battery_isCharging();

#endif
