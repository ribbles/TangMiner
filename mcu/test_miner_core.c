#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "src/miner_core.h"

static int hexval(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static void hex_to_bytes(const char *hex, uint8_t *out, size_t len)
{
    for (size_t i = 0; i < len; i++) {
        int hi = hexval(hex[i * 2]);
        int lo = hexval(hex[i * 2 + 1]);
        if (hi < 0 || lo < 0) {
            fprintf(stderr, "bad hex at byte %u\n", (unsigned)i);
            exit(1);
        }
        out[i] = (uint8_t)((hi << 4) | lo);
    }
}

static void bytes_to_hex(const uint8_t *in, size_t len, char *out)
{
    static const char h[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        out[i * 2] = h[in[i] >> 4];
        out[i * 2 + 1] = h[in[i] & 0xf];
    }
    out[len * 2] = 0;
}

static void expect_hex(const char *name, const uint8_t *got, size_t len, const char *want_hex)
{
    char got_hex[MINER_HEADER_BYTES * 2 + 1];
    bytes_to_hex(got, len, got_hex);
    if (strcmp(got_hex, want_hex) != 0) {
        fprintf(stderr, "%s mismatch\n got  %s\n want %s\n", name, got_hex, want_hex);
        exit(1);
    }
}

static void test_logged_header_packet_and_digest(void)
{
    const char *header_hex =
        "000000206dd34bd75055d75ac715506f20ccd167312ad913599d01000000000000000000"
        "ff98ab6b54cc4e9b5fa0e8f70bf47b6ac8f46d0368c089f0223845ba93b9f5f2"
        "9a07946ac13c021700000000";
    const char *packet_hex =
        "544e4ae951375574c20cd80a6000dcc42f2a72e46fdc7d5c4c1e8073bbcb5d6f"
        "f822bf93b9f5f29a07946ac13c02170000014d5408000000000000000000000000"
        "0000000000000000000000000000";
    const char *nonce_hex = "001c8723";
    const char *digest_hex = "a883ea30810c942b37513b5e8a4f4aff4e4f4a5c277631e68ecb8e624f97a961";

    uint8_t header[MINER_HEADER_BYTES];
    uint8_t packet[MINER_JOB_PACKET_BYTES];
    uint8_t digest[32];

    hex_to_bytes(header_hex, header, sizeof(header));
    miner_core_packet_from_header(header, 0.003, packet);
    expect_hex("packet", packet, sizeof(packet), packet_hex);

    hex_to_bytes(nonce_hex, header + 76, 4);
    miner_core_sha256d(header, sizeof(header), digest);
    expect_hex("nonce digest", digest, sizeof(digest), digest_hex);
}

int main(void)
{
    test_logged_header_packet_and_digest();
    puts("PASS miner core tests");
    return 0;
}
