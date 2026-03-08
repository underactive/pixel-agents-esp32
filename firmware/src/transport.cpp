#include "transport.h"
#include <Arduino.h>

int SerialTransport::available() {
    return Serial.available();
}

int SerialTransport::read() {
    return Serial.read();
}
