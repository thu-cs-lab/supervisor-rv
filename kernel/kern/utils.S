#include <common.h>
#include <serial.h>

    .p2align 2
    .text
    .global WRITESERIAL
    .global READSERIAL
    .global READSERIALWORD

WRITESERIAL:                        // 写串口：将a0的低八位写入串口
    lui t0, %hi(COM1)
.TESTW:
    lb t1, %lo(COM_LSR_OFFSET)(t0)  // 查看串口状态
    andi t1, t1, COM_LSR_THRE       // 截取写状态位
    bne t1, zero, .WSERIAL          // 状态位非零可写进入写
    j .TESTW                        // 检测验证，忙等待
.WSERIAL:
    sb a0, %lo(COM_THR_OFFSET)(t0)  // 写入寄存器a0中的值
    jr ra

READSERIAL:                         // 读串口：将读到的数据写入v0低八位
    lui t0, %hi(COM1)
.TESTR:
    lb t1, %lo(COM_LSR_OFFSET)(t0)
    andi t1, t1, COM_LSR_DR         // 截取读状态位
    bne t1, zero, .RSERIAL          // 状态位非零可读进入读
/*
#ifdef ENABLE_INT
    ori v0, zero, SYS_wait          // 取得wait调用号
    syscall SYSCALL_BASE            // 睡眠等待
#endif
*/
    j .TESTR                        // 检测验证
.RSERIAL:
    lb t5, %lo(COM_RBR_OFFSET)(t0)
    jr ra

READSERIALWORD:
    addi sp, sp, -5*XLEN             // 保存ra,s0-3
    STORE ra, 0x0(sp)
    STORE s0, XLEN(sp)
    STORE s1, 2*XLEN(sp)
    STORE s2, 3*XLEN(sp)
    STORE s3, 4*XLEN(sp)

    jal READSERIAL                  // 读串口获得八个比特
    or s0, zero, t5                 // 结果存入s0
    jal READSERIAL                  // 读串口获得八个比特
    or s1, zero, t5                 // 结果存入s1
    jal READSERIAL                  // 读串口获得八个比特
    or s2, zero, t5                 // 结果存入s2
    jal READSERIAL                  // 读串口获得八个比特
    or s3, zero, t5                 // 结果存入s3

    andi s0, s0, 0x00FF             // 截取低八位
    andi s1, s1, 0x00FF
    andi s2, s2, 0x00FF
    andi s3, s3, 0x00FF
    or t5, zero, s3                 // 存高八位
    sll t5, t5, 8                   // 左移
    or t5, t5, s2                   // 存八位
    sll t5, t5, 8                   // 左移
    or t5, t5, s1                   // 存八位
    sll t5, t5, 8                   // 左移
    or t5, t5, s0                   // 存低八位

    mv t4, t5                       // t4 保存最终结果

#ifdef RV64
    jal READSERIAL                  // 读串口获得八个比特
    or s0, zero, t5                 // 结果存入s0
    jal READSERIAL                  // 读串口获得八个比特
    or s1, zero, t5                 // 结果存入s1
    jal READSERIAL                  // 读串口获得八个比特
    or s2, zero, t5                 // 结果存入s2
    jal READSERIAL                  // 读串口获得八个比特
    or s3, zero, t5                 // 结果存入s3

    andi s0, s0, 0x00FF             // 截取低八位
    andi s1, s1, 0x00FF
    andi s2, s2, 0x00FF
    andi s3, s3, 0x00FF
    or t6, zero, s3                 // 存高八位
    sll t6, t6, 8                   // 左移
    or t6, t6, s2                   // 存八位
    sll t6, t6, 8                   // 左移
    or t6, t6, s1                   // 存八位
    sll t6, t6, 8                   // 左移
    or t6, t6, s0                   // 存低八位

    sll t6, t6, 32                  // 合并高位到低位
    or t4, t4, t6
#endif

    mv t5, t4                       // 返回值在 t5

    LOAD ra, 0x0(sp)                // 恢复ra,s0
    LOAD s0, XLEN(sp)
    LOAD s1, 2*XLEN(sp)
    LOAD s2, 3*XLEN(sp)
    LOAD s3, 4*XLEN(sp)
    addi sp, sp, 5*XLEN
    jr ra
