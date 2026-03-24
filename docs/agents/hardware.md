# Hardware Reference

Pin assignments and component details for all board variants. Referenced from `CLAUDE.md`.

---

## Components

| Ref | Component | Purpose |
|-----|-----------|---------|
| U1 | ESP32 (CYD), ESP32-S3 (CYD-S3, LILYGO) | MCU + display driver |
| D1 | ILI9341 2.8" TFT (CYD, CYD-S3) or ST7789 1.9" IPS (LILYGO) | Pixel art scene display |
| T1 | XPT2046 (CYD) or FT6336G (CYD-S3) | Touch input |
| S1 | SC8002B mono amp (CYD) or ES8311 audio codec + speaker amp (CYD-S3) | Sound effects playback |
| M1 | ES8311 analog mic input (CYD-S3 only) | Wake word detection microphone |

## Pin Assignments

### LILYGO T-Display S3

| Pin | Function | Notes |
|-----|----------|-------|
| 11 | TFT_MOSI | SPI data |
| 12 | TFT_SCLK | SPI clock |
| 10 | TFT_CS | Chip select |
| 13 | TFT_DC | Data/command |
| 9 | TFT_RST | Reset |
| 14 | TFT_BL | Backlight |

### CYD (ESP32-2432S028R)

| Pin | Function | Notes |
|-----|----------|-------|
| 13 | TFT_MOSI | SPI data |
| 14 | TFT_SCLK | SPI clock |
| 15 | TFT_CS | Chip select |
| 2 | TFT_DC | Data/command |
| -1 | TFT_RST | No reset pin |
| 21 | TFT_BL | Backlight |
| 12 | TFT_MISO | SPI read-back |
| 25 | TOUCH_CLK | XPT2046 SPI clock (separate bus) |
| 39 | TOUCH_MISO | XPT2046 SPI data in |
| 32 | TOUCH_MOSI | XPT2046 SPI data out |
| 33 | TOUCH_CS | XPT2046 chip select |
| 36 | TOUCH_IRQ | XPT2046 interrupt |
| 26 | AUDIO_DAC | ESP32 internal DAC → SC8002B amp → speaker header |

### CYD-S3 Capacitive (`freenove-s3-28c`)

| Pin | Function | Notes |
|-----|----------|-------|
| 11 | TFT_MOSI | SPI data |
| 12 | TFT_SCLK | SPI clock |
| 10 | TFT_CS | Chip select |
| 46 | TFT_DC | Data/command |
| -1 | TFT_RST | No reset pin |
| 45 | TFT_BL | Backlight |
| 16 | TOUCH_SDA | FT6336G I2C data (shared with ES8311) |
| 15 | TOUCH_SCL | FT6336G I2C clock (shared with ES8311) |
| 42 | LED_NEOPIXEL | WS2812B addressable RGB LED |
| 4 | I2S_MCK | ES8311 master clock |
| 5 | I2S_BCLK | I2S bit clock |
| 6 | I2S_DIN | I2S data in (ES8311 ADC, wake word mic input) |
| 7 | I2S_WS | I2S word select |
| 8 | I2S_DOUT | I2S data out |
| 1 | AMP_ENABLE | Speaker amp enable (AP_ENABLE) |
