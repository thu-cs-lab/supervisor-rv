//#include <regdef.h>
//#include <mipsregs.h>
//#include <unistd.h>

//    .set noreorder
//    .set noat
    .p2align 2
    .text
    .global WRITESERIAL
    .global READSERIAL
    .global READSERIALWORD

WRITESERIAL:                        // 写串口：将a0的低八位写入串口
#ifdef MACH_FPGA
    lui t1, %hi(SerialStat)
.TESTW:
    lb t0, %lo(SerialStat)(t1)      // 查看串口状态
    andi t0, t0, 0x0001             // 截取写状态位
    bne t0, zero, .WSERIAL          // 状态位非零可写进入写
    nop
    j .TESTW                        // 检测验证，忙等待
    nop
.WSERIAL:
    lui t1, %hi(SerialData)
    sb a0, %lo(SerialData)(t1)      // 写入寄存器a0中的值
    jr ra
    nop
#else
    la t1, COM_LSR_THRE
.TESTW:
    lb t0, COM_LSR
    and t0, t0, t1
    bne t0, zero, .WSERIAL
    nop
    j .TESTW
    nop
.WSERIAL:
    lui t1, %hi(COM1)
    sb a0, %lo(COM1)(t1)
    jr ra
    nop
#endif

READSERIAL:                         // 读串口：将读到的数据写入v0低八位
#ifdef MACH_FPGA
.TESTR:
    lb t0, SerialStat
    andi t0, t0, 0x0002             // 截取读状态位
    bne t0, zero, .RSERIAL          // 状态位非零可读进入读
    nop
/*
#ifdef ENABLE_INT
    ori v0, zero, SYS_wait          // 取得wait调用号
    syscall SYSCALL_BASE            // 睡眠等待
#endif
 */
    j .TESTR                        // 检测验证
    nop
.RSERIAL:
    lb t5, SerialData
    jr ra
    nop
#else // MACH_FPGA undefined
    la t1, COM_LSR_DR
.TESTR:
    lb t0, COM_LSR
    and t0, t0, t1
    bne t0, zero, .RSERIAL
    nop
    j .TESTR
    nop
.RSERIAL:
    lb t5, COM1
    jr ra
    nop
#endif //ifdef MACH_FPGA

READSERIALWORD:
    addi sp, sp, -0x14             // 保存ra,s0
    sw ra, 0x0(sp)
    sw s0, 0x4(sp)
    sw s1, 0x8(sp)
    sw s2, 0xC(sp)
    sw s3, 0x10(sp)

    jal READSERIAL                  // 读串口获得八个比特
    nop
    or s0, zero, t5                 // 结果存入s0
    jal READSERIAL                  // 读串口获得八个比特
    nop
    or s1, zero, t5                 // 结果存入s1
    jal READSERIAL                  // 读串口获得八个比特
    nop
    or s2, zero, t5                 // 结果存入s2
    jal READSERIAL                  // 读串口获得八个比特
    nop
    or s3, zero, t5                 // 结果存入s3

    andi s0, s0, 0x00FF             // 截取低八位
    andi s3, s3, 0x00FF
    andi s2, s2, 0x00FF
    andi s1, s1, 0x00FF
    or t5, zero, s3                 // 存高八位
    sll t5, t5, 8                   // 左移
    or t5, t5, s2                   // 存八位
    sll t5, t5, 8                   // 左移
    or t5, t5, s1                   // 存八位
    sll t5, t5, 8                   // 左移
    or t5, t5, s0                   // 存低八位

    lw ra, 0x0(sp)                  // 恢复ra,s0
    lw s0, 0x4(sp)
    lw s1, 0x8(sp)
    lw s2, 0xC(sp)
    lw s3, 0x10(sp)
    addi sp, sp, 0x14
    jr ra
    nop
