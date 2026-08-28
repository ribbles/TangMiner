# ESP32-C3 OLED Miner Host

This firmware moves the TangMiner host loop from `scripts/mine.py` onto an ESP32-C3 OLED development board. The ESP32-C3 connects to WiFi with DHCP, speaks Stratum TCP to `public-pool.io:13333`, builds TangMiner UART work packets, reads FPGA `F` responses, validates hashes locally, and submits accepted shares.

## Board

Target board: `ESP32-C3 OLED development board with 0.42 inch OLED module ceramic antenna wifi Bluetooth ESP32 supermini development board`.

### Relevant Specs

- CPU Core: 32-bit RISC-V single-core processor (with FPU support)
- Clock Frequency: Up to 160 MHz
- In-Package Flash: 4 MB (embedded SPI flash)
- SRAM: 400 KB (including 16 KB dedicated for cache)
- ROM: 384 KB
- RTC SRAM: 8 KB
- Wi-Fi: 2.4 GHz IEEE 802.11 b/g/n (up to 150 Mbps data rate, supports 20/40 MHz bandwidth)
- USB-C: native ESP32-C3 USB serial/JTAG for flashing, logs, and power
- Operating Voltage: 3.0 V to 3.6 V
- OLED: 0.42 inch I2C OLED

> **OLED placement note:** this module is offset inside a 128x64 controller space; defaults use column offset `13` and page offset `1`, matching the advertised `(13, 14)` start point as closely as page-addressed text permits.

> **Important limitation:** ESP32-C3 USB is device-side serial/JTAG, not a USB host controller. A USB-C to USB-C cable cannot make the ESP32-C3 host the Tang Nano USB-UART. Use USB-C for power/flashing and wire the FPGA UART to ESP32-C3 GPIO UART pins.

## Pinout

![ESP32-C3](ESP32-C3.png)

| Function | ESP32-C3 pin | Direction | Notes |
| --- | --- | --- | --- |
| FPGA UART TX | GPIO21 / TX | ESP32-C3 to FPGA | Connect to FPGA UART RX |
| FPGA UART RX | GPIO20 / RX | FPGA to ESP32-C3 | Connect to FPGA UART TX |
| Ground | GND | Shared | Required common ground |
| OLED SCL | GPIO6 | On-board | Built-in display I2C clock |
| OLED SDA | GPIO5 | On-board | Built-in display I2C data |
| USB-C | USB serial/JTAG | Host PC to ESP32-C3 | Flashing, monitor, and power |
| 3V3 | 3.3 V | Power rail | Logic level is 3.3 V |
| 5V | VBUS | Power rail | Use only as appropriate with the split power cable |

UART settings to the FPGA are `115200 8N1`, no flow control.

## Screen

The OLED is monochrome and too small for useful runtime text, so the firmware uses pixels and compact glyphs only.

```text
+------+----------------------------------------------------------+--+
|####  |                                                          |M^|
|####  |                                                          |Mv|
|####  |                  \              /                       |P^|
|####  |                   \  bad hash  /                        |Pv|
|####  |                    \   X      /                         |W^|
|####  |                    /          \                         |Wv|
|####  |                   /            \                        |  |
|####  |                                                          |  |
|####  |                                    1h23m15s             |  |
+------+----------------------------------------------------------+--+
```

Left bar:

- Fill amount shows current FPGA work progress toward the timeout window.

Center:

- A large X appears after a bad FPGA hash validation failure.
- The requested color is red, but this OLED is monochrome, so the X is rendered as a high-contrast white X.

Right indicators, top to bottom:

- `M^`: miner UART TX
- `Mv`: miner UART RX
- `P^`: pool TCP TX
- `Pv`: pool TCP RX
- `W^`: WiFi connected/TX placeholder
- `Wv`: WiFi connected/RX placeholder

Requested color semantics:

- Red: disconnected
- White: connected
- Blue: TX activity
- Green: RX activity

Monochrome mapping:

- Disconnected: broken/off 2x2 marker
- Connected: steady 2x2 marker
- TX/RX activity: blinking 2x2 marker
- WiFi activity is not tracked cheaply; WiFi indicators show connection state

## Firmware Layout

- `mcu/mine.c`: app entrypoint, WiFi, DHCP logging, SNTP, main retry loop
- `mcu/miner.c` / `mcu/miner.h`: FPGA UART transport, work packet creation, stale work timeout, hash validation, share statistics
- `mcu/pool.c` / `mcu/pool.h`: Stratum TCP connection, JSON parsing, reconnect handling, share submissions
- `mcu/oled.c` / `mcu/oled.h`: SSD1306-style I2C OLED framebuffer and runtime indicators

## Libraries

Build system: PlatformIO with ESP-IDF.

Components used:

- ESP-IDF WiFi station and DHCP: `esp_wifi`, `esp_netif`, `esp_event`
- ESP-IDF logging: `ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE`
- ESP-IDF SNTP helper: `esp_netif_sntp`
- lwIP BSD sockets for Stratum TCP
- Managed component `espressif/cjson` for Stratum JSON
- ESP-IDF UART driver for the TangMiner binary protocol
- ESP-IDF I2C driver for the built-in OLED
- ESP-IDF mbedTLS SHA-256 for hashing and midstates

PlatformIO downloads any missing ESP32 platform packages and managed ESP-IDF components during build.

## Build And Flash

From the repository root, put local overrides in `./.env`:

```sh
MCU_PORT=COM14
WIFI_SSID=your-wifi
WIFI_PASS=your-pass
POOL_HOST=public-pool.io
POOL_PORT=13333
MINER_USER=bc1q...youraddress.worker
MINER_PASS=
```

Then build or flash:

```sh
make mcu-build
make mcu-flash
make mcu-monitor
```

The Makefile loads `./.env` before applying defaults, so it can set any Make override, including `TARGET`, `PIO`, `MCU_DIR`, `MCU_ENV`, `MCU_PORT`, `WIFI_SSID`, `WIFI_PASS`, `POOL_HOST`, `POOL_PORT`, `MINER_USER`, and `MINER_PASS`.

Command-line values still win over `.env` values:

```sh
make mcu-flash MCU_PORT=COM14 WIFI_SSID="other-wifi"
make mcu-monitor MCU_PORT=COM14
```

Use Make-style `KEY=value` lines in `.env`; avoid shell-only syntax such as `export KEY=value`.

Optional alternate env file:

```sh
make mcu-build ENV_FILE=.env.lab
```
