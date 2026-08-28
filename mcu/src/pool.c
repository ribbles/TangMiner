#include "pool.h"

#include <errno.h>
#include <string.h>
#include <time.h>

#include "cJSON.h"
#include "esp_log.h"
#include "oled.h"

#include <lwip/netdb.h>
#include <lwip/sockets.h>

#if __has_include("mine_config.h")
#include "mine_config.h"
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

#define SUGGESTED_POOL_DIFF 0.001
#define LINE_BUF 65536

static const char *TAG = "pool";
static int sock = -1;
static int req_id;
static char line[LINE_BUF];
static size_t line_len;
static bool discarding_oversized_line;
static double pool_diff = 1.0;

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

static bool hexval(char c, uint8_t *v)
{
    if (c >= '0' && c <= '9') *v = (uint8_t)(c - '0');
    else if (c >= 'a' && c <= 'f') *v = (uint8_t)(c - 'a' + 10);
    else if (c >= 'A' && c <= 'F') *v = (uint8_t)(c - 'A' + 10);
    else return false;
    return true;
}

static bool hex_to_bytes(const char *hex, uint8_t *out, size_t max, size_t *out_len)
{
    size_t n = strlen(hex);
    if ((n & 1) || n / 2 > max) return false;
    for (size_t i = 0; i < n / 2; i++) {
        uint8_t hi, lo;
        if (!hexval(hex[i * 2], &hi) || !hexval(hex[i * 2 + 1], &lo)) return false;
        out[i] = (uint8_t)((hi << 4) | lo);
    }
    *out_len = n / 2;
    return true;
}

static void reverse_word_bytes(const uint8_t in[32], uint8_t out[32])
{
    for (int i = 0; i < 32; i += 4) {
        out[i] = in[i + 3]; out[i + 1] = in[i + 2];
        out[i + 2] = in[i + 1]; out[i + 3] = in[i];
    }
}

static void reverse_copy(const uint8_t *in, uint8_t *out, size_t len)
{
    for (size_t i = 0; i < len; i++) {
        out[i] = in[len - 1 - i];
    }
}

static bool send_json(const char *method, const char *params)
{
    char msg[512];
    req_id++;
    int len = snprintf(msg, sizeof(msg), "{\"id\":%d,\"method\":\"%s\",\"params\":%s}\n", req_id, method, params);
    if (len <= 0 || len >= (int)sizeof(msg)) {
        return false;
    }
    oled_set_indicator(OLED_IND_POOL_TX, OLED_LINK_TX);
    int sent = send(sock, msg, len, 0);
    if (sent != len) {
        LOGW("POOL send failed sent=%d expected=%d errno=%d", sent, len, errno);
        return false;
    }
    LOGI("POOL >> %s", msg);
    return true;
}

static void parse_subscribe(cJSON *msg)
{
    cJSON *result = cJSON_GetObjectItem(msg, "result");
    if (!cJSON_IsArray(result)) {
        return;
    }
    cJSON *x1 = cJSON_GetArrayItem(result, 1);
    cJSON *x2 = cJSON_GetArrayItem(result, 2);
    if (cJSON_IsString(x1) && cJSON_IsNumber(x2)) {
        uint8_t extranonce1[64];
        size_t extranonce1_len = 0;
        if (hex_to_bytes(x1->valuestring, extranonce1, sizeof(extranonce1), &extranonce1_len)) {
            miner_set_extranonce(extranonce1, extranonce1_len, (size_t)x2->valueint);
        }
    }
}

static bool parse_notify(cJSON *msg, miner_job_t *job)
{
    cJSON *p = cJSON_GetObjectItem(msg, "params");
    if (!cJSON_IsArray(p) || cJSON_GetArraySize(p) < 9) return false;
    memset(job, 0, sizeof(*job));
    strlcpy(job->job_id, cJSON_GetArrayItem(p, 0)->valuestring, sizeof(job->job_id));
    uint8_t tmp[256];
    size_t len = 0;
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 1)->valuestring, tmp, sizeof(tmp), &len) || len != 32) return false;
    reverse_word_bytes(tmp, job->prevhash);
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 2)->valuestring, job->coinb1, sizeof(job->coinb1), &job->coinb1_len)) return false;
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 3)->valuestring, job->coinb2, sizeof(job->coinb2), &job->coinb2_len)) return false;

    cJSON *branches = cJSON_GetArrayItem(p, 4);
    if (cJSON_IsArray(branches)) {
        int count = cJSON_GetArraySize(branches);
        if (count > 16) count = 16;
        for (int i = 0; i < count; i++) {
            if (!hex_to_bytes(cJSON_GetArrayItem(branches, i)->valuestring, job->branches[i], 32, &len) || len != 32) return false;
            job->branch_count++;
        }
    }
    if (!hex_to_bytes(cJSON_GetArrayItem(p, 5)->valuestring, tmp, sizeof(tmp), &len) || len != 4) return false;
    reverse_copy(tmp, job->version, 4);
    strlcpy(job->nbits, cJSON_GetArrayItem(p, 6)->valuestring, sizeof(job->nbits));
    if (!hex_to_bytes(job->nbits, tmp, sizeof(tmp), &len) || len != 4) return false;
    reverse_copy(tmp, job->nbits_le, 4);
    strlcpy(job->ntime, cJSON_GetArrayItem(p, 7)->valuestring, sizeof(job->ntime));
    if (!hex_to_bytes(job->ntime, tmp, sizeof(tmp), &len) || len != 4) return false;
    reverse_copy(tmp, job->ntime_le, 4);
    job->valid = true;
    LOGI("new job %s branches=%u pool_diff=%g", job->job_id, (unsigned)job->branch_count, pool_diff);
    return true;
}

static bool parse_line(char *text, pool_event_t *event)
{
    LOGI("POOL << %.240s", text);
    cJSON *msg = cJSON_Parse(text);
    if (!msg) {
        return false;
    }
    cJSON *method = cJSON_GetObjectItem(msg, "method");
    cJSON *id = cJSON_GetObjectItem(msg, "id");
    if (cJSON_IsNumber(id) && id->valueint == 2) {
        parse_subscribe(msg);
    }
    if (cJSON_IsString(method) && strcmp(method->valuestring, "mining.set_difficulty") == 0) {
        cJSON *p = cJSON_GetObjectItem(msg, "params");
        cJSON *d = cJSON_IsArray(p) ? cJSON_GetArrayItem(p, 0) : NULL;
        if (cJSON_IsNumber(d)) {
            pool_diff = d->valuedouble;
            LOGI("pool difficulty=%g", pool_diff);
        }
    } else if (cJSON_IsString(method) && strcmp(method->valuestring, "mining.set_extranonce") == 0) {
        cJSON *p = cJSON_GetObjectItem(msg, "params");
        cJSON *x1 = cJSON_IsArray(p) ? cJSON_GetArrayItem(p, 0) : NULL;
        cJSON *x2 = cJSON_IsArray(p) ? cJSON_GetArrayItem(p, 1) : NULL;
        if (cJSON_IsString(x1) && cJSON_IsNumber(x2)) {
            uint8_t extranonce1[64];
            size_t extranonce1_len = 0;
            if (hex_to_bytes(x1->valuestring, extranonce1, sizeof(extranonce1), &extranonce1_len)) {
                miner_set_extranonce(extranonce1, extranonce1_len, (size_t)x2->valueint);
            }
        }
    } else if (cJSON_IsString(method) && strcmp(method->valuestring, "mining.notify") == 0) {
        if (parse_notify(msg, &event->job)) {
            event->pool_diff = pool_diff;
            event->type = POOL_EVENT_JOB;
        }
    }
    cJSON_Delete(msg);
    return event->type != POOL_EVENT_NONE;
}

bool pool_connect(void)
{
    pool_disconnect();
    char port[12];
    snprintf(port, sizeof(port), "%d", POOL_PORT);
    struct addrinfo hints = {.ai_socktype = SOCK_STREAM};
    struct addrinfo *res = NULL;
    int rc = getaddrinfo(POOL_HOST, port, &hints, &res);
    if (rc != 0 || !res) {
        LOGW("pool DNS failed host=%s port=%s rc=%d", POOL_HOST, port, rc);
        return false;
    }
    sock = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (sock >= 0 && connect(sock, res->ai_addr, res->ai_addrlen) != 0) {
        close(sock);
        sock = -1;
    }
    freeaddrinfo(res);
    if (sock < 0) {
        LOGW("pool connect failed host=%s port=%s errno=%d", POOL_HOST, port, errno);
        oled_set_indicator(OLED_IND_POOL_TX, OLED_LINK_DOWN);
        oled_set_indicator(OLED_IND_POOL_RX, OLED_LINK_DOWN);
        return false;
    }

    struct timeval tv = {.tv_sec = 0, .tv_usec = 200000};
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    line_len = 0;
    discarding_oversized_line = false;
    LOGI("pool connected host=%s port=%s", POOL_HOST, port);
    oled_set_indicator(OLED_IND_POOL_TX, OLED_LINK_UP);
    oled_set_indicator(OLED_IND_POOL_RX, OLED_LINK_UP);

    char params[256];
    snprintf(params, sizeof(params), "[%g]", SUGGESTED_POOL_DIFF);
    return send_json("mining.suggest_difficulty", params) &&
           send_json("mining.subscribe", "[]") &&
           (snprintf(params, sizeof(params), "[\"%s\",\"%s\"]", MINER_USER, MINER_PASS) > 0) &&
           send_json("mining.authorize", params);
}

void pool_disconnect(void)
{
    if (sock >= 0) {
        LOGW("pool disconnected");
        close(sock);
        sock = -1;
        oled_set_indicator(OLED_IND_POOL_TX, OLED_LINK_DOWN);
        oled_set_indicator(OLED_IND_POOL_RX, OLED_LINK_DOWN);
    }
}

bool pool_poll(pool_event_t *event)
{
    memset(event, 0, sizeof(*event));
    event->pool_diff = pool_diff;
    if (sock < 0) {
        event->type = POOL_EVENT_DISCONNECTED;
        return true;
    }

    char rx[512];
    int n = recv(sock, rx, sizeof(rx), 0);
    if (n == 0 || (n < 0 && errno != EWOULDBLOCK && errno != EAGAIN)) {
        LOGW("pool recv disconnected n=%d errno=%d", n, errno);
        pool_disconnect();
        event->type = POOL_EVENT_DISCONNECTED;
        return true;
    }
    if (n <= 0) {
        return false;
    }

    oled_set_indicator(OLED_IND_POOL_RX, OLED_LINK_RX);
    for (int i = 0; i < n; i++) {
        if (rx[i] == '\n') {
            if (discarding_oversized_line) {
                discarding_oversized_line = false;
                line_len = 0;
                continue;
            }
            line[line_len] = 0;
            if (line_len && parse_line(line, event)) {
                line_len = 0;
                return true;
            }
            line_len = 0;
        } else if (line_len + 1 < sizeof(line)) {
            line[line_len++] = rx[i];
        } else {
            discarding_oversized_line = true;
            line_len = 0;
            LOGW("pool line longer than %u bytes; discarding until newline", (unsigned)sizeof(line));
        }
    }
    return false;
}

bool pool_submit_share(const miner_result_t *result)
{
    char params[256];
    int len = snprintf(params, sizeof(params), "[\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"]",
                       MINER_USER, result->job_id, result->xn2_hex, result->ntime, result->nonce_hex);
    if (len <= 0 || len >= (int)sizeof(params)) {
        return false;
    }
    LOGI("submit share job=%s nonce=%s", result->job_id, result->nonce_hex);
    return send_json("mining.submit", params);
}

bool pool_is_connected(void)
{
    return sock >= 0;
}
