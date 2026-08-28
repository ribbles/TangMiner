#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_netif_sntp.h"
#include "esp_sntp.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "miner.h"
#include "nvs_flash.h"
#include "oled.h"
#include "pool.h"

#include <lwip/ip4_addr.h>

#if __has_include("mine_config.h")
#include "mine_config.h"
#endif

#ifndef WIFI_SSID
#define WIFI_SSID ""
#endif
#ifndef WIFI_PASS
#define WIFI_PASS ""
#endif

static const char *TAG = "tangminer-mcu";
static EventGroupHandle_t wifi_events;
static esp_netif_t *sta_netif;
static const int WIFI_READY = BIT0;
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

static void log_network_details(void)
{
    esp_netif_ip_info_t ip;
    esp_netif_dns_info_t dns;
    if (esp_netif_get_ip_info(sta_netif, &ip) == ESP_OK) {
        LOGI("WiFi DHCP ip=" IPSTR " subnet=" IPSTR " gw=" IPSTR,
             IP2STR(&ip.ip), IP2STR(&ip.netmask), IP2STR(&ip.gw));
    }
    if (esp_netif_get_dns_info(sta_netif, ESP_NETIF_DNS_MAIN, &dns) == ESP_OK) {
        LOGI("WiFi DNS main=" IPSTR, IP2STR(&dns.ip.u_addr.ip4));
    }
}

static void wifi_event(void *arg, esp_event_base_t base, int32_t id, void *data)
{
    (void)arg;
    (void)data;
    if (base == WIFI_EVENT && id == WIFI_EVENT_STA_START) {
        LOGI("WiFi connect start ssid=%s", WIFI_SSID);
        esp_wifi_connect();
    } else if (base == WIFI_EVENT && id == WIFI_EVENT_STA_DISCONNECTED) {
        LOGW("WiFi disconnected; retrying");
        oled_set_indicator(OLED_IND_WIFI_TX, OLED_LINK_DOWN);
        oled_set_indicator(OLED_IND_WIFI_RX, OLED_LINK_DOWN);
        xEventGroupClearBits(wifi_events, WIFI_READY);
        esp_wifi_connect();
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        LOGI("WiFi connected");
        oled_set_indicator(OLED_IND_WIFI_TX, OLED_LINK_UP);
        oled_set_indicator(OLED_IND_WIFI_RX, OLED_LINK_UP);
        log_network_details();
        xEventGroupSetBits(wifi_events, WIFI_READY);
    }
}

static void wifi_start(void)
{
    wifi_events = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    sta_netif = esp_netif_create_default_wifi_sta();
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

static void time_start(void)
{
    setenv("TZ", "UTC0", 1);
    tzset();
    esp_sntp_config_t config = ESP_NETIF_SNTP_DEFAULT_CONFIG("pool.ntp.org");
    esp_netif_sntp_init(&config);
    if (esp_netif_sntp_sync_wait(pdMS_TO_TICKS(5000)) == ESP_OK) {
        LOGI("SNTP synced");
    } else {
        LOGW("SNTP sync timed out; logs continue with uptime until time is set");
    }
}

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
    if (strlen(WIFI_SSID) == 0) {
        LOGE("Set WIFI_SSID and WIFI_PASS before flashing");
        oled_set_bad_hash(true);
        oled_render();
        return;
    }

    wifi_start();
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
