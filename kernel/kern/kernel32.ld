ENTRY(START)
OUTPUT(kernel.elf)
OUTPUT_ARCH("riscv:rv32")
OUTPUT_FORMAT("elf32-littleriscv")

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
    PROVIDE(uregs_sp = uregs + (2 - 1) * 4);
    PROVIDE(uregs_fp = uregs + (8 - 1) * 4);
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
