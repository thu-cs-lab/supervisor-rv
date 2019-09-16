set endian little
file kernel.elf
symbol-file kernel.elf
target remote 127.0.0.1:1234

b START
b FATAL
b EXCEPTION_HANDLER
continue
