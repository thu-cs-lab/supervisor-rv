#include <regdef.h>
#include <mipsregs.h> 

    .set noreorder
    .set noat
    .p2align 2
    .text
    .global SCHEDULE

/* 本文件仅在启用异常处理时有用 */

SCHEDULE:                           
#ifdef ENABLE_INT                             
    lui t1, %hi(TCBT)               // 调度程序。此时处于中断处理中。
    addiu t1, %lo(TCBT)           // 获得TCBT地址
    lw t2, 0(t1)                    // 获得idle的TCB地址
    lui t4, %hi(current)
    lw t3, %lo(current)(t4)         // 获得current线程的TCB地址
    nop
    bne t2, t3, .LC0                // 判断current是哪个线程
    nop
    lw t2, 4(t1)                    // 切换为shell
    nop
.LC0:
    or sp, t2, zero                 // 调换中断帧指针
    sw sp, %lo(current)(t4)         // 设置current为调度线程
    j RETURNFRMTRAP                 // 退出中断，加载调度线程中断帧，完成线程切换
    nop
#else
    b SCHEDULE                      // Infinity loop for debug
    nop
#endif

    .set reorder
    .set at
