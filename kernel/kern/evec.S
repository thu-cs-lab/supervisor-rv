#include <regdef.h>
#include <mipsregs.h> 

    .set noreorder
    .set noat
    .p2align 2
    .section .text.init
INITLOCATE:                         // 定位启动程序
    lui k0, %hi(START)
    ori k0, %lo(START)
    jr k0
    nop

    .section .text.ebase180
EHANDLERLOCATE:                     // 定位普通中断处理程序
    lui k0, %hi(EXCEPTIONHANDLER)
    ori k0, %lo(EXCEPTIONHANDLER)
    jr k0
    nop

    .section .text.ebase
TLBREFILL:                          // TLB快速重填
    mfc0 k1, CP0_CONTEXT
    lw k0, 0x0(k1)
    lw k1, 0x8(k1)
    mtc0 k0, CP0_ENTRYLO0
    mtc0 k1, CP0_ENTRYLO1
    nop
    tlbwr
    eret
    nop



    .set reorder
    .set at
