#ifndef __LIBS_UNISTD_H__
#define __LIBS_UNISTD_H__
#include <mipsregs.h>

#define PAGE_SIZE   0x1000          // 4KB页
#define RAM0UBASE   0x80100000
#define RAM1BASE    0x80400000
#define RAM1KBASE   0x807F0000
#define KSEG0_BASE  0x80000000
#define PTECODE_SIZE    ((RAM1BASE - RAM0UBASE) / 0x1000 * 8)
#define PTESTACK_SIZE   ((RAM1KBASE - RAM1BASE) / 0x1000 * 8)

#define PRAM0UBASE  0x00100000
#define PRAM1BASE   0x00400000

#define KSEG2PAGE0  0xC0000000      // kseg2中页表的第一页位置

/* for EntryLo0-1   */
#define ELO_GLOBALB 0
#define ELO_GLOBALF (_ULCAST_(1) << 0)
#define ELO_VALIDB  1
#define ELO_VALIDF  (_ULCAST_(1) << 1)
#define ELO_DIRTYB  2
#define ELO_DIRTYF  (_ULCAST_(1) << 2)

#define SYSCALL_BASE            0x80

/* syscall number */
#define SYS_exit            1
#define SYS_fork            2
#define SYS_wait            3
#define SYS_exec            4
#define SYS_clone           5
#define SYS_yield           10
#define SYS_sleep           11
#define SYS_kill            12
#define SYS_gettime         17
#define SYS_getpid          18
#define SYS_mmap            20
#define SYS_munmap          21
#define SYS_shmem           22
#define SYS_putc            30
#define SYS_pgdir           31
#define SYS_open            100
#define SYS_close           101
#define SYS_read            102
#define SYS_write           103
#define SYS_seek            104
#define SYS_fstat           110
#define SYS_fsync           111
#define SYS_getcwd          121
#define SYS_getdirentry     128
#define SYS_dup             130

/* fetch program from serial bus */
#define SYS_fetchrun		241	 // a prime number :)

#define SYS_redraw_console		242

/* OLNY FOR LAB6 */
#define SYS_lab6_set_priority 255

/* SYS_fork flags */
#define CLONE_VM            0x00000100  // set if VM shared between processes
#define CLONE_THREAD        0x00000200  // thread group
#define CLONE_FS            0x00000800  // set if shared between processes

/* VFS flags */
// flags for open: choose one of these
#define O_RDONLY            0           // open for reading only
#define O_WRONLY            1           // open for writing only
#define O_RDWR              2           // open for reading and writing
// then or in any of these:
#define O_CREAT             0x00000004  // create file if it does not exist
#define O_EXCL              0x00000008  // error if O_CREAT and the file exists
#define O_TRUNC             0x00000010  // truncate file upon open
#define O_APPEND            0x00000020  // append on each write
// additonal related definition
#define O_ACCMODE           3           // mask for O_RDONLY / O_WRONLY / O_RDWR

#define NO_FD               -0x9527     // invalid fd

/* lseek codes */
#define LSEEK_SET           0           // seek relative to beginning of file
#define LSEEK_CUR           1           // seek relative to current position in file
#define LSEEK_END           2           // seek relative to end of file

#define FS_MAX_DNAME_LEN    31
#define FS_MAX_FNAME_LEN    255
#define FS_MAX_FPATH_LEN    4095

#define EXEC_MAX_ARG_NUM    32
#define EXEC_MAX_ARG_LEN    4095

#endif /* !__LIBS_UNISTD_H__ */

