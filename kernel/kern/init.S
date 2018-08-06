#include <regdef.h>
#include <mipsregs.h>
#include <unistd.h>
#include <exception.h>

    .set noreorder
    .set noat

    .section .bss
    .p2align 2
    .global TCBT                    // thread control block table
TCBT:
    .long 0
    .long 0
    .global current                 // current thread TCB address
current:
    .long 0
#ifdef ENABLE_TLB                   // 声明页表
    .section .bss.ptes
    .global PTECODE
    .global PTESTACK
    .p2align 12                     // 每个两页，页对齐
PTECODE:
    .rept PAGE_SIZE / 2             // 8KB一个TLB项
    .long 0
    .endr
PTE2BASE:
    .rept PAGE_SIZE / 2 - PTESTACK_SIZE / 4
                                    // 空余
    .long 0
    .endr
PTESTACK:
    .rept PTESTACK_SIZE / 4
    .long 0
    .endr
#endif

    .text
    .p2align 2
monitor_version:
    .asciz "MONITOR for MIPS32 - initialized."


    /* start address for the .bss section. defined in linker script */
    .word   _sbss
    /* end address for the .bss section. defined in linker script */
    .word   _ebss
    .global START
START:                              // kernel init
    lui k0, %hi(_sbss)
    addiu k0, %lo(_sbss)
    lui k1, %hi(_ebss)
    addiu k1, %lo(_ebss)
bss_init:
    beq k0, k1, bss_init_done
    nop
    sw  zero, 0(k0)
    addiu k0, k0, 4
    b   bss_init
    nop

bss_init_done:
#ifdef ENABLE_INT
    mfc0 t0, CP0_STATUS             // 取得cp0的status Reg
    nop
    xori t1, t0, (ST0_IM | ST0_IE | ST0_EXL | ST0_ERL)
                                    // 取消错误、异常位，使得eret正常
                                    // 见Vol3p196ERL,错误置位会让eret跳ErEPC
    and t0, t0, t1                  // status Reg 的IE位和IM位置零
    mtc0 t0, CP0_STATUS             // 暂停中断响应，直到启动完成
    nop

    mfc0 t0, CP0_STATUS
    lui t1, %hi(ST0_BEV)
    xor t1, t0, t1
    and t0, t0, t1                  // status Reg 的BEV位置零
    mtc0 t0, CP0_STATUS             // 中断处理转为正常模式
    ori t2, zero, PAGE_SIZE
    mtc0 t2, CP0_EBASE              // 设定中断响应基址为0x8000.1000
    mfc0 t0, CP0_CAUSE
    lui t1, %hi(CAUSEF_IV)
    xor t1, t1, t0
    and t0, t0, t1                  // Cause IV位置零
    mtc0 t0, CP0_CAUSE              // 关闭中断特殊入口
#endif
    lui sp, %hi(KERNEL_STACK_INIT)  // 设置内核栈
    addiu sp, %lo(KERNEL_STACK_INIT)
    or fp, sp, zero
    lui t0, %hi(USER_STACK_INIT)    // 设置用户栈
    addiu t0, %lo(USER_STACK_INIT)
    lui t1, %hi(uregs_sp)           // 写入用户空间备份
    sw t0, %lo(uregs_sp)(t1)
    lui t1, %hi(uregs_fp)
    sw t0, %lo(uregs_fp)(t1)

    /* init serial */
#ifdef MACH_QEMU
    /* see ucore/kern/driver/console.c */
    lui t0, 0xBFD0                  // NOTE: all COM_* share high 16 bits
                                    // 0xBFD0 should be %hi(COM1) but can not be used
                                    // due to a compiler bug (bugzilla/20649)
    sb zero, %lo(COM_FCR)(t0)       // console.c:54
    ori t1, zero, %lo(COM_LCR_DLAB)
    sb t1, %lo(COM_LCR)(t0)         // :57
    ori t1, zero, %lo(COM_DLL_VAL)
    sb t1, %lo(COM_DLL)(t0)         // :58
    sb zero, %lo(COM_DLM)(t0)       // :59
    ori t1, zero, %lo(COM_LCR_CONFIG)
    sb t1, %lo(COM_LCR)(t0)         // :62
    sb zero, %lo(COM_MCR)(t0)       // :65
    ori t1, zero, %lo(COM_IER_RDI)
    sb t1, %lo(COM_IER)(t0)         // :67
#else
    lui t0, %hi(SerialStat)
    ori t1, zero, 0x10
    sb t1, %lo(SerialStat)(t0)      // 串口可读中断
#endif

#ifdef ENABLE_INT
    /* enable serial interrupt */
    mfc0 t0, CP0_STATUS
    ori t0, t0, STATUSF_IP4         // hardware interrupt source #2, irq #4
    mtc0 t0, CP0_STATUS
#endif


    ori t0, zero, TF_SIZE / 4       // 计数器
.LC0:
    addiu t0, t0, -1                // 滚动计数器
    addiu sp, sp, -4                // 移动栈指针
    sw zero, 0(sp)                  // 初始化栈空间
    bne t0, zero, .LC0              // 初始化循环
    nop
    lui t0, %hi(TCBT)
    addiu t0, %lo(TCBT)           // 载入TCBT地址
    sw sp, 0(t0)                    // thread0(idle)的中断帧地址设置
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
    or t6, sp, zero                 // t6保存idle中断帧位置

    ori t0, zero, TF_SIZE / 4       // 计数器
.LC1:
    addiu t0, t0, -1                // 滚动计数器
    addiu sp, sp, -4                // 移动栈指针
    sw zero, 0(sp)                  // 初始化栈空间
    bne t0, zero, .LC1              // 初始化循环
    nop
    lui t0, %hi(TCBT)
    addiu t0, %lo(TCBT)           // 载入TCBT地址
    sw sp, 4(t0)                    // thread1(shell/user)的中断帧地址设置
    sw sp, TF_sp(t6)                // 设置idle线程栈指针(调试用?)

    lui t2, %hi(TCBT + 4)
    addiu t2, %lo(TCBT + 4)
    lw t2, 0(t2)                    // 取得thread1的TCB地址
    lui t1, %hi(current)
    sw t2, %lo(current)(t1)         // 设置当前线程为thread1

#ifdef ENABLE_TLB                   // 打开TLB机制
    lui t0, 0xC000                  // PTE在kseg2
    mtc0 zero, CP0_PAGEMASK         // pagemask置零，使用4kB页
    mtc0 t0, CP0_CONTEXT            // 设置PTEBase
    lui t0, 0x8000                  // 使用kuseg，用户栈地址确定
    lui t1, %hi(uregs_sp)           // 写入用户空间备份
    sw t0, %lo(uregs_sp)(t1)
    lui t1, %hi(uregs_fp)
    sw t0, %lo(uregs_fp)(t1)
    mfc0 t3, CP0_CONFIG, 1          // CP0_Config1
    srl t3, t3, 25
    andi t3, t3, 0x3F               // 截取MMUSize
    addiu t3, t3, 1                 // TLB有MMUSize+1项
    lui t4, 0x8000                  // 用于检测TLB命中
    or t2, t4, t4                   // va = begin(kseg0)
    mtc0 zero, CP0_ENTRYLO0
    mtc0 zero, CP0_ENTRYLO1         // 设为非可用
.LC_tlb:
    addiu t3, t3, -1
.LC_vamat:
    addiu t2, t2, PAGE_SIZE * 2     // va += 8KB
    mtc0 t2, CP0_ENTRYHI            // 写va
    nop
    tlbp
    nop
    mfc0 t1, CP0_INDEX              // 获得匹配结果
    and t1, t1, t4                  // 截取最高位
    beq t1, zero, .LC_vamat         // 匹配到则不能设这个va
    nop
    mtc0 t3, CP0_INDEX
    nop
    tlbwi                           // 清零
    bne t3, zero, .LC_tlb
    nop

    lui a0, %hi(PTECODE)            // 填页表1
    addiu a0, %lo(PTECODE)
    lui t0, %hi(PRAM0UBASE)
    addiu t0, %lo(PRAM0UBASE)     // 物理地址
    srl t0, t0, 6                   // pa(12)->pfn(6)
    ori t0, t0, (ELO_VALIDF | ELO_DIRTYF | ELO_GLOBALF)
                                    // 可访问可写
    ori t6, zero, PTECODE_SIZE / 8  // 计数器
.LC_pte1:
    sw t0, 0x0(a0)                  // 写Lo
    addiu t6, t6, -1                // 滚动计数器
    addiu a0, a0, 8                 // 下一个Lo
    addiu t0, t0, PAGE_SIZE >> 6    // 下一页
    bne t6, zero, .LC_pte1
    nop

    lui a0, %hi(PTESTACK)           // 填页表2
    addiu a0, %lo(PTESTACK)
    lui t0, %hi(PRAM1BASE)
    addiu t0, %lo(PRAM1BASE)      // 物理地址
    srl t0, t0, 6                   // pa(12)->pfn(6)
    ori t0, t0, (ELO_VALIDF | ELO_DIRTYF | ELO_GLOBALF)
                                    // 可访问可写
    ori t6, zero, PTESTACK_SIZE / 8 // 计数器
.LC_pte2:
    sw t0, 0x0(a0)                  // 写Lo
    addiu t6, t6, -1                // 滚动计数器
    addiu a0, a0, 8                 // 下一个Lo
    addiu t0, t0, PAGE_SIZE >> 6    // 下一页
    bne t6, zero, .LC_pte2
    nop

    ori t0, zero, 2
    mtc0 t0, CP0_WIRED              // wired置二

    lui s2, 0x1FFF
    ori s2, s2, 0xFFFF              // kseg0 掩码
    mtc0 zero, CP0_INDEX            // 取TLB第一项
    lui a0, %hi(PTECODE)            // kseg2页表page0
    addiu a0, %lo(PTECODE)
    and a0, a0, s2                  // 取物理地址
    srl a0, a0, 6                   // PA[35..12] => ENTRYLO{0,1}[29..6]
    ori a0, a0, ELO_VALIDF | ELO_GLOBALF    // 置合法位，不允许修改kseg2
    addiu a1, a0, PAGE_SIZE >> 6    // page1
    mtc0 a0, CP0_ENTRYLO0
    mtc0 a1, CP0_ENTRYLO1
    lui t0, %hi(KSEG2PAGE0)         // kseg2第一二页
    addiu t0, %lo(KSEG2PAGE0)
    mtc0 t0, CP0_ENTRYHI            // kseg2第一页翻译为ptecode
    nop
    tlbwi
    ori t0, zero, 0x1               // 2
    mtc0 t0, CP0_INDEX              // 取TLB第二项
    lui a0, %hi(PTE2BASE)           // kseg2页表page1022
    addiu a0, %lo(PTE2BASE)
    and a0, a0, s2                  // 取物理地址
    srl a0, a0, 6                   // PA[35..12] => ENTRYLO{0,1}[29..6]
    ori a0, a0, ELO_VALIDF | ELO_GLOBALF    // 置合法位，不允许修改kseg2
    addiu a1, a0, PAGE_SIZE >> 6    // page1023
    mtc0 a0, CP0_ENTRYLO0
    mtc0 a1, CP0_ENTRYLO1
    lui t0, 0xC03F                  // kseg2第1022,1023页
    ori t0, t0, 0xE000
    mtc0 t0, CP0_ENTRYHI
    nop
    tlbwi
    nop
#endif

#ifdef ENABLE_INT
    mfc0 t0, CP0_STATUS             // 取得cp0的status Reg
    nop
    ori t0, t0, ST0_IE              // status Reg 的IE位置一
    xori t1, t0, STATUSF_IP4
    and t0, t0, t1                  // 主线程屏蔽串口硬件中断
    mtc0 t0, CP0_STATUS             // 启动完成，恢复中断机制
    nop
#endif

    j WELCOME                       // 进入主线程
    nop



WELCOME:
    lui s0, %hi(monitor_version)    // 装入启动信息
    addiu s0, %lo(monitor_version)
    lb a0, 0(s0)
.Loop0:
    addiu s0, s0, 0x1
    jal WRITESERIAL                 // 调用串口写函数
    nop
    lb a0, 0(s0)
    bne a0, zero, .Loop0            // 打印循环至0结束符
    nop
    j SHELL                         // 开始交互
    nop



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


    .set at
    .set reorder







// vim: syntax=asm
