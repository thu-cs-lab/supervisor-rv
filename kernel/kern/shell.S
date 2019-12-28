#include <exception.h>

    .section .bss.uregs
    .p2align 2
    .global uregs
uregs:
    .rept 32                        // 第1个为用户程序入口地址临时保存
    .dword 0
    .endr

    .text
    .p2align 2
    .global SHELL

    /*
     *  SHELL: 监控程序交互模块
     * 
     *  用户空间寄存器：x1-x31依次保存在0x807F0000连续124字节
     *  用户程序入口临时存储：0x807F0000
     */
SHELL:
    jal READ_SERIAL                  // 读操作符

    ori t0, zero, 'R'
    beq a0, t0, .OP_R
    ori t0, zero, 'D'
    beq a0, t0, .OP_D
    ori t0, zero, 'A'
    beq a0, t0, .OP_A
    ori t0, zero, 'G'
    beq a0, t0, .OP_G
    ori t0, zero, 'T'
    beq a0, t0, .OP_T

    li a0, XLEN                     // 错误的操作符，输出 XLEN，用于区分 RV32 和 RV64
    jal WRITE_SERIAL                 // 把 XLEN 写给 term
    j .DONE                         

.OP_T:                              // 操作 - 打印页表
    addi sp, sp, -3*XLEN
    STORE s1, 0(sp)
    STORE s2, XLEN(sp)

#ifdef ENABLE_PAGING
    csrr s1, satp
    slli s1, s1, 12
#else
    li s1, -1
#endif
    STORE s1, 2*XLEN(sp)
    addi s1, sp, 2*XLEN
    li s2, XLEN
.LC0:
    lb a0, 0(s1)           // 读取字节
    addi s2, s2, -1                 // 滚动计数器
    jal WRITE_SERIAL                 // 写入串口
    addi s1, s1, 0x1                // 移动打印指针
    bne s2, zero, .LC0              // 打印循环

    LOAD s1, 0x0(sp)
    LOAD s2, XLEN(sp)
    addi sp, sp, 3*XLEN

    j .DONE

.OP_R:                              // 操作 - 打印用户空间寄存器
    addi sp, sp, -2*XLEN                 // 保存s1,s2
    STORE s1, 0(sp)
    STORE s2, XLEN(sp)

    la s1, uregs
    ori s2, zero, 31*XLEN               // 计数器，打印 31 个寄存器
.LC1:
    lb a0, 0(s1)           // 读取字节
    addi s2, s2, -1                 // 滚动计数器
    jal WRITE_SERIAL                 // 写入串口
    addi s1, s1, 0x1                // 移动打印指针
    bne s2, zero, .LC1              // 打印循环

    LOAD s1, 0(sp)                    // 恢复s1,s2
    LOAD s2, XLEN(sp)
    addi sp, sp, 2*XLEN
    j .DONE

.OP_D:                              // 操作 - 打印内存num字节
    addi sp, sp, -2*XLEN                 // 保存s1,s2
    STORE s1, 0(sp)
    STORE s2, XLEN(sp)

    jal READ_SERIAL_XLEN
    or s1, a0, zero                 // 获得addr
    jal READ_SERIAL_XLEN
    or s2, a0, zero                 // 获得num

.LC2:
    lb a0, 0(s1)                    // 读取字节
    addi s2, s2, -1                 // 滚动计数器
    jal WRITE_SERIAL                 // 写入串口
    addi s1, s1, 0x1                // 移动打印指针
    bne s2, zero, .LC2              // 打印循环

    LOAD s1, 0(sp)                    // 恢复s1,s2
    LOAD s2, XLEN(sp)
    addi sp, sp, 2*XLEN
    j .DONE

.OP_A:                              // 操作 - 写入内存num字节，num为4的倍数
    addi sp, sp, -2*XLEN                 // 保存s1,s2
    STORE s1, 0(sp)
    STORE s2, 4(sp)

    jal READ_SERIAL_XLEN
    or s1, a0, zero                 // 获得addr
    jal READ_SERIAL_XLEN
    or s2, a0, zero                 // 获得num
    srl s2, s2, 2                   // num除4，获得字数
.LC3:                               // 每次写入一字
    jal READ_SERIAL_WORD              // 从串口读入一字
    sw a0, 0(s1)                    // 写内存一字
    addi s2, s2, -1                 // 滚动计数器
    addi s1, s1, 4                  // 移动写指针
    bne s2, zero, .LC3              // 写循环

#ifdef ENABLE_FENCEI
    fence.i                         // 有 Cache 时让写入的代码生效
#endif

    LOAD s1, 0(sp)                    // 恢复s1,s2
    LOAD s2, XLEN(sp)
    addi sp, sp, 2*XLEN
    j .DONE

.OP_G:
    jal READ_SERIAL_XLEN            // 获取addr
    mv s10, a0                      // 保存到 s10

    ori a0, zero, TIMERSET          // 写TIMERSET(0x06)信号
    jal WRITE_SERIAL                 // 告诉终端用户程序开始运行

#ifdef ENABLE_INT
    csrw mepc, s10                // 用户程序入口写入EPC
    li a0, MSTATUS_MPP_MASK
    csrc mstatus, a0     // 设置 MPP=0 ，对应 U-mode
#endif

    la ra, uregs              // 定位用户空间寄存器备份地址
    STORE sp, TF_ksp(ra)           // 保存栈指针

    // LOAD x1,  TF_ra(ra)
    LOAD sp, TF_sp(ra)
    LOAD gp, TF_gp(ra)
    LOAD tp, TF_tp(ra)
    LOAD t0, TF_t0(ra)
    LOAD t1, TF_t1(ra)
    LOAD t2, TF_t2(ra)
    LOAD s0, TF_s0(ra)
    LOAD s1, TF_s1(ra)
    LOAD a0, TF_a0(ra)
    LOAD a1, TF_a1(ra)
    LOAD a2, TF_a2(ra)
    LOAD a3, TF_a3(ra)
    LOAD a4, TF_a4(ra)
    LOAD a5, TF_a5(ra)
    LOAD a6, TF_a6(ra)
    LOAD a7, TF_a7(ra)
    LOAD s2, TF_s2(ra)
    LOAD s3, TF_s3(ra)
    LOAD s4, TF_s4(ra)
    LOAD s5, TF_s5(ra)
    LOAD s6, TF_s6(ra)
    LOAD s7, TF_s7(ra)
    LOAD s8, TF_s8(ra)
    LOAD s9, TF_s9(ra)
    // LOAD s10, TF_s10(ra)
    LOAD s11, TF_s11(ra)
    LOAD t3, TF_t3(ra)
    LOAD t4, TF_t4(ra)
    LOAD t5, TF_t5(ra)
    LOAD t6, TF_t6(ra)

.ENTER_UESR:
#ifdef ENABLE_INT
    la ra, .USERRET_USER                // ra写入返回地址
    mret                                // 进入用户程序
#else
    la ra, .USERRET2                    // ra写入返回地址
    jr s10
#endif

#ifdef ENABLE_INT
.USERRET_USER:
    ebreak

    .global USERRET_MACHINE
USERRET_MACHINE:
    la s1, uregs
    li s2, TF_SIZE                  // 计数器
.LC4:
    lw a0, 0(sp)
    sw a0, 0(s1)
    addi s2, s2, -4                 // 滚动计数器
    addi s1, s1, 0x4
    addi sp, sp, 0x4
    bne s2, zero, .LC4

    la s1, uregs
    LOAD sp, TF_ksp(s1)             // 重新获得当前监控程序栈顶指针

    ori a0, zero, TIMETOKEN         // 发送TIMETOKEN(0x07)信号
    jal WRITE_SERIAL                // 告诉终端用户程序结束运行

    j .DONE
#endif

.USERRET2:
    la ra, uregs              // 定位用户空间寄存器备份地址

    //STORE ra, TF_ra(ra)
    STORE sp, TF_sp(ra)
    STORE gp, TF_gp(ra)
    STORE tp, TF_tp(ra)
    STORE t0, TF_t0(ra)
    STORE t1, TF_t1(ra)
    STORE t2, TF_t2(ra)
    STORE s0, TF_s0(ra)
    STORE s1, TF_s1(ra)
    STORE a0, TF_a0(ra)
    STORE a1, TF_a1(ra)
    STORE a2, TF_a2(ra)
    STORE a3, TF_a3(ra)
    STORE a4, TF_a4(ra)
    STORE a5, TF_a5(ra)
    STORE a6, TF_a6(ra)
    STORE a7, TF_a7(ra)
    STORE s2, TF_s2(ra)
    STORE s3, TF_s3(ra)
    STORE s4, TF_s4(ra)
    STORE s5, TF_s5(ra)
    STORE s6, TF_s6(ra)
    STORE s7, TF_s7(ra)
    STORE s8, TF_s8(ra)
    STORE s9, TF_s9(ra)
    STORE s10, TF_s10(ra)
    STORE s11, TF_s11(ra)
    STORE t3, TF_t3(ra)
    STORE t4, TF_t4(ra)
    STORE t5, TF_t5(ra)
    STORE t6, TF_t6(ra)

    LOAD sp, TF_ksp(ra)             // 重新获得当前监控程序栈顶指针
    mv a0, ra
    la ra, .USERRET2
    STORE ra, TF_ra(a0)

    ori a0, zero, TIMETOKEN         // 发送TIMETOKEN(0x07)信号
    jal WRITE_SERIAL                // 告诉终端用户程序结束运行

    j .DONE

.DONE:
    j SHELL                         // 交互循环
