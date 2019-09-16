#ifndef _COMMON_H
#define _COMMON_H

#ifdef RV32
#define STORE sw
#define LOAD lw
#define XLEN 4
#else
#define STORE sd
#define LOAD ld
#define XLEN 8
#endif

#define TIMERSET    0x06            // ascii (ACK) 启动计时
#define TIMETOKEN   0x07            // ascii (BEL) 停止计时

#define SYS_exit 1
#define SYS_putc 30

#define MSTATUS_MPP_MASK 0x1800

#define SATP_SV32 0x80000000
#define SATP_SV39 0x8000000000000000

#ifdef ENABLE_PAGING
#define USER_STACK_INIT 0x80000000
#else
#define USER_STACK_INIT 0x807F0000
#endif
#endif
