#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum {
    OLED_IND_MINER_TX,
    OLED_IND_MINER_RX,
    OLED_IND_POOL_TX,
    OLED_IND_POOL_RX,
    OLED_IND_WIFI_TX,
    OLED_IND_WIFI_RX,
    OLED_IND_COUNT,
} oled_indicator_t;

typedef enum {
    OLED_LINK_DOWN,
    OLED_LINK_UP,
    OLED_LINK_TX,
    OLED_LINK_RX,
} oled_link_t;

void oled_init(void);
void oled_set_indicator(oled_indicator_t indicator, oled_link_t state);
void oled_set_work(uint64_t sent_us, uint64_t timeout_us, bool active);
void oled_set_last_pow(uint64_t last_pow_us);
void oled_set_bad_hash(bool bad_hash);
void oled_render(void);
