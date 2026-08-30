#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "miner.h"
#include "nvs_flash.h"
#include "oled.h"
#include "pool.h"
#include "wifi.h"

static const char *TAG = "tangminer-mcu";
static miner_job_t current_job;
static pool_event_t pool_event;
static miner_result_t result;
static double current_pool_diff = 1.0;
static bool have_job;
static uint64_t last_pow_us;

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

static void refresh_screen(void)
{
    bool is_mining = pool_is_connected() && have_job && miner_is_connected() && miner_work_sent_us() != 0;
    oled_set_work(miner_work_sent_us(), miner_work_timeout_us(), is_mining);
    oled_set_last_pow(last_pow_us);
    oled_render();
}

void app_main(void)
{
    esp_log_level_set("*", ESP_LOG_INFO);
    esp_err_t nvs = nvs_flash_init();
    if (nvs == ESP_ERR_NVS_NO_FREE_PAGES || nvs == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ESP_ERROR_CHECK(nvs_flash_init());
    }

    oled_init();
    miner_init();
    if (!wifi_start()) {
        oled_set_bad_hash(true);
        oled_render();
        return;
    }

    time_start();

    while (true) {
        if (!pool_is_connected()) {
            have_job = false;
            miner_clear_work();
            LOGI("connecting to pool");
            if (!pool_connect()) {
                refresh_screen();
                vTaskDelay(pdMS_TO_TICKS(3000));
                continue;
            }
        }

        if (pool_poll(&pool_event)) {
            if (pool_event.type == POOL_EVENT_JOB) {
                current_job = pool_event.job;
                current_pool_diff = pool_event.pool_diff;
                have_job = true;
                miner_clear_work();
            } else if (pool_event.type == POOL_EVENT_DISCONNECTED) {
                have_job = false;
                miner_clear_work();
            }
        }

        if (miner_poll(&result)) {
            if (result.bad_hash) {
                oled_set_bad_hash(true);
                oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
                oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
            } else {
                last_pow_us = esp_timer_get_time();
                oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_UP);
                oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_UP);
                if (result.share) {
                    pool_submit_share(&result);
                }
            }
        }

        if (miner_timed_out()) {
            LOGW("serial retry path active; stale FPGA work cleared");
            oled_set_indicator(OLED_IND_MINER_TX, OLED_LINK_DOWN);
            oled_set_indicator(OLED_IND_MINER_RX, OLED_LINK_DOWN);
        }
        if (have_job && pool_is_connected() && miner_work_sent_us() == 0) {
            miner_start_work(&current_job, current_pool_diff);
        }

        refresh_screen();
        vTaskDelay(pdMS_TO_TICKS(50));
    }
}
