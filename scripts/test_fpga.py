#!/usr/bin/env python3
import argparse
import hashlib
import time

import serial

from make_job import IV, compress, words_to_bytes


GENESIS_HEADER = bytes.fromhex(
    "01000000"
    "0000000000000000000000000000000000000000000000000000000000000000"
    "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a"
    "29ab5f49"
    "ffff001d"
    "1dac2b7c"
)
HEADER_TEMPLATE = GENESIS_HEADER[:76]
GENESIS_NONCE = GENESIS_HEADER[76:80]
RESPONSE_BYTES = 37


def double_sha256(data):
    return hashlib.sha256(hashlib.sha256(data).digest()).digest()


def make_packet(target):
    midstate = words_to_bytes(compress(IV, HEADER_TEMPLATE[:64]))
    return b"TNJ" + midstate + HEADER_TEMPLATE[64:76] + target.to_bytes(32, "big")


def read_response(uart, timeout):
    deadline = time.monotonic() + timeout
    response = bytearray()
    while len(response) < RESPONSE_BYTES:
        if time.monotonic() >= deadline:
            raise TimeoutError(
                f"timed out after {timeout:.1f}s; received {len(response)} of {RESPONSE_BYTES} bytes"
            )
        chunk = uart.read(RESPONSE_BYTES - len(response))
        if chunk:
            response.extend(chunk)
    return bytes(response)


def run_test(uart, name, target, expected_nonce, timeout):
    packet = make_packet(target)
    uart.write(b"TNS")
    uart.flush()
    time.sleep(0.02)
    uart.reset_input_buffer()

    started = time.monotonic()
    uart.write(packet)
    uart.flush()
    response = read_response(uart, timeout)
    elapsed = time.monotonic() - started

    if response[:1] != b"F":
        raise RuntimeError(f"{name}: invalid response header: {response.hex()}")

    nonce = response[1:5]
    fpga_hash = response[5:37]
    host_hash = double_sha256(HEADER_TEMPLATE + nonce)
    work = int.from_bytes(host_hash[::-1], "big")

    if fpga_hash != host_hash:
        raise RuntimeError(
            f"{name}: FPGA hash mismatch: fpga={fpga_hash.hex()} host={host_hash.hex()}"
        )
    if work >= target:
        raise RuntimeError(
            f"{name}: returned hash does not meet target: work={work:064x} target={target:064x}"
        )
    if nonce != expected_nonce:
        raise RuntimeError(
            f"{name}: unexpected nonce: got={nonce.hex()} expected={expected_nonce.hex()}"
        )

    hashes_per_second = (int.from_bytes(nonce, "big") + 1) / max(elapsed, 1e-9)
    print(
        f"PASS {name}: nonce={nonce.hex()} hash={host_hash.hex()} "
        f"elapsed={elapsed:.3f}s hashrate={hashes_per_second / 1e6:.3f} MH/s"
    )


def main():
    parser = argparse.ArgumentParser(
        description="Run deterministic proof-of-work and Bitcoin genesis tests on TangMiner"
    )
    parser.add_argument("port", help="serial port, for example COM6")
    parser.add_argument(
        "--test",
        choices=("pow", "bitcoin", "all"),
        default="all",
        help="test to run (default: all)",
    )
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--pow-timeout", type=float, default=10.0)
    parser.add_argument("--bitcoin-timeout", type=float, default=300.0)
    args = parser.parse_args()

    nonce_zero_hash = double_sha256(HEADER_TEMPLATE + bytes(4))
    nonce_zero_work = int.from_bytes(nonce_zero_hash[::-1], "big")
    proof_target = nonce_zero_work + 1

    compact = int.from_bytes(GENESIS_HEADER[72:76], "little")
    exponent = compact >> 24
    coefficient = compact & 0xFFFFFF
    bitcoin_target = coefficient << (8 * (exponent - 3))

    with serial.Serial(
        args.port,
        baudrate=args.baud,
        timeout=0.2,
        write_timeout=1.0,
    ) as uart:
        time.sleep(0.1)
        uart.reset_input_buffer()
        uart.reset_output_buffer()
        try:
            if args.test in ("pow", "all"):
                run_test(uart, "proof-of-work", proof_target, bytes(4), args.pow_timeout)
            if args.test in ("bitcoin", "all"):
                run_test(
                    uart,
                    "bitcoin-genesis",
                    bitcoin_target,
                    GENESIS_NONCE,
                    args.bitcoin_timeout,
                )
        finally:
            uart.write(b"TNS")
            uart.flush()


if __name__ == "__main__":
    main()
