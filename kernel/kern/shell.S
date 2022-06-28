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
     *  用户空间寄存器：x1-x31依次保存在 0x807F0000 连续 124 字节
     *  用户程序入口临时存储：0x807F0000
     */
SHELL:
    // 读操作符
    jal READ_SERIAL

    // 根据操作符进行不同的操作
    li t0, 'R'
    beq a0, t0, .OP_R
    li t0, 'D'
    beq a0, t0, .OP_D
    li t0, 'A'
    beq a0, t0, .OP_A
    li t0, 'G'
    beq a0, t0, .OP_G
    li t0, 'T'
    beq a0, t0, .OP_T

    // 错误的操作符，输出 XLEN，用于区分 RV32 和 RV64
    li a0, XLEN
    // 把 XLEN 写给 term
    jal WRITE_SERIAL
    j .DONE

.OP_T:
    // 操作 - 打印页表
    // 保存寄存器
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
    // 读取内存并写入串口
    lb a0, 0(s1)
    addi s2, s2, -1
    jal WRITE_SERIAL
    addi s1, s1, 0x1
    bne s2, zero, .LC0

    // 恢复寄存器
    LOAD s1, 0x0(sp)
    LOAD s2, XLEN(sp)
    addi sp, sp, 3*XLEN

    j .DONE

.OP_R:
    // 操作 - 打印用户空间寄存器
    // 保存 s1, s2
    addi sp, sp, -2*XLEN
    STORE s1, 0(sp)
    STORE s2, XLEN(sp)

    // 打印 31 个寄存器
    la s1, uregs
    li s2, 31*XLEN
.LC1:
    // 读取内存并写入串口
    lb a0, 0(s1)
    addi s2, s2, -1
    jal WRITE_SERIAL
    addi s1, s1, 0x1
    bne s2, zero, .LC1

    // 恢复s1,s2
    LOAD s1, 0(sp)
    LOAD s2, XLEN(sp)
    addi sp, sp, 2*XLEN
    j .DONE

.OP_D:
    // 操作 - 打印内存 num 个字节
    // 保存 s1, s2
    addi sp, sp, -2*XLEN
    STORE s1, 0(sp)
    STORE s2, XLEN(sp)

    // 获得 addr
    jal READ_SERIAL_XLEN
    or s1, a0, zero
    // 获得 num
    jal READ_SERIAL_XLEN
    or s2, a0, zero

.LC2:
    // 读取内存并写入串口
    lb a0, 0(s1)
    addi s2, s2, -1
    jal WRITE_SERIAL
    addi s1, s1, 0x1
    bne s2, zero, .LC2

    // 恢复 s1, s2
    LOAD s1, 0(sp)                    
    LOAD s2, XLEN(sp)
    addi sp, sp, 2*XLEN
    j .DONE

.OP_A:
    // 操作 - 写入内存 num 字节，num 为 4 的倍数
    // 保存 s1, s2
    addi sp, sp, -2*XLEN
    STORE s1, 0(sp)
    STORE s2, 4(sp)

    // 获得 addr
    jal READ_SERIAL_XLEN
    or s1, a0, zero

    // 获得 num
    jal READ_SERIAL_XLEN
    or s2, a0, zero

    // num 除 4，获得字数
    srl s2, s2, 2

.LC3:
    // 每次写入一字
    // 从串口读入一字
    jal READ_SERIAL_WORD
    // 写内存一字
    sw a0, 0(s1)
    addi s2, s2, -1
    addi s1, s1, 4
    bne s2, zero, .LC3

#ifdef ENABLE_FENCEI
    // 有 Cache 时让写入的代码生效
    fence.i
#endif

    // 恢复 s1, s2
    LOAD s1, 0(sp)
    LOAD s2, XLEN(sp)
    addi sp, sp, 2*XLEN
    j .DONE

.OP_G:
    // 操作 - 跳转到用户程序执行
    // 获取 addr
    jal READ_SERIAL_XLEN
    // 保存到 s10
    mv s10, a0

    // 写开始计时信号
    // 告诉终端用户程序开始运行
    li a0, SIG_TIMERSET
    jal WRITE_SERIAL

#ifdef ENABLE_INT
    // 用户程序入口写入EPC
    csrw mepc, s10

    // 设置 MPP=0，对应 U-mode
    li a0, MSTATUS_MPP_MASK
    csrc mstatus, a0

    // 设置时钟中断，用于检测运行超时
#ifdef RV64
    li t0, CLINT_MTIME
    ld t1, 0(t0)        // 读取 mtime
    li t3, 10000000
    add t3, t1, t3      // + 10000000
    li t0, CLINT_MTIMECMP
    sd t3, 0(t0)        // 写入 mtimecmp
#else
    li t0, CLINT_MTIME
    lw t1, 0(t0)        // 读取 mtime 低 32 位
    lw t2, 4(t0)        // 读取 mtime 高 32 位
    li t3, 10000000
    add t3, t1, t3      // 低 32 位 + 10000000
    sltu t1, t3, t1     // 生成进位，若进位 t1 = 1
    add t2, t2, t1      // 高 32 位进位
    li t0, CLINT_MTIMECMP
    sw t2, 4(t0)        // 写入 mtimecmp 高 32 位
    sw t3, 0(t0)        // 写入 mtimecmp 低 32 位
#endif

#endif

    // 定位用户空间寄存器备份地址
    la ra, uregs
    // 保存栈指针
    STORE sp, TF_ksp(ra)

    // x1 就是 ra
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
    // s10 用来保存用户程序地址
    // LOAD s10, TF_s10(ra)
    LOAD s11, TF_s11(ra)
    LOAD t3, TF_t3(ra)
    LOAD t4, TF_t4(ra)
    LOAD t5, TF_t5(ra)
    LOAD t6, TF_t6(ra)

.ENTER_UESR:
#ifdef ENABLE_INT
    // ra 写入返回地址
    la ra, .USERRET_USER
    // 进入用户程序
    mret
#else
    // ra 写入返回地址
    la ra, .USERRET2
    jr s10
#endif

#ifdef ENABLE_INT
.USERRET_USER:
    ebreak

    .global USERRET_TIMEOUT
USERRET_TIMEOUT:
    // 发送超时信号
    // 告诉终端用户程序结束运行
    li a0, SIG_TIMEOUT
    jal WRITE_SERIAL
    j 0f

    .global USERRET_MACHINE
USERRET_MACHINE:
    // 发送停止计时信号
    // 告诉终端用户程序结束运行
    li a0, SIG_TIMETOKEN
    jal WRITE_SERIAL

    // 复制寄存器数据
0:
    la s1, uregs
    li s2, TF_SIZE
.LC4:
    lw a0, 0(sp)
    sw a0, 0(s1)
    addi s2, s2, -4
    addi s1, s1, 0x4
    addi sp, sp, 0x4
    bne s2, zero, .LC4

    // 重新获得当前监控程序栈顶指针
    la s1, uregs
    LOAD sp, TF_ksp(s1)

    j .DONE
#endif

.USERRET2:
    // 定位用户空间寄存器备份地址
    la ra, uregs

    // 不能先恢复 ra
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

    // 重新获得当前监控程序栈顶指针
    LOAD sp, TF_ksp(ra)
    mv a0, ra
    la ra, .USERRET2
    STORE ra, TF_ra(a0)

    // 发送停止计时信号
    li a0, SIG_TIMETOKEN
    // 告诉终端用户程序结束运行
    jal WRITE_SERIAL

    j .DONE

.DONE:
    // 交互循环
    j SHELL
