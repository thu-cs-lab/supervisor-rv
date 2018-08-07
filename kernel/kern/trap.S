#include <regdef.h>
#include <mipsregs.h>
#include <unistd.h>
#include <exception.h>

    .set noreorder
    .set noat
    .p2align 2
    .text
    .global EXCEPTIONHANDLER
    .global RETURNFRMTRAP

/* 本文件仅在启用异常处理时有用 */

#ifndef ENABLE_INT
FATAL:
EXCEPTIONHANDLER:
RETURNFRMTRAP:
WAKEUPSHELL:
SYSCALL:
    b   FATAL                       // 不支持异常时，这些入口都不应该进入，如果进入就永远等待，用于调试
    nop
#else

FATAL:                              
                                    // 严重问题，重启
    ori a0, zero, 0x80              // 错误信号
    jal WRITESERIAL                 // 发送
    nop
    lui v0, %hi(START)              // 重启地址
    addiu v0, %lo(START)
    jr v0
    nop


EXCEPTIONHANDLER:
    mfc0 k0, CP0_STATUS             // 处理一般中断
    nop
    xori k1, k0, ST0_IE
    and k0, k1, k0                  // IE置零
    mtc0 k0, CP0_STATUS             // 禁止嵌套中断
                                    // 一般由异常级别位自动禁止中断
    lui k0, %hi(current)
    lw k0, %lo(current)(k0)         // k0 = 取得current的中断帧存储地址

    sw sp, TF_sp(k0)                // 保存中断帧
    or sp, k0, zero
    sw AT, TF_AT(sp)
    sw v0, TF_v0(sp)
    sw v1, TF_v1(sp)
    sw a0, TF_a0(sp)
    sw a1, TF_a1(sp)
    sw a2, TF_a2(sp)
    sw a3, TF_a3(sp)
    sw t0, TF_t0(sp)
    sw t1, TF_t1(sp)
    sw t2, TF_t2(sp)
    sw t3, TF_t3(sp)
    sw t4, TF_t4(sp)
    sw t5, TF_t5(sp)
    sw t6, TF_t6(sp)
    sw t7, TF_t7(sp)
    sw t8, TF_t8(sp)
    sw t9, TF_t9(sp)
    sw s0, TF_s0(sp)
    sw s1, TF_s1(sp)
    sw s2, TF_s2(sp)
    sw s3, TF_s3(sp)
    sw s4, TF_s4(sp)
    sw s5, TF_s5(sp)
    sw s6, TF_s6(sp)
    sw s7, TF_s7(sp)
    sw gp, TF_gp(sp)
    sw fp, TF_fp(sp)
    sw ra, TF_ra(sp)
    mfc0 k0, CP0_STATUS
    mfc0 k1, CP0_CAUSE
    sw k0, TF_STATUS(sp)
    mfc0 k0, CP0_EPC
    sw k1, TF_CAUSE(sp)
    sw k0, TF_EPC(sp)


    mfc0 k0, CP0_CAUSE
    nop
    andi k1, k0, 0x00FF             // 截取CP0_CAUSE 的ExcCode
    srl k1, k1, 2
    ori k0, zero, EX_IRQ            // 硬件中断
    beq k1, k0, WAKEUPSHELL         // 让主线程控制
    nop
    ori k0, zero, EX_SYS            // 系统调用
    beq k1, k0, SYSCALL             // 内核处理
    nop

    // 中断处理扩展

    j FATAL                         // 无法处理的中断，出现严重错误
    nop


RETURNFRMTRAP:
    lw k0, TF_STATUS(sp)
    ori k0, k0, ST0_IE              // 使能中断。通常eret自动取消EXL位。
    xori k1, k0, ST0_ERL
    and k0, k0, k1                  // 清除错误位(防止eret出错)
    lw k1, TF_EPC(sp)
    mtc0 k0, CP0_STATUS
    mtc0 k1, CP0_EPC
    lw AT, TF_AT(sp)                // 从中断帧中恢复k0,k1以外寄存器，上下文
    lw v0, TF_v0(sp)
    lw v1, TF_v1(sp)
    lw a0, TF_a0(sp)
    lw a1, TF_a1(sp)
    lw a2, TF_a2(sp)
    lw a3, TF_a3(sp)
    lw t0, TF_t0(sp)
    lw t1, TF_t1(sp)
    lw t2, TF_t2(sp)
    lw t3, TF_t3(sp)
    lw t4, TF_t4(sp)
    lw t5, TF_t5(sp)
    lw t6, TF_t6(sp)
    lw t7, TF_t7(sp)
    lw t8, TF_t8(sp)
    lw t9, TF_t9(sp)
    lw s0, TF_s0(sp)
    lw s1, TF_s1(sp)
    lw s2, TF_s2(sp)
    lw s3, TF_s3(sp)
    lw s4, TF_s4(sp)
    lw s5, TF_s5(sp)
    lw s6, TF_s6(sp)
    lw s7, TF_s7(sp)
    lw gp, TF_gp(sp)
    lw fp, TF_fp(sp)
    lw ra, TF_ra(sp)

    lw sp, TF_sp(sp)                // 从中断帧中恢复
    eret
    nop



WAKEUPSHELL:
    lui t1, %hi(current)
    lw t1, %lo(current)(t1)         // 取得当前线程TCB地址
    lui t0, %hi(TCBT)
    lw t0, %lo(TCBT)(t0)            // 取得idle线程TCB地址
    nop
    bne t0, t1, RETURNFRMTRAP       // 若当前是shell/user线程无需调度
    nop
    j SCHEDULE                      // 进行调度使主线程获得控制权
    nop

SYSCALL:
    lw k0, TF_EPC(sp)               // SYSCALL需对EPC特别处理
    addiu k0, k0, 0x4               // EPC+4,退出中断后执行SYSCALL的下一条语句
    sw k0, TF_EPC(sp)
    ori t0, zero, SYS_wait          // 取得wait调用号
    beq v0, t0, .syscall_wait       // syscall wait
    nop
    ori t0, zero, SYS_putc          // 取得putc调用号
    beq v0, t0, .syscall_putc       // syscall putc
    nop

    // 系统调用扩展

    j RETURNFRMTRAP                 // 其他系统调用忽略
    nop

.syscall_wait:
    j SCHEDULE                      // 调度转交控制权
    nop

.syscall_putc:
    jal WRITESERIAL                 // 写串口采用忙等待，不产生嵌套中断
    nop
    j RETURNFRMTRAP
    nop
#endif



    .set reorder
    .set at
