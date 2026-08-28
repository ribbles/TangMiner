#define MBEDTLS_DECLARE_PRIVATE_IDENTIFIERS
#include "miner.h"

#include <errno.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "driver/gpio.h"
#include "driver/uart.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mbedtls/sha256.h"
#include "oled.h"

#define FPGA_UART UART_NUM_1
#define FPGA_BAUD 115200
#define FPGA_TX_GPIO GPIO_NUM_21
#define FPGA_RX_GPIO GPIO_NUM_20
#define TARGET_SECS 12.0
#define MAX_SECS 30.0

static const char *TAG = "miner";
static uint8_t extranonce1[64];
static uint8_t coinbase[17000];
static size_t extranonce1_len;
static size_t extranonce2_size;
static uint64_t extranonce2;
static double batch_diff = 0.003;
static int64_t last_no_response_warn_us;

static struct {
    uint8_t header[80];
    char job_id[MINER_JOB_ID_MAX];
    char xn2_hex[MINER_XN2_HEX_MAX];
    char ntime[MINER_NTIME_MAX];
    uint8_t pool_target[32];
    uint8_t network_target[32];
    double pool_diff;
    int64_t sent_us;
    bool valid;
} active;

static const char *utc_now(char *buf, size_t len)
{
    time_t now = time(NULL);
    struct tm tm = {0};
    if (now > 24 * 3600 && gmtime_r(&now, &tm)) {
        strftime(buf, len, "%Y-%m-%dT%H:%M:%SZ", &tm);
    } else {
        strlcpy(buf, "time-unsynced", len);
    }
    return buf;
}

#define LOGI(fmt, ...) do { char ts[24]; ESP_LOGI(TAG, "%s " fmt, utc_now(ts, sizeof(ts)), ##__VA_ARGS__); } while (0)
#define LOGW(fmt, ...) do { char ts[24]; ESP_LOGW(TAG, "%s " fmt, utc_now(ts, sizeof(ts)), ##__VA_ARGS__); } while (0)
#define LOGE(fmt, ...) do { char ts[24]; ESP_LOGE(TAG, "%s " fmt, utc_now(ts, sizeof(ts)), ##__VA_ARGS__); } while (0)

static void bytes_to_hex(const uint8_t *in, size_t len, char *out)
{
    static const char h[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        out[i * 2] = h[in[i] >> 4];
        out[i * 2 + 1] = h[in[i] & 0xf];
    }
    out[len * 2] = 0;
}

static int be_cmp32(const uint8_t a[32], const uint8_t b[32])
{
    return memcmp(a, b, 32);
}

static void sha256d(const uint8_t *data, size_t len, uint8_t out[32])
{
    uint8_t tmp[32];
    mbedtls_sha256(data, len, tmp, 0);
    mbedtls_sha256(tmp, sizeof(tmp), out, 0);
}

static void sha256_midstate(const uint8_t block[64], uint8_t out[32])
{
    mbedtls_sha256_context ctx;
    mbedtls_sha256_init(&ctx);
    mbedtls_sha256_starts(&ctx, 0);
    mbedtls_sha256_update(&ctx, block, 64);
    for (int i = 0; i < 8; i++) {
        uint32_t s = ctx.state[i];
        out[i * 4] = (uint8_t)(s >> 24);
        out[i * 4 + 1] = (uint8_t)(s >> 16);
        out[i * 4 + 2] = (uint8_t)(s >> 8);
        out[i * 4 + 3] = (uint8_t)s;
    }
    mbedtls_sha256_free(&ctx);
}

static void diff_to_target(double diff, uint8_t target[32])
{
    if (diff < 1e-12) diff = 1e-12;
    memset(target, 0, 32);
    double v = ldexp(65535.0 / diff, 208);
    double max_target = ldexp(1.0, 256) - 1.0;
    if (v > max_target) {
        v = max_target;
    }
    for (int i = 0; i < 32 && v > 0.0; i++) {
        double place = ldexp(1.0, 8 * (31 - i));
        int byte = (int)(v / place);
        if (byte > 255) {
            byte = 255;
        }
        target[i] = (uint8_t)byte;
        v -= (double)byte * place;
    }
}

static void compact_to_target(const char *nbits, uint8_t target[32])
{
    memset(target, 0, 32);
    uint32_t bits = strtoul(nbits, NULL, 16);
    uint32_t mant = bits & 0x00ffffff;
    int exp = (int)(bits >> 24);
    int idx = 32 - exp;
    if (idx >= 0 && idx + 2 < 32) {
        target[idx] = (uint8_t)(mant >> 16);
        target[idx + 1] = (uint8_t)(mant >> 8);
        target[idx + 2] = (uint8_t)mant;
    }
}

static double share_diff_from_work(const uint8_t work[32])
{
    int first = 0;
    while (first < 32 && work[first] == 0) first++;
    if (first == 32) return INFINITY;
    long double w = 0.0L;
    for (int i = first; i < 32 && i < first + 10; i++) {
        w = w * 256.0L + work[i];
    }
    int exp = 8 * (32 - first - 10);
    return (double)(ldexpl(65535.0L, 208 - exp) / w);
}

static bool miner_connected;

void miner_init(void)
{
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
    miner_connected = false;
    oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
    oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
    LOGI("FPGA UART ready baud=%d tx=GPIO%d rx=GPIO%d", FPGA_BAUD, FPGA_TX_GPIO, FPGA_RX_GPIO);
}

void miner_set_extranonce(const uint8_t *x1, size_t x1_len, size_t x2_size)
{
    if (x1_len > sizeof(extranonce1)) {
        x1_len = sizeof(extranonce1);
    }
    memcpy(extranonce1, x1, x1_len);
    extranonce1_len = x1_len;
    extranonce2_size = x2_size;
    extranonce2 = 0;
    LOGI("extranonce set x1_len=%u x2_size=%u", (unsigned)x1_len, (unsigned)x2_size);
}

bool miner_start_work(const miner_job_t *job, double pool_diff)
{
    if (!job->valid || extranonce2_size == 0 || extranonce2_size > 8) {
        return false;
    }

    uint8_t xn2[8] = {0};
    for (size_t i = 0; i < extranonce2_size; i++) {
        xn2[extranonce2_size - 1 - i] = (uint8_t)(extranonce2 >> (8 * i));
    }
    extranonce2++;
    bytes_to_hex(xn2, extranonce2_size, active.xn2_hex);

    size_t pos = 0;
    if (job->coinb1_len + extranonce1_len + extranonce2_size + job->coinb2_len > sizeof(coinbase)) {
        LOGE("coinbase too large");
        return false;
    }
    memcpy(coinbase + pos, job->coinb1, job->coinb1_len); pos += job->coinb1_len;
    memcpy(coinbase + pos, extranonce1, extranonce1_len); pos += extranonce1_len;
    memcpy(coinbase + pos, xn2, extranonce2_size); pos += extranonce2_size;
    memcpy(coinbase + pos, job->coinb2, job->coinb2_len); pos += job->coinb2_len;

    uint8_t merkle[32];
    sha256d(coinbase, pos, merkle);
    for (size_t i = 0; i < job->branch_count; i++) {
        uint8_t pair[64];
        memcpy(pair, merkle, 32);
        memcpy(pair + 32, job->branches[i], 32);
        sha256d(pair, sizeof(pair), merkle);
    }

    memcpy(active.header, job->version, 4);
    memcpy(active.header + 4, job->prevhash, 32);
    memcpy(active.header + 36, merkle, 32);
    memcpy(active.header + 68, job->ntime_le, 4);
    memcpy(active.header + 72, job->nbits_le, 4);
    memset(active.header + 76, 0, 4);
    strlcpy(active.job_id, job->job_id, sizeof(active.job_id));
    strlcpy(active.ntime, job->ntime, sizeof(active.ntime));
    active.pool_diff = pool_diff;
    diff_to_target(pool_diff, active.pool_target);
    compact_to_target(job->nbits, active.network_target);

    uint8_t packet[79];
    packet[0] = 'T'; packet[1] = 'N'; packet[2] = 'J';
    sha256_midstate(active.header, packet + 3);
    memcpy(packet + 35, active.header + 64, 12);
    uint8_t batch_target[32];
    diff_to_target(batch_diff, batch_target);
    memcpy(packet + 47, batch_target, 32);

    const uint8_t stop[] = {'T', 'N', 'S'};
    oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_TX);
    uart_write_bytes(FPGA_UART, stop, sizeof(stop));
    uart_wait_tx_done(FPGA_UART, pdMS_TO_TICKS(100));
    vTaskDelay(pdMS_TO_TICKS(20));
    uart_flush_input(FPGA_UART);
    uart_write_bytes(FPGA_UART, packet, sizeof(packet));
    uart_wait_tx_done(FPGA_UART, pdMS_TO_TICKS(500));
    active.sent_us = esp_timer_get_time();
    active.valid = true;
    last_no_response_warn_us = active.sent_us;
    LOGI("MINER >> job=%s xn2=%s pool_diff=%g batch_diff=%g", active.job_id, active.xn2_hex, pool_diff, batch_diff);
    return true;
}

bool miner_poll(miner_result_t *result)
{
    uint8_t resp[37];
    int n = uart_read_bytes(FPGA_UART, resp, sizeof(resp), pdMS_TO_TICKS(1));
    if (n <= 0) {
        int64_t now = esp_timer_get_time();
        if (active.valid && now - last_no_response_warn_us > 5000000LL) {
            LOGW("no FPGA miner response on UART yet; check TX=GPIO%d RX=GPIO%d GND and FPGA bitstream", FPGA_TX_GPIO, FPGA_RX_GPIO);
            last_no_response_warn_us = now;
        }
        return false;
    }
    last_no_response_warn_us = esp_timer_get_time();
    oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_RX);
    while (n < (int)sizeof(resp)) {
        int r = uart_read_bytes(FPGA_UART, resp + n, sizeof(resp) - n, pdMS_TO_TICKS(200));
        if (r <= 0) {
            LOGW("short FPGA response bytes=%d errno=%d; continuing", n, errno);
            return false;
        }
        n += r;
    }
    if (!active.valid || resp[0] != 'F') {
        return false;
    }
    miner_connected = true;

    memset(result, 0, sizeof(*result));
    memcpy(active.header + 76, resp + 1, 4);
    uint8_t digest[32];
    sha256d(active.header, sizeof(active.header), digest);
    if (memcmp(digest, resp + 5, 32) != 0) {
        LOGE("bad FPGA hash validation failure");
        result->bad_hash = true;
        active.valid = false;
        return true;
    }

    double secs = (esp_timer_get_time() - active.sent_us) / 1000000.0;
    uint32_t nonce = ((uint32_t)resp[1] << 24) | ((uint32_t)resp[2] << 16) | ((uint32_t)resp[3] << 8) | resp[4];
    result->elapsed_secs = secs;
    result->hashrate = ((double)nonce + 1.0) / fmax(secs, 1e-9);
    batch_diff *= fmax(0.5, fmin(4.0, sqrt(TARGET_SECS / fmax(secs, 0.1))));

    uint8_t work[32];
    for (int i = 0; i < 32; i++) {
        work[i] = digest[31 - i];
    }
    result->share = be_cmp32(work, active.pool_target) <= 0;
    result->block = be_cmp32(work, active.network_target) <= 0;
    result->share_diff = share_diff_from_work(work);
    result->batch_diff = batch_diff;
    strlcpy(result->job_id, active.job_id, sizeof(result->job_id));
    strlcpy(result->xn2_hex, active.xn2_hex, sizeof(result->xn2_hex));
    strlcpy(result->ntime, active.ntime, sizeof(result->ntime));
    uint8_t submit_nonce[4] = {resp[4], resp[3], resp[2], resp[1]};
    bytes_to_hex(submit_nonce, 4, result->nonce_hex);
    LOGI("FPGA found nonce=%08lx secs=%.2f rate=%.3fMH/s share=%d share_diff=%.8g pool_diff=%g batch_diff=%g",
         (unsigned long)nonce, secs, result->hashrate / 1e6, result->share, result->share_diff,
         active.pool_diff, batch_diff);
    active.valid = false;
    return true;
}

bool miner_timed_out(void)
{
    if (!active.valid) {
        return false;
    }
    if ((esp_timer_get_time() - active.sent_us) <= (int64_t)(MAX_SECS * 1000000.0)) {
        return false;
    }
    batch_diff *= TARGET_SECS / MAX_SECS;
    active.valid = false;
    miner_connected = false;
    LOGW("work timed out after %.1fs; next batch_diff=%g", MAX_SECS, batch_diff);
    return true;
}

void miner_clear_work(void)
{
    active.valid = false;
}

uint64_t miner_work_sent_us(void)
{
    return active.valid ? (uint64_t)active.sent_us : 0;
}

uint64_t miner_work_timeout_us(void)
{
    return (uint64_t)(MAX_SECS * 1000000.0);
}

bool miner_is_connected(void)
{
    return miner_connected;
}
