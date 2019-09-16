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
#endif
