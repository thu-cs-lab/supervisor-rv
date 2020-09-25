// 监控程序的入口点，.text.init 段放在内存的 0x80000000 位置，是最先执行的代码。
    .p2align 2
    .section .text.init
INITLOCATE:                         // 定位启动程序
    la s10, START
    jr s10
