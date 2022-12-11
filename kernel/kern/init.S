#include <common.h>
#include <exception.h>
#include <serial.h>

    .section .bss
    .p2align 2

    // TCBT = Thread Control Block Table
    .global TCBT
TCBT:
    .dword 0
    .dword 0

    // 当前线程 TCB 地址
    .global current
current:
    .dword 0

    // 页表
#ifdef ENABLE_PAGING
    .section .data
    .global PAGE_TABLE
    // 一个页 4096 字节 = 2^12
    .p2align 12
    // 预留空间，在之后的代码里进行初始化
PAGE_TABLE:
    .rept 1024
    .long 0
    .endr

    // RV64 的 Sv39 下页表比 Sv32 多了一级
#ifdef RV64
PAGE_TABLE_2:
    .rept 1024
    .long 0
    .endr
#endif

    // 用户代码的页表
PAGE_TABLE_USER_CODE:
    .rept 1024
    .long 0
    .endr

#ifdef RV64
PAGE_TABLE_USER_CODE_2:
    .rept 1024
    .long 0
    .endr
#endif

    // 内核代码的页表
PAGE_TABLE_KERNEL_CODE:
#ifdef RV32
    .long 0x200000fb                // 0x80000000 -> 0x80000000 DAGUX-RV
    .long 0x200004fb                // 0x80001000 -> 0x80001000 DAGUX-RV
    .rept 254
    .long 0
    .endr
    .long 0x200400fb                // 0x80100000 -> 0x80100000 DAGUX-RV
    .rept 767
    .long 0
    .endr
#else
    .dword 0x200000fb                // 0x80000000 -> 0x80000000 DAGUX-RV
    .rept 511
    .dword 0
    .endr
#endif

    // 用户栈的页表
PAGE_TABLE_USER_STACK:
    .rept 1024
    .long 0
    .endr
#ifdef RV64
PAGE_TABLE_USER_STACK_2:
    .rept 1024
    .long 0
    .endr
#endif
PAGE_TABLE_USER_STACK_3:
    .rept 1024
    .long 0
    .endr
#endif

    .section .rodata
    // 启动时输出的信息
monitor_version:
    .asciz "MONITOR for RISC-V - initialized."
    .p2align 2
    .word 0

    .text
    .p2align 2

    .global START
START:
    // 清空 BSS
    // _sbss 和 _ebss 在 ld script 中定义
    la s10, _sbss
    la s11, _ebss
bss_init:
    beq s10, s11, bss_init_done
    sw  zero, 0(s10)
    addi s10, s10, 4
    j   bss_init
bss_init_done:

#ifdef ENABLE_INT
    // 设置异常处理地址寄存器 mtvec
    la s0, EXCEPTION_HANDLER
    csrw mtvec, s0

    // 判断是否设置成功（mtvec 是 WARL）
    csrr t0, mtvec
    beq t0, s0, mtvec_done

    // 不成功，尝试 MODE=VECTORED
    la s0, VECTORED_EXCEPTION_HANDLER
    ori s0, s0, 1
    csrw mtvec, s0
mtvec_done:

    // 打开时钟中断
    li t0, MIE_MTIE
    csrw mie, t0
#endif

    // 设置内核栈
    la sp, KERNEL_STACK_INIT

    // 设置用户栈
    li t0, USER_STACK_INIT
    // 设置用户态程序的 sp(x2) 和 fp(x8) 寄存器
    // uregs_sp 和 uregs_fp 在 ld script 中定义
    la t1, uregs_sp
    STORE t0, 0(t1)
    la t1, uregs_fp
    STORE t0, 0(t1)

#ifdef ENABLE_UART16550
    // 配置串口，见 serial.h 中的叙述进行配置
    li t0, COM1
    // 打开 FIFO，并且清空 FIFO
    li t1, COM_FCR_CONFIG 
    sb t1, %lo(COM_FCR_OFFSET)(t0)
    // 打开 DLAB
    li t1, COM_LCR_DLAB
    sb t1, %lo(COM_LCR_OFFSET)(t0)
    // 设置 Baudrate
    li t1, COM_DLL_VAL
    sb t1, %lo(COM_DLL_OFFSET)(t0)
    sb x0, %lo(COM_DLM_OFFSET)(t0)
    // 关闭 DLAB，打开 WLEN8
    li t1, COM_LCR_CONFIG
    sb t1, %lo(COM_LCR_OFFSET)(t0)
    sb x0, %lo(COM_MCR_OFFSET)(t0)
    // 打开串口中断
    li t1, COM_IER_RDI
    sb t1, %lo(COM_IER_OFFSET)(t0)
#endif

    // 从内核栈顶清空并留出 TF_SIZE 大小的空间用于存储中断帧
    li t0, TF_SIZE
.LC0:
    addi t0, t0, -XLEN
    addi sp, sp, -XLEN
    STORE zero, 0(sp)
    bne t0, zero, .LC0

    // 保存中断帧地址到 TCBT
    la t0, TCBT
    STORE sp, 0(t0)

    // t6 保存 idle 中断帧位置
    mv t6, sp

    // 初始化栈空间
    li t0, TF_SIZE
.LC1:
    addi t0, t0, -XLEN
    addi sp, sp, -XLEN
    STORE zero, 0(sp)
    bne t0, zero, .LC1

    // 载入TCBT地址
    la t0, TCBT
    // thread1(shell/user) 的中断帧地址设置
    STORE sp, XLEN(t0)
    // 设置 idle 线程栈指针(调试用?)
    STORE sp, TF_sp(t6)

    // 取得 thread1 的 TCB 地址
    la t2, TCBT + XLEN
    LOAD t2, 0(t2)

#ifdef ENABLE_INT
    // 设置当前线程为 thread1
    csrw mscratch, t2
#endif

    la t1, current
    sw t2, 0(t1)

#ifdef ENABLE_PAGING
#ifdef RV32
    // Sv32 是两级页表，PAGE_TABLE 为一级页表
    la t0, PAGE_TABLE
#else
    // Sv39 是三级页表，PAGE_TABLE 为一级页表，PAGE_TABLE_2为二级页表
    la t0, PAGE_TABLE_2
    la t1, PAGE_TABLE
    srli t0, t0, 2
    ori t0, t0, 0xf1
    sd t0, 0(t1)

    la t0, PAGE_TABLE_2
#endif

    // 填写用户代码的页表
    // 需要映射 0x00000000-0x002FF000
    // Sv32 时都在一个页中
    la t1, PAGE_TABLE_USER_CODE
#ifdef RV32
    li t3, 768
#else
    li t3, 512
#endif
    li t2, 0
.LOOP_USER_CODE:
    li t4, 0x200400fb  // 0x80100000 DAGUX-RV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, XLEN
    addi t2, t2, 1
    bne t2, t3, .LOOP_USER_CODE

    la t1, PAGE_TABLE_USER_CODE
    srli t1, t1, 2
    ori t1, t1, 0xf1
    sw t1, 0(t0)

    // Sv39 时需要第二个页
    // 映射 0x00200000-0x002FF000
#ifdef RV64
    la t1, PAGE_TABLE_USER_CODE_2
    li t3, 256
    li t2, 0
.LOOP_USER_CODE_2:
    li t4, 0x200c00fb  // 0x80300000 DAGUX-RV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, XLEN
    addi t2, t2, 1
    bne t2, t3, .LOOP_USER_CODE_2

    la t1, PAGE_TABLE_USER_CODE_2
    srli t1, t1, 2
    ori t1, t1, 0xf1
    sw t1, 8(t0)
#endif

    // 内核代码段映射
    // 需要映射 0x80000000 和 0x80100000
    la t0, PAGE_TABLE
    la t1, PAGE_TABLE_KERNEL_CODE
    srli t1, t1, 2
    ori t1, t1, 0xf1
#ifdef RV32
    li t2, 512*4
#else
    li t2, 2*8
#endif
    add t2, t0, t2
    sw t1, 0(t2)

    // 填写用户数据的页表
    // 需要映射 0x7FC10000-0x7FFFF000
    // Sv32 情况下在一个二级页表内
#ifdef RV32
    la t1, PAGE_TABLE_USER_STACK
    addi t1, t1, 4*16
    li t3, 1024
    li t2, 16
.LOOP_USER_STACK:
    li t4, 0x200fc0f7  // 0x803F0000 DAGU-WRV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, 4
    addi t2, t2, 1
    bne t2, t3, .LOOP_USER_STACK

    la t1, PAGE_TABLE_USER_STACK
    srli t1, t1, 2
    ori t1, t1, 0xf1
    li t2, 2044
    add t2, t0, t2
    sw t1, 0(t2)
#else 
    // Sv39 时有单独的二级页表和两个三级页表
    // 三级页表 0x7fc10000 - 0x7fdff000
    la t1, PAGE_TABLE_USER_STACK_2
    addi t1, t1, 16*8
    li t3, 512
    li t2, 16
.LOOP_USER_STACK_2:
    li t4, 0x200fc0f7  // 0x803F0000 DAGU-WRV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, 8
    addi t2, t2, 1
    bne t2, t3, .LOOP_USER_STACK_2

    // 三级页表 0x7ff00000 - 0x7ffff000
    la t1, PAGE_TABLE_USER_STACK_3
    li t3, 512
    li t2, 0
.LOOP_USER_STACK_3:
    li t4, 0x2017c0f7  // 0x805F0000 DAGU-WRV
    slli t5, t2, 10
    add t4, t4, t5
    sw t4, 0(t1)
    addi t1, t1, 8
    addi t2, t2, 1
    bne t2, t3, .LOOP_USER_STACK_3

    la t0, PAGE_TABLE_USER_STACK
    la t1, PAGE_TABLE_USER_STACK_2
    srli t1, t1, 2
    ori t1, t1, 0xf1
    li t2, 4080
    add t2, t0, t2
    sw t1, 0(t2)
    la t1, PAGE_TABLE_USER_STACK_3
    srli t1, t1, 2
    ori t1, t1, 0xf1
    li t2, 4088
    add t2, t0, t2
    sw t1, 0(t2)

    la t0, PAGE_TABLE
    la t1, PAGE_TABLE_USER_STACK
    srli t1, t1, 2
    ori t1, t1, 0xf1
    li t2, 8
    add t2, t0, t2
    sw t1, 0(t2)
#endif

    // 让页表生效
    la t0, PAGE_TABLE
    srli t0, t0, 12
#ifdef RV32
    li t1, SATP_SV32
#else
    li t1, SATP_SV39
#endif
    or t0, t0, t1
    csrw satp, t0
    sfence.vma
#endif

#ifdef ENABLE_INT
    // 设置 PMP Config
#ifdef RV32
    // 0x00000000-0xffffffff RWX
    li t0, 0b00001111
    csrw pmpcfg0, t0
    li t0, 0xffffffff
    csrw pmpaddr0, t0
#else
    // 0x0000000000000000-0xffffffffffffffff RWX
    li t0, 0b00001111
    csrw pmpcfg0, t0
    li t0, 0xffffffffffffffff
    csrw pmpaddr0, t0
#endif
#endif

    // 进入主线程
    j WELCOME

WELCOME:
    // 装入启动信息并打印
    la a0, monitor_version
    jal WRITE_SERIAL_STRING

    // 开始交互
    j SHELL
