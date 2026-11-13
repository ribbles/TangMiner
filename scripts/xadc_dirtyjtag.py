#!/usr/bin/env python3
"""Read a Xilinx 7-series XADC over a persistent DirtyJTAG USB session."""

import argparse
import ctypes.util
import json
import os
import struct
import sys
import time

import usb.core
import usb.util
import usb.backend.libusb1


VID = 0x1209
PID = 0xC0CA
EP_OUT = 0x01
EP_IN = 0x82
CMD_STOP = 0x00
CMD_INFO = 0x01
CMD_FREQ = 0x02
CMD_XFER = 0x03
CMD_SETSIG = 0x04
CMD_GETSIG = 0x05
CMD_CLK = 0x06
SIG_TCK = 1 << 1
SIG_TDI = 1 << 2
SIG_TDO = 1 << 3
SIG_TMS = 1 << 4
EXTEND_LENGTH = 0x40
READ_TIMEOUT_MS = 1000
FLUSH_TIMEOUT_MS = 20
STARTUP_TIMEOUT_S = 20.0
STARTUP_PROBE_INTERVAL_S = 0.25


def backend():
    dll = os.environ.get("LIBUSB_DLL")
    if dll:
        return usb.backend.libusb1.get_backend(find_library=lambda _: dll)
    return usb.backend.libusb1.get_backend(find_library=ctypes.util.find_library)


def classify_usb_error(error):
    text = str(error).lower()
    errno = getattr(error, "errno", None)
    if errno == 13 or "access denied" in text or "insufficient permissions" in text:
        return (
            "DirtyJTAG is busy or permission-denied. "
            "Stop any other USB owner first (for example openFPGALoader --xvc, "
            "openFPGALoader --detect, or another xadc_dirtyjtag.py process)."
        )
    if "no such device" in text or "not found" in text:
        return "DirtyJTAG disconnected while opening the device."
    if errno == 10060 or "timed out" in text:
        return (
            "DirtyJTAG did not answer INFO in time. This usually means the bridge "
            "was left mid-transaction by a previous owner."
        )
    return None


class DirtyJtag:
    def __init__(self, frequency):
        self.device = None
        self.claimed = False
        self.interface = 0
        self.ep_out = EP_OUT
        self.ep_in = EP_IN
        self.device = usb.core.find(idVendor=VID, idProduct=PID, backend=backend())
        if self.device is None:
            raise RuntimeError("DirtyJTAG USB device 1209:c0ca not found")
        try:
            # DirtyJTAG is already configured and is a composite USB device;
            # re-setting its configuration can fail on Windows.
            usb.util.claim_interface(self.device, self.interface)
            self.claimed = True
            self._clear_halt(self.ep_in)
            self._clear_halt(self.ep_out)
            self._sync_session()
            self.tdi = 0
            self.tms = 0
            self.version = self._info()
            self._write(bytes((CMD_FREQ, (frequency // 1000) >> 8,
                               (frequency // 1000) & 0xff, CMD_STOP)))
        except usb.core.USBError as error:
            hint = classify_usb_error(error)
            if hint:
                self.close()
                raise RuntimeError(hint) from error
            self.close()
            raise
        except Exception:
            self.close()
            raise


    def _clear_halt(self, endpoint):
        try:
            self.device.clear_halt(endpoint)
        except usb.core.USBError:
            pass

    def _drain_input(self, max_packets=8):
        for _ in range(max_packets):
            try:
                self.device.read(self.ep_in, 64, timeout=FLUSH_TIMEOUT_MS)
            except usb.core.USBTimeoutError:
                return
            except usb.core.USBError:
                self._clear_halt(self.ep_in)
                return

    def _sync_session(self):
        # Recover from a previous owner leaving unread bytes or a halted pipe.
        self._clear_halt(self.ep_in)
        self._clear_halt(self.ep_out)
        self._drain_input()
        try:
            self._write(bytes((CMD_STOP,)))
        except usb.core.USBError:
            self._clear_halt(self.ep_out)
        self._drain_input()

    def close(self):
        if self.device is not None:
            try:
                try:
                    self._write(bytes((CMD_STOP,)))
                except usb.core.USBError:
                    pass
                if self.claimed:
                    usb.util.release_interface(self.device, self.interface)
                # Best-effort reset improves next-process startup after
                # timeout-heavy sessions on some Windows/libusb stacks.
                try:
                    self.device.reset()
                except usb.core.USBError:
                    pass
            finally:
                self.claimed = False
                usb.util.dispose_resources(self.device)
                self.device = None

    def _write(self, data):
        self.device.write(self.ep_out, data, timeout=READ_TIMEOUT_MS)

    def _read(self, length=32):
        data = bytes(self.device.read(self.ep_in, length, timeout=READ_TIMEOUT_MS))
        if not data:
            raise RuntimeError("DirtyJTAG returned an empty USB packet")
        return data

    def _info(self):
        last_timeout = None
        for _ in range(3):
            self._write(bytes((CMD_INFO, CMD_STOP)))
            try:
                info = self._read(64).decode("ascii", errors="replace")
                break
            except usb.core.USBTimeoutError as error:
                last_timeout = error
                # If a previous owner left DirtyJTAG mid-transaction, force a
                # short stop+flush cycle and try INFO again.
                self._sync_session()
                time.sleep(0.01)
        else:
            raise last_timeout
        if not info.startswith("DJTAG"):
            raise RuntimeError(f"unexpected DirtyJTAG response: {info!r}")
        return int(info[5])

    def _tms(self, bits, tdi=1):
        mask = SIG_TCK | SIG_TMS | SIG_TDI
        packet = bytearray()
        for bit in bits:
            self.tdi = SIG_TDI if tdi else 0
            self.tms = SIG_TMS if bit else 0
            value = self.tdi | self.tms
            packet += bytes((CMD_SETSIG, mask, value,
                             CMD_SETSIG, mask, value | SIG_TCK))
        value = self.tdi | self.tms
        packet += bytes((CMD_SETSIG, mask, value, CMD_STOP))
        self._write(packet)

    def _xfer(self, value, bits, end=True):
        real_bits = bits - (1 if end else 0)
        last_bit = (value >> (bits - 1)) & 1
        tx = bytearray(struct.pack("<I", value))
        rx = bytearray()
        max_bits = 4000 if self.version >= 3 else 240
        while real_bits:
            count = min(real_bits, max_bits)
            count_bytes = (count + 7) // 8
            if self.version >= 3:
                header = bytes((CMD_XFER, (count >> 8) & 0xff, count & 0xff))
            elif count > 255:
                header = bytes((CMD_XFER | EXTEND_LENGTH, count - 256))
            else:
                header = bytes((CMD_XFER, count))
            wire = bytearray(count_bytes)
            for i in range(count):
                if tx[i // 8] & (1 << (i % 8)):
                    wire[i // 8] |= 0x80 >> (i % 8)
            self._write(header + wire)
            received = self._read(32 if count <= 255 else count_bytes)
            shifted = bytearray(count_bytes)
            for i in range(count):
                if received[i // 8] & (0x80 >> (i % 8)):
                    shifted[i // 8] = (shifted[i // 8] >> 1) | 0x80
                else:
                    shifted[i // 8] >>= 1
            if count < max_bits and count % 8:
                diff = count % 8
                shifted[-1] >>= 8 - diff
            rx += shifted
            tx = tx[count_bytes:]
            real_bits -= count
        if end:
            self._tms([1], tdi=last_bit)
        return struct.unpack("<I", rx[:4].ljust(4, b"\0"))[0]

    def _reset(self):
        # Leave the TAP in TEST_LOGIC_RESET, matching go_test_logic_reset().
        self._tms([1, 1, 1, 1, 1, 1])

    def _instruction(self, instruction, reset=True):
        if reset:
            self._reset()
            self._tms([0, 1, 1, 0, 0])
        else:
            self._tms([1, 1, 0, 0])
        self._xfer(instruction, 6, end=True)
        self._tms([1, 0])

    def _data(self, value, bits=32, reset=True):
        if reset:
            self._reset()
            self._tms([0, 1, 0, 0])
        else:
            self._tms([1, 0, 0])
        result = self._xfer(value, bits, end=True)
        self._tms([1, 0])
        return result

    def xadc_read(self, address):
        command = (1 << 26) | (address << 16)
        self._instruction(0x37)  # XADC_DRP
        self._data(command, reset=False)
        time.sleep(0.001)
        self._instruction(0x37, reset=False)
        return self._data(command, reset=False)

    def xadc_write(self, address, value):
        command = (1 << 26) | (address << 16) | value
        self._instruction(0x37)
        self._data(command, reset=False)

    def xadc_single(self, channel):
        self.xadc_write(0x41, 0x3000)  # disable the sequencer
        self.xadc_write(0x40, (1 << 15) | (1 << 8) | channel)
        time.sleep(0.001)
        return self.xadc_read(channel)


def open_dirtyjtag(frequency):
    deadline = time.monotonic() + STARTUP_TIMEOUT_S
    attempts = 0
    last_error = None
    while True:
        attempts += 1
        try:
            return DirtyJtag(frequency)
        except RuntimeError as error:
            last_error = error
        except usb.core.USBError as error:
            hint = classify_usb_error(error)
            if hint:
                last_error = RuntimeError(hint)
            else:
                raise

        if time.monotonic() >= deadline:
            detail = f"{last_error}" if last_error else "unknown startup failure"
            raise RuntimeError(
                f"Unable to acquire DirtyJTAG after {attempts} attempts over "
                f"{STARTUP_TIMEOUT_S:g}s: {detail}"
            )
        time.sleep(STARTUP_PROBE_INTERVAL_S)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--interval", type=float, default=5)
    parser.add_argument("--frequency", type=int, default=6_000_000)
    parser.add_argument("--count", type=int, default=0, help="stop after this many samples")
    args = parser.parse_args()
    jtag = None
    try:
        jtag = open_dirtyjtag(args.frequency)
        print(f"DirtyJTAG DJTAG{jtag.version}; polling every {args.interval:g}s", file=sys.stderr)
        jtag.xadc_single(8)  # XADC calibration
        sample = 0
        while not args.count or sample < args.count:
            raw_temp = sum(jtag.xadc_single(0x00) for _ in range(4)) / 4
            raw_vccint = jtag.xadc_single(0x01)
            raw_vccint_max = jtag.xadc_single(0x21)
            raw_vccint_min = jtag.xadc_single(0x25)
            raw_vccaux = jtag.xadc_single(0x02)
            raw_vccaux_max = jtag.xadc_single(0x22)
            raw_vccaux_min = jtag.xadc_single(0x26)
            print(json.dumps({
                "temp": round(raw_temp * 503.975 / 65536.0 - 273.15),
                "vccint": round((raw_vccint >> 4) / 4096.0 * 3.0, 3),
                "maxvccint": round((raw_vccint_max >> 4) / 4096.0 * 3.0, 3),
                "minvccint": round((raw_vccint_min >> 4) / 4096.0 * 3.0, 3),
                "vccaux": round((raw_vccaux >> 4) / 4096.0 * 3.0, 3),
                "maxvccaux": round((raw_vccaux_max >> 4) / 4096.0 * 3.0, 3),
                "minvccaux": round((raw_vccaux_min >> 4) / 4096.0 * 3.0, 3),
            }), flush=True)
            sample += 1
            if not args.count or sample < args.count:
                time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nStopping.", flush=True, file=sys.stderr)
    finally:
        if jtag is not None:
            jtag.close()


if __name__ == "__main__":
    main()
