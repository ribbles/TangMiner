#include "oled.h"

#include <stdio.h>
#include <string.h>

#include "driver/i2c_master.h"
#include "esp_check.h"
#include "esp_rom_sys.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "u8g2.h"

#define OLED_SCL_GPIO 6
#define OLED_SDA_GPIO 5
#define OLED_ADDR 0x3C
#define OLED_I2C_HZ 400000
#define OLED_I2C_TIMEOUT_MS 1000
#define OLED_WIDTH 72
#define OLED_HEIGHT 40

#define INDICATOR_SIZE 8
#define PROGRESS_X 2
#define PROGRESS_Y 2
#define PROGRESS_W 13
#define PROGRESS_H 36
#define TIMER_MARGIN_R 2
#define TIMER_Y 27
#define BAD_HASH_X0 2
#define BAD_HASH_X1 14
#define BAD_HASH_Y0 2
#define BAD_HASH_Y1 37
#define OLED_TX_BUF_SIZE 64

typedef struct {
    oled_link_t link;
    uint64_t last_activity_us;
} oled_indicator_state_t;

static u8g2_t u8g2;
static i2c_master_bus_handle_t oled_bus;
static i2c_master_dev_handle_t oled_dev;
static uint8_t oled_tx_buf[OLED_TX_BUF_SIZE];
static size_t oled_tx_len;
static oled_indicator_state_t indicators[OLED_IND_COUNT];
static uint64_t work_sent_us;
static uint64_t work_timeout_us;
static uint64_t last_pow_us;
static bool work_active;
static bool bad_hash;

static const uint8_t wifi_icon_8x7[] = {
    0x7E, /* .######. */
    0x81, /* #......# */
    0x3C, /* ..####.. */
    0x42, /* .#....#. */
    0x18, /* ...##... */
    0x00, /* ........ */
    0x18, /* ...##... */
};

static bool oled_i2c_flush(void)
{
    if (oled_tx_len == 0) {
        return true;
    }
    esp_err_t err = i2c_master_transmit(oled_dev, oled_tx_buf, oled_tx_len,
                                        pdMS_TO_TICKS(OLED_I2C_TIMEOUT_MS));
    oled_tx_len = 0;
    return err == ESP_OK;
}

static uint8_t oled_u8x8_byte_i2c(u8x8_t *u8x8, uint8_t msg, uint8_t arg_int, void *arg_ptr)
{
    (void)u8x8;

    switch (msg) {
    case U8X8_MSG_BYTE_INIT: {
        i2c_master_bus_config_t bus_cfg = {
            .i2c_port = I2C_NUM_0,
            .sda_io_num = OLED_SDA_GPIO,
            .scl_io_num = OLED_SCL_GPIO,
            .clk_source = I2C_CLK_SRC_DEFAULT,
            .glitch_ignore_cnt = 7,
            .flags.enable_internal_pullup = true,
        };
        i2c_device_config_t dev_cfg = {
            .dev_addr_length = I2C_ADDR_BIT_LEN_7,
            .device_address = OLED_ADDR,
            .scl_speed_hz = OLED_I2C_HZ,
        };
        ESP_RETURN_ON_FALSE(i2c_new_master_bus(&bus_cfg, &oled_bus) == ESP_OK, 0,
                            "oled", "OLED I2C bus init failed");
        ESP_RETURN_ON_FALSE(i2c_master_bus_add_device(oled_bus, &dev_cfg, &oled_dev) == ESP_OK, 0,
                            "oled", "OLED I2C device init failed");
        return 1;
    }
    case U8X8_MSG_BYTE_START_TRANSFER:
        oled_tx_len = 0;
        return 1;
    case U8X8_MSG_BYTE_SEND: {
        const uint8_t *data = (const uint8_t *)arg_ptr;
        for (uint8_t i = 0; i < arg_int; i++) {
            if (oled_tx_len == sizeof(oled_tx_buf) && !oled_i2c_flush()) {
                return 0;
            }
            oled_tx_buf[oled_tx_len++] = data[i];
        }
        return 1;
    }
    case U8X8_MSG_BYTE_END_TRANSFER:
        return oled_i2c_flush() ? 1 : 0;
    case U8X8_MSG_BYTE_SET_DC:
        return 1;
    default:
        return 0;
    }
}

static uint8_t oled_u8x8_gpio_delay(u8x8_t *u8x8, uint8_t msg, uint8_t arg_int, void *arg_ptr)
{
    (void)u8x8;
    (void)arg_ptr;

    switch (msg) {
    case U8X8_MSG_GPIO_AND_DELAY_INIT:
        return 1;
    case U8X8_MSG_DELAY_MILLI:
        vTaskDelay(pdMS_TO_TICKS(arg_int));
        return 1;
    case U8X8_MSG_DELAY_10MICRO:
        esp_rom_delay_us(10 * arg_int);
        return 1;
    case U8X8_MSG_DELAY_100NANO:
    case U8X8_MSG_DELAY_NANO:
    case U8X8_MSG_DELAY_I2C:
        return 1;
    default:
        return 1;
    }
}

static void draw_border(void)
{
    if (!work_active) {
        uint64_t now = esp_timer_get_time();
        if (((now / 500000ULL) & 1ULL) != 0) {
            u8g2_DrawFrame(&u8g2, 0, 0, OLED_WIDTH, OLED_HEIGHT);
        }
    }
}

static void draw_elapsed(void)
{
    uint64_t base = last_pow_us ? last_pow_us : esp_timer_get_time();
    uint32_t secs = (uint32_t)((esp_timer_get_time() - base) / 1000000ULL);
    uint32_t hours = secs / 3600;
    uint32_t mins = (secs / 60) % 60;
    uint32_t rem = secs % 60;
    char text[12];

    if (hours > 99) {
        hours = 99;
        mins = 59;
        rem = 59;
    }
    snprintf(text, sizeof(text), "%02lu:%02lu:%02lu",
             (unsigned long)hours, (unsigned long)mins, (unsigned long)rem);
    u8g2_SetFont(&u8g2, u8g2_font_6x10_mn);
    u8g2_SetFontPosTop(&u8g2);
    u8g2_DrawStr(&u8g2, OLED_WIDTH - u8g2_GetStrWidth(&u8g2, text) - TIMER_MARGIN_R, TIMER_Y, text);
}

static void draw_progress(void)
{
    u8g2_DrawFrame(&u8g2, PROGRESS_X, PROGRESS_Y, PROGRESS_W, PROGRESS_H);
    if (!work_active || work_timeout_us == 0 || work_sent_us == 0) {
        return;
    }
    uint64_t now = esp_timer_get_time();
    uint64_t elapsed = now > work_sent_us ? now - work_sent_us : 0;
    if (elapsed > work_timeout_us) {
        elapsed = work_timeout_us;
    }
    int fill = (int)((elapsed * (PROGRESS_H - 2)) / work_timeout_us);
    u8g2_DrawBox(&u8g2, PROGRESS_X + 1, PROGRESS_Y + PROGRESS_H - 1 - fill,
                 PROGRESS_W - 2, fill);
}

static void draw_indicator_box(int x, int y, oled_indicator_t ind, uint64_t now)
{
    bool is_recent = (now - indicators[ind].last_activity_us) < 300000ULL; // 300 ms window
    bool pulse_on = ((now / 50000ULL) & 1ULL) != 0; // toggle every 50 ms

    // Always draw the outline (hollow frame)
    u8g2_DrawFrame(&u8g2, x, y, INDICATOR_SIZE, INDICATOR_SIZE);

    // Determine whether we should fill the box
    bool fill = false;
    if (indicators[ind].link == OLED_LINK_UP) {
        // Connected: normally solid, flash to hollow on activity
        fill = !(is_recent && !pulse_on);
    } else {
        // Disconnected: normally hollow, flash solid on activity attempts
        fill = is_recent && pulse_on;
    }

    if (fill) {
        u8g2_DrawBox(&u8g2, x, y, INDICATOR_SIZE, INDICATOR_SIZE);
    }
}


static void draw_indicators(void)
{
    uint64_t now = esp_timer_get_time();

    // 1. Draw 2x larger header labels: WiFi icon, 'P', 'F'
    u8g2_DrawBitmap(&u8g2, 32, 2, 1, 7, wifi_icon_8x7);

    u8g2_SetFont(&u8g2, u8g2_font_6x10_tr);
    u8g2_SetFontPosTop(&u8g2);
    u8g2_DrawStr(&u8g2, 47, 1, "P");
    u8g2_DrawStr(&u8g2, 61, 1, "F");

    // 2. Draw TX and RX tags to the left of the indicator rows in 6x10 font
    u8g2_DrawStr(&u8g2, 18, 9, "TX");
    u8g2_DrawStr(&u8g2, 18, 18, "RX");

    // 3. Draw 8x8 indicator pairs for WiFi, Pool, FPGA (TX row at Y=10, RX row at Y=19)
    const oled_indicator_t col_tx[3] = {OLED_IND_WIFI_TX, OLED_IND_POOL_TX, OLED_IND_MINER_TX};
    const oled_indicator_t col_rx[3] = {OLED_IND_WIFI_RX, OLED_IND_POOL_RX, OLED_IND_MINER_RX};
    const int col_x[3] = {32, 46, 60};

    for (int i = 0; i < 3; i++) {
        draw_indicator_box(col_x[i], 10, col_tx[i], now);
        draw_indicator_box(col_x[i], 19, col_rx[i], now);
    }
}

static void draw_bad_hash(void)
{
    if (!bad_hash) {
        return;
    }
    u8g2_DrawLine(&u8g2, BAD_HASH_X0, BAD_HASH_Y0, BAD_HASH_X1, BAD_HASH_Y1);
    u8g2_DrawLine(&u8g2, BAD_HASH_X0 + 1, BAD_HASH_Y0, BAD_HASH_X1 + 1, BAD_HASH_Y1);
    u8g2_DrawLine(&u8g2, BAD_HASH_X1, BAD_HASH_Y0, BAD_HASH_X0, BAD_HASH_Y1);
    u8g2_DrawLine(&u8g2, BAD_HASH_X1 + 1, BAD_HASH_Y0, BAD_HASH_X0 + 1, BAD_HASH_Y1);
}

void oled_init(void)
{
    u8g2_Setup_ssd1306_i2c_72x40_er_f(&u8g2, U8G2_R0, oled_u8x8_byte_i2c,
                                      oled_u8x8_gpio_delay);
    u8x8_SetI2CAddress(u8g2_GetU8x8(&u8g2), OLED_ADDR << 1);
    u8g2_InitDisplay(&u8g2);
    u8g2_SetPowerSave(&u8g2, 0);
    oled_render();
}

void oled_set_indicator(oled_indicator_t indicator, oled_link_t state)
{
    if (indicator < OLED_IND_COUNT) {
        if (state == OLED_LINK_DOWN) {
            indicators[indicator].link = OLED_LINK_DOWN;
        } else if (state == OLED_LINK_UP) {
            indicators[indicator].link = OLED_LINK_UP;
        } else if (state == OLED_LINK_TX || state == OLED_LINK_RX) {
            indicators[indicator].last_activity_us = esp_timer_get_time();
        }
    }
}

void oled_set_work(uint64_t sent_us, uint64_t timeout_us, bool active)
{
    work_sent_us = sent_us;
    work_timeout_us = timeout_us;
    work_active = active;
}

void oled_set_last_pow(uint64_t pow_us)
{
    last_pow_us = pow_us;
}

void oled_set_bad_hash(bool value)
{
    bad_hash = value;
}

void oled_render(void)
{
    u8g2_ClearBuffer(&u8g2);
    draw_border();
    draw_progress();
    draw_indicators();
    draw_elapsed();
    draw_bad_hash();
    u8g2_SendBuffer(&u8g2);
}
