/*==============================================================
 *                        TEST for MONITOR
 *  Built-in test program
 *  Entry symbol prefix 'UTEST_'
 *  为了测试时间，性能测试程序执行完毕会向串口写入令符。
 *==============================================================*/

#include <common.h>
#define TESTLOOP64  0x04000000      /*  64M约6.7千万次   */
#define TESTLOOP32  0x02000000      /*  32M约3.4千万次   */
#define TESTLOOP16  0x01000000      /*  16M约1.7千万次   */


    .section .text.utest
    .p2align 2

UTEST_SIMPLE:
    addi t5, t5, 0x1
    jr ra

    /*  性能标定程序(1)
     *  这段程序一般没有数据冲突和结构冲突，可作为性能标定。
     *  执行这段程序需至少 320M 指令
     */
UTEST_1PTB:
    li t0, TESTLOOP64         // 装入 64M
.LC0:
    addi t0, t0, -1                // 滚动计数器
    li t1, 0
    li t2, 1
    li t3, 2
    bne t0, zero, .LC0
    jr ra

    /*  运算数据冲突的效率测试(2)
     *  这段程序含有大量数据冲突，可测试数据冲突对效率的影响。
     *  执行这段程序需至少 176M 指令。
     */
UTEST_2DCT:
    lui t0, %hi(TESTLOOP16)         // 装入16M
    li t1, 1
    li t2, 2
    li t3, 3
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
    addi t0, t0, -1
    bne t0, zero, .LC1
    jr ra

    /*  控制指令冲突测试(3)
     *  这段程序有大量控制冲突。
     *  执行需要至少 256M 指令。
     */
UTEST_3CCT:
    lui t0, %hi(TESTLOOP64)         // 装入64M
.LC2_0:
    bne t0, zero, .LC2_1
    jr ra
.LC2_1:
    j .LC2_2
.LC2_2:
    addi t0, t0, -1
    j .LC2_0
    addi t0, t0, -1

    /*  访存相关数据冲突测试(4)
     *  这段程序反复对内存进行有数据冲突的读写。
     *  需要至少执行 192M 指令。
     */
UTEST_4MDCT:
    lui t0, %hi(TESTLOOP32)          // 装入32M
    addi sp, sp, -4
.LC3:
    sw t0, 0(sp)
    lw t1, 0(sp)
    addi t1, t1, -1
    sw t1, 0(sp)
    lw t0, 0(sp)
    bne t0, zero, .LC3

    addi sp, sp, 4
    jr ra

#ifdef ENABLE_INT
UTEST_PUTC:
    li s0, SYS_putc
    li a0, 0x4F              // 'O'
    ecall
    li a0, 0x4B              // 'K'
    ecall
    jr ra

UTEST_SPIN:
    j UTEST_SPIN
#endif

UTEST_CRYPTONIGHT:
#ifdef ENABLE_PAGING
    li a0, 0x7FC10000
#else
    li a0, 0x80400000 // base addr
#endif
    li a1, 0x200000 // 2M bytes
    li a3, 524288 // number of iterations
    li a4, 0x1FFFFC // 2M mask
    add a1, a1, a0 // end addr
    li s0, 1 // rand number

    mv a2, a0
.INIT_LOOP:
    sw s0, 0(a2)

    // xorshift lfsr
    slli s1, s0, 13
    xor s0, s0, s1
    srli s1, s0, 17
    xor s0, s0, s1
    slli s1, s0, 5
    xor s0, s0, s1

    addi a2, a2, 4
    bne a2, a1, .INIT_LOOP

    li a2, 0
    li t0, 0
.MAIN_LOOP:
    // calculate a valid addr from rand number
    and t0, s0, a4
    add t0, a0, t0
    // read from it
    lw t0, 0(t0)
    // xor with last iteration's t0
    xor t0, t0, t1
    // xor rand number with current t0
    xor s0, s0, t0

    // get new rand number from xorshift lfsr
    slli s1, s0, 13
    xor s0, s0, s1
    srli s1, s0, 17
    xor s0, s0, s1
    slli s1, s0, 5
    xor s0, s0, s1

    // calculate a valid addr from new rand number
    and t1, s0, a4
    add t1, a0, t1
    // write t0 to this addr
    sw t0, 0(t1)
    // save t0 for next iteration
    mv t1, t0

    // get new rand number from xorshift lfsr
    slli s1, s0, 13
    xor s0, s0, s1
    srli s1, s0, 17
    xor s0, s0, s1
    slli s1, s0, 5
    xor s0, s0, s1

    add a2, a2, 1
    bne a2, a3, .MAIN_LOOP

    jr ra
