#include "miner.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "driver/gpio.h"
#include "driver/uart.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "miner_core.h"
#include "oled.h"

#define FPGA_UART UART_NUM_1
#define FPGA_BAUD 115200
#define FPGA_TX_GPIO GPIO_NUM_21
#define FPGA_RX_GPIO GPIO_NUM_20
#define TARGET_SECS 12.0
#define MAX_SECS 120.0
#define INITIAL_BATCH_DIFF 0.003
#define MAX_BATCH_DIFF 0.003
#define MIN_BATCH_DIFF 0.000001
#define JOB_PACKET_BYTES MINER_JOB_PACKET_BYTES
#define FOUND_RESPONSE_BYTES MINER_FOUND_RESPONSE_BYTES
#define HEADER_BYTES MINER_HEADER_BYTES

static const char *TAG = "miner";
static double batch_diff = INITIAL_BATCH_DIFF;
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

static void fpga_stop_and_drain(void)
{
    const uint8_t stop[] = {'T', 'N', 'S'};
    uint8_t trash[FOUND_RESPONSE_BYTES];

    uart_write_bytes(FPGA_UART, stop, sizeof(stop));
    uart_wait_tx_done(FPGA_UART, pdMS_TO_TICKS(100));
    vTaskDelay(pdMS_TO_TICKS(20));
    while (uart_read_bytes(FPGA_UART, trash, sizeof(trash), pdMS_TO_TICKS(20)) > 0) {
    }
    uart_flush_input(FPGA_UART);
}

static int be_cmp32(const uint8_t a[32], const uint8_t b[32])
{
    return memcmp(a, b, 32);
}

static double clamp_double(double value, double low, double high)
{
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

static void retune_batch_diff(double multiplier)
{
    batch_diff = clamp_double(batch_diff * multiplier, MIN_BATCH_DIFF, MAX_BATCH_DIFF);
}

static double share_diff_from_work(const uint8_t work[32])
{
    int first = 0;
    while (first < 32 && work[first] == 0) first++;
    if (first == 32) return 1.0e300;
    long double w = 0.0L;
    int used = 0;
    for (int i = first; i < 32 && used < 8; i++, used++) {
        w = w * 256.0L + work[i];
    }
    long double diff = 65535.0L / w;
    int scale_bytes = first + used - 6;
    while (scale_bytes > 0) {
        diff *= 256.0L;
        scale_bytes--;
    }
    while (scale_bytes < 0) {
        diff /= 256.0L;
        scale_bytes++;
    }
    return (double)diff;
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
    if (miner_core_set_extranonce(x1, x1_len, x2_size)) {
        LOGI("extranonce set x1_len=%u x2_size=%u", (unsigned)x1_len, (unsigned)x2_size);
    } else {
        LOGE("invalid extranonce x1_len=%u x2_size=%u", (unsigned)x1_len, (unsigned)x2_size);
    }
}

bool miner_start_work(const miner_job_t *job, double pool_diff)
{
    miner_work_t work;
    if (!miner_core_build_work(job, pool_diff, batch_diff, &work)) {
        LOGE("work build failed");
        return false;
    }

    memcpy(active.header, work.header, sizeof(active.header));
    memcpy(active.xn2_hex, work.xn2_hex, sizeof(active.xn2_hex));
    memcpy(active.pool_target, work.pool_target, sizeof(active.pool_target));
    memcpy(active.network_target, work.network_target, sizeof(active.network_target));
    strlcpy(active.job_id, job->job_id, sizeof(active.job_id));
    strlcpy(active.ntime, job->ntime, sizeof(active.ntime));
    active.pool_diff = pool_diff;

    fpga_stop_and_drain();
    uart_write_bytes(FPGA_UART, work.packet, sizeof(work.packet));
    uart_wait_tx_done(FPGA_UART, pdMS_TO_TICKS(500));
    oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_TX);
    active.sent_us = esp_timer_get_time();
    active.valid = true;
    last_no_response_warn_us = active.sent_us;
    LOGI("MINER >> job=%s xn2=%s pool_diff=%g batch_diff=%g", active.job_id, active.xn2_hex, pool_diff, batch_diff);
    return true;
}

bool miner_poll(miner_result_t *result)
{
    uint8_t resp[FOUND_RESPONSE_BYTES];
    int n = uart_read_bytes(FPGA_UART, resp, sizeof(resp), pdMS_TO_TICKS(1));
    if (n <= 0) {
        int64_t now = esp_timer_get_time();
        if (active.valid && now - last_no_response_warn_us > 50000000LL) {
            LOGW("no FPGA miner response on UART yet; check TX=GPIO%d RX=GPIO%d GND and FPGA bitstream", FPGA_TX_GPIO, FPGA_RX_GPIO);
            miner_connected = false;
            oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
            oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
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
            miner_connected = false;
            oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
            oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
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
    miner_core_sha256d(active.header, sizeof(active.header), digest);
    if (memcmp(digest, resp + 5, 32) != 0) {
        char exp_hex[65], got_hex[65], nonce_hex[9];
        bytes_to_hex(digest, 32, exp_hex);
        bytes_to_hex(resp + 5, 32, got_hex);
        bytes_to_hex(resp + 1, 4, nonce_hex);
        LOGE("bad FPGA hash validation failure nonce=%s host=%s fpga=%s", nonce_hex, exp_hex, got_hex);
        result->bad_hash = true;
        active.valid = false;
        miner_connected = false;
        oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
        oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
        return true;
    }

    double secs = (esp_timer_get_time() - active.sent_us) / 1000000.0;
    uint32_t nonce = ((uint32_t)resp[1] << 24) | ((uint32_t)resp[2] << 16) | ((uint32_t)resp[3] << 8) | resp[4];
    result->elapsed_secs = secs;
    double safe_secs = secs > 1e-9 ? secs : 1e-9;
    result->hashrate = ((double)nonce + 1.0) / safe_secs;
    double retune_secs = secs > 0.1 ? secs : 0.1;
    retune_batch_diff(clamp_double(TARGET_SECS / retune_secs, 0.5, 4.0));

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
    retune_batch_diff(TARGET_SECS / MAX_SECS);
    active.valid = false;
    miner_connected = false;
    oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
    oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
    LOGW("work timed out after %.1fs; next batch_diff=%g", MAX_SECS, batch_diff);
    return true;
}

void miner_clear_work(void)
{
    if (active.valid) {
        fpga_stop_and_drain();
    }
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
