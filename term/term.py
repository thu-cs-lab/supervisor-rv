#!/usr/bin/env python
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

CCPREFIX = "mips-mti-elf-"
if 'GCCPREFIX' in os.environ:
    CCPREFIX=os.environ['GCCPREFIX']
CMD_ASSEMBLER = CCPREFIX + 'as'
CMD_DISASSEMBLER = CCPREFIX + 'objdump'
CMD_BINARY_COPY = CCPREFIX + 'objcopy'

Reg_alias = ['zero', 'AT', 'v0', 'v1', 'a0', 'a1', 'a2', 'a3', 't0', 't1', 't2', 't3', 't4', 't5', 't6', 't7', 's0', 
                's1', 's2', 's3', 's4', 's5', 's6', 's7', 't8', 't9/jp', 'k0', 'k1', 'gp', 'sp', 'fp/s8', 'ra']

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

# convert 32-bit int to byte string of length 4, from LSB to MSB
def int_to_byte_string(val):
    return struct.pack('<I', val)

def byte_string_to_int(val):
    return struct.unpack('<I', val)[0]

# invoke assembler to encode single instruction (in little endian MIPS32)
# returns a byte string of encoded instruction, from lowest byte to highest byte
# returns empty string on failure (in which case assembler messages are printed to stdout)
def single_line_asm(instr):
    tmp_asm = tempfile.NamedTemporaryFile(delete=False)
    tmp_obj = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)

    try:
        tmp_asm.write((instr + "\n").encode('utf-8'))
        tmp_asm.close()
        tmp_obj.close()
        tmp_binary.close()
        subprocess.check_output([
            CMD_ASSEMBLER, '-EL', '-mips32r2', tmp_asm.name, '-o', tmp_obj.name])
        subprocess.check_call([
            CMD_BINARY_COPY, '-j', '.text', '-O', 'binary', tmp_obj.name, tmp_binary.name])
        with open(tmp_binary.name, 'rb') as f:
            binary = f.read()
            if len(binary) > 4:
                binary = binary[:4]
            # assert len(binary) == 4, \
            #     "the result does not contains exactly one instruction, " + \
            #     "%d instruction found" % (len(binary) / 4)
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
    return ''

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
        '-m', 'mips:isa32r2', tmp_binary.name])
    # the last line should be something like:
    #    0:   21107f00        addu    v0,v1,ra
    result = raw_output.strip().split(b'\n')[-1].split(None, 2)[-1]

    os.remove(tmp_binary.name)

    return result.decode('utf-8')


def run_T(num):
    if num < 0: #Print all entries
        start = 0
        entries = 16
    else:
        start = num
        entries = 1
    print("Index | ASID |  VAddr  |  PAddr  | C | D | V | G")
    for i in range(start, start+entries):
        outp.write(b'T')
        outp.write(int_to_byte_string(i))
        entry_hi = byte_string_to_int(inp.read(4))
        entry_lo0 = byte_string_to_int(inp.read(4))
        entry_lo1 = byte_string_to_int(inp.read(4))
        if (entry_hi & entry_lo1 & entry_lo0) == 0xffffffff:
            print("Error: TLB support not enabled")
            break
        print("  %x      %02x   %05x_000 %05x_000  %x   %x   %x   %x" %
            (i, entry_hi&0xff, entry_hi>>12, entry_lo0>>6, entry_lo0>>3&7, entry_lo0>>2&1, entry_lo0>>1&1, entry_lo0&1))
        print("              %05x_000 %05x_000  %x   %x   %x   %x" %
            (                entry_hi>>12|1, entry_lo1>>6, entry_lo1>>3&7, entry_lo1>>2&1, entry_lo1>>1&1, entry_lo1&1))

def run_A(addr):
    print("one instruction per line, empty line to end.")
    while True:
        line = raw_input('[0x%04x] ' % addr)
        if line.strip() == '':
            return
        try:
            instr = int_to_byte_string(int(line, 16))
        except ValueError:
            instr = single_line_asm(line)
            if instr == '':
                continue
        outp.write(b'A')
        outp.write(int_to_byte_string(addr))
        outp.write(int_to_byte_string(4))
        outp.write(instr)
        addr = addr + 4


def run_R():
    outp.write(b'R')
    for i in range(1, 31):
        val_raw = inp.read(4)
        val = byte_string_to_int(val_raw)
        print('R{0}{1:7} = 0x{2:0>8x}'.format(
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
        val = byte_string_to_int(val_raw)
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
        print('0x%08x: %s' % (addr,single_line_disassmble(val_raw, addr)))
        counter = counter + 4
        addr = addr + 4

def run_G(addr):
    outp.write(b'G')
    outp.write(int_to_byte_string(addr))
    class TrapError(Exception):
        pass
    try:
        ret = inp.read(1)
        if ret == b'\x80':
            raise TrapError()
        if ret != b'\x06':
            print("start mark should be 0x06")
        time_start = timer()
        while True:
            ret = inp.read(1)
            if ret == b'\x07':
                break
            elif ret == b'\x80':
                raise TrapError()
            output_binary(ret)
        print('') #just a new line
        elapse = timer() - time_start
        print('elapsed time: %.3fs' % (elapse))
    except TrapError:
        print('supervisor reported an exception during execution')


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
                addr = raw_input('>>addr: 0x')
                run_A(int(addr, 16))
            elif cmd == 'R':
                run_R()
            elif cmd == 'D':
                addr = raw_input('>>addr: 0x')
                num = raw_input('>>num: ')
                run_D(int(addr, 16), int(num))
            elif cmd == 'U':
                addr = raw_input('>>addr: 0x')
                num = raw_input('>>num: ')
                run_U(int(addr, 16), int(num))
            elif cmd == 'G':
                addr = raw_input('>>addr: 0x')
                run_G(int(addr, 16))
            elif cmd == 'T':
                num = raw_input('>>num: ')
                run_T(int(num))
            else:
                print("Invalid command")
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
    #debug
    # welcome_message = False
    if welcome_message:
        output_binary(inp.read(33))
        print('')
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

    parser = argparse.ArgumentParser(description = 'Term for mips32 expirence.')
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

