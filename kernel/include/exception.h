#ifndef _EXCEPTION_H
#define _EXCEPTION_H

#define TF_SIZE     0x80    /* trap frame size */

#define EX_IRQ      0       /* Interrupt */
#define EX_MOD      1       /* TLB Modify (write to read-only page) */
#define EX_TLBL     2       /* TLB miss on load */
#define EX_TLBS     3       /* TLB miss on store */
#define EX_ADEL     4       /* Address error on load */
#define EX_ADES     5       /* Address error on store */
#define EX_IBE      6       /* Bus error on instruction fetch */
#define EX_DBE      7       /* Bus error on data load *or* store */
#define EX_SYS      8       /* Syscall */
#define EX_BP       9       /* Breakpoint */
#define EX_RI       10      /* Reserved (illegal) instruction */
#define EX_CPU      11      /* Coprocessor unusable */
#define EX_OVF      12      /* Arithmetic overflow */

#define TF_AT       0x00
#define TF_v0       0x04
#define TF_v1       0x08
#define TF_a0       0x0C
#define TF_a1       0x10
#define TF_a2       0x14
#define TF_a3       0x18
#define TF_t0       0x1C
#define TF_t1       0x20
#define TF_t2       0x24
#define TF_t3       0x28
#define TF_t4       0x2C
#define TF_t5       0x30
#define TF_t6       0x34
#define TF_t7       0x38
#define TF_t8       0x3C
#define TF_t9       0x40
#define TF_s0       0x44
#define TF_s1       0x48
#define TF_s2       0x4C
#define TF_s3       0x50
#define TF_s4       0x54
#define TF_s5       0x58
#define TF_s6       0x5C
#define TF_s7       0x60
#define TF_gp       0x64
#define TF_fp       0x68
#define TF_ra       0x6C
#define TF_STATUS   0x70
#define TF_CAUSE    0x74
#define TF_EPC      0x78
#define TF_sp       0x7C


#endif
