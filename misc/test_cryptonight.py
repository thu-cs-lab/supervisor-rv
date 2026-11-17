#!/usr/bin/env python3
"""Check a basic RV32/RV64 kernel's CRYPTONIGHT result across G commands.

Build without interrupts or paging, then run:
    python3 misc/test_cryptonight.py kernel/kernel.elf
Run on Linux/macOS with qemu-system-riscv32 or qemu-system-riscv64 on PATH.
"""

import argparse
import os
from pathlib import Path
import select
import shutil
import struct
import subprocess


def elf_symbols(path):
    data = path.read_bytes()
    if data[:4] != b"\x7fELF" or data[4] not in (1, 2) or data[5] != 1:
        raise ValueError("Expected a little-endian ELF32 or ELF64 kernel")
    bits = 32 if data[4] == 1 else 64
    header = struct.unpack_from("<16sHHIIIIIHHHHHH" if bits == 32
                                else "<16sHHIQQQIHHHHHH", data)
    if header[2] != 243:
        raise ValueError("Expected a RISC-V kernel")
    section_format = "<IIIIIIIIII" if bits == 32 else "<IIQQQQIIQQ"
    sections = [struct.unpack_from(section_format, data,
                                  header[6] + i * header[11])
                for i in range(header[12])]
    symbols = {}
    for section in sections:
        if section[1] != 2:  # SHT_SYMTAB
            continue
        strings = sections[section[6]]
        for offset in range(section[4], section[4] + section[5], section[9]):
            entry = struct.unpack_from("<IIIBBH" if bits == 32 else "<IBBHQQ",
                                       data, offset)
            name_offset = strings[4] + entry[0]
            name = data[name_offset:data.index(b"\0", name_offset)].decode()
            symbols[name] = entry[1] if bits == 32 else entry[4]
    return bits, symbols


class Monitor:
    def __init__(self, qemu, kernel, bits):
        self.qemu, self.kernel, self.bits = qemu, kernel, bits

    def __enter__(self):
        self.process = subprocess.Popen(
            [self.qemu, "-M", "virt", "-m", "32M", "-bios", "none",
             "-kernel", str(self.kernel), "-display", "none", "-monitor", "none",
             "-serial", "stdio"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        try:
            banner = b"MONITOR for RISC-V - initialized."
            if self.read(len(banner)) != banner:
                raise AssertionError("Unexpected monitor boot message")
            self.send(b"W")
            if self.read(1) != bytes([self.bits // 8]):
                raise AssertionError("Unexpected monitor XLEN")
        except BaseException:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, *_):
        self.process.terminate()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.process.stdin.close()
        self.process.stdout.close()

    def read(self, length):
        data = bytearray()
        while len(data) < length:
            ready, _, _ = select.select([self.process.stdout], [], [], 20)
            if not ready:
                raise TimeoutError("Timed out waiting for monitor serial data")
            chunk = os.read(self.process.stdout.fileno(), length - len(data))
            if not chunk:
                raise EOFError("QEMU closed the serial connection")
            data.extend(chunk)
        return bytes(data)

    def word(self, value):
        return value.to_bytes(self.bits // 8, "little")

    def send(self, data):
        self.process.stdin.write(data)
        self.process.stdin.flush()

    def run(self, address):
        self.send(b"G" + self.word(address))
        if self.read(1) != b"\x06" or self.read(1) != b"\x07":
            raise AssertionError("User program did not start and return normally")

    def registers(self):
        self.send(b"R")
        return struct.unpack("<31I" if self.bits == 32 else "<31Q",
                             self.read(31 * self.bits // 8))

    def seed_t1(self):
        # addi t1, zero, 1; ret. Set state through a real preceding G command.
        program = struct.pack("<II", 0x00100313, 0x00008067)
        address = 0x80100000
        self.send(b"A" + self.word(address) + self.word(len(program)) + program)
        self.run(address)
        if self.registers()[5] != 1:
            raise AssertionError("Preceding program did not leave t1 = 1")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kernel", type=Path)
    args = parser.parse_args()
    bits, symbols = elf_symbols(args.kernel)
    qemu = shutil.which("qemu-system-riscv" + str(bits))
    if not qemu:
        parser.error("qemu-system-riscv%d is not on PATH" % bits)
    expected = 0xa2e31a85 if bits == 32 else 0xffffffff861c65d4
    failures = []
    for case in ("cold", "repeat", "after_2DCT", "t1_equals_1"):
        with Monitor(qemu, args.kernel.resolve(), bits) as monitor:
            if case == "repeat":
                monitor.run(symbols["UTEST_CRYPTONIGHT"])
            elif case == "after_2DCT":
                monitor.run(symbols["UTEST_2DCT"])
            elif case == "t1_equals_1":
                monitor.seed_t1()
            monitor.run(symbols["UTEST_CRYPTONIGHT"])
            actual = monitor.registers()[4]  # t0 = x5
            ok = actual == expected
            print("RV%d %-12s t0=%0*x %s" %
                  (bits, case, bits // 4, actual, "PASS" if ok else "FAIL"))
            if not ok:
                failures.append(case)
    if failures:
        raise SystemExit("Unexpected CRYPTONIGHT result: " + ", ".join(failures))


if __name__ == "__main__":
    main()
