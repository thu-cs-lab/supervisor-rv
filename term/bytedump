#!/bin/bash

# works like alias - quick way to inspect file byte-by-byte in hexadecimal
hexdump -v -e '/1 "0x%02x "' -e '/1 "%u\n"' "$@"
