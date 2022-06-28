    .p2align 2
    .section .text.init
    // 监控程序的入口点，是最先执行的代码
    // .text.init 段放在内存的 0x80000000 位置
INITLOCATE:
    // 跳转到 init.S:START
    la s10, START
    jr s10
