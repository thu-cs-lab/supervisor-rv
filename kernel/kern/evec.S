// You don't have to care about this file if you don't enable interrupt and paging.

    .p2align 2
    .section .text.init
INITLOCATE:                         // 定位启动程序
    la s10, START
    jr s10
