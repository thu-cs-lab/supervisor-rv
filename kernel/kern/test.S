#include <regdef.h>
#include <mipsregs.h>
#include <unistd.h>
#include <exception.h>
#include <shell.h>

/*==============================================================
 *                        TEST for MONITOR
 *  Built-in test program
 *  Entry symbol prefix 'UTEST_'
 *  为了测试时间，性能测试程序执行完毕会向串口写入令符。
 *==============================================================*/

#define TESTLOOP64  0x04000000      /*  64M约6.7千万次   */
#define TESTLOOP32  0x02000000      /*  32M约3.4千万次   */
#define TESTLOOP16  0x01000000      /*  16M约1.7千万次   */
    

    .set noreorder
    .set noat
    .section .text.utest
    .p2align 2

UTEST_SIMPLE:
    addiu v0, v0, 0x1
    jr ra
    nop

    /*  系统调用测试程序
     *  该测试仅在实现异常处理时有效
     */
#ifdef ENABLE_INT
UTEST_PUTC:
    ori v0, zero, SYS_putc          // 系统调用号
    ori a0, zero, 0x4F              // 'O'
    syscall SYSCALL_BASE
    nop
    ori a0, zero, 0x4B              // 'K'
    syscall SYSCALL_BASE
    nop
    jr ra
    nop
#endif


    /*  性能标定程序(1)
     *  这段程序一般没有数据冲突和结构冲突，可作为性能标定。
     *  若执行延迟槽，执行这段程序需至少384M指令，384M/time可算得频率。
     *  不执行延迟槽，执行这段程序需至少320M指令，320M/time可算得频率。
     */
UTEST_1PTB:
    lui t0, %hi(TESTLOOP64)         // 装入64M
    nop
    nop
    nop
.LC0:
    addiu t0, t0, -1                // 滚动计数器
    ori t1, zero, 0
    ori t2, zero, 1
    ori t3, zero, 2
    bne t0, zero, .LC0
    nop
    nop
    jr ra
    nop


    /*  运算数据冲突的效率测试(2)
     *  这段程序含有大量数据冲突，可测试数据冲突对效率的影响。
     *  执行延迟槽，执行这段程序需至少192M指令。
     *  不执行延迟槽，执行这段程序需至少176M指令。
     */
UTEST_2DCT:
    lui t0, %hi(TESTLOOP16)         // 装入16M
    ori t1, zero, 1
    ori t2, zero, 2
    ori t3, zero, 3
.LC1:
    xor t2, t2, t1                  // 交换t1,t2
    xor t1, t1, t2
    xor t2, t2, t1
    xor t3, t3, t2                  // 交换t2,t3
    xor t2, t2, t3
    xor t3, t3, t2
    xor t1, t1, t3                  // 交换t3,t1
    xor t3, t3, t1
    xor t1, t1, t3
    addiu t0, t0, -1
    bne t0, zero, .LC1
    nop
    jr ra
    nop


    /*  控制指令冲突测试(3)
     *  这段程序有大量控制冲突。
     *  无延迟槽执行需要至少256M指令；
     *  有延迟槽需要224M指令。
     */
UTEST_3CCT:
    lui t0, %hi(TESTLOOP64)         // 装入64M
.LC2_0:
    bne t0, zero, .LC2_1
    nop
    jr ra
    nop
.LC2_1:
    j .LC2_2
    nop
.LC2_2:
    addiu t0, t0, -1
    j .LC2_0
    addiu t0, t0, -1
    nop


    /*  访存相关数据冲突测试(4)
     *  这段程序反复对内存进行有数据冲突的读写。
     *  不执行延迟槽需要至少192M指令。
     *  执行延迟槽，需要至少224M指令。
     */
UTEST_4MDCT:
    lui t0, %hi(TESTLOOP32)          // 装入32M
    addiu sp, sp, -4
.LC3:
    sw t0, 0(sp)
    lw t1, 0(sp)
    addiu t1, t1, -1
    sw t1, 0(sp)
    lw t0, 0(sp)
    bne t0, zero, .LC3
    nop
    addiu sp, sp, 4
    jr ra
    nop


    // 测试程序扩展



    .set reorder
    .set at
