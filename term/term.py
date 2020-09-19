#!/usr/bin/env python3
# -*- encoding=utf-8 -*-

import argparse
import math
import os
import platform
import re
import select
import socket
import string
import struct
import subprocess
import sys
import tempfile
from timeit import default_timer as timer
try:
    import serial
except:
    print("Please install pyserial")
    exit(1)
try:
    import readline
except:
    pass
try: type(raw_input)
except NameError: raw_input = input

CCPREFIX = "riscv64-unknown-elf-"
if 'GCCPREFIX' in os.environ:
    CCPREFIX=os.environ['GCCPREFIX']
CMD_ASSEMBLER = CCPREFIX + 'as'
CMD_DISASSEMBLER = CCPREFIX + 'objdump'
CMD_BINARY_COPY = CCPREFIX + 'objcopy'

Reg_alias = ['zero', 'ra', 'sp', 'gp', 'tp', 't0', 't1', 't2', 's0/fp', 's1', 'a0', 'a1', 'a2', 'a3', 'a4', 'a5', 'a6', 
                'a7', 's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10', 's11', 't3', 't4', 't5', 't6']

xlen = 4
arch = 'rv32'

def test_programs():
    tmp = tempfile.NamedTemporaryFile()
    for prog in [CMD_ASSEMBLER, CMD_DISASSEMBLER, CMD_BINARY_COPY]:
        try:
            subprocess.check_call([prog, '--version'], stdout=tmp)
        except:
            print("Couldn't run", prog)
            print("Please check your PATH env", os.environ["PATH"].split(os.pathsep))
            tmp.close()
            return False
    tmp.close()
    return True

def output_binary(binary):
    if hasattr(sys.stdout,'buffer'): # Python 3
        sys.stdout.buffer.write(binary)
    else:
        sys.stdout.write(binary)

# convert int to byte string of length xlen, from LSB to MSB
def int_to_byte_string(val):
    if xlen == 4:
        return struct.pack('<I', val)
    else:
        return struct.pack('<Q', val)

def byte_string_to_int(val):
    if xlen == 4:
        return struct.unpack('<I', val)[0]
    else:
        return struct.unpack('<Q', val)[0]

# convert 32-bit int to byte string of length 4, from LSB to MSB
def byte_string_to_dword(val):
    return struct.unpack('<I', val)[0]

# invoke assembler to compile instructions (in little endian RV32/64)
# returns a byte string of encoded instructions, from lowest byte to highest byte
# returns empty string on failure (in which case assembler messages are printed to stdout)
def multi_line_asm(instr):
    tmp_asm = tempfile.NamedTemporaryFile(delete=False)
    tmp_obj = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)

    try:
        tmp_asm.write((instr + "\n").encode('utf-8'))
        tmp_asm.close()
        tmp_obj.close()
        tmp_binary.close()
        subprocess.check_output([
            CMD_ASSEMBLER,  tmp_asm.name, '-march={}i'.format(arch), '-o', tmp_obj.name])
        subprocess.check_call([
            CMD_BINARY_COPY, '-j', '.text', '-O', 'binary', tmp_obj.name, tmp_binary.name])
        with open(tmp_binary.name, 'rb') as f:
            binary = f.read()
            return binary
    except subprocess.CalledProcessError as e:
        print(e.output)
    except:
        print("Unexpected error:", sys.exc_info()[0])
    finally:
        os.remove(tmp_asm.name)
        # object file won't exist if assembler fails
        if os.path.exists(tmp_obj.name):
            os.remove(tmp_obj.name)
        os.remove(tmp_binary.name)
    # can only reach here when assembler fails
    return None

# invoke objdump to disassemble single instruction
# accepts encoded instruction (exactly 4 bytes), from least significant byte
# objdump does not seem to report errors so this function does not guarantee
# to produce meaningful result
def single_line_disassmble(binary_instr, addr):
    assert(len(binary_instr) == 4)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary.write(binary_instr)
    tmp_binary.close()

    raw_output = subprocess.check_output([
        CMD_DISASSEMBLER, '-D', '-b', 'binary',
        '--adjust-vma=' + str(addr),
        '-m', 'riscv:{}'.format(arch), tmp_binary.name])
    # the last line should be something like:
    #    0:   21107f00        addu    v0,v1,ra
    result = raw_output.strip().split(b'\n')[-1].split(None, 2)[-1]

    os.remove(tmp_binary.name)

    return result.decode('utf-8')


def run_T():
    outp.write(b'T')
    addr = byte_string_to_int(inp.read(xlen))
    if addr == (2**(8*xlen))-1:
        print("Paging not enabled")
        return
    print("Page table at %08x" % addr)
    print("     Virtual Address     |      Physical Address     | D | A | G | U | X | W | R | V")
    if xlen == 4:
        for vpn1 in range(0, 1024):
            outp.write(b'D')
            outp.write(int_to_byte_string(addr))
            outp.write(int_to_byte_string(4))
            entry = byte_string_to_int(inp.read(4))
            if (entry & 1) != 0:
                # Valid
                if (entry & 0xe) == 0:
                    # non-leaf
                    addr2 = (entry >> 10) << 12
                    outp.write(b'D')
                    outp.write(int_to_byte_string(addr2))
                    outp.write(int_to_byte_string(4096))
                    for vpn0 in range(0, 1024):
                        entry2 = byte_string_to_int(inp.read(4))
                        if (entry2 & 1) != 0:
                            # Valid
                            size = (1 << 12) - 1
                            vaddr = (vpn1 << 22) | (vpn0 << 12)
                            paddr = (entry2 >> 10) << 12
                            print("    %08x-%08x          %08x-%08x       %x   %x   %x   %x   %x   %x   %x   %x" %
                                (vaddr, vaddr + size, paddr, paddr + size, (entry2 >> 7) & 1, (entry2 >> 6) & 1, (entry2 >> 5) & 1,
                                    (entry2 >> 4) & 1, (entry2 >> 3) & 1, (entry2 >> 2) & 1, (entry2 >> 1) & 1, entry2 & 1))
                else:
                    size = (1 << 22) - 1
                    vaddr = vpn1 << 22
                    paddr = (entry >> 10) << 12
                    print("    %08x-%08x          %08x-%08x       %x   %x   %x   %x   %x   %x   %x   %x" %
                        (vaddr, vaddr + size, paddr, paddr + size, (entry >> 7) & 1, (entry >> 6) & 1,
                            (entry >> 5) & 1, (entry >> 4) & 1, (entry >> 3) & 1, (entry >> 2) & 1, (entry >> 1) & 1, entry & 1))

            addr = addr + 4
    else:
        for vpn2 in range(0, 512):
            outp.write(b'D')
            outp.write(int_to_byte_string(addr))
            outp.write(int_to_byte_string(8))
            entry = byte_string_to_int(inp.read(8))
            if (entry & 1) != 0:
                # Valid
                if (entry & 0xe) == 0:
                    # non-leaf
                    addr2 = (entry >> 10) << 12
                    for vpn1 in range(0, 512):
                        outp.write(b'D')
                        outp.write(int_to_byte_string(addr2))
                        outp.write(int_to_byte_string(8))
                        entry2 = byte_string_to_int(inp.read(8))
                        if (entry2 & 1) != 0:
                            # Valid
                            if (entry2 & 0xe) == 0:
                                # non-leaf
                                addr3 = (entry2 >> 10) << 12
                                outp.write(b'D')
                                outp.write(int_to_byte_string(addr3))
                                outp.write(int_to_byte_string(4096))
                                for vpn0 in range(0, 512):
                                    entry3 = byte_string_to_int(inp.read(8))
                                    if (entry3 & 1) != 0:
                                        # Valid
                                        size = (1 << 12) - 1
                                        vaddr = (vpn2 << 30) | (vpn1 << 21) | (vpn0 << 12)
                                        paddr = (entry3 >> 10) << 12
                                        print("    %08x-%08x          %08x-%08x       %x   %x   %x   %x   %x   %x   %x   %x" %
                                            (vaddr, vaddr + size, paddr, paddr + size, (entry3 >> 7) & 1, (entry3 >> 6) & 1, (entry3 >> 5) & 1,
                                                (entry3 >> 4) & 1, (entry3 >> 3) & 1, (entry3 >> 2) & 1, (entry3 >> 1) & 1, entry3 & 1))
                            else:
                                size = (1 << 21) - 1
                                vaddr = (vpn2 << 30) | (vpn1 << 21)
                                paddr = (entry2 >> 10) << 12
                                print("    %08x-%08x          %08x-%08x       %x   %x   %x   %x   %x   %x   %x   %x" %
                                    (vaddr, vaddr + size, paddr, paddr + size, (entry2 >> 7) & 1, (entry2 >> 6) & 1, (entry2 >> 5) & 1,
                                        (entry2 >> 4) & 1, (entry2 >> 3) & 1, (entry2 >> 2) & 1, (entry2 >> 1) & 1, entry2 & 1))
                        addr2 = addr2 + 8
                else:
                    size = (1 << 30) - 1
                    vaddr = vpn2 << 30
                    paddr = (entry >> 10) << 12
                    print("    %08x-%08x          %08x-%08x       %x   %x   %x   %x   %x   %x   %x   %x" %
                        (vaddr, vaddr + size, paddr, paddr + size, (entry >> 7) & 1, (entry >> 6) & 1, (entry >> 5) & 1,
                            (entry >> 4) & 1, (entry >> 3) & 1, (entry >> 2) & 1, (entry >> 1) & 1, entry & 1))

            addr = addr + 8

def run_A(addr):
    print("one instruction per line, empty line to end.")
    offset = addr & 0xfffffff
    prompt_addr = addr
    asm = ".org {:#x}\n".format(offset)
    while True:
        line = raw_input('[0x%04x] ' % prompt_addr).strip()
        if line == '':
            break
        elif re.match("^.+:$", line) is not None:
            # ASM label only, not incrementing addr
            asm += line + "\n"
            continue
        try:
            # directly add hex to assembly lines
            asm += ".word {:#x}\n".format(int(line, 16))
        except ValueError:
            # instruction text, check validity
            if multi_line_asm(line) is None:
                # error occurred when running assembler, skip this line
                continue
            asm += line + "\n"
        prompt_addr = addr + len(multi_line_asm(asm)) - offset
    # print(asm)
    binary = multi_line_asm(asm)
    for i in range(offset, len(binary), 4):
        outp.write(b'A')
        outp.write(int_to_byte_string(addr))
        outp.write(int_to_byte_string(4))
        outp.write(binary[i:i+4])
        addr = addr + 4

def run_F(addr, file_name):
    if not os.path.isfile(file_name):
        print("file %s does not exist" % file_name)
        return
    print("reading from file %s" % file_name)
    offset = addr & 0xfffffff
    prompt_addr = addr
    asm = ".org {:#x}\n".format(offset)
    with open(file_name, "r") as f:
        for line in f:
            print('[0x%04x] %s' % (prompt_addr, line.strip()))
            if line == '':
                break
            elif re.match("^.+:$", line) is not None:
                # ASM label only, not incrementing addr
                asm += line + "\n"
                continue
            try:
                # directly add hex to assembly lines
                asm += ".word {:#x}\n".format(int(line, 16))
            except ValueError:
                # instruction text, check validity
                if multi_line_asm(line) is None:
                    # error occurred when running assembler, skip this line
                    continue
                asm += line + "\n"
            prompt_addr = addr + len(multi_line_asm(asm)) - offset
    binary = multi_line_asm(asm)
    for i in range(offset, len(binary), 4):
        outp.write(b'A')
        outp.write(int_to_byte_string(addr))
        outp.write(int_to_byte_string(4))
        outp.write(binary[i:i+4])
        addr = addr + 4


def run_R():
    outp.write(b'R')
    for i in range(1, 32):
        val_raw = inp.read(xlen)
        val = byte_string_to_int(val_raw)
        print(('R{0}{1:7} = 0x{2:0>' + str(xlen * 2) +'x}').format(
            str(i).ljust(2),
            '(' + Reg_alias[i] + ')',
            val,
        ))


def run_D(addr, num):
    if num % 4 != 0:
        print("num % 4 should be zero")
        return
    outp.write(b'D')
    outp.write(int_to_byte_string(addr))
    outp.write(int_to_byte_string(num))
    counter = 0
    while counter < num:
        val_raw = inp.read(4)
        counter = counter + 4
        val = byte_string_to_dword(val_raw)
        print('0x%08x: 0x%08x' % (addr,val))
        addr = addr + 4


def run_U(addr, num):
    if num % 4 != 0:
        print("num % 4 should be zero")
        return
    outp.write(b'D')
    outp.write(int_to_byte_string(addr))
    outp.write(int_to_byte_string(num))
    counter = 0
    while counter < num:
        val_raw = inp.read(4)
        val = byte_string_to_dword(val_raw)
        print('0x%08x:\t%08x\t%s' % (addr, val, single_line_disassmble(val_raw, addr)))
        counter = counter + 4
        addr = addr + 4

def run_G(addr):
    outp.write(b'G')
    outp.write(int_to_byte_string(addr))
    class TrapError(Exception):
        def __init__(self, info):
            self.info = info

    def trap():
        mepc = int.from_bytes(inp.read(xlen), "little")
        mcause = int.from_bytes(inp.read(xlen), "little")
        mtval = int.from_bytes(inp.read(xlen), "little")
        raise TrapError({
            "mepc": mepc,
            "mcause": mcause,
            "mtval": mtval,
        });

    try:
        ret = inp.read(1)
        if ret == b'\x80':
            trap()
        if ret != b'\x06':
            print("start mark should be 0x06")
        time_start = timer()
        while True:
            ret = inp.read(1)
            if ret == b'\x07':
                break
            elif ret == b'\x80':
                trap()
            output_binary(ret)
        print('') #just a new line
        elapse = timer() - time_start
        print('elapsed time: %.3fs' % (elapse))
    except TrapError as e:
        print('supervisor reported an exception during execution')
        for (k, v) in e.info.items():
            print("  {0}: 0x{1:0{2}x}".format(k, v, xlen*2))


def MainLoop():
    while True:
        try:
            cmd = raw_input('>> ').strip().upper()
        except EOFError:
            break
        EmptyBuf()
        try:
            if cmd == 'Q':
                break
            elif cmd == 'A':
                addr = raw_input('addr: 0x')
                run_A(int(addr, 16))
            elif cmd == 'F':
                file_name = raw_input('>>file name: ')
                addr = raw_input('>>addr: 0x')
                run_F(int(addr, 16), file_name)
            elif cmd == 'R':
                run_R()
            elif cmd == 'D':
                addr = raw_input('addr: 0x')
                num = raw_input('num: ')
                run_D(int(addr, 16), int(num))
            elif cmd == 'U':
                addr = raw_input('addr: 0x')
                num = raw_input('num: ')
                run_U(int(addr, 16), int(num))
            elif cmd == 'G':
                addr = raw_input('addr: 0x')
                run_G(int(addr, 16))
            elif cmd == 'T':
                run_T()
            else:
                print("Invalid command")
                print("Usage:\tR: print registers")
                print("\tD: display memory")
                print("\tA: put assembly at specified address")
                print("\tU: read data and disassemble")
                print("\tG: run user code")
                print("\tT: print page table")
        except ValueError as e:
            print(e)

def InitializeSerial(pipe_path, baudrate):
    global outp, inp
    tty = serial.Serial(port=pipe_path, baudrate=baudrate)
    tty.reset_input_buffer()
    inp = tty
    outp = tty
    return True

def Main(welcome_message=True):
    global xlen, arch

    if welcome_message:
        output_binary(inp.read(33))
        print('')

    # probe xlen
    outp.write(b'W')
    while True:
        xlen = ord(inp.read(1))
        if xlen == 4:
            print('running in 32bit, xlen = 4')
            arch = 'rv32'
            break
        elif xlen == 8:
            print('running in 64bit, xlen = 8')
            arch = 'rv64'
            break
        elif xlen < 20:
            print('Got unexpected XLEN: {}'.format(xlen))
            sys.exit(1)
    MainLoop()

class tcp_wrapper:

    def __init__(self, sock=None):
        if sock is None:
            self.sock = socket.socket(
                socket.AF_INET, socket.SOCK_STREAM)
        else:
            self.sock = sock

    def connect(self, host, port):
        self.sock.connect((host, port))

    def write(self, msg):
        totalsent = 0
        MSGLEN = len(msg)
        while totalsent < MSGLEN:
            sent = self.sock.send(msg[totalsent:])
            if sent == 0:
                raise RuntimeError("socket connection broken")
            totalsent = totalsent + sent

    def flush(self): # dummy
        pass

    def read(self, MSGLEN):
        chunks = []
        bytes_recd = 0
        while bytes_recd < MSGLEN:
            chunk = self.sock.recv(min(MSGLEN - bytes_recd, 2048))
            # print 'read:...', list(map(lambda c: hex(ord(c)), chunk))
            if chunk == b'':
                raise RuntimeError("socket connection broken")
            chunks.append(chunk)
            bytes_recd = bytes_recd + len(chunk)
        return b''.join(chunks)

    def reset_input_buffer(self):
        local_input = [self.sock]
        while True:
            inputReady, o, e = select.select(local_input, [], [], 0.0)
            if len(inputReady) == 0:
                break
            for s in inputReady:
                s.recv(1)

def EmptyBuf():
    inp.reset_input_buffer()

def InitializeTCP(host_port):
    
    ValidIpAddressRegex = re.compile("^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])):(\d+)$");
    ValidHostnameRegex = re.compile("^((([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])):(\d+)$");

    if ValidIpAddressRegex.search(host_port) is None and \
        ValidHostnameRegex.search(host_port) is None:
        return False

    match = ValidIpAddressRegex.search(host_port) or ValidHostnameRegex.search(host_port)
    groups = match.groups()
    ser = tcp_wrapper()
    host, port = groups[0], groups[4]
    sys.stdout.write("connecting to %s:%s..." % (host, port))
    sys.stdout.flush()
    ser.connect(host, int(port))
    print("connected")

    global outp, inp
    outp = ser
    inp = ser
    return True

if __name__ == "__main__":
    # para = '127.0.0.1:6666' if len(sys.argv) != 2 else sys.argv[1]

    if sys.version_info[0] != 3:
        print("You MUST use Python3 to run terminal.")
        exit(1)

    parser = argparse.ArgumentParser(description = 'Term for rv32/64 expirence.')
    parser.add_argument('-c', '--continued', action='store_true', help='Term will not wait for welcome if this flag is set')
    parser.add_argument('-t', '--tcp', default=None, help='TCP server address:port for communication')
    parser.add_argument('-s', '--serial', default=None, help='Serial port name (e.g. /dev/ttyACM0, COM3)')
    parser.add_argument('-b', '--baud', default=9600, help='Serial port baudrate (9600 by default)')
    args = parser.parse_args()

    if args.tcp:
        if not InitializeTCP(args.tcp):
            print('Failed to establish TCP connection')
            exit(1)
    elif args.serial:
        if not InitializeSerial(args.serial, args.baud):
            print('Failed to open serial port')
            exit(1)
    else:
        parser.print_help()
        exit(1)
    if not test_programs():
        exit(1)
    Main(not args.continued)

