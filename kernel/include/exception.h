#ifndef _EXCEPTION_H
#define _EXCEPTION_H

#include <common.h>

#define TF_SIZE     32*XLEN    /* trap frame size excluding ksp */

#define EX_INST_MISALIGN      0       /* Instruction address misaligned */
#define EX_INST_FAULT         1       /* Instruction access fault */
#define EX_ILLEGAL_INST       2       /* Illegal instruction */
#define EX_BREAK              3       /* Breakpoint */
#define EX_LOAD_MISALIGN      4       /* Load address misaligned */
#define EX_LOAD_FAULT         5       /* Load access fault */
#define EX_STORE_MISALIGN     6       /* Store/AMO address misaligned */
#define EX_STORE_FAULT        7       /* Store/AMO access fault */
#define EX_ECALL_U            8       /* Environment call from U-mode */
#define EX_ECALL_S            9       /* Environment call from S-mode */
#define EX_ECALL_M            11      /* Environment call from M-mode */
#define EX_INST_PAGE_FAULT    12      /* Instruction page fault */
#define EX_LOAD_PAGE_FAULT    13      /* Load page fault */
#define EX_STORE_PAGE_FAULT   15      /* Store/AMO page fault */

#ifdef RV32
#define EX_INT_FLAG 0x80000000
#else
#define EX_INT_FLAG 0x8000000000000000
#endif

#define EX_INT_MODE_MASK 0x3
#define EX_INT_MODE_USER 0x0
#define EX_INT_MODE_SUPERVISOR 0x1
#define EX_INT_MODE_MACHINE 0x3

#define EX_INT_TYPE_MASK 0xC
#define EX_INT_TYPE_SOFT 0x0
#define EX_INT_TYPE_TIMER 0x4
#define EX_INT_TYPE_EXTERNAL 0x8

#define TF_ra       0*XLEN
#define TF_sp       1*XLEN
#define TF_gp       2*XLEN
#define TF_tp       3*XLEN
#define TF_t0       4*XLEN
#define TF_t1       5*XLEN
#define TF_t2       6*XLEN
#define TF_s0       7*XLEN
#define TF_s1       8*XLEN
#define TF_a0       9*XLEN
#define TF_a1       10*XLEN
#define TF_a2       11*XLEN
#define TF_a3       12*XLEN
#define TF_a4       13*XLEN
#define TF_a5       14*XLEN
#define TF_a6       15*XLEN
#define TF_a7       16*XLEN
#define TF_s2       17*XLEN
#define TF_s3       18*XLEN
#define TF_s4       19*XLEN
#define TF_s5       20*XLEN
#define TF_s6       21*XLEN
#define TF_s7       22*XLEN
#define TF_s8       23*XLEN
#define TF_s9       24*XLEN
#define TF_s10      25*XLEN
#define TF_s11      26*XLEN
#define TF_t3       27*XLEN
#define TF_t4       28*XLEN
#define TF_t5       29*XLEN
#define TF_t6       30*XLEN
#define TF_epc      31*XLEN
#define TF_ksp      32*XLEN


#endif
