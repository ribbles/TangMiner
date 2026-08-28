#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "miner.h"

typedef enum {
    POOL_EVENT_NONE,
    POOL_EVENT_JOB,
    POOL_EVENT_DISCONNECTED,
} pool_event_type_t;

typedef struct {
    pool_event_type_t type;
    miner_job_t job;
    double pool_diff;
} pool_event_t;

bool pool_connect(void);
void pool_disconnect(void);
bool pool_poll(pool_event_t *event);
bool pool_submit_share(const miner_result_t *result);
bool pool_is_connected(void);
