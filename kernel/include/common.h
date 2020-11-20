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

#define SIG_TIMERSET    0x06        // ascii (ACK) 启动计时
#define SIG_TIMETOKEN   0x07        // ascii (BEL) 停止计时
#define SIG_FATAL       0x80        // 严重错误
#define SIG_TIMEOUT     0x81        // 超时

#define SYS_exit 1
#define SYS_putc 30

#define MSTATUS_MPP_MASK 0x1800

#define MIE_MTIE (1 << 7)

#define SATP_SV32 0x80000000
#define SATP_SV39 0x8000000000000000

#define CLINT 0x2000000
#define CLINT_MTIME (CLINT + 0xBFF8)
#define CLINT_MTIMECMP (CLINT + 0x4000)

#ifdef ENABLE_PAGING
#define USER_STACK_INIT 0x80000000
#else
#define USER_STACK_INIT 0x807F0000
#endif
#endif
