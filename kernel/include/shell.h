#ifndef _MONITOR_SHELL_H
#define _MONITOR_SHELL_H

#define SH_OP_R 0x0052              // char 'R'
#define SH_OP_D 0x0044              // char 'D'
#define SH_OP_A 0x0041              // char 'A'
#define SH_OP_G 0x0047              // char 'G'
#define SH_OP_T 0x0054              // char 'T'

#define PUTREG(r)  ((r - 1) << 2)

#define TIMERSET    0x06            // ascii (ACK) 启动计时
#define TIMETOKEN   0x07            // ascii (BEL) 停止计时


#endif
