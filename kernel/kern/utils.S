#include <common.h>
#include <serial.h>

    .p2align 2
    .text
    .global WRITE_SERIAL
    .global WRITE_SERIAL_WORD
    .global WRITE_SERIAL_XLEN
    .global WRITE_SERIAL_STRING
    .global READ_SERIAL
    .global READ_SERIAL_WORD
    .global READ_SERIAL_XLEN

WRITE_SERIAL:                       // 写串口：将a0的低八位写入串口
    li t0, COM1
.TESTW:
    lb t1, %lo(COM_LSR_OFFSET)(t0)  // 查看串口状态
    andi t1, t1, COM_LSR_THRE       // 截取写状态位
    bne t1, zero, .WSERIAL          // 状态位非零可写进入写
    j .TESTW                        // 检测验证，忙等待
.WSERIAL:
    sb a0, %lo(COM_THR_OFFSET)(t0)  // 写入寄存器a0中的值
    jr ra

WRITE_SERIAL_WORD:
    addi sp, sp, -2*XLEN
    STORE ra, 0x0(sp)
    STORE s0, XLEN(sp)

    mv s0, a0

    andi a0, a0, 0xFF
    jal WRITE_SERIAL
    srli a0, s0, 8

    andi a0, a0, 0xFF
    jal WRITE_SERIAL
    srli a0, s0, 16

    andi a0, a0, 0xFF
    jal WRITE_SERIAL
    srli a0, s0, 24

    andi a0, a0, 0xFF
    jal WRITE_SERIAL
    mv a0, s0

    LOAD ra, 0x0(sp)
    LOAD s0, XLEN(sp)
    addi sp, sp, 2*XLEN

    jr ra

WRITE_SERIAL_XLEN:
    addi sp, sp, -XLEN
    STORE ra, 0x0(sp)

    jal WRITE_SERIAL_WORD
#ifdef RV64
    srli a0, a0, 32
    jal WRITE_SERIAL_WORD
#endif
    LOAD ra, 0x0(sp)
    addi sp, sp, XLEN

    jr ra

WRITE_SERIAL_STRING:                // 写字符串：将 a0 地址开始处的字符串写入串口
    mv a1, a0
    mv a2, ra
    lb a0, 0(a1)
0:  jal WRITE_SERIAL                // 调用串口写函数
    addi a1, a1, 0x1
    lb a0, 0(a1)
    bne a0, zero, 0b                // 打印循环至 0 结束符
    jr a2

READ_SERIAL:                        // 读串口：将读到的数据写入a0低八位
    li t0, COM1
.TESTR:
    lb t1, %lo(COM_LSR_OFFSET)(t0)
    andi t1, t1, COM_LSR_DR         // 截取读状态位
    bne t1, zero, .RSERIAL          // 状态位非零可读进入读
    j .TESTR                        // 检测验证
.RSERIAL:
    lb a0, %lo(COM_RBR_OFFSET)(t0)
    jr ra

READ_SERIAL_WORD:
    addi sp, sp, -5*XLEN             // 保存ra,s0-3
    STORE ra, 0x0(sp)
    STORE s0, XLEN(sp)
    STORE s1, 2*XLEN(sp)
    STORE s2, 3*XLEN(sp)
    STORE s3, 4*XLEN(sp)

    jal READ_SERIAL                 // 读串口获得八个比特
    or s0, zero, a0                 // 结果存入s0
    jal READ_SERIAL                 // 读串口获得八个比特
    or s1, zero, a0                 // 结果存入s1
    jal READ_SERIAL                 // 读串口获得八个比特
    or s2, zero, a0                 // 结果存入s2
    jal READ_SERIAL                 // 读串口获得八个比特
    or s3, zero, a0                 // 结果存入s3

    andi s0, s0, 0x00FF             // 截取低八位
    andi s1, s1, 0x00FF
    andi s2, s2, 0x00FF
    andi s3, s3, 0x00FF
    or a0, zero, s3                 // 存高八位
    sll a0, a0, 8                   // 左移
    or a0, a0, s2                   // 存八位
    sll a0, a0, 8                   // 左移
    or a0, a0, s1                   // 存八位
    sll a0, a0, 8                   // 左移
    or a0, a0, s0                   // 存低八位

    LOAD ra, 0x0(sp)                // 恢复ra,s0
    LOAD s0, XLEN(sp)
    LOAD s1, 2*XLEN(sp)
    LOAD s2, 3*XLEN(sp)
    LOAD s3, 4*XLEN(sp)
    addi sp, sp, 5*XLEN
    jr ra

READ_SERIAL_XLEN:
    addi sp, sp, -2*XLEN             // 保存ra,s0-3
    STORE ra, 0x0(sp)
    STORE s0, XLEN(sp)

    jal READ_SERIAL_WORD
    mv s0, a0
#ifdef RV64
    jal READ_SERIAL_WORD
    sll a0, a0, 32
    add s0, s0, a0
#endif
    mv a0, s0
    LOAD ra, 0x0(sp)                // 恢复ra,s0
    LOAD s0, XLEN(sp)
    addi sp, sp, 2*XLEN
    jr ra
