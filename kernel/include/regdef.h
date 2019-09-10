/*
 * This file is subject to the terms and conditions of the GNU General Public
 * License.  See the file "COPYING" in the main directory of this archive
 * for more details.
 *
 * Copyright (C) 1985 MIPS Computer Systems, Inc.
 * Copyright (C) 1994, 95, 99, 2003 by Ralf Baechle
 * Copyright (C) 1990 - 1992, 1999 Silicon Graphics, Inc.
 */
#ifndef _ASM_REGDEF_H
#define _ASM_REGDEF_H



/*
 * Symbolic register names for 32 bit ABI
 */
#define zero	x0	/* wired zero */
#define ra	x1	/* return address */
#define sp	x2	/* return value */
#define gp	x3  /* global pointer */
#define tp	x4	/* thread pointer */
#define t0	x5
#define t1	x6
#define t2	x7
#define fp	x8	/* frame pointer */
#define s0  x8
#define s1	x9
#define a0	x10 /* return value or function argument 0 */
#define a1	x11 /* return value or function argument 1 */
#define a2	x12 /* function argument 2 */
#define a3	x13
#define a4	x14
#define a5	x15
#define a6	x16	/* callee saved */
#define a7	x17
#define s2	x18
#define s3	x19
#define s4	x20
#define s5	x21
#define s6	x22
#define s7	x23
#define s8	x24	/* caller saved */
#define s9	x25
#define s10	x26	/* PIC jump register */
#define s11	x27	/* kernel scratch */
#define t3	x28
#define t4	x29	/* global pointer */
#define t5	x30	/* stack pointer */
#define t6	x31	/* frame pointer */



#endif /* _ASM_REGDEF_H */
