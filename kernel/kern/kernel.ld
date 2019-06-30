ENTRY(INITLOCATE)
OUTPUT("kernel.elf")
OUTPUT_ARCH("mips:isa32r2")
OUTPUT_FORMAT("elf32-tradlittlemips")

PROVIDE(SerialData = 0xBFD003F8);
PROVIDE(SerialStat = 0xBFD003FC);

/* Qemu serial constants */
PROVIDE(COM1 = 0xBFD003F8);
PROVIDE(COM_LSR = COM1 + 5);
PROVIDE(COM_LSR_DATA = 0x01);
PROVIDE(COM_FCR = COM1 + 2);
PROVIDE(COM_LCR = COM1 + 3);
PROVIDE(COM_LCR_DLAB = 0x80);
PROVIDE(COM_DLL = COM1 + 0);
PROVIDE(COM_DLL_VAL = 115200 / 9600);
PROVIDE(COM_DLM = COM1 + 1);
PROVIDE(COM_LCR_WLEN8 = 0x03);
PROVIDE(COM_LCR_CONFIG = COM_LCR_WLEN8 & ~(COM_LCR_DLAB));
PROVIDE(COM_MCR = COM1 + 4);
PROVIDE(COM_IER = COM1 + 1);
PROVIDE(COM_IER_RDI = 0x01);

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
    PROVIDE(uregs_sp = uregs + (29 - 1) * 4);
    PROVIDE(uregs_fp = uregs + (30 - 1) * 4);
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
