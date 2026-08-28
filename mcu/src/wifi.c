#include "wifi.h"

#include <string.h>
#include <time.h>

#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_netif_sntp.h"
#include "esp_sntp.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "oled.h"

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

static const char *TAG = "wifi";
static EventGroupHandle_t wifi_events;
static esp_netif_t *sta_netif;
static const int WIFI_READY = BIT0;
static bool connected;

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
        connected = false;
        oled_set_indicator(OLED_IND_WIFI_TX, OLED_LINK_DOWN);
        oled_set_indicator(OLED_IND_WIFI_RX, OLED_LINK_DOWN);
        if (wifi_events) {
            xEventGroupClearBits(wifi_events, WIFI_READY);
        }
        esp_wifi_connect();
    } else if (base == IP_EVENT && id == IP_EVENT_STA_GOT_IP) {
        LOGI("WiFi connected");
        connected = true;
        oled_set_indicator(OLED_IND_WIFI_TX, OLED_LINK_UP);
        oled_set_indicator(OLED_IND_WIFI_RX, OLED_LINK_UP);
        log_network_details();
        if (wifi_events) {
            xEventGroupSetBits(wifi_events, WIFI_READY);
        }
    }
}

bool wifi_start(void)
{
    if (strlen(WIFI_SSID) == 0) {
        LOGE("Set WIFI_SSID and WIFI_PASS before flashing");
        return false;
    }

    wifi_events = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    sta_netif = esp_netif_create_default_wifi_sta();
    ESP_ERROR_CHECK(esp_netif_set_hostname(sta_netif, "PaperWeight"));
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
    return true;
}

void time_start(void)
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

bool wifi_is_connected(void)
{
    return connected;
}
