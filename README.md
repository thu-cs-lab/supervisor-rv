# supervisor-rv： RISC-V 监控程序

[![Build Status](https://travis-ci.org/jiegec/supervisor-rv.svg?branch=master)](https://travis-ci.org/jiegec/supervisor-rv)

## 介绍

Thinpad 教学计算机搭配了监控程序，能够接受用户命令，支持输入汇编指令并运行，查看寄存器及内存状态等功能。监控程序可在学生实现的 32/64 位 RISC-V CPU 上运行，一方面可以帮助学生理解、掌握 RISC-V 指令系统及其软件开发，另一方面可以作为验证学生 CPU 功能正确性的标准。

监控程序分为两个部分，Kernel 和 Term。其中 Kernel 使用 RISC-V 汇编语言编写，运行在 Thinpad 上学生实现的 CPU 中，用于管理硬件资源；Term 是上位机程序，使用 Python 语言编写，有基于命令行的用户界面，达到与用户交互的目的。Kernel 和 Term 直接通过串口通信，即用户在 Term 界面中输入的命令、代码经过 Term 处理后，通过串口传输给 Kernel 程序；反过来，Kernel 输出的信息也会通过串口传输到 Term，并展示给用户。

## Kernel

Kernel 使用汇编语言编写，使用到的指令有 20 余条，均符合 RISC-V 规范。Kernel 提供了三种不同的版本，以适应不同的档次的 CPU 实现。它们分别是：第一档为基础版本，直接基本的 I/O 和命令执行功能，不依赖异常、中断、csr 等处理器特征，适合于最简单的 CPU 实现；第二档支持中断，使用中断方式完成串口的 I/O 功能，需要处理器实现中断处理机制，及相关的 csr 寄存器；第三档在第二档基础上进一步增加了页表的应用，要求处理器支持基于 Sv32 或者 Sv39 的内存映射，更加接近于操作系统对处理器的需求。

为了在硬件上运行 Kernel 程序，我们首先要对 Kernel 的汇编代码进行编译。

下面是编译监控程序的过程。在 `kernel` 文件夹下面，有汇编代码和 Makefile 文件，我们可以使用 make 工具编译 Kernel 程序。假设当前目录为 `kernel` ，目标版本为基础版本，我们在终端中运行命令

`make`

即可开始编译流程。如果顺利结束，将生成 `kernel.elf` 和 `kernel.bin` 文件，即可执行文件。要在模拟器中运行它，可以使用命令

`make sim`

它会在 QEMU 中启动监控程序，并等待 Term 程序连接。本文后续章节介绍了如何使用 Term 连接模拟器。需要注意的是，如果需要打开一些开关（下面会提到），需要在每条命令中传递参数，比如应该输入

`make EN_INT=y sim`

而不是

`make EN_INT=y`
`make sim`

目前所有可能出现的开关有：

1. EN_INT： 打开中断、异常和用户态支持，默认关闭。
2. EN_PAGING：打开页表支持，要求 EN_INT 已打开，默认关闭。
3. EN_FENCEI：如果实现了 L1 Cache 并且分离了 I Cache 和 D Cache 则应当开启，在写入代码后执行 FENCE.I 指令，默认关闭。
4. EN_UART16550：如果实现了 UART 16550 兼容的串口控制器则要开启，否则可以关闭，详情见下方的讨论，默认开启。

若要在硬件上运行，使用开发板提供的工具，将 `kernel.bin` 写入内存 0x80000000 地址位置，并让处理器复位从 0x80000000 地址处开始执行，Kernel 就运行起来了。

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

如果实现的是 RISC-V 64 位，则额外需要实现以下指令：

```asm
ADDIW iiiiiiiiiiiisssss000ddddd0011011
LD    iiiiiiiiiiiisssss011ddddd0000011
SD    iiiiiiiSSSSSsssss011iiiii0100011
```

在以上指令里面，很多指令的功能是相近的，分类以后，实际上只需要实现如下的几种指令，然后很容易就可以扩展到其它指令：

```
ADD: ADDI, AND, ANDI, OR, ORI, SLLI, SRLI, XOR, ADDIW
AUIPC:
BEQ: BNE
JAL:
JALR:
LB: LW，LD
LUI:
SB: SW，SD
```

所以，实际上只需要实现上面的八条指令，简单扩展即可实现需要的所有指令。

根据 RISC-V 规范（在参考文献中）正确实现这些指令后，程序才能正常工作。

监控程序使用了 8 MB 的内存空间，其中约 1 MB 由 Kernel 使用，剩下的空间留给用户程序。此外，为了支持串口通信，还设置了一个内存以外的地址区域，用于串口收发。具体内存地址的分配方法如下表所示：

| 地址区间 | 说明 |
| --- | --- |
| 0x80000000-0x800FFFFF | 监控程序代码 |
| 0x80100000-0x803FFFFF | 用户程序代码 |
| 0x80400000-0x807EFFFF | 用户程序数据 |
| 0x807F0000-0x807FFFFF | 监控程序数据 |
| 0x10000000-0x10000008 | 串口数据及状态 |

串口控制器按照 [16550 UART 的寄存器](https://www.lammertbies.nl/comm/info/serial-uart) 的子集实现，访问的代码位于 `kern/utils.S` ，其部分数据格式为：

| 地址 | 位 | 说明 |
| --- | --- | --- |
| 0x10000000 | [7:0] | 串口数据，读、写地址分别表示串口接收、发送一个字节 |
| 0x10000005 | [5] | 只读，为1时表示串口空闲，可发送数据 |
| 0x10000005 | [0] | 只读，为1时表示串口收到数据 |

除此之外，默认情况下还会按照 UART 16550 的初始化流程进行一些寄存器的配置。在 QEMU 中运行的时候，请保持 `EN_UART16550=y`，这也是默认行为。如果你采用了自定义的实现，请设置 `EN_UART16550=n` 以去掉这些寄存器操作，或者忽略掉这些寄存器的操作（但初始化时仍然会输出额外的字符，因为 RBR THR 和 DLL 在同一个地址）。如果使用了 AXI UART16550 作为串口控制器，请参考代码注释并修改 `kernel/include/serial.h` 中的常量，并设置 `EN_UART16550=y`。

Kernel 的入口地址为 0x80000000，对应汇编代码 `kern/init.S` 中的 `START:` 标签。在完成必要的初始化流程后，Kernel 输出版本信息，随后进入 shell 线程，与用户交互。shell 线程会等待串口输入，执行输入的命令，并通过串口返回结果，如此往复运行。

当收到启动用户程序的命令后，用户线程代替 shell 线程的活动。用户程序的寄存器，保存在从 0x807F0000 开始的连续 31*XLEN 字节中，依次对应 x1 到 x31 用户寄存器，每次启动用户程序时从上述地址装载寄存器值，用户程序运行结束后保存到上述地址。

### 进阶一：中断和异常支持

作为扩展功能之一，Kernel 支持中断方式的 I/O，和 Syscall 功能。要启用这一功能，编译时的命令变为：

`make EN_INT=y`

这一编译选项，会使得代码编译时增加宏定义 `ENABLE_INT` ，从而使能中断相关的代码。

为支持中断，CPU 要额外实现以下指令

```asm
CSRRC  ccccccccccccsssss011ddddd1110011
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
5. mstatus: MPP

csr 寄存器字段功能定义参见 RISC-V 特权态规范（在参考文献中）。

监控程序对于异常、中断的使用方式如下：

- 入口函数 EXCEPTION_HANDLER，根据异常号跳转至相应的异常处理程序。
- 初始化时设置 mtvec = EXCEPTION_HANDLER，使用正常中断模式（MODE = DIRECT）；如果不支持 MODE = DIRECT（利用 mtvec 的 WARL 判断），则会使用向量中断模式（MODE = VECTORED）。
- 用户程序在 U-mode 中运行（mret 时 mstatus.MPP = 0），通过 ebreak 回到 M-mode ，在异常处理中跳回到 SHELL。
- 异常帧保存 31 个通用寄存器及 mepc 寄存器。
- 禁止发生嵌套异常。
- 支持 SYS_putc 系统调用，调用方法参考 UTEST_PUTC 函数。写串口忙等待，与禁止嵌套异常不冲突。
- 当发生不能处理的中断时，表示出现严重错误，终止当前任务，自行重启。并且发送错误信号 0x80 提醒 TERM。

### 进阶二：页表支持

在支持异常处理的基础上，可以进一步使能页表支持，从而实现用户态地址映射。要启用这一功能，编译时的命令变为：

`make EN_INT=y EN_PAGING=y`

CPU 需要额外实现以下指令

```asm
SFENCE.VMA  0001001SSSSSsssss000000001110011
```

如果没有实现 TLB，可以把 SFENCE.VMA 实现为 NOP。

此外还需要实现 csr 寄存器：

1. satp: MODE, PPN

以及页表相关的几个异常，RV32 需要实现 Sv32 的页表格式，RV64 需要实现 Sv39 的页表格式。

为了简化，实际的映射是线性映射，Sv32 映射的方式在下面给出：

- va[0x00000000, 0x002FFFFF] = pa[0x80100000, 0x803FFFFF] DAGUX-RV 用户态代码
- va[0x7FC10000, 0x7FFFFFFF] = pa[0x80400000, 0x807EFFFF] DAGU-WRV 用户态数据
- va[0x80000000, 0x80000FFF] = pa[0x80000000, 0x80000FFF] DAGUX-RV 用于返回内核态
- va[0x80100000, 0x80100FFF] = pa[0x80100000, 0x80100FFF] DAGUX-RV 方便测试

Sv39 下为了实现的方便，映射的地址比以上的地址区域更大一些。

其它地址都未经映射，访问则会引发异常。

初始化过程：

1. 根据 RV32 还是 RV64 选择 Sv32 或者 Sv39 的页表进行填写
2. 将页表的物理地址写入 satp 并配置好模式，启用 U-mode 下的页表映射机制。
3. 通过 sfence.vma 指令刷新 TLB。
4. 将用户栈指针设为 0x80000000。

## Term

Term 程序运行在实验者的电脑上，提供监控程序和人交互的界面。Term 支持7种命令，它们分别是

- R：按照 x1 至 x31 的顺序返回用户程序寄存器值。
- D：显示从指定地址开始的一段内存区域中的数据。
- A：用户输入汇编指令，并放置到指定地址上。
- F：从文件读入汇编指令并放置到指定地址上，格式与 A 命令相同。
- U：从指定地址读取一定长度的数据，并显示反汇编结果。
- G：执行指定地址的用户程序。
- T：查看页表内容，仅在启用页表时有效。
- Q：退出 Term。

利用这些命令，实验者可以输入一段汇编程序，检查数据是否正确写入，并让程序在处理器上运行验证。

Term 程序位于 `term` 文件夹中，可执行文件为 `term.py` 。对于本地的 Thinpad，运行程序时用 `-s` 选项指定串口。例如：

`python term.py -s COM3` 或者 `python term.py -s /dev/ttyACM0`（串口名称根据实际情况修改）

连接远程实验平台的 Thinpad，或者 QEMU 模拟器时，使用 -t 选项指定 IP 和端口。例如：

`python term.py -t 127.0.0.1:6666`

### 测试程序

监控程序附带了几个测试程序，代码见 `kern/test.S` 。我们可以通过命令

`make EN_XXX=y show-utest`

来查看测试程序入口地址。记下这些地址，并在 Term 中使用 G 命令运行它们。

其中 CRYPTONIGHT 测试模仿了 CryptoNight 算法，它会进行很多次的随机访存，数据缓存命中率会很低。运行结束后，寄存器 `t0` 保存的是最终结果，32位下应该是 `a2e31a85`，64 位下应该是 `ffffffff861c65d4`。

### 用户程序编写

根据监控程序设计，用户程序的代码区为 0x80100000-0x803FFFFF ，实验时需要把用户程序写入这一区域。用户程序的最后需要以 `jr ra` 结束，从而保证正确返回监控程序。

在输入用户程序的过程中，既可以用汇编指令，又可以直接写 16 进制的机器码，还可以写 label （见以下例子中 loop: 的用法）。空行表示输入结束。

以下是一次输入用户程序并运行的过程演示：

```asm
connecting to 127.0.0.1:6666...connected
running in 32bit, xlen = 4
>> a
addr: 0x80100000
one instruction per line, empty line to end.
[0x80100000] li a0, 5
[0x80100004] li t0, 0
[0x80100008] 00000313
[0x8010000c] loop:
[0x8010000c] add t1, t1, t0
[0x80100010] addi t0, t0, 1
[0x80100014] bne a0, t0, loop
[0x80100018] jr ra
[0x8010001c]
>> u
addr: 0x80100000
num: 32
0x80100000:	00500513	li	a0,5
0x80100004: 00000293	li	t0,0
0x80100008: 00000313	li	t1,0
0x8010000c: 00530333	add	t1,t1,t0
0x80100010: 00128293	addi	t0,t0,1
0x80100014: fe551ce3	bne	a0,t0,0x8010000c
0x80100018: 00008067	ret
0x8010001c: 00000000	...
>> g
addr: 0x80100000

elapsed time: 0.000s
>> r
R1 (ra)    = 0x80000414
R2 (sp)    = 0x807fff00
R3 (gp)    = 0x00000000
R4 (tp)    = 0x00000000
R5 (t0)    = 0x00000005
R6 (t1)    = 0x0000000a
R7 (t2)    = 0x00000000
R8 (s0/fp) = 0x80000000
R9 (s1)    = 0x00000000
R10(a0)    = 0x00000005
R11(a1)    = 0x00000000
R12(a2)    = 0x00000000
R13(a3)    = 0x00000000
R14(a4)    = 0x00000000
R15(a5)    = 0x00000000
R16(a6)    = 0x00000000
R17(a7)    = 0x00000000
R18(s2)    = 0x00000000
R19(s3)    = 0x00000000
R20(s4)    = 0x00000000
R21(s5)    = 0x00000000
R22(s6)    = 0x00000000
R23(s7)    = 0x00000000
R24(s8)    = 0x00000000
R25(s9)    = 0x00000000
R26(s10)   = 0x80100000
R27(s11)   = 0x00000000
R28(t3)    = 0x00000000
R29(t4)    = 0x00000000
R30(t5)    = 0x00000000
R31(t6)    = 0x00000000
>> q
```

当处理器和 Kernel 支持异常功能时（即上文所述 EN_INT=y），用户还可以用 Syscall 的方式打印字符。打印字符的系统调用号为 30。使用时，用户把调用号保存在 s0 寄存器，打印字符参数保存在 a0 寄存器，并执行 syscall 指令，a0 寄存器的低八位将作为字符打印。例如：

```asm
li s0, 30          # 系统调用号
li a0, 0x4F         # 'O'
ecall
li a0, 0x4B         # 'K'
ecall
jr ra
```

用 `A` 命令输入的汇编指令支持常见的伪指令（pseudo instructions），并且地址也会相应地变化，如：

```asm
connecting to 127.0.0.1:6666...connected
running in 32bit, xlen = 4
>> A
addr: 0x80100000
one instruction per line, empty line to end.
[0x80100000] li a0, 0x12345678
[0x80100008] li t0, 0x23333332
[0x80100010] ret
[0x80100014]
>> U
addr: 0x80100000
num: 20
0x80100000:     12345537        lui     a0,0x12345
0x80100004:     67850513        addi    a0,a0,1656
0x80100008:     233332b7        lui     t0,0x23333
0x8010000c:     33228293        addi    t0,t0,818
0x80100010:     00008067        ret
>>
```

如果是 RV64，上面的 `addi` 指令会相应地变成 `addiw` 指令。

## 在 QEMU 里调试监控程序

在 Makefile 中提供了 `debug` 目标，它会编译 kernel 并且运行 QEMU：

```bash
$ cd kernel
$ make debug
qemu-system-riscv32 -M virt -m 32M -kernel kernel.elf -nographic -monitor stdio -serial tcp::6666,server -S -s
QEMU 5.0.0 monitor - type 'help' for more information
(qemu) qemu-system-riscv32: -serial tcp::6666,server: info: QEMU waiting for connection on: disconnected:tcp::::6666,server
```

之后它会在 6666 端口上等待 term 的连接。另起一个窗口，运行 term 连接到 `localhost:6666` ：

```bash
$ python3 term/term.py -t 127.0.0.1:6666 -c
connecting to 127.0.0.1:6666...connected
```

这一步连上以后，就可以用 gdb 挂载到 qemu 里的 kernel 上了。采用比较新的 gdb 或者 SiFive 的 riscv64-elf-unknown-gdb 都是可以的。命令：

```bash
$ gdb kernel/kernel.elf
GNU gdb (GDB) 9.2
Copyright (C) 2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "x86_64-apple-darwin19.4.0".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from kernel/kernel.elf...
(gdb) target remote localhost:1234
Remote debugging using localhost:1234
0x00001000 in ?? ()
(gdb)
```

之后就可以正常进行调试。

## 参考文献

- CPU 采用的 RISC-V 指令集标准：The RISC-V Instruction Set Manual Volume I: User-Level ISA Document
- RISC-V 中断及 Sv32/Sv39 等特权态资源：The RISC-V Instruction Set Manual Volume II: Privileged Architecture

## 项目作者

- 初始版本：韦毅龙，李成杰，孟子焯
- RISC-V 版本移植：韩东池，耿威
- 后续维护：张宇翔，董豪宇，陈嘉杰
- 代码贡献：王润基，刘晓义
