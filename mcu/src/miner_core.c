#include "miner_core.h"

#include <stdlib.h>
#include <string.h>

static uint8_t extranonce1[64];
static size_t extranonce1_len;
static size_t extranonce2_size;
static uint64_t extranonce2;
static uint8_t coinbase[17000];

static void bytes_to_hex(const uint8_t *in, size_t len, char *out)
{
    static const char h[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        out[i * 2] = h[in[i] >> 4];
        out[i * 2 + 1] = h[in[i] & 0xf];
    }
    out[len * 2] = 0;
}

#define ROR32(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(x, y, z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x, y, z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define BSIG0(x) (ROR32((x), 2) ^ ROR32((x), 13) ^ ROR32((x), 22))
#define BSIG1(x) (ROR32((x), 6) ^ ROR32((x), 11) ^ ROR32((x), 25))
#define SSIG0(x) (ROR32((x), 7) ^ ROR32((x), 18) ^ ((x) >> 3))
#define SSIG1(x) (ROR32((x), 17) ^ ROR32((x), 19) ^ ((x) >> 10))

static uint32_t load_be32(const uint8_t *p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}

static void store_be32(uint8_t *p, uint32_t v)
{
    p[0] = (uint8_t)(v >> 24);
    p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);
    p[3] = (uint8_t)v;
}

static void sha256_compress(const uint8_t state_in[32], const uint8_t block[64], uint8_t out[32])
{
    static const uint32_t k[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    };
    uint32_t w[64];
    uint32_t state[8];
    for (int i = 0; i < 8; i++) {
        state[i] = load_be32(state_in + i * 4);
    }
    for (int i = 0; i < 16; i++) {
        w[i] = load_be32(block + i * 4);
    }
    for (int i = 16; i < 64; i++) {
        w[i] = w[i - 16] + SSIG0(w[i - 15]) + w[i - 7] + SSIG1(w[i - 2]);
    }
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];
    for (int i = 0; i < 64; i++) {
        uint32_t t1 = h + BSIG1(e) + CH(e, f, g) + k[i] + w[i];
        uint32_t t2 = BSIG0(a) + MAJ(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
    for (int i = 0; i < 8; i++) {
        store_be32(out + i * 4, state[i]);
    }
}

static void sha256(const uint8_t *data, size_t len, uint8_t out[32])
{
    static const uint8_t iv[32] = {
        0x6a, 0x09, 0xe6, 0x67, 0xbb, 0x67, 0xae, 0x85,
        0x3c, 0x6e, 0xf3, 0x72, 0xa5, 0x4f, 0xf5, 0x3a,
        0x51, 0x0e, 0x52, 0x7f, 0x9b, 0x05, 0x68, 0x8c,
        0x1f, 0x83, 0xd9, 0xab, 0x5b, 0xe0, 0xcd, 0x19,
    };
    uint8_t state[32];
    uint64_t total_bits = (uint64_t)len * 8;
    memcpy(state, iv, sizeof(state));
    while (len >= 64) {
        sha256_compress(state, data, state);
        data += 64;
        len -= 64;
    }
    uint8_t block[128] = {0};
    memcpy(block, data, len);
    block[len] = 0x80;
    size_t pad_len = len + 1 + 8 <= 64 ? 64 : 128;
    for (int i = 0; i < 8; i++) {
        block[pad_len - 1 - i] = (uint8_t)(total_bits >> (i * 8));
    }
    sha256_compress(state, block, state);
    if (pad_len == 128) {
        sha256_compress(state, block + 64, state);
    }
    memcpy(out, state, 32);
}

void miner_core_sha256d(const uint8_t *data, size_t len, uint8_t out[32])
{
    uint8_t tmp[32];
    sha256(data, len, tmp);
    sha256(tmp, sizeof(tmp), out);
}

static void sha256_midstate(const uint8_t block[64], uint8_t out[32])
{
    static const uint8_t iv[32] = {
        0x6a, 0x09, 0xe6, 0x67, 0xbb, 0x67, 0xae, 0x85,
        0x3c, 0x6e, 0xf3, 0x72, 0xa5, 0x4f, 0xf5, 0x3a,
        0x51, 0x0e, 0x52, 0x7f, 0x9b, 0x05, 0x68, 0x8c,
        0x1f, 0x83, 0xd9, 0xab, 0x5b, 0xe0, 0xcd, 0x19,
    };
    sha256_compress(iv, block, out);
}

void miner_core_target_from_diff(double diff, uint8_t target[32])
{
    if (diff < 1e-12) {
        diff = 1e-12;
    }
    memset(target, 0, 32);

    double scaled_double = 65535.0 / diff;
    if (scaled_double >= 281474976710655.0) {
        for (int i = 0; i < 32; i++) {
            target[i] = 0xff;
        }
        return;
    }

    uint64_t scaled = (uint64_t)scaled_double;
    for (int i = 5; i >= 0 && scaled; i--) {
        target[i] = (uint8_t)scaled;
        scaled >>= 8;
    }
}

void miner_core_target_from_nbits(const char *nbits, uint8_t target[32])
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

void miner_core_reset_extranonce(void)
{
    extranonce2 = 0;
}

bool miner_core_set_extranonce(const uint8_t *x1, size_t x1_len, size_t x2_size)
{
    if (x1_len > sizeof(extranonce1) || x2_size == 0 || x2_size > 8) {
        return false;
    }
    memcpy(extranonce1, x1, x1_len);
    extranonce1_len = x1_len;
    extranonce2_size = x2_size;
    extranonce2 = 0;
    return true;
}

bool miner_core_build_work(const miner_job_t *job, double pool_diff, double batch_diff, miner_work_t *work)
{
    if (!job->valid || extranonce2_size == 0 || extranonce2_size > 8) {
        return false;
    }

    memset(work, 0, sizeof(*work));
    uint8_t xn2[8] = {0};
    for (size_t i = 0; i < extranonce2_size; i++) {
        xn2[extranonce2_size - 1 - i] = (uint8_t)(extranonce2 >> (8 * i));
    }
    extranonce2++;
    bytes_to_hex(xn2, extranonce2_size, work->xn2_hex);

    size_t pos = 0;
    if (job->coinb1_len + extranonce1_len + extranonce2_size + job->coinb2_len > sizeof(coinbase)) {
        return false;
    }
    memcpy(coinbase + pos, job->coinb1, job->coinb1_len); pos += job->coinb1_len;
    memcpy(coinbase + pos, extranonce1, extranonce1_len); pos += extranonce1_len;
    memcpy(coinbase + pos, xn2, extranonce2_size); pos += extranonce2_size;
    memcpy(coinbase + pos, job->coinb2, job->coinb2_len); pos += job->coinb2_len;
    work->coinbase_len = pos;

    miner_core_sha256d(coinbase, pos, work->merkle);
    for (size_t i = 0; i < job->branch_count; i++) {
        uint8_t pair[64];
        memcpy(pair, work->merkle, 32);
        memcpy(pair + 32, job->branches[i], 32);
        miner_core_sha256d(pair, sizeof(pair), work->merkle);
    }

    memcpy(work->header, job->version, 4);
    memcpy(work->header + 4, job->prevhash, 32);
    memcpy(work->header + 36, work->merkle, 32);
    memcpy(work->header + 68, job->ntime_le, 4);
    memcpy(work->header + 72, job->nbits_le, 4);

    miner_core_packet_from_header(work->header, batch_diff, work->packet);
    miner_core_target_from_diff(pool_diff, work->pool_target);
    miner_core_target_from_nbits(job->nbits, work->network_target);
    return true;
}

void miner_core_packet_from_header(const uint8_t header[MINER_HEADER_BYTES], double batch_diff,
                                   uint8_t packet[MINER_JOB_PACKET_BYTES])
{
    packet[0] = 'T';
    packet[1] = 'N';
    packet[2] = 'J';
    sha256_midstate(header, packet + 3);
    memcpy(packet + 35, header + 64, 12);
    miner_core_target_from_diff(batch_diff, packet + 47);
}
