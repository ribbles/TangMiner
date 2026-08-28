#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cJSON.h"
#include "driver/gpio.h"
#include "driver/i2c.h"
#include "driver/uart.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "nvs_flash.h"

#include <lwip/sockets.h>
#include <lwip/netdb.h>

#if __has_include("mine_config.h")
#include "mine_config.h"
#endif

#ifndef WIFI_SSID
#define WIFI_SSID ""
#endif
#ifndef WIFI_PASS
#define WIFI_PASS ""
#endif
#ifndef POOL_HOST
#define POOL_HOST "public-pool.io"
#endif
#ifndef POOL_PORT
#define POOL_PORT 13333
#endif
#ifndef MINER_USER
#define MINER_USER "bc1qjwgtd0sa3znxftx5s7mzwaz8ct34yvesr2nqa6.tangnano9k"
#endif
#ifndef MINER_PASS
#define MINER_PASS ""
#endif

#define FPGA_UART UART_NUM_1
#define FPGA_BAUD 115200
#define FPGA_TX_GPIO GPIO_NUM_21
#define FPGA_RX_GPIO GPIO_NUM_20

#define I2C_PORT I2C_NUM_0
#define OLED_SCL_GPIO GPIO_NUM_6
#define OLED_SDA_GPIO GPIO_NUM_5
#define OLED_ADDR 0x3C
#define OLED_WIDTH 72
#define OLED_HEIGHT 40
#define OLED_X_OFFSET 13
#define OLED_PAGE_OFFSET 1

#define SUGGESTED_POOL_DIFF 0.001
#define TARGET_SECS 12.0
#define MAX_SECS 30.0
#define LINE_BUF 4096
#define BRANCH_MAX 16

static const char *TAG = "tangminer-mcu";
static EventGroupHandle_t wifi_events;
static const int WIFI_READY = BIT0;
static double batch_diff = 0.003;
static int req_id;

typedef struct {
    char job_id[96];
    uint8_t prevhash[32];
    uint8_t coinb1[256];
    size_t coinb1_len;
    uint8_t coinb2[256];
    size_t coinb2_len;
    uint8_t branches[BRANCH_MAX][32];
    size_t branch_count;
    uint8_t version[4];
    char nbits[9];
    uint8_t nbits_le[4];
    char ntime[9];
    uint8_t ntime_le[4];
    bool valid;
} job_t;

typedef struct {
    uint8_t header[80];
    char job_id[96];
    char xn2_hex[32];
    char ntime[9];
    uint8_t pool_target[32];
    uint8_t network_target[32];
    double pool_diff;
    int64_t sent_us;
    bool valid;
} active_t;

static job_t job;
static active_t active;
static uint8_t extranonce1[64];
static size_t extranonce1_len;
static size_t extranonce2_size;
static uint64_t extranonce2;
static double pool_diff = 1.0;

static const uint32_t IV[8] = {
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
};

static const uint32_t K[64] = {
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
};

static const uint8_t font5x7[96][5] = {
    {0,0,0,0,0},{0,0,0x5f,0,0},{0,7,0,7,0},{0x14,0x7f,0x14,0x7f,0x14},{0x24,0x2a,0x7f,0x2a,0x12},{0x23,0x13,8,0x64,0x62},{0x36,0x49,0x55,0x22,0x50},{0,5,3,0,0},{0,0x1c,0x22,0x41,0},{0,0x41,0x22,0x1c,0},{0x14,8,0x3e,8,0x14},{8,8,0x3e,8,8},{0,0x50,0x30,0,0},{8,8,8,8,8},{0,0x60,0x60,0,0},{0x20,0x10,8,4,2},
    {0x3e,0x51,0x49,0x45,0x3e},{0,0x42,0x7f,0x40,0},{0x42,0x61,0x51,0x49,0x46},{0x21,0x41,0x45,0x4b,0x31},{0x18,0x14,0x12,0x7f,0x10},{0x27,0x45,0x45,0x45,0x39},{0x3c,0x4a,0x49,0x49,0x30},{1,0x71,9,5,3},{0x36,0x49,0x49,0x49,0x36},{6,0x49,0x49,0x29,0x1e},{0,0x36,0x36,0,0},{0,0x56,0x36,0,0},{8,0x14,0x22,0x41,0},{0x14,0x14,0x14,0x14,0x14},{0,0x41,0x22,0x14,8},{2,1,0x51,9,6},
    {0x32,0x49,0x79,0x41,0x3e},{0x7e,0x11,0x11,0x11,0x7e},{0x7f,0x49,0x49,0x49,0x36},{0x3e,0x41,0x41,0x41,0x22},{0x7f,0x41,0x41,0x22,0x1c},{0x7f,0x49,0x49,0x49,0x41},{0x7f,9,9,9,1},{0x3e,0x41,0x49,0x49,0x7a},{0x7f,8,8,8,0x7f},{0,0x41,0x7f,0x41,0},{0x20,0x40,0x41,0x3f,1},{0x7f,8,0x14,0x22,0x41},{0x7f,0x40,0x40,0x40,0x40},{0x7f,2,0x0c,2,0x7f},{0x7f,4,8,0x10,0x7f},{0x3e,0x41,0x41,0x41,0x3e},
    {0x7f,9,9,9,6},{0x3e,0x41,0x51,0x21,0x5e},{0x7f,9,0x19,0x29,0x46},{0x46,0x49,0x49,0x49,0x31},{1,1,0x7f,1,1},{0x3f,0x40,0x40,0x40,0x3f},{0x1f,0x20,0x40,0x20,0x1f},{0x3f,0x40,0x38,0x40,0x3f},{0x63,0x14,8,0x14,0x63},{7,8,0x70,8,7},{0x61,0x51,0x49,0x45,0x43},{0,0x7f,0x41,0x41,0},{2,4,8,0x10,0x20},{0,0x41,0x41,0x7f,0},{4,2,1,2,4},{0x40,0x40,0x40,0x40,0x40},
    {0,1,2,4,0},{0x20,0x54,0x54,0x54,0x78},{0x7f,0x48,0x44,0x44,0x38},{0x38,0x44,0x44,0x44,0x20},{0x38,0x44,0x44,0x48,0x7f},{0x38,0x54,0x54,0x54,0x18},{8,0x7e,9,1,2},{0x0c,0x52,0x52,0x52,0x3e},{0x7f,8,4,4,0x78},{0,0x44,0x7d,0x40,0},{0x20,0x40,0x44,0x3d,0},{0x7f,0x10,0x28,0x44,0},{0,0x41,0x7f,0x40,0},{0x7c,4,0x18,4,0x78},{0x7c,8,4,4,0x78},{0x38,0x44,0x44,0x44,0x38},
    {0x7c,0x14,0x14,0x14,8},{8,0x14,0x14,0x18,0x7c},{0x7c,8,4,4,8},{0x48,0x54,0x54,0x54,0x20},{4,0x3f,0x44,0x40,0x20},{0x3c,0x40,0x40,0x20,0x7c},{0x1c,0x20,0x40,0x20,0x1c},{0x3c,0x40,0x30,0x40,0x3c},{0x44,0x28,0x10,0x28,0x44},{0x0c,0x50,0x50,0x50,0x3c},{0x44,0x64,0x54,0x4c,0x44},{0,8,0x36,0x41,0},{0,0,0x7f,0,0},{0,0x41,0x36,8,0},{0x10,8,8,0x10,8},{0,0,0,0,0}
};

static uint32_t rotr(uint32_t x, int n) {
    return (x >> n) | (x << (32 - n));
}

static void sha256_compress(uint32_t state[8], const uint8_t block[64]) {
    uint32_t w[64];
    for (int i = 0; i < 16; i++) {
        w[i] = ((uint32_t)block[i * 4] << 24) | ((uint32_t)block[i * 4 + 1] << 16) |
               ((uint32_t)block[i * 4 + 2] << 8) | block[i * 4 + 3];
    }
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];
    for (int i = 0; i < 64; i++) {
        uint32_t s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        uint32_t ch = (e & f) ^ (~e & g);
        uint32_t t1 = h + s1 + ch + K[i] + w[i];
        uint32_t s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t t2 = s0 + maj;
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

static void sha256_bytes(const uint8_t *data, size_t len, uint8_t out[32]) {
    uint32_t state[8];
    memcpy(state, IV, sizeof(state));
    uint8_t block[64];
    size_t off = 0;
    while (len - off >= 64) {
        sha256_compress(state, data + off);
        off += 64;
    }
    size_t rem = len - off;
    memset(block, 0, sizeof(block));
    memcpy(block, data + off, rem);
    block[rem] = 0x80;
    if (rem >= 56) {
        sha256_compress(state, block);
        memset(block, 0, sizeof(block));
    }
    uint64_t bits = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++) {
        block[63 - i] = (uint8_t)(bits >> (i * 8));
    }
    sha256_compress(state, block);
    for (int i = 0; i < 8; i++) {
        out[i * 4] = state[i] >> 24;
        out[i * 4 + 1] = state[i] >> 16;
        out[i * 4 + 2] = state[i] >> 8;
        out[i * 4 + 3] = state[i];
    }
}

static void sha256d(const uint8_t *data, size_t len, uint8_t out[32]) {
    uint8_t tmp[32];
    sha256_bytes(data, len, tmp);
    sha256_bytes(tmp, sizeof(tmp), out);
}

static bool hexval(char c, uint8_t *v) {
    if (c >= '0' && c <= '9') *v = c - '0';
    else if (c >= 'a' && c <= 'f') *v = c - 'a' + 10;
    else if (c >= 'A' && c <= 'F') *v = c - 'A' + 10;
    else return false;
    return true;
}

static bool hex_to_bytes(const char *hex, uint8_t *out, size_t max, size_t *out_len) {
    size_t n = strlen(hex);
    if ((n & 1) || n / 2 > max) return false;
    for (size_t i = 0; i < n / 2; i++) {
        uint8_t hi, lo;
        if (!hexval(hex[i * 2], &hi) || !hexval(hex[i * 2 + 1], &lo)) return false;
        out[i] = (hi << 4) | lo;
    }
    *out_len = n / 2;
    return true;
}

static void bytes_to_hex(const uint8_t *in, size_t len, char *out) {
    static const char h[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        out[i * 2] = h[in[i] >> 4];
        out[i * 2 + 1] = h[in[i] & 0xf];
    }
    out[len * 2] = 0;
}

static void reverse_word_bytes(const uint8_t in[32], uint8_t out[32]) {
    for (int i = 0; i < 32; i += 4) {
        out[i] = in[i + 3]; out[i + 1] = in[i + 2];
        out[i + 2] = in[i + 1]; out[i + 3] = in[i];
    }
}

static void reverse_copy(const uint8_t *in, uint8_t *out, size_t len) {
    for (size_t i = 0; i < len; i++) out[i] = in[len - 1 - i];
}

static int be_cmp32(const uint8_t a[32], const uint8_t b[32]) {
    return memcmp(a, b, 32);
}

static void diff_to_target(double diff, uint8_t target[32]) {
    if (diff < 1e-12) diff = 1e-12;
    long double v = ldexpl(65535.0L, 208) / (long double)diff;
    memset(target, 0, 32);
    for (int i = 31; i >= 0 && v > 0.0L; i--) {
        long double byte = fmodl(v, 256.0L);
        target[i] = (uint8_t)byte;
        v = floorl(v / 256.0L);
    }
}

static void compact_to_target(const char *nbits, uint8_t target[32]) {
    memset(target, 0, 32);
    uint32_t bits = strtoul(nbits, NULL, 16);
    uint32_t mant = bits & 0x00ffffff;
    int exp = bits >> 24;
    int idx = 32 - exp;
    if (idx >= 0 && idx + 2 < 32) {
        target[idx] = mant >> 16;
        target[idx + 1] = mant >> 8;
        target[idx + 2] = mant;
    }
}

static void oled_cmd(uint8_t cmd) {
    uint8_t buf[2] = {0x00, cmd};
    i2c_master_write_to_device(I2C_PORT, OLED_ADDR, buf, sizeof(buf), pdMS_TO_TICKS(50));
}

static void oled_data(const uint8_t *data, size_t len) {
    uint8_t buf[OLED_WIDTH + 1];
    buf[0] = 0x40;
    memcpy(buf + 1, data, len);
    i2c_master_write_to_device(I2C_PORT, OLED_ADDR, buf, len + 1, pdMS_TO_TICKS(50));
}

static void oled_init(void) {
    i2c_config_t cfg = {
        .mode = I2C_MODE_MASTER,
        .sda_io_num = OLED_SDA_GPIO,
        .scl_io_num = OLED_SCL_GPIO,
        .sda_pullup_en = GPIO_PULLUP_ENABLE,
        .scl_pullup_en = GPIO_PULLUP_ENABLE,
        .master.clk_speed = 400000,
    };
    i2c_param_config(I2C_PORT, &cfg);
    i2c_driver_install(I2C_PORT, cfg.mode, 0, 0, 0);
    vTaskDelay(pdMS_TO_TICKS(50));
    const uint8_t init[] = {0xAE,0xD5,0x80,0xA8,0x3F,0xD3,0x00,0x40,0x8D,0x14,0x20,0x00,0xA1,0xC8,0xDA,0x12,0x81,0x7F,0xD9,0xF1,0xDB,0x40,0xA4,0xA6,0xAF};
    for (size_t i = 0; i < sizeof(init); i++) oled_cmd(init[i]);
}

static void oled_clear(void) {
    uint8_t zeros[OLED_WIDTH] = {0};
    for (int p = 0; p < OLED_HEIGHT / 8; p++) {
        oled_cmd(0xB0 + OLED_PAGE_OFFSET + p);
        oled_cmd(0x00 + ((OLED_X_OFFSET) & 0x0f));
        oled_cmd(0x10 + ((OLED_X_OFFSET >> 4) & 0x0f));
        oled_data(zeros, sizeof(zeros));
    }
}

static void oled_text_line(int line, const char *text) {
    uint8_t row[OLED_WIDTH] = {0};
    int col = 0;
    for (const char *p = text; *p && col + 6 <= OLED_WIDTH; p++) {
        char ch = (*p >= 32 && *p <= 127) ? *p : '?';
        memcpy(&row[col], font5x7[ch - 32], 5);
        col += 6;
    }
    oled_cmd(0xB0 + OLED_PAGE_OFFSET + line);
    oled_cmd(0x00 + ((OLED_X_OFFSET) & 0x0f));
    oled_cmd(0x10 + ((OLED_X_OFFSET >> 4) & 0x0f));
    oled_data(row, sizeof(row));
}

static void status_screen(const char *a, const char *b, const char *c, const char *d) {
    oled_text_line(0, a);
    oled_text_line(1, b);
    oled_text_line(2, c);
    oled_text_line(3, d);
}

static void wifi_event(void *arg, esp_event_base_t base, int32_t id, void *data) {
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        esp_wifi_connect();
        xEventGroupClearBits(wifi_events, WIFI_READY);
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        xEventGroupSetBits(wifi_events, WIFI_READY);
    }
}

static void wifi_start(void) {
    wifi_events = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    wifi_init_config_t init = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&init));
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, wifi_event, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, wifi_event, NULL));
    wifi_config_t cfg = {0};
    strlcpy((char *)cfg.sta.ssid, WIFI_SSID, sizeof(cfg.sta.ssid));
    strlcpy((char *)cfg.sta.password, WIFI_PASS, sizeof(cfg.sta.password));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &cfg));
    ESP_ERROR_CHECK(esp_wifi_start());
    xEventGroupWaitBits(wifi_events, WIFI_READY, pdFALSE, pdTRUE, portMAX_DELAY);
}

static int pool_connect(void) {
    char port[12];
    snprintf(port, sizeof(port), "%d", POOL_PORT);
    struct addrinfo hints = {.ai_socktype = SOCK_STREAM};
    struct addrinfo *res = NULL;
    int rc = getaddrinfo(POOL_HOST, port, &hints, &res);
    if (rc != 0 || !res) return -1;
    int s = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (s >= 0 && connect(s, res->ai_addr, res->ai_addrlen) != 0) {
        close(s);
        s = -1;
    }
    freeaddrinfo(res);
    if (s >= 0) {
        struct timeval tv = {.tv_sec = 0, .tv_usec = 200000};
        setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    }
    return s;
}

static void send_json(int sock, const char *method, const char *params) {
    char line[512];
    req_id++;
    snprintf(line, sizeof(line), "{\"id\":%d,\"method\":\"%s\",\"params\":%s}\n", req_id, method, params);
    send(sock, line, strlen(line), 0);
    ESP_LOGI(TAG, "POOL >> %s", line);
}

static void parse_subscribe(cJSON *msg) {
    cJSON *result = cJSON_GetObjectItem(msg, "result");
    if (!cJSON_IsArray(result)) return;
    cJSON *x1 = cJSON_GetArrayItem(result, 1);
    cJSON *x2 = cJSON_GetArrayItem(result, 2);
    if (cJSON_IsString(x1) && cJSON_IsNumber(x2)) {
        hex_to_bytes(x1->valuestring, extranonce1, sizeof(extranonce1), &extranonce1_len);
        extranonce2_size = (size_t)x2->valueint;
    }
}

static void parse_notify(cJSON *msg) {
    cJSON *p = cJSON_GetObjectItem(msg, "params");
    if (!cJSON_IsArray(p) || cJSON_GetArraySize(p) < 9) return;
    memset(&job, 0, sizeof(job));
    strlcpy(job.job_id, cJSON_GetArrayItem(p, 0)->valuestring, sizeof(job.job_id));
    uint8_t tmp[256];
    size_t len = 0;
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 1)->valuestring, tmp, sizeof(tmp), &len) || len != 32) return;
    reverse_word_bytes(tmp, job.prevhash);
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 2)->valuestring, job.coinb1, sizeof(job.coinb1), &job.coinb1_len)) return;
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 3)->valuestring, job.coinb2, sizeof(job.coinb2), &job.coinb2_len)) return;
    cJSON *branches = cJSON_GetArrayItem(p, 4);
    if (cJSON_IsArray(branches)) {
        int count = cJSON_GetArraySize(branches);
        if (count > BRANCH_MAX) count = BRANCH_MAX;
        for (int i = 0; i < count; i++) {
            if (!hex_to_bytes(cJSON_GetArrayItem(branches, i)->valuestring, job.branches[i], 32, &len) || len != 32) return;
            job.branch_count++;
        }
    }
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 5)->valuestring, tmp, sizeof(tmp), &len) || len != 4) return;
    reverse_copy(tmp, job.version, 4);
    strlcpy(job.nbits, cJSON_GetArrayItem(p, 6)->valuestring, sizeof(job.nbits));
    hex_to_bytes(job.nbits, tmp, sizeof(tmp), &len);
    reverse_copy(tmp, job.nbits_le, 4);
    strlcpy(job.ntime, cJSON_GetArrayItem(p, 7)->valuestring, sizeof(job.ntime));
    hex_to_bytes(job.ntime, tmp, sizeof(tmp), &len);
    reverse_copy(tmp, job.ntime_le, 4);
    job.valid = true;
    active.valid = false;
    ESP_LOGI(TAG, "new job %s branches=%u", job.job_id, (unsigned)job.branch_count);
}

static void parse_pool_line(char *line) {
    cJSON *msg = cJSON_Parse(line);
    if (!msg) return;
    cJSON *method = cJSON_GetObjectItem(msg, "method");
    cJSON *id = cJSON_GetObjectItem(msg, "id");
    if (cJSON_IsNumber(id) && id->valueint == 2) parse_subscribe(msg);
    if (cJSON_IsString(method) && strcmp(method->valuestring, "mining.set_difficulty") == 0) {
        cJSON *p = cJSON_GetObjectItem(msg, "params");
        cJSON *d = cJSON_IsArray(p) ? cJSON_GetArrayItem(p, 0) : NULL;
        if (cJSON_IsNumber(d)) pool_diff = d->valuedouble;
    } else if (cJSON_IsString(method) && strcmp(method->valuestring, "mining.set_extranonce") == 0) {
        cJSON *p = cJSON_GetObjectItem(msg, "params");
        cJSON *x1 = cJSON_IsArray(p) ? cJSON_GetArrayItem(p, 0) : NULL;
        cJSON *x2 = cJSON_IsArray(p) ? cJSON_GetArrayItem(p, 1) : NULL;
        if (cJSON_IsString(x1) && cJSON_IsNumber(x2)) {
            hex_to_bytes(x1->valuestring, extranonce1, sizeof(extranonce1), &extranonce1_len);
            extranonce2_size = (size_t)x2->valueint;
        }
    } else if (cJSON_IsString(method) && strcmp(method->valuestring, "mining.notify") == 0) {
        parse_notify(msg);
    }
    cJSON_Delete(msg);
}

static bool make_work_packet(uint8_t packet[79]) {
    if (!job.valid || extranonce2_size == 0 || extranonce2_size > 8) return false;
    uint8_t xn2[8] = {0};
    for (size_t i = 0; i < extranonce2_size; i++) {
        xn2[extranonce2_size - 1 - i] = (uint8_t)(extranonce2 >> (8 * i));
    }
    extranonce2++;
    bytes_to_hex(xn2, extranonce2_size, active.xn2_hex);

    uint8_t coinbase[600];
    size_t pos = 0;
    memcpy(coinbase + pos, job.coinb1, job.coinb1_len); pos += job.coinb1_len;
    memcpy(coinbase + pos, extranonce1, extranonce1_len); pos += extranonce1_len;
    memcpy(coinbase + pos, xn2, extranonce2_size); pos += extranonce2_size;
    memcpy(coinbase + pos, job.coinb2, job.coinb2_len); pos += job.coinb2_len;
    uint8_t merkle[32];
    sha256d(coinbase, pos, merkle);
    for (size_t i = 0; i < job.branch_count; i++) {
        uint8_t pair[64];
        memcpy(pair, merkle, 32);
        memcpy(pair + 32, job.branches[i], 32);
        sha256d(pair, sizeof(pair), merkle);
    }

    memcpy(active.header, job.version, 4);
    memcpy(active.header + 4, job.prevhash, 32);
    memcpy(active.header + 36, merkle, 32);
    memcpy(active.header + 68, job.ntime_le, 4);
    memcpy(active.header + 72, job.nbits_le, 4);
    memset(active.header + 76, 0, 4);
    strlcpy(active.job_id, job.job_id, sizeof(active.job_id));
    strlcpy(active.ntime, job.ntime, sizeof(active.ntime));
    active.pool_diff = pool_diff;
    diff_to_target(pool_diff, active.pool_target);
    compact_to_target(job.nbits, active.network_target);

    uint32_t st[8];
    memcpy(st, IV, sizeof(st));
    sha256_compress(st, active.header);
    packet[0] = 'T'; packet[1] = 'N'; packet[2] = 'J';
    for (int i = 0; i < 8; i++) {
        packet[3 + i * 4] = st[i] >> 24;
        packet[4 + i * 4] = st[i] >> 16;
        packet[5 + i * 4] = st[i] >> 8;
        packet[6 + i * 4] = st[i];
    }
    memcpy(packet + 35, active.header + 64, 12);
    uint8_t batch_target[32];
    diff_to_target(batch_diff, batch_target);
    memcpy(packet + 47, batch_target, 32);
    active.sent_us = esp_timer_get_time();
    active.valid = true;
    return true;
}

static void send_work_to_fpga(void) {
    uint8_t packet[79];
    if (!make_work_packet(packet)) return;
    const uint8_t stop[] = {'T', 'N', 'S'};
    uart_write_bytes(FPGA_UART, stop, sizeof(stop));
    uart_wait_tx_done(FPGA_UART, pdMS_TO_TICKS(100));
    vTaskDelay(pdMS_TO_TICKS(20));
    uart_flush_input(FPGA_UART);
    uart_write_bytes(FPGA_UART, packet, sizeof(packet));
    uart_wait_tx_done(FPGA_UART, pdMS_TO_TICKS(500));
    ESP_LOGI(TAG, "MINER >> job=%s xn2=%s pool_diff=%g batch_diff=%g", active.job_id, active.xn2_hex, pool_diff, batch_diff);
}

static double share_diff_from_work(const uint8_t work[32]) {
    int first = 0;
    while (first < 32 && work[first] == 0) first++;
    if (first == 32) return INFINITY;
    long double w = 0.0L;
    for (int i = first; i < 32 && i < first + 10; i++) w = w * 256.0L + work[i];
    int exp = 8 * (32 - first - 10);
    return (double)(ldexpl(65535.0L, 208 - exp) / w);
}

static void submit_share(int sock, const uint8_t nonce[4]) {
    char nonce_hex[9];
    uint8_t submit_nonce[4] = {nonce[3], nonce[2], nonce[1], nonce[0]};
    bytes_to_hex(submit_nonce, 4, nonce_hex);
    char params[256];
    snprintf(params, sizeof(params), "[\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"]",
             MINER_USER, active.job_id, active.xn2_hex, active.ntime, nonce_hex);
    send_json(sock, "mining.submit", params);
}

static void handle_fpga_response(int sock) {
    uint8_t resp[37];
    int n = uart_read_bytes(FPGA_UART, resp, sizeof(resp), pdMS_TO_TICKS(1));
    if (n <= 0) return;
    while (n < 37) {
        int r = uart_read_bytes(FPGA_UART, resp + n, 37 - n, pdMS_TO_TICKS(200));
        if (r <= 0) return;
        n += r;
    }
    if (!active.valid || resp[0] != 'F') return;
    memcpy(active.header + 76, resp + 1, 4);
    uint8_t digest[32];
    sha256d(active.header, sizeof(active.header), digest);
    if (memcmp(digest, resp + 5, 32) != 0) {
        ESP_LOGE(TAG, "bad FPGA hash");
        active.valid = false;
        return;
    }
    double secs = (esp_timer_get_time() - active.sent_us) / 1000000.0;
    uint32_t nonce = ((uint32_t)resp[1] << 24) | ((uint32_t)resp[2] << 16) | ((uint32_t)resp[3] << 8) | resp[4];
    double hashrate = ((double)nonce + 1.0) / fmax(secs, 1e-9);
    batch_diff *= fmax(0.5, fmin(4.0, sqrt(TARGET_SECS / fmax(secs, 0.1))));
    uint8_t work[32];
    for (int i = 0; i < 32; i++) work[i] = digest[31 - i];
    bool share = be_cmp32(work, active.pool_target) <= 0;
    bool block = be_cmp32(work, active.network_target) <= 0;
    double found_diff = share_diff_from_work(work);
    ESP_LOGI(TAG, "nonce=%08lx secs=%.2f rate=%.3fMH/s share=%d diff=%.8g",
             (unsigned long)nonce, secs, hashrate / 1e6, share, found_diff);
    char l2[20], l3[20];
    snprintf(l2, sizeof(l2), "%.3f MH/s", hashrate / 1e6);
    snprintf(l3, sizeof(l3), share ? "share yes" : "batch diff");
    status_screen("TangMiner", l2, l3, block ? "BLOCK?" : active.job_id);
    if (share) submit_share(sock, resp + 1);
    active.valid = false;
}

static void uart_start(void) {
    uart_config_t cfg = {
        .baud_rate = FPGA_BAUD,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    ESP_ERROR_CHECK(uart_driver_install(FPGA_UART, 1024, 0, 0, NULL, 0));
    ESP_ERROR_CHECK(uart_param_config(FPGA_UART, &cfg));
    ESP_ERROR_CHECK(uart_set_pin(FPGA_UART, FPGA_TX_GPIO, FPGA_RX_GPIO, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE));
}

void app_main(void) {
    esp_log_level_set(TAG, ESP_LOG_INFO);
    esp_err_t nvs = nvs_flash_init();
    if (nvs == ESP_ERR_NVS_NO_FREE_PAGES || nvs == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }
    oled_init();
    oled_clear();
    status_screen("TangMiner", "WiFi...", "", "");
    uart_start();
    if (strlen(WIFI_SSID) == 0) {
        status_screen("No WiFi", "set SSID", "make mcu", "");
        ESP_LOGE(TAG, "Set WIFI_SSID and WIFI_PASS in the make command");
        return;
    }
    wifi_start();
    status_screen("TangMiner", "pool...", POOL_HOST, "");

    while (true) {
        int sock = pool_connect();
        if (sock < 0) {
            status_screen("Pool fail", POOL_HOST, "retrying", "");
            vTaskDelay(pdMS_TO_TICKS(3000));
            continue;
        }
        char params[256];
        snprintf(params, sizeof(params), "[%g]", SUGGESTED_POOL_DIFF);
        send_json(sock, "mining.suggest_difficulty", params);
        send_json(sock, "mining.subscribe", "[]");
        snprintf(params, sizeof(params), "[\"%s\",\"%s\"]", MINER_USER, MINER_PASS);
        send_json(sock, "mining.authorize", params);
        status_screen("TangMiner", "connected", POOL_HOST, "waiting job");

        char line[LINE_BUF];
        size_t llen = 0;
        while (true) {
            char rx[512];
            int n = recv(sock, rx, sizeof(rx), 0);
            if (n == 0) break;
            if (n < 0 && errno != EWOULDBLOCK && errno != EAGAIN) break;
            if (n > 0) {
                for (int i = 0; i < n; i++) {
                    if (rx[i] == '\n') {
                        line[llen] = 0;
                        if (llen) parse_pool_line(line);
                        llen = 0;
                    } else if (llen + 1 < sizeof(line)) {
                        line[llen++] = rx[i];
                    }
                }
            }
            handle_fpga_response(sock);
            if (job.valid && !active.valid) send_work_to_fpga();
            if (active.valid && (esp_timer_get_time() - active.sent_us) > (int64_t)(MAX_SECS * 1000000.0)) {
                batch_diff *= TARGET_SECS / MAX_SECS;
                active.valid = false;
            }
            vTaskDelay(pdMS_TO_TICKS(5));
        }
        close(sock);
        active.valid = false;
        status_screen("Pool drop", "reconnect", "", "");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
