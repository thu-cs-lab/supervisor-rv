ENTRY(START)
OUTPUT(kernel.elf)
OUTPUT_ARCH("riscv:rv64")
OUTPUT_FORMAT("elf64-littleriscv")

PROVIDE(KERNEL_STACK_INIT = 0x80800000);
PROVIDE(USER_STACK_INIT = 0x807F0000);
SECTIONS
{
    . = 0x807F0000;
    .bss : {
        _sbss = .;         /* define a global symbol at bss start */
        *(.bss.uregs)
        *(.bss)
        *(.bss.ptes)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end */
    }
    .rodata : {
        *(.rodata)
    }
    PROVIDE(uregs_sp = uregs + (2 - 1) * 8);
    PROVIDE(uregs_fp = uregs + (8 - 1) * 8);
    . = 0x80000000;
    .text.init : {
        KEEP (*(.text.init))
    }
    . = 0x80001000;
    .text.ebase : {
        KEEP (*(.text.ebase))
    }
    . = 0x80001180;
    .text.ebase180 : {
        KEEP (*(.text.ebase180))
    }
    .text : {
        *(.text)
        . = ALIGN(0x1000); /* "fixed" utest address */
        *(.text.utest)
    }
}
