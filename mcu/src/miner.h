#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#define MINER_JOB_ID_MAX 96
#define MINER_XN2_HEX_MAX 32
#define MINER_NTIME_MAX 9

typedef struct {
    char job_id[MINER_JOB_ID_MAX];
    uint8_t prevhash[32];
    uint8_t coinb1[8192];
    size_t coinb1_len;
    uint8_t coinb2[8192];
    size_t coinb2_len;
    uint8_t branches[16][32];
    size_t branch_count;
    uint8_t version[4];
    char nbits[9];
    uint8_t nbits_le[4];
    char ntime[MINER_NTIME_MAX];
    uint8_t ntime_le[4];
    bool valid;
} miner_job_t;

typedef struct {
    char job_id[MINER_JOB_ID_MAX];
    char xn2_hex[MINER_XN2_HEX_MAX];
    char ntime[MINER_NTIME_MAX];
    char nonce_hex[9];
    double elapsed_secs;
    double hashrate;
    double share_diff;
    double batch_diff;
    bool share;
    bool block;
    bool bad_hash;
} miner_result_t;

void miner_init(void);
void miner_set_extranonce(const uint8_t *x1, size_t x1_len, size_t x2_size);
bool miner_start_work(const miner_job_t *job, double pool_diff);
bool miner_poll(miner_result_t *result);
bool miner_timed_out(void);
void miner_clear_work(void);
uint64_t miner_work_sent_us(void);
uint64_t miner_work_timeout_us(void);
bool miner_is_connected(void);
