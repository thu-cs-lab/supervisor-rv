ENTRY(START)
OUTPUT(kernel.elf)
OUTPUT_ARCH("riscv:rv64")
OUTPUT_FORMAT("elf64-littleriscv")

PROVIDE(KERNEL_STACK_INIT = 0x80800000);
SECTIONS
{
    . = 0x807F0000;
    .bss : {
        _sbss = .;         /* define a global symbol at bss start */
        *(.bss.uregs)
        *(.bss)
        . = ALIGN(4);
        _ebss = .;         /* define a global symbol at bss end */
    }
    PROVIDE(uregs_sp = uregs + (2 - 1) * 8);
    PROVIDE(uregs_fp = uregs + (8 - 1) * 8);
    . = 0x80000000;
    .text : {
        KEEP (*(.text.init))
        *(.text)
        . = ALIGN(0x1000); /* "fixed" utest address */
        *(.text.utest)
    }
    .rodata : {
        *(.rodata)
    }
    .data : {
        *(.data)
    }
}
