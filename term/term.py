#!/usr/bin/python
# -*- encoding=utf-8 -*-

import sys
import re
import socket
import string
import os
import tempfile
import subprocess
import serial

CCPREFIX = "mips-sde-elf-"

# convert 32-bit int to byte string of length 4, from LSB to MSB
def int_to_byte_string(val):
    return ''.join([chr((val >> (8 * k)) & 0xFF) for k in xrange(4)])

def byte_string_to_int(val):
    return int(''.join(reversed(map(lambda c: '%02x' % ord(c), val))), 16)

# invoke assembler to encode single instruction (in little endian MIPS32)
# returns a byte string of encoded instruction, from lowest byte to highest byte
# returns empty string on failure (in which case assembler messages are printed to stdout)
def single_line_asm(instr):
    tmp_asm = tempfile.NamedTemporaryFile(delete=False)
    tmp_obj = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)

    try:
        tmp_asm.write(instr + "\n")
        tmp_asm.close()
        tmp_obj.close()
        tmp_binary.close()
        subprocess.check_output([
            CCPREFIX + 'as', '-EL', '-mips32r2', tmp_asm.name, '-o', tmp_obj.name])
        subprocess.check_call([
            CCPREFIX + 'objcopy', '-O', 'binary', tmp_obj.name, tmp_binary.name])
        with open(tmp_binary.name, 'r') as f:
            binary = f.read()
            if len(binary) == 8 and binary[4:] == '\0' * 4:
                binary = binary[:4]
            assert len(binary) == 4, \
                "the result does not contains exactly one instruction, " + \
                "%d instruction found" % (len(binary) / 4)
            return binary
    except subprocess.CalledProcessError as e:
        print(e.output)
        return ''
    except AssertionError as e:
        print(e.message)
        return ''
    finally:
        os.remove(tmp_asm.name)
        # object file won't exist if assembler fails
        if os.path.exists(tmp_obj.name):
            os.remove(tmp_obj.name)
        os.remove(tmp_binary.name)

# invoke objdump to disassemble single instruction
# accepts encoded instruction (exactly 4 bytes), from least significant byte
# objdump does not seem to report errors so this function does not guarantee
# to produce meaningful result
def single_line_disassmble(binary_instr):
    assert(len(binary_instr) == 4)
    tmp_binary = tempfile.NamedTemporaryFile(delete=False)
    tmp_binary.write(binary_instr)
    tmp_binary.close()

    raw_output = subprocess.check_output([
        CCPREFIX + 'objdump', '-D', '-b', 'binary',
        '-m', 'mips:isa32r2', tmp_binary.name])
    # the last line should be something like:
    #    0:   21107f00        addu    v0,v1,ra
    result = raw_output.strip().split('\n')[-1].split(None, 2)[-1]

    os.remove(tmp_binary.name)

    return result


def run_A(addr):
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
        outp.write('A')
        outp.write(int_to_byte_string(addr))
        outp.write(int_to_byte_string(4))
        outp.write(instr)
        addr = addr + 4


def run_R():
    outp.write('R')
    for i in xrange(1, 31):
        val_raw = inp.read(4)
        val = byte_string_to_int(val_raw)
        print('R%s = 0x%08x' % (
            str(i).ljust(2),
            val,
        ))


def run_D(addr, num):
    outp.write('D')
    outp.write(int_to_byte_string(addr))
    outp.write(int_to_byte_string(num))
    counter = 0
    while counter < num:
    # for i in xrange(1, num + 1):
        val_raw = inp.read(4)
        counter = counter + 4
        val = byte_string_to_int(val_raw)
        print('0x%08x: ' % addr),
        print('0x%08x  ' % (val))
        addr = addr + 4


def run_U(addr, num):
    if num % 4 != 0:
        print("num % 4 should be zero")
        return
    outp.write('D')
    outp.write(int_to_byte_string(addr))
    outp.write(int_to_byte_string(num))
    counter = 0
    while counter < num:
        val_raw = inp.read(4)
        print('0x%08x: ' % addr),
        print(single_line_disassmble(val_raw))
        counter = counter + 4
        addr = addr + 4

def run_G(addr):
    outp.write('G')
    outp.write(int_to_byte_string(addr))



def MainLoop():
    while True:
        cmd = raw_input('>> ')
        if cmd == 'A':
            addr = raw_input('>>addr: ')
            run_A(string.atoi(addr, 16))
        if cmd == 'R':
            run_R()
        if cmd == 'D':
            addr = raw_input('>>addr: ')
            num = raw_input('>>num: ')
            run_D(string.atoi(addr, 16), string.atoi(num))
        if cmd == 'U':
            addr = raw_input('>>addr: ')
            num = raw_input('>>num: ')
            run_U(string.atoi(addr, 16), string.atoi(num))
        if cmd == 'G':
            addr = raw_input('>>addr: ')
            run_G(string.atoi(addr, 16))


def Initialize(pipe_path='/tmp/acm'):
    # "in" and "out" are from QEMU's perspective
    global outp, inp
    # outp = open(pipe_path + '.in', 'r+', 0)
    # inp = open(pipe_path + '.out', 'r+', 0)
    tty = serial.Serial(pipe_path, 115200, rtscts=True, dsrdtr=True)
    inp = tty
    outp = tty


def Main(welcome_message=True):
    if welcome_message:
        inp.read(33)
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

    def flush(sel): # dummy
        pass

    def read(self, MSGLEN):
        chunks = []
        bytes_recd = 0
        while bytes_recd < MSGLEN:
            chunk = self.sock.recv(min(MSGLEN - bytes_recd, 2048))
            if chunk == '':
                raise RuntimeError("socket connection broken")
            chunks.append(chunk)
            bytes_recd = bytes_recd + len(chunk)
        return ''.join(chunks)

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
    print "connecting to %s:%s..." % (host, port) ,
    ser.connect(host, int(port))
    print "connected"

    global outp, inp
    outp = ser
    inp = ser
    return True

if __name__ == "__main__":
    assert len(sys.argv) == 2

    if not InitializeTCP(sys.argv[1]):
        Initialize(sys.argv[1])
    Main()

