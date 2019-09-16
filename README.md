# supervisor-rv： RISC-V 监控程序

[![Build Status](https://travis-ci.org/jiegec/supervisor-rv.svg?branch=master)](https://travis-ci.org/jiegec/supervisor-rv)

## 介绍

Thinpad 教学计算机搭配了监控程序，能够接受用户命令，支持输入汇编指令并运行，查看寄存器及内存状态等功能。监控程序可在学生实现的 32/64 位 RISC-V CPU 上运行，一方面可以帮助学生理解、掌握 RISC-V 指令系统及其软件开发，另一方面可以作为验证学生 CPU 功能正确性的标准。

监控程序分为两个部分，Kernel 和 Term。其中 Kernel 使用 RISC-V 汇编语言编写，运行在 Thinpad 上学生实现的 CPU 中，用于管理硬件资源；Term 是上位机程序，使用 Python 语言编写，有基于命令行的用户界面，达到与用户交互的目的。Kernel 和 Term 直接通过串口通信，即用户在 Term 界面中输入的命令、代码经过 Term 处理后，通过串口传输给 Kernel 程序；反过来，Kernel 输出的信息也会通过串口传输到 Term，并展示给用户。

## Kernel

Kernel 使用汇编语言编写，使用到的指令有20余条，均符合 RISC-V 规范。Kernel 提供了三种不同的版本，以适应不同的档次的 CPU 实现。它们分别是：第一档为基础版本，直接基本的I/O和命令执行功能，不依赖异常、中断、CP0等处理器特征，适合于最简单的 CPU 实现；第二档支持中断，使用中断方式完成串口的I/O功能，需要处理器实现中断处理机制，及相关的CP0处理器；第三档在第二档基础上进一步增加了TLB的应用，要求处理器支持基于 TLB 的内存映射，更加接近于操作系统对处理器的需求。

为了在硬件上运行 Kernel 程序，我们首先要对 Kernel 的汇编代码进行编译。

下面是编译监控程序的过程。在`kernel`文件夹下面，有汇编代码和 Makefile 文件，我们可以使用 make 工具编译 Kernel 程序。假设当前目录为 `kernel` ，目标版本为基础版本，我们在终端中运行命令

`make`

即可开始编译流程。如果顺利结束，将生成 `kernel.elf` 和 `kernel.bin` 文件，即可执行文件。要在模拟器中运行它，可以使用命令

`make sim`

它会在 QEMU 中启动监控程序，并等待 Term 程序连接。本文后续章节介绍了如何使用 Term 连接模拟器。

若要在硬件上运行，使用开发板提供的工具，将 `kernel.bin` 写入内存 0 地址位置，并让处理器复位从 0x8000000 地址（RISC-V 中对应 RAM 地址为 0 的物理地址）处开始执行，Kernel 就运行起来了。

Kernel 运行后会先通过串口输出版本号，该功能可作为检验其正常运行的标志。之后 Kernel 将等待 Term 从串口发来的命令，关于 Term 的使用将在后续章节描述。

接下来我们分别说明三个档次的监控程序对于硬件的要求，及简要的设计思想。

### 基础版本

基础版本的 Kernel 共使用了 19 条不同的指令，它们是：

```asm
ADD   0000000SSSSSsssss000ddddd0110011
ADDI  iiiiiiiiiiiisssss000ddddd0010011
AND   0000000SSSSSsssss111ddddd0110011
ANDI  iiiiiiiiiiiisssss111ddddd0010011
AUIPC iiiiiiiiiiiiiiiiiiiiddddd0010111
BEQ   iiiiiiiSSSSSsssss000iiiii1100011
BNE   iiiiiiiSSSSSsssss001iiiii1100011
JAL   iiiiiiiiiiiiiiiiiiiiddddd1101111
JALR  iiiiiiiiiiiisssss000ddddd1100111
LB    iiiiiiiiiiiisssss000ddddd0000011
LUI   iiiiiiiiiiiiiiiiiiiiddddd0110111
LW    iiiiiiiiiiiisssss010ddddd0000011
OR    0000000SSSSSsssss110ddddd0110011
ORI   iiiiiiiiiiiisssss110ddddd0010011
SB    iiiiiiiSSSSSsssss000iiiii0100011
SLLI  0000000iiiiisssss001ddddd0010011
SRLI  0000000iiiiisssss101ddddd0010011
SW    iiiiiiiSSSSSsssss010iiiii0100011
XOR   0000000SSSSSsssss100ddddd0110011
```

如果实现的是 RISC-V 64位，则额外需要实现以下指令：

```asm
ADDIW iiiiiiiiiiiisssss000ddddd0011011
LD    iiiiiiiiiiiisssss011ddddd0000011
SD    iiiiiiiSSSSSsssss011iiiii0100011
```

根据 RISC-V 规范（在参考文献中）正确实现这些指令后，程序才能正常工作。

监控程序使用了 8 MB 的内存空间，其中约 1 MB 由 Kernel 使用，剩下的空间留给用户程序。此外，为了支持串口通信，还设置了一个内存以外的地址区域，用于串口收发。具体内存地址的分配方法如下表所示：


| 地址区间 | 说明 |
| --- | --- |
| 0x80000000-0x800FFFFF | 监控程序代码 |
| 0x80100000-0x803FFFFF | 用户程序代码 |
| 0x80400000-0x807EFFFF | 用户程序数据 |
| 0x807F0000-0x807FFFFF | 监控程序数据 |
| 0x10000000-0x10000008 | 串口数据及状态 |

串口控制器访问的代码位于`kern/utils.S`，其数据格式为：

| 地址 | 位 | 说明 |
| --- | --- | --- |
| 0x10000000 | [7:0] | 串口数据，读、写地址分别表示串口接收、发送一个字节 |
| 0x10000005 | [5] | 只读，为1时表示串口空闲，可发送数据 |
| 0x10000005 | [1] | 只读，为1时表示串口收到数据 |

Kernel 的入口地址为 0x80000000，对应汇编代码`kern/init.S`中的 `START:`标签。在完成必要的初始化流程后，Kernel 输出版本信息，随后进入 shell 线程，与用户交互。shell 线程会等待串口输入，执行输入的命令，并通过串口返回结果，如此往复运行。

当收到启动用户程序的命令后，用户线程代替 shell 线程的活动。用户程序的寄存器，保存在从 0x807F0000 开始的连续 31*XLEN 字节中，依次对应 x1 到 x31 用户寄存器，每次启动用户程序时从上述地址装载寄存器值，用户程序运行结束后保存到上述地址。

### 进阶一：中断和异常支持

作为扩展功能之一，Kernel 支持中断方式的 I/O ，和 Syscall 功能。要启用这一功能，编译时的命令变为：

`make EN_INT=y`

这一编译选项，会使得代码编译时增加宏定义 `ENABLE_INT` ，从而使能中断相关的代码。

为支持中断，CPU 要额外实现以下指令

```asm
CSRRS  ccccccccccccsssss010ddddd1110011
CSRRW  ccccccccccccsssss001ddddd1110011
EBREAK 00000000000100000000000001110011
ECALL  00000000000000000000000001110011
MRET   00110000001000000000000001110011
```

此外还需要实现 CSR 寄存器的这些字段：

1. mtvec: BASE, MODE
2. mscratch
3. mepc
4. mcause: Interrupt, Exception Code

csr 寄存器字段功能定义参见 RISC-V32 特权态规范（在参考文献中）。

监控程序对于异常、中断的使用方式如下：

- 入口函数 EXCEPTION_HANDLER ，根据异常号跳转至相应的异常处理程序。
- 用户程序通过 ebreak 回到 M-mode ，在异常处理中跳回到 SHELL 。
- 异常帧保存 31 个通用寄存器及 mepc 寄存器。
- 禁止发生嵌套异常。
- 支持 SYS\_putc 系统调用。写串口忙等待，与禁止嵌套异常不冲突。
- 当发生不能处理的中断时，表示出现严重错误，终止当前任务，自行重启。并且发送错误信号 0x80 提醒 TERM 。
- 初始化时设置 mtvec=EXCEPTION_HANDLER ，使用正常中断模式（MODE=DIRECT）。

### 进阶二：TLB支持

在支持异常处理的基础上，可以进一步使能TLB支持，从而实现用户态地址映射。要启用这一功能，编译时的命令变为：

`make EN_INT=y EN_TLB=y`

CPU 要额外实现以下指令

1. `TLBP` 01000010000000000000000000001000
1. `TLBR` 01000010000000000000000000000001
1. `TLBWI` 01000010000000000000000000000010
1. `TLBWR` 01000010000000000000000000000110


此外还需要实现 CP0 寄存器：

1. Context
2. Config1: MMUSize
3. Index
4. Entryhi: VPN2
5. Entrylo0/1: PFN, D, V
6. Wired
7. Random

以及TLB相关的几个异常，其中 Refill 异常入口地址为 0x80001000，与其它异常的入口地址不同。

为了简化，TLB实际的映射是线性映射。将0x80100000-0x803FFFFF放在kuseg地址最低端，将0x80400000-0x807EFFFF放在kuseg的地址最高端。4MB的地址映射在kseg2的页表里只需8KB的页表。因此设CP0的WIRED=2，TLB最低两项存kseg2地址翻译。

在一般中断处理中，需要处理TLB不合法异常。修改异常通过统一置D位为一避免。当访问无法映射的地址时，向串口发送地址访问违法信号，并重启。因为正常访问kseg2不会引发TLB异常，所以异常类型TLBL,TLBS,Mod(修改TLB只读页)都是严重错误，需要发送错误信号 0x80 并重启。

kuseg的映射：

- va[0x00000000, 0x002FFFFF] = pa[0x00100000, 0x003FFFFF]
- va[0x7FC10000, 0x7FFFFFFF] = pa[0x00400000, 0x007EFFFF]
 
页表：
 
- PTECODE: va(i*page_size)->[i]->RAM0UBASE[i]
- PTESTACK: va(KSEG0BASE+i*page_size-RAM1USIZE)->[i]->RAM1[i]

初始化过程：

1. 从Config1获得TLB大小，初始化TLB
1. 设Context的PTEBase并填写页表
1. PageMask设零（固定为4K页大小）
1. 将用户栈指针设为 0x80000000
1. Wired设为2，设置对kseg2的映射。

## Term

Term 程序运行在实验者的电脑上，提供监控程序和人交互的界面。Term 支持7种命令，它们分别是

- R：按照\$1至\$30的顺序返回用户程序寄存器值。
- D：显示从指定地址开始的一段内存区域中的数据。
- A：用户输入汇编指令，并放置到指定地址上
- U：从指定地址读取一定长度的数据，并显示反汇编结果。
- G：执行指定地址的用户程序。
- T：查看指定的TLB条目。本功能仅在Kernel支持TLB时有效。
- Q：退出 Term

利用这些命令，实验者可以输入一段汇编程序，检查数据是否正确写入，并让程序在处理器上运行验证。

Term 程序位于`term`文件夹中，可执行文件为`term.py`。对于本地的 Thinpad，运行程序时用 -s 选项指定串口。例如：

`python term.py -s COM3` 或者 `python term.py -s /dev/ttyACM0`（串口名称根据实际情况修改）

连接远程实验平台的 Thinpad，或者 QEMU 模拟器时，使用 -t 选项指定 IP 和端口。例如：

`python term.py -t 127.0.0.1:6666`

### 测试程序

监控程序附带了几个测试程序，代码见`kern/test.S`。我们可以通过命令

`make show-utest`

来查看测试程序入口地址。记下这些地址，并在 Term 中使用G命令运行它们。

### 用户程序编写

根据监控程序设计，用户程序的代码区为0x80100000-0x803FFFFF，实验时需要把用户程序写入这一区域。用户程序的最后需要以`jr $31`结束，从而保证正确返回监控程序。

在输入用户程序的过程中，既可以用汇编指令，也可以直接写16进制的机器码。空行表示输入结束。

以下是一次输入用户程序并运行的过程演示：

	MONITOR for RISC-V - initialized.
	>> a
	>> addr: 0x80100000
	one instruction per line, empty line to end.
	[0x80100000] ori $v0,$0,5
	[0x80100004] xor $t0,$t0,$t0
	[0x80100008] xor $t1,$t1,$t1
	[0x8010000c] loop:
	[0x8010000c] addu $t1,$t1,$t0
	[0x80100010] addiu $t0,$t0,1
	[0x80100014] bne $v0,$t0,loop
	[0x80100018] nop
	[0x8010001c] jr $ra
	[0x80100020] nop
	[0x80100024] 
	>> u
	addr: 0x80100000
	num: 64
	0x80100000: li	v0,0x5
	0x80100004: xor	t0,t0,t0
	0x80100008: xor	t1,t1,t1
	0x8010000c: addu	t1,t1,t0
	0x80100010: addiu	t0,t0,1
	0x80100014: bne	v0,t0,0x8010000c
	0x80100018: nop
	0x8010001c: jr	ra
	0x80100020: nop
	0x80100024: nop
	0x80100028: nop
	0x8010002c: nop
	0x80100030: nop
	0x80100034: nop
	0x80100038: nop
	0x8010003c: nop
	>> g
	addr: 0x80100000

	elapsed time: 0.000s
	>> r
	R1 (AT)    = 0x00000000
	R2 (v0)    = 0x00000005
	R3 (v1)    = 0x00000000
	R4 (a0)    = 0x00000000
	R5 (a1)    = 0x00000000
	R6 (a2)    = 0x00000000
	R7 (a3)    = 0x00000000
	R8 (t0)    = 0x00000005
	R9 (t1)    = 0x0000000a
	R10(t2)    = 0x00000000
	R11(t3)    = 0x00000000
	R12(t4)    = 0x00000000
	R13(t5)    = 0x00000000
	R14(t6)    = 0x00000000
	R15(t7)    = 0x00000000
	R16(s0)    = 0x00000000
	R17(s1)    = 0x00000000
	R18(s2)    = 0x00000000
	R19(s3)    = 0x00000000
	R20(s4)    = 0x00000000
	R21(s5)    = 0x00000000
	R22(s6)    = 0x00000000
	R23(s7)    = 0x00000000
	R24(t8)    = 0x00000000
	R25(t9/jp) = 0x00000000
	R26(k0)    = 0x00000000
	R27(k1)    = 0x00000000
	R28(gp)    = 0x00000000
	R29(sp)    = 0x807f0000
	R30(fp/s8) = 0x807f0000
	>> q


当处理器和 Kernel 支持异常功能时（即上文所述 EN_INT=y ），用户还可以用 Syscall 的方式打印字符。打印字符的系统调用号为 30。使用时，用户把调用号保存在v0寄存器，打印字符参数保存在a0寄存器，并执行 syscall 指令，a0寄存器的低八位将作为字符打印。例如：
	
	ori $v0, $0, 30          # 系统调用号
	ori $a0, $0, 0x4F        # 'O'
	syscall 0x80
	nop
	ori $a0, $0, 0x4B        # 'K'
	syscall 0x80
	nop
	jr $ra
	nop

## 参考文献

- CPU采用的 RISC-V 指令集标准：The RISC-V Instruction Set Manual Volume I: User-Level ISA Document
- RISC-V 中断及TLB等特权态资源：The RISC-V Instruction Set Manual Volume II: Privileged Architecture

## 项目作者

- 初始版本：韦毅龙，李成杰，孟子焯
- RISC-V版本移植：韩东池，耿威
- 后续维护：张宇翔，董豪宇，陈嘉杰
- 代码贡献：王润基
