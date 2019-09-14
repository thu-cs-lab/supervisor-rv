BITS := 32
RM	:= rm -f
# linux 下编译器的地址，可能根据不同的操作系统有所修改
GCCPREFIX := /PATH/bin/riscv32-unknown-elf-
LD	:= $(GCCPREFIX)ld
CC	:= $(GCCPREFIX)gcc
AS  := $(GCCPREFIX)as
OBJDUMP := $(GCCPREFIX)objdump
MODULE	:= init
OBJDIR	:= obj
INCLUDE	:= include
SRCDIR	:= kern
SRC	:= $(foreach sdir, $(SRCDIR), $(wildcard $(sdir)/*.S))
OBJ	:= $(patsubst $(SRCDIR)/%.S, $(OBJDIR)/%.o, $(SRC))
TARGET	:= kernel.elf
ASFLAGS	:= -D__ASSEMBLY__ -g
ifeq ($(BITS), 32)
	ASFLAGS += -march=rv32i -mabi=ilp32 -DRV32
	QEMU := qemu-system-riscv32
	LDSCRIPT	:= kern/kernel32.ld
else
	ASFLAGS += -march=rv64i -mabi=lp64 -DRV64
	QEMU := qemu-system-riscv64
	LDSCRIPT	:= kern/kernel64.ld
endif

override ON_FPGA ?= n

ifeq ($(ON_FPGA), y)
	MACH_DEF = -DMACH_FPGA
else
   	MACH_DEF = -DMACH_QEMU
endif
ASFLAGS += $(MACH_DEF)

.PHONY: all clean show-utest sim debug

all: checkdirs $(TARGET) kernel.bin kernel.asm

$(TARGET): $(OBJ) $(LDSCRIPT)
	$(LD) $(OBJ) -T$(LDSCRIPT)

checkdirs: $(OBJDIR)

$(OBJDIR):
	test -d $@ || mkdir $@

$(OBJ): $(OBJDIR)/%.o : $(SRCDIR)/%.S
	$(CC) -o $@ $< -c -I$(INCLUDE) $(ASFLAGS)

kernel.bin: $(TARGET)
	@$(GCCPREFIX)objcopy -j .text -j .text.* -O binary -v $< $@

kernel.asm: $(TARGET)
	@$(GCCPREFIX)objdump -d -S $< > $@

show-utest: $(TARGET)
	@$(GCCPREFIX)objdump -D $< | grep "^[0-9a-f]\{8\} <UTEST_" | grep -n --color=auto 'UTEST_'

sim: checkdirs $(TARGET)
	$(QEMU) -M virt -m 32M -kernel kernel.elf -nographic -monitor none -serial tcp::6666,server -s

debug: checkdirs $(TARGET)
	$(QEMU) -M virt -m 32M -kernel kernel.elf -nographic -monitor none -serial tcp::6666,server -S -s

clean:
	-$(RM) -r $(OBJDIR)
