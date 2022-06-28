#include <exception.h>

    .p2align 2
    .text
    .global EXCEPTION_HANDLER

#ifdef ENABLE_INT
EXCEPTION_HANDLER:
    // 交换 mscratch 和 sp ，保存上下文
    csrrw sp, mscratch, sp

    STORE ra, TF_ra(sp)
    // 读出原来的 sp
    csrrw ra, mscratch, sp
    STORE ra, TF_sp(sp)
    STORE gp, TF_gp(sp)
    STORE tp, TF_tp(sp)
    STORE t0, TF_t0(sp)
    STORE t1, TF_t1(sp)
    STORE t2, TF_t2(sp)
    STORE s0, TF_s0(sp)
    STORE s1, TF_s1(sp)
    STORE a0, TF_a0(sp)
    STORE a1, TF_a1(sp)
    STORE a2, TF_a2(sp)
    STORE a3, TF_a3(sp)
    STORE a4, TF_a4(sp)
    STORE a5, TF_a5(sp)
    STORE a6, TF_a6(sp)
    STORE a7, TF_a7(sp)
    STORE s2, TF_s2(sp)
    STORE s3, TF_s3(sp)
    STORE s4, TF_s4(sp)
    STORE s5, TF_s5(sp)
    STORE s6, TF_s6(sp)
    STORE s7, TF_s7(sp)
    STORE s8, TF_s8(sp)
    STORE s9, TF_s9(sp)
    STORE s10, TF_s10(sp)
    STORE s11, TF_s11(sp)
    STORE t3, TF_t3(sp)
    STORE t4, TF_t4(sp)
    STORE t5, TF_t5(sp)
    STORE t6, TF_t6(sp)
    csrr t0, mepc
    STORE t0, TF_epc(sp)

    // 根据 mcause 调用不同的异常处理例程
    csrr t0, mcause
    li t1, EX_INT_FLAG | EX_INT_MODE_MACHINE | EX_INT_TYPE_TIMER
    beq t1, t0, .HANDLE_TIMER
    li t1, EX_INT_FLAG
    and t1, t0, t1
    bne t1, zero, .HANDLE_INT
    li t1, EX_ECALL_U
    beq t1, t0, .HANDLE_ECALL
    li t1, EX_BREAK
    beq t1, t0, .HANDLE_BREAK

    j FATAL

.HANDLE_ECALL:
    LOAD t0, TF_epc(sp)
    addi t0, t0, 0x4
    STORE t0, TF_epc(sp)

    LOAD t0, TF_s0(sp)
    li t1, SYS_putc
    beq t0, t1, .HANDLE_ECALL_PUTC

    // 忽略其他系统调用
    j CONTEXT_SWITCH

.HANDLE_ECALL_PUTC:
    LOAD a0, TF_a0(sp)
    jal WRITE_SERIAL
    j CONTEXT_SWITCH

.HANDLE_BREAK:
    j USERRET_MACHINE

.HANDLE_INT:
    // 暂未实现
    j FATAL

.HANDLE_TIMER:
    // 读取 mstatus.MPP
    csrr t0, mstatus
    li t1, MSTATUS_MPP_MASK
    and t0, t0, t1
    // 来自 M 态的中断，直接返回
    bne t0, zero, CONTEXT_SWITCH

    // 处理用户程序超时
    j USERRET_TIMEOUT

CONTEXT_SWITCH:
    LOAD t0, TF_epc(sp)
    csrw mepc, t0

    LOAD ra, TF_ra(sp)
    LOAD gp, TF_gp(sp)
    LOAD tp, TF_tp(sp)
    LOAD t0, TF_t0(sp)
    LOAD t1, TF_t1(sp)
    LOAD t2, TF_t2(sp)
    LOAD s0, TF_s0(sp)
    LOAD s1, TF_s1(sp)
    LOAD a0, TF_a0(sp)
    LOAD a1, TF_a1(sp)
    LOAD a2, TF_a2(sp)
    LOAD a3, TF_a3(sp)
    LOAD a4, TF_a4(sp)
    LOAD a5, TF_a5(sp)
    LOAD a6, TF_a6(sp)
    LOAD a7, TF_a7(sp)
    LOAD s2, TF_s2(sp)
    LOAD s3, TF_s3(sp)
    LOAD s4, TF_s4(sp)
    LOAD s5, TF_s5(sp)
    LOAD s6, TF_s6(sp)
    LOAD s7, TF_s7(sp)
    LOAD s8, TF_s8(sp)
    LOAD s9, TF_s9(sp)
    LOAD s10, TF_s10(sp)
    LOAD s11, TF_s11(sp)
    LOAD t3, TF_t3(sp)
    LOAD t4, TF_t4(sp)
    LOAD t5, TF_t5(sp)
    LOAD t6, TF_t6(sp)
    
    csrw mscratch, sp
    LOAD sp, TF_sp(sp)

    mret

    // 用于仅支持 VECTORED 的 CPU
    .balign 256
    .global VECTORED_EXCEPTION_HANDLER
VECTORED_EXCEPTION_HANDLER:
    .rept 64
    j EXCEPTION_HANDLER
    .endr

#else
HALT:
EXCEPTION_HANDLER:
    j HALT
#endif

FATAL:
    // 严重问题，重启
    // 错误信号
    li a0, SIG_FATAL
    // 发送
    jal WRITE_SERIAL

#ifdef ENABLE_INT
    csrrs a0, mepc, zero
    jal WRITE_SERIAL_XLEN
    csrrs a0, mcause, zero
    jal WRITE_SERIAL_XLEN
    csrrs a0, mtval, zero
    jal WRITE_SERIAL_XLEN
#else
    mv a0, zero
    jal WRITE_SERIAL_XLEN
    jal WRITE_SERIAL_XLEN
    jal WRITE_SERIAL_XLEN
#endif

    // 重启地址
    la a0, START
    jr a0
