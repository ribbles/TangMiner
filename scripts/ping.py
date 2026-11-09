#!/usr/bin/env python3
import argparse
import time

import serial


PAYLOAD = bytes(76)
REQUEST = b"TNE" + PAYLOAD
EXPECTED_RESPONSE = b"E" + PAYLOAD


def main():
    parser = argparse.ArgumentParser(description="Ping a TangMiner FPGA over UART")
    parser.add_argument("port", help="serial port, for example COM11", default="COM5")
    args = parser.parse_args()

    print(f"request:  {REQUEST.hex()}")
    started = time.monotonic()
    response = b""

    try:
        with serial.Serial(
            args.port,
            baudrate=115200,
            timeout=5.0,
            write_timeout=5.0,
        ) as uart:
            uart.reset_input_buffer()
            uart.reset_output_buffer()
            uart.write(REQUEST)
            uart.flush()
            response = uart.read(len(EXPECTED_RESPONSE))
    except Exception as exc:
        elapsed = time.monotonic() - started
        print(f"response: {response.hex()}")
        print(f"elapsed:  {elapsed:.3f}s")
        raise SystemExit(f"error: {exc}")

    elapsed = time.monotonic() - started
    print(f"response: {response.hex()}")
    print(f"elapsed:  {elapsed:.3f}s")

    if response != EXPECTED_RESPONSE:
        if not response:
            raise SystemExit("error: no response from FPGA within 5 seconds")
        raise SystemExit(
            f"error: invalid response (expected {EXPECTED_RESPONSE.hex()})"
        )

    print("FPGA is alive")


if __name__ == "__main__":
    main()
