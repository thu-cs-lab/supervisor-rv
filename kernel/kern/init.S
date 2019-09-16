#include <common.h>
#include <exception.h>
#include <serial.h>

    .section .bss
    .p2align 2
    .global TCBT                    // thread control block table
TCBT:
    .dword 0
    .dword 0
    .global current                 // current thread TCB address
current:
    .dword 0
#ifdef ENABLE_PAGING                // 声明页表
    .section .data
    .global PAGE_TABLE
    .global PTESTACK
    .p2align 12                     // 每个两页，页对齐
PAGE_TABLE:
    .rept 1024
    .long 0
    .endr
PAGE_TABLE_USER_CODE:
    .rept 1024
    .long 0
    .endr
PAGE_TABLE_KERNEL_CODE:
    .long 0x200000fb                // 0x80000000 -> 0x80000000 DAGUX-RV
    .rept 1023
    .long 0
    .endr
PAGE_TABLE_USER_STACK:
    .rept 1024
    .long 0
    .endr
#endif

    .section .rodata
monitor_version:
    .asciz "MONITOR for RISC-V - initialized."

    .text
    .p2align 2

    .global START
START:
    la s10, _sbss
    la s11, _ebss
bss_init:
    beq s10, s11, bss_init_done
    sw  zero, 0(s10)
    addi s10, s10, 4
    j   bss_init

bss_init_done:
#ifdef ENABLE_INT
    la s0, EXCEPTION_HANDLER        // 设定异常相应地址
    csrw mtvec, s0
#endif
    la sp, KERNEL_STACK_INIT         // 设置内核栈
    or s0, sp, zero
    la t0, USER_STACK_INIT          // 设置用户栈
    la t1, uregs_sp
    STORE t0, 0(t1)                 // 写入用户空间备份
    la t1, uregs_fp
    STORE t0, 0(t1)

    /* init serial */
    /* see ucore/kern/driver/console.c */
    lui t0, %hi(COM1)               // all COM_* shares the same %hi
    li t1, COM_FCR_CONFIG           // console.c:54
    sb t1, %lo(COM_FCR_OFFSET)(t0)  // :57
    li t1, COM_LCR_DLAB
    sb t1, %lo(COM_LCR_OFFSET)(t0)  // :57
    li t1, COM_DLL_VAL
    sb t1, %lo(COM_DLL_OFFSET)(t0)  // :58
    sb x0, %lo(COM_DLM_OFFSET)(t0)  // :59
    li t1, COM_LCR_CONFIG
    sb t1, %lo(COM_LCR_OFFSET)(t0)  // :62
    sb x0, %lo(COM_MCR_OFFSET)(t0)  // :65
    li t1, COM_IER_RDI
    sb t1, %lo(COM_IER_OFFSET)(t0)  // :67


//#ifdef ENABLE_INT
//    /* enable serial interrupt */
//    mfc0 t0, CP0_STATUS
//    ori t0, t0, STATUSF_IP4         // hardware interrupt source #2, irq #4
//    mtc0 t0, CP0_STATUS
//#endif

    ori t0, zero, TF_SIZE / 4       // 计数器
.LC0:
    addi t0, t0, -1                // 滚动计数器
    addi sp, sp, -4                // 移动栈指针
    STORE zero, 0(sp)                  // 初始化栈空间
    bne t0, zero, .LC0              // 初始化循环
    la t0, TCBT           // 载入TCBT地址
    STORE sp, 0(t0)                    // thread0(idle)的中断帧地址设置
/*
#ifdef ENABLE_INT
    mfc0 t1, CP0_STATUS             // 取STATUS
    mfc0 t2, CP0_CAUSE              // 取CAUSE
    ori t1, t1, ST0_IE              // 使能中断
    sw t2, TF_CAUSE(sp)             // 写中断帧CAUSE
    sw t1, TF_STATUS(sp)            // 写中断帧STATUS; idle线程打开串口硬件中断响应
    lui t3, %hi(IDLELOOP)
    addiu t3, %lo(IDLELOOP)       // 取得idle线程入口
    sw t3, TF_EPC(sp)               // 写中断帧EPC
#endif
*/
    or t6, sp, zero                 // t6保存idle中断帧位置

    ori t0, zero, TF_SIZE / XLEN     // 计数器
.LC1:
    addi t0, t0, -1                // 滚动计数器
    addi sp, sp, -XLEN              // 移动栈指针
    STORE zero, 0(sp)                  // 初始化栈空间
    bne t0, zero, .LC1              // 初始化循环
    la t0, TCBT                     // 载入TCBT地址
    STORE sp, XLEN(t0)                    // thread1(shell/user)的中断帧地址设置
    STORE sp, TF_sp(t6)                // 设置idle线程栈指针(调试用?)

    la t2, TCBT + XLEN
    LOAD t2, 0(t2)                    // 取得thread1的TCB地址

#ifdef ENABLE_INT
    csrw mscratch, t2              // 设置当前线程为thread1
#endif

    la t1, current   
    sw t2, 0(t1)

#ifdef ENABLE_PAGING
    la t0, PAGE_TABLE

    // 填写用户代码部分的页表
    la t1, PAGE_TABLE_USER_CODE
    li t3, 768
    li t2, 0
.LOOP_USER_CODE:
    li t4, 0x200400fb  // 0x80100000 DAGUX-RV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, 4
    addi t2, t2, 1
    bne t2, t3, .LOOP_USER_CODE

    la t1, PAGE_TABLE_USER_CODE
    srli t1, t1, 2
    ori t1, t1, 0xf1
    sw t1, 0(t0)

    la t1, PAGE_TABLE_KERNEL_CODE
    srli t1, t1, 2
    ori t1, t1, 0xf1
    li t2, 2048
    add t2, t0, t2
    sw t1, 0(t2)

    // 填写用户数据部分的页表
    la t1, PAGE_TABLE_USER_STACK
    addi t1, t1, 4*16
    li t3, 1024
    li t2, 16
.PAGE_TABLE_USER_STACK:
    li t4, 0x200fc0f7  // 0x803F0000 DAGU-WRV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, 4
    addi t2, t2, 1
    bne t2, t3, .PAGE_TABLE_USER_STACK

    la t1, PAGE_TABLE_USER_STACK
    srli t1, t1, 2
    ori t1, t1, 0xf1
    li t2, 2044
    add t2, t0, t2
    sw t1, 0(t2)

    srli t0, t0, 12
    li t1, SATP_SV32
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
#endif
/*
#ifdef ENABLE_INT
    mfc0 t0, CP0_STATUS             // 取得cp0的status Reg
    nop
    ori t0, t0, ST0_IE              // status Reg 的IE位置一
    xori t1, t0, STATUSF_IP4
    and t0, t0, t1                  // 主线程屏蔽串口硬件中断
    mtc0 t0, CP0_STATUS             // 启动完成，恢复中断机制
    nop
#endif
*/

    j WELCOME                       // 进入主线程

WELCOME:
    la s1, monitor_version          // 装入启动信息
    lb a0, 0(s1)
.Loop0:
    addi s1, s1, 0x1
    jal WRITE_SERIAL                // 调用串口写函数
    lb a0, 0(s1)
    bne a0, zero, .Loop0            // 打印循环至0结束符

    j SHELL                         // 开始交互

IDLELOOP:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    j IDLELOOP
    nop
