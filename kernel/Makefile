RM	:= rm -f
ifeq ($(OS),Windows_NT)
# Windows Host
GCCPREFIX	:= mips-mti-elf-
else
#GCCPREFIX	:= mipsel-linux-gnu-
GCCPREFIX	:= mips-sde-elf-
endif
QEMU := qemu-system-mipsel
LD	:= $(GCCPREFIX)ld
CC	:= $(GCCPREFIX)gcc
MODULE	:= init
OBJDIR	:= obj
INCLUDE	:= include
SRCDIR	:= kern
LDSCRIPT	:= kern/kernel.ld
SRC	:= $(foreach sdir, $(SRCDIR), $(wildcard $(sdir)/*.S))
OBJ	:= $(patsubst $(SRCDIR)/%.S, $(OBJDIR)/%.o, $(SRC))
TARGET	:= kernel.elf
ASFLAG	:= -D__ASSEMBLY__ -EL -g -mips32

override ON_FPGA ?= n

ifeq ($(ON_FPGA), y)
	MACH_DEF = -DMACH_FPGA
else
   	MACH_DEF = -DMACH_QEMU
endif
ASFLAG += $(MACH_DEF)

override EN_INT ?= n
ifeq ($(EN_INT), y)
	ASFLAG += -DENABLE_INT
	EN_TLB = n
endif

override EN_TLB ?= n
ifeq ($(EN_TLB), y)
	ASFLAG += -DENABLE_TLB
endif


.PHONY: all clean show-utest

all: checkdirs $(TARGET) kernel.bin


$(TARGET): $(OBJ) $(LDSCRIPT)
	$(LD) $(OBJ) -T$(LDSCRIPT)

$(OBJ): $(OBJDIR)/%.o : $(SRCDIR)/%.S
	$(CC) -o $@ $< -c -I$(INCLUDE) $(ASFLAG)


checkdirs: $(OBJDIR)

$(OBJDIR):
	test -d $@ || mkdir $@

kernel.bin: $(TARGET)
	@$(GCCPREFIX)objcopy -O binary -v $< kernel.bin
	split -a 1 -b 4m kernel.bin kernel.bin.

show-utest: $(TARGET)
	@$(GCCPREFIX)objdump -D $< | grep "^[0-9a-f]\{8\} <UTEST_" | grep -n --color=auto 'UTEST_'

.PHONY: commits-num show-utest sim clean

sim: $(TARGET)
	$(QEMU) -M mipssim -m 8M -kernel $< -vnc :0 -serial tcp::6666,server -s

commits-num:
	@git log --pretty=format:"commit %H" | grep -c 'commit'

clean:
	-$(RM) -r $(OBJDIR)
