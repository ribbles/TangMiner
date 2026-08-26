#!/usr/bin/env python3
import hashlib
import json
import logging
import socket
import time

import serial

PORT = "COM9"
BAUD = 115200
HOST = "public-pool.io"
POOL_PORT = 13333
USER = "bc1qjwgtd0sa3znxftx5s7mzwaz8ct34yvesr2nqa6.tangnano9k"
PASS = ""
DIFF1 = 0xffff * 2 ** (8 * (0x1D - 3))
SUGGESTED_POOL_DIFF = 0.001
TARGET_SECS = 12.0
MIN_SECS = 5.0
MAX_SECS = 30.0
# Internal difficulty seed chosen from observed board performance so startup batches are already near the target window.
batch_diff = 0.003
MINER_LOG_FILE = "miner.log"
PROOF_LOG_FILE = "proof_of_work.jsonl"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s.%(msecs)03d %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(MINER_LOG_FILE, mode="a", encoding="utf-8"),
    ],
)
log = logging.getLogger("fpga")
proof_log = open(PROOF_LOG_FILE, "a", encoding="utf-8", buffering=1)
sock = socket.create_connection((HOST, POOL_PORT))
sock.settimeout(0.2)
ser = serial.Serial(PORT, BAUD, timeout=0.2, write_timeout=1)
time.sleep(0.1)
ser.reset_input_buffer()
ser.reset_output_buffer()
buf = b""
rid = 0
diff = 1.0
xn1 = b""
xn2_size = 0
job = None
active = None
xn2 = 0
pending = {}

# BEGIN: Taken from https://github.com/skot/TangMiner/blob/main/scripts/make_job.py 
IV = (
    0x6A09E667,
    0xBB67AE85,
    0x3C6EF372,
    0xA54FF53A,
    0x510E527F,
    0x9B05688C,
    0x1F83D9AB,
    0x5BE0CD19,
)
K = (
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
)


def rotr(x, n):
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF


def compress(state, block):
    w = [int.from_bytes(block[i:i + 4], "big") for i in range(0, 64, 4)]
    for i in range(16, 64):
        s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
        s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
        w.append((w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF)

    a, b, c, d, e, f, g, h = state
    for i in range(64):
        s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
        ch = (e & f) ^ (~e & g)
        t1 = (h + s1 + ch + K[i] + w[i]) & 0xFFFFFFFF
        s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
        maj = (a & b) ^ (a & c) ^ (b & c)
        t2 = (s0 + maj) & 0xFFFFFFFF
        h, g, f, e, d, c, b, a = g, f, e, (d + t1) & 0xFFFFFFFF, c, b, a, (t1 + t2) & 0xFFFFFFFF

    return tuple((x + y) & 0xFFFFFFFF for x, y in zip(state, (a, b, c, d, e, f, g, h)))


def words_to_bytes(words):
    return b"".join(word.to_bytes(4, "big") for word in words)


def share_diff(work):
    return DIFF1 / max(work, 1)


def reverse_word_bytes(data):
    return b"".join(data[i:i + 4][::-1] for i in range(0, len(data), 4))

# END: Taken from https://github.com/skot/TangMiner/blob/main/scripts/make_job.py 


for method, params in (
    ("mining.suggest_difficulty", [SUGGESTED_POOL_DIFF]),
    ("mining.subscribe", []),
    ("mining.authorize", [USER, PASS]),
):
    rid += 1
    line = json.dumps({"id": rid, "method": method, "params": params}) + "\n"
    pending[rid] = method
    log.info("POOL >> %s", line.strip())
    sock.sendall(line.encode())

while True:
    try:
        chunk = sock.recv(65536)
        if not chunk:
            raise SystemExit("pool disconnected")
        buf += chunk
    except socket.timeout:
        pass
    while b"\n" in buf:
        raw, buf = buf.split(b"\n", 1)
        if not raw.strip():
            continue
        log.info("POOL << %s", raw.decode(errors="replace"))
        msg = json.loads(raw)
        method = pending.pop(msg.get("id"), None)
        if method == "mining.subscribe" and msg.get("result"):
            xn1 = bytes.fromhex(msg["result"][1])
            xn2_size = int(msg["result"][2])
        elif msg.get("method") == "mining.set_difficulty":
            diff = float(msg["params"][0])
            expected_secs = diff * (2 ** 32) / 200_000.0
            log.info("POOL << share difficulty=%g expected_time_at_0.2MH/s=%.1fs", diff, expected_secs)
        elif msg.get("method") == "mining.set_extranonce":
            xn1 = bytes.fromhex(msg["params"][0])
            xn2_size = int(msg["params"][1])
        elif msg.get("method") == "mining.notify":
            p = msg["params"]
            job = {"job_id": p[0], "prevhash": reverse_word_bytes(bytes.fromhex(p[1])), "coinb1": bytes.fromhex(p[2]), "coinb2": bytes.fromhex(p[3]), "branches": [bytes.fromhex(x) for x in p[4]], "version": bytes.fromhex(p[5])[::-1], "nbits": p[6], "nbits_le": bytes.fromhex(p[6])[::-1], "ntime": p[7], "ntime_le": bytes.fromhex(p[7])[::-1]}
            active = None
    packet = ser.read(37)
    if packet:
        while len(packet) < 37:
            packet += ser.read(37 - len(packet))
        log.info("MINER << %s", packet.hex())
        if not active or packet[:1] != b"F":
            continue
        nonce = packet[1:5]
        submit_nonce = nonce[::-1].hex()
        header = active["header"][:76] + nonce
        digest = hashlib.sha256(hashlib.sha256(header).digest()).digest()
        if digest != packet[5:]:
            raise SystemExit(f"bad FPGA hash host={digest.hex()} fpga={packet[5:].hex()}")
        secs = time.time() - active["sent"]
        hashrate = (int.from_bytes(nonce, "big") + 1) / max(secs, 1e-9)
        # Retune gently because share timing is noisy; one lucky nonce should not swing the next batch too far.
        batch_diff *= max(0.5, min(4.0, (TARGET_SECS / max(secs, 0.1)) ** 0.5))
        work = int.from_bytes(digest[::-1], "big")
        found_diff = share_diff(work)
        ok = work <= active["pool_target"]
        block = work <= active["network_target"]
        log.info(
            "MINER << nonce=%s secs=%.2f hashrate=%.3f MH/s share=%s share_diff=%.8g pool_diff=%.8g batch_diff=%.8g",
            nonce.hex(), secs, hashrate / 1e6, ok, found_diff, active["pool_diff"], batch_diff,
        )
        if ok:
            proof_log.write(json.dumps({
                "time": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "job_id": active["job_id"],
                "extranonce2": active["xn2"],
                "ntime": active["ntime"],
                "nonce": submit_nonce,
                "hash": digest.hex(),
                "work": f"{work:064x}",
                "share": ok,
                "block": block,
                "share_diff": found_diff,
                "pool_diff": active["pool_diff"],
                "batch_diff": batch_diff,
                "secs": secs,
                "hashrate": hashrate,
            }, separators=(",", ":")) + "\n")
            log.info("FOUND proof-of-work job=%s nonce=%s hash=%s", active["job_id"], nonce.hex(), digest.hex())
        if block:
            log.info("FOUND bitcoin block candidate job=%s nonce=%s hash=%s", active["job_id"], nonce.hex(), digest.hex())
        if ok:
            rid += 1
            line = json.dumps({"id": rid, "method": "mining.submit", "params": [USER, active["job_id"], active["xn2"], active["ntime"], submit_nonce]}) + "\n"
            log.info("POOL >> %s", line.strip())
            sock.sendall(line.encode())
        active = None
    if job and not active:
        xn2_bytes = xn2.to_bytes(xn2_size, "big")
        xn2 += 1
        # Pool work defines the coinbase in two pieces around extranonce1/extranonce2.
        coinbase = job["coinb1"] + xn1 + xn2_bytes + job["coinb2"]
        merkle = hashlib.sha256(hashlib.sha256(coinbase).digest()).digest()
        for branch in job["branches"]:
            merkle = hashlib.sha256(hashlib.sha256(merkle + branch).digest()).digest()
        header = job["version"] + job["prevhash"] + merkle + job["ntime_le"] + job["nbits_le"] + b"\0\0\0\0"
        # Pool target is the share threshold from the current Stratum difficulty.
        pool_target = int(DIFF1 / diff)
        bits = int(job["nbits"], 16)
        # Network target is the actual Bitcoin block target decoded from nBits.
        network_target = (bits & 0xFFFFFF) * (1 << (8 * ((bits >> 24) - 3)))
        # FPGA target is intentionally easier than the pool target so the board returns periodic proof-of-work batches.
        target = max(1, min((1 << 256) - 1, int(DIFF1 / max(batch_diff, 1e-12))))
        # Midstate is the SHA-256 internal state after hashing header bytes 0..63; the FPGA finishes the nonce-bearing tail.
        midstate = words_to_bytes(compress(IV, header[:64]))
        packet = b"TNJ" + midstate + header[64:76] + target.to_bytes(32, "big")
        log.info("MINER >> job=%s xn2=%s pool_diff=%.8g batch_diff=%.8g target=%064x", job["job_id"], xn2_bytes.hex(), diff, batch_diff, target)
        # Tell the FPGA to stop old work first so a stale found nonce cannot be misattributed to the new job.
        ser.write(b"TNS")
        ser.flush()
        # The stop command is only three bytes; a tiny pause is enough to let the core quiesce before we replace work.
        time.sleep(0.02)
        ser.reset_input_buffer()
        ser.write(packet)
        ser.flush()
        active = {"header": header, "job_id": job["job_id"], "xn2": xn2_bytes.hex(), "ntime": job["ntime"], "pool_target": pool_target, "pool_diff": diff, "network_target": network_target, "sent": time.time()}
    if active and time.time() - active["sent"] > MAX_SECS:
        batch_diff *= TARGET_SECS / MAX_SECS
        log.info("MINER >> timeout secs=%.2f new_batch_diff=%.6g", time.time() - active["sent"], batch_diff)
        active = None
