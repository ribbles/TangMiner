#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "miner.h"

#define MINER_HEADER_BYTES 80
#define MINER_JOB_PACKET_BYTES 79
#define MINER_FOUND_RESPONSE_BYTES 37

typedef struct {
    uint8_t header[MINER_HEADER_BYTES];
    uint8_t packet[MINER_JOB_PACKET_BYTES];
    uint8_t pool_target[32];
    uint8_t network_target[32];
    uint8_t merkle[32];
    char xn2_hex[MINER_XN2_HEX_MAX];
    size_t coinbase_len;
} miner_work_t;

void miner_core_reset_extranonce(void);
bool miner_core_set_extranonce(const uint8_t *x1, size_t x1_len, size_t x2_size);
bool miner_core_build_work(const miner_job_t *job, double pool_diff, double batch_diff, miner_work_t *work);
void miner_core_packet_from_header(const uint8_t header[MINER_HEADER_BYTES], double batch_diff,
                                   uint8_t packet[MINER_JOB_PACKET_BYTES]);
void miner_core_sha256d(const uint8_t *data, size_t len, uint8_t out[32]);
void miner_core_target_from_diff(double diff, uint8_t target[32]);
void miner_core_target_from_nbits(const char *nbits, uint8_t target[32]);
