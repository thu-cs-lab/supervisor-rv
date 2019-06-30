#include <regdef.h>
#include <mipsregs.h> 

// You don't have to care about this file if you don't enable interrupt and TLB.

    .set noreorder
    .set noat
    .p2align 2
    .section .text.init
    .global INITLOCATE
INITLOCATE:                         // 定位启动程序
    lui k0, %hi(START)
    addiu k0, %lo(START)
    jr k0
    nop

    .section .text.ebase180
EHANDLERLOCATE:                     // 定位普通中断处理程序
    lui k0, %hi(EXCEPTIONHANDLER)
    addiu k0, %lo(EXCEPTIONHANDLER)
    jr k0
    nop

    .section .text.ebase
TLBREFILL:                          // TLB快速重填
#ifdef ENABLE_TLB
    mfc0 k1, CP0_CONTEXT
    lw k0, 0x0(k1)
    lw k1, 0x8(k1)
    mtc0 k0, CP0_ENTRYLO0
    mtc0 k1, CP0_ENTRYLO1
    nop
    tlbwr
    eret
#endif
    nop


    .set reorder
    .set at
