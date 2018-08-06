#include <regdef.h>
#include <mipsregs.h> 
#include <shell.h>

    .set noreorder
    .set noat

    .section .bss.uregs
    .p2align 2
    .global uregs
uregs:
    .rept 32                        // 第31个为用户程序入口地址临时保存
    .long 0
    .endr

    .text
    .p2align 2
    .global SHELL

    /*
     *  SHELL: 监控程序交互模块
     * 
     *  用户空间寄存器：$1-$30依次保存在0x807F0000连续120字节
     *  用户程序入口临时存储：0x807F0078
     */
SHELL:
    jal READSERIAL                  // 读操作符
    nop

    ori t0, zero, SH_OP_R
    beq v0, t0, .OP_R
    nop
    ori t0, zero, SH_OP_D
    beq v0, t0, .OP_D
    nop
    ori t0, zero, SH_OP_A
    beq v0, t0, .OP_A
    nop
    ori t0, zero, SH_OP_G
    beq v0, t0, .OP_G
    nop
    ori t0, zero, SH_OP_T
    beq v0, t0, .OP_T
    nop
    j .DONE                         // 错误的操作符，默认忽略
    nop

.OP_T:                              // 操作 - 打印TLB项
    jal READSERIALWORD              // 取num(index)
    nop
    addiu sp, sp, -0x18
    sw s0, 0x0(sp)
    sw s1, 0x4(sp)

#ifdef ENABLE_TLB
    mtc0 v0, CP0_INDEX              // 写入index
    mfc0 s1, CP0_ENTRYHI            // 保存ASID
    nop
    tlbr
    nop
    mfc0 s0, CP0_ENTRYHI            // 取ENTRYHI打印
    sw s0, 0xC(sp)
    mfc0 s0, CP0_ENTRYLO0           // 取ENTRYLO0
    sw s0, 0x10(sp)
    mfc0 s0, CP0_ENTRYLO1           // 取ENTRYLO1
    sw s0, 0x14(sp)
    mtc0 s1, CP0_ENTRYHI            // 写回ASID
    nop
#else
    addiu s0, zero, -1              // 不支持TLB则返回全1
    sw s0, 0xC(sp)
    sw s0, 0x10(sp)
    sw s0, 0x14(sp)
#endif

    ori s1, zero, 0xC               // 打印12字节
    addiu s0, sp, 0xC               // ENTRYHI位置
.LC3:
    lb a0, 0x0(s0)                  // 读一字节
    addiu s1, s1, -1                // 滚动计数器
    jal WRITESERIAL                 // 打印
    nop
    addiu s0, s0, 1                 // 移动打印指针
    bne s1, zero, .LC3              // 打印循环
    nop

    lw s0, 0x0(sp)
    lw s1, 0x4(sp)
    addiu sp, sp, 0x18

    j .DONE
    nop

.OP_R:                              // 操作 - 打印用户空间寄存器
    addiu sp, sp, -8                // 保存s0,s1
    sw s0, 0(sp)
    sw s1, 4(sp)

    lui s0, %hi(uregs)
    ori s1, zero, 120               // 计数器，打印120字节
.LC0:
    lb a0, %lo(uregs)(s0)           // 读取字节
    addiu s1, s1, -1                // 滚动计数器
    jal WRITESERIAL                 // 写入串口
    nop
    addiu s0, s0, 0x1               // 移动打印指针
    bne s1, zero, .LC0              // 打印循环
    nop

    lw s0, 0(sp)                    // 恢复s0,s1
    lw s1, 4(sp)
    addiu sp, sp, 8
    j .DONE
    nop

.OP_D:                              // 操作 - 打印内存num字节
    addiu sp, sp, -8                // 保存s0,s1
    sw s0, 0(sp)
    sw s1, 4(sp)

    jal READSERIALWORD
    nop
    or s0, v0, zero                 // 获得addr
    jal READSERIALWORD
    nop
    or s1, v0, zero                 // 获得num

.LC1:
    lb a0, 0(s0)                    // 读取字节
    addiu s1, s1, -1                // 滚动计数器
    jal WRITESERIAL                 // 写入串口
    nop
    addiu s0, s0, 0x1               // 移动打印指针
    bne s1, zero, .LC1              // 打印循环
    nop

    lw s0, 0(sp)                    // 恢复s0,s1
    lw s1, 4(sp)
    addiu sp, sp, 8
    j .DONE
    nop

.OP_A:                              // 操作 - 写入内存num字节，num为4的倍数
    addiu sp, sp, -8                // 保存s0,s1
    sw s0, 0(sp)
    sw s1, 4(sp)

    jal READSERIALWORD
    nop
    or s0, v0, zero                 // 获得addr
    jal READSERIALWORD
    nop
    or s1, v0, zero                 // 获得num
    srl s1, s1, 2                   // num除4，获得字数
.LC2:                               // 每次写入一字
    jal READSERIALWORD              // 从串口读入一字
    nop
    sw v0, 0(s0)                    // 写内存一字
    addiu s1, s1, -1                // 滚动计数器
    addiu s0, s0, 4                 // 移动写指针
    bne s1, zero, .LC2              // 写循环
    nop

    lw s0, 0(sp)                    // 恢复s0,s1
    lw s1, 4(sp)
    addiu sp, sp, 8
    j .DONE
    nop

.OP_G:
    jal READSERIALWORD              // 获取addr
    nop

    ori a0, zero, TIMERSET          // 写TIMERSET(0x06)信号
    jal WRITESERIAL                 // 告诉终端用户程序开始运行
    nop

#ifdef ENABLE_INT
    mtc0 v0, CP0_EPC                // 用户程序入口写入EPC
#else
    or k0, v0, zero
#endif

    lui ra, %hi(uregs)              // 定位用户空间寄存器备份地址
    addiu ra, %lo(uregs)
    sw v0, PUTREG(31)(ra)           // 保存用户程序入口
    sw sp, PUTREG(32)(ra)           // 保存栈指针

    lw $1,  PUTREG(1)(ra)           // 装入$1-$30
    lw $2,  PUTREG(2)(ra)
    lw $3,  PUTREG(3)(ra)
    lw $4,  PUTREG(4)(ra)
    lw $5,  PUTREG(5)(ra)
    lw $6,  PUTREG(6)(ra)
    lw $7,  PUTREG(7)(ra)
    lw $8,  PUTREG(8)(ra)
    lw $9,  PUTREG(9)(ra)
    lw $10, PUTREG(10)(ra)
    lw $11, PUTREG(11)(ra)
    lw $12, PUTREG(12)(ra)
    lw $13, PUTREG(13)(ra)
    lw $14, PUTREG(14)(ra)
    lw $15, PUTREG(15)(ra)
    lw $16, PUTREG(16)(ra)
    lw $17, PUTREG(17)(ra)
    lw $18, PUTREG(18)(ra)
    lw $19, PUTREG(19)(ra)
    lw $20, PUTREG(20)(ra)
    lw $21, PUTREG(21)(ra)
    lw $22, PUTREG(22)(ra)
    lw $23, PUTREG(23)(ra)
    lw $24, PUTREG(24)(ra)
    lw $25, PUTREG(25)(ra)
    //lw $26, PUTREG(26)(ra)
    //lw $27, PUTREG(27)(ra)
    lw $28, PUTREG(28)(ra)
    lw $29, PUTREG(29)(ra)
    lw $30, PUTREG(30)(ra)

    lui ra, %hi(.USERRET2)          // ra写入返回地址
    addiu ra, %lo(.USERRET2)
    nop
#ifdef ENABLE_INT
    eret                            // 进入用户程序
#else
    jr k0
    nop
#endif
.USERRET2:
    nop

    lui ra, %hi(uregs)              // 定位用户空间寄存器备份地址
    addiu ra, %lo(uregs)

    sw $1,  PUTREG(1)(ra)           // 备份$1-$30
    sw $2,  PUTREG(2)(ra)
    sw $3,  PUTREG(3)(ra)
    sw $4,  PUTREG(4)(ra)
    sw $5,  PUTREG(5)(ra)
    sw $6,  PUTREG(6)(ra)
    sw $7,  PUTREG(7)(ra)
    sw $8,  PUTREG(8)(ra)
    sw $9,  PUTREG(9)(ra)
    sw $10, PUTREG(10)(ra)
    sw $11, PUTREG(11)(ra)
    sw $12, PUTREG(12)(ra)
    sw $13, PUTREG(13)(ra)
    sw $14, PUTREG(14)(ra)
    sw $15, PUTREG(15)(ra)
    sw $16, PUTREG(16)(ra)
    sw $17, PUTREG(17)(ra)
    sw $18, PUTREG(18)(ra)
    sw $19, PUTREG(19)(ra)
    sw $20, PUTREG(20)(ra)
    sw $21, PUTREG(21)(ra)
    sw $22, PUTREG(22)(ra)
    sw $23, PUTREG(23)(ra)
    sw $24, PUTREG(24)(ra)
    sw $25, PUTREG(25)(ra)
    //sw $26, PUTREG(26)(ra)
    //sw $27, PUTREG(27)(ra)
    sw $28, PUTREG(28)(ra)
    sw $29, PUTREG(29)(ra)
    sw $30, PUTREG(30)(ra)

    lw sp, PUTREG(32)(ra)
    ori a0, zero, TIMETOKEN         // 发送TIMETOKEN(0x07)信号
    jal WRITESERIAL                 // 告诉终端用户程序结束运行
    nop

    j .DONE
    nop

.DONE:
    j SHELL                         // 交互循环
    nop




    .set reorder
    .set at
