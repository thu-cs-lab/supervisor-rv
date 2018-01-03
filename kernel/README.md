# supervisor-32 —— 32位监控程序

## 准备

- CPU采用的MIPS32指令集标准[Volume II-A](http://cdn2.imgtec.com/documentation/MIPS_Architecture_MIPS32_InstructionSet_%20AFP_P_MD00086_06.05.pdf)
- CPU支持的指令[集合](https://git.net9.org/Neptunus/Neptunus/wikis/instruction-set)
- 中断等CPU模式见[Volume III](http://cdn2.imgtec.com/documentation/MD00090-2B-MIPS32PRA-AFP-06.02.pdf)
- mips工具链见ucore wiki

> `/include`文件夹下的头文件大部分来自于[armcpu ucore](https://git.net9.org/armcpu-devteam/armcpu/tree/master/ucore)

## 使用指令

以下指令是必须的。

1. `ADDIU 001001ssssstttttiiiiiiiiiiiiiiii`
1. `ADDU 000000ssssstttttddddd00000100001`
1. `AND 000000ssssstttttddddd00000100100`
1. `ANDI 001100ssssstttttiiiiiiiiiiiiiiii`
1. `BEQ 000100ssssstttttoooooooooooooooo`
1. `BGTZ 000111sssss00000oooooooooooooooo`
1. `BNE 000101ssssstttttoooooooooooooooo`
1. `J 000010iiiiiiiiiiiiiiiiiiiiiiiiii`
1. `JAL 000011iiiiiiiiiiiiiiiiiiiiiiiiii`
1. `JR 000000sssss0000000000hhhhh001000`
1. `LB 100000bbbbbtttttoooooooooooooooo`
1. `LUI 00111100000tttttiiiiiiiiiiiiiiii`
1. `LW 100011bbbbbtttttoooooooooooooooo`
1. `OR 000000ssssstttttddddd00000100101`
1. `ORI 001101ssssstttttiiiiiiiiiiiiiiii`
1. `SB 101000bbbbbtttttoooooooooooooooo`
1. `SLL 00000000000tttttdddddaaaaa000000`
1. `SRL 00000000000tttttdddddaaaaa000010`
1. `SW 101011bbbbbtttttoooooooooooooooo`
1. `XOR 000000ssssstttttddddd00000100110`
1. `XORI 001110ssssstttttiiiiiiiiiiiiiiii`

如果使能异常、中断支持，需要增加以下指令。

1. `ERET 01000010000000000000000000011000`
1. `MFC0 01000000000tttttddddd00000000lll`
1. `MTC0 01000000100tttttddddd00000000lll`
1. `SYSCALL 000000cccccccccccccccccccc001100`

如果进一步使能TLB支持，需要增加以下指令。

1. `TLBP 01000010000000000000000000001000`
1. `TLBR 01000010000000000000000000000001`
1. `TLBWI 01000010000000000000000000000010`
1. `TLBWR 01000010000000000000000000000110`


## 设计

若编译时不使能TLB机制，只能访问kseg0和kseg1。使能TLB机制后按照后述约定访问kuseg。用户程序被授予内核级权限。

监控程序运行两个线程，idle线程和shell线程，shell线程优先，但会因等待硬件进入睡眠，转交控制权予idle线程。

### 地址分配

| 地址区间 | 说明 |
| --- | --- |
| `0x8000.0000-0x800F.FFFF` | 监控程序代码 |
| `0x8010.0000-0x803F.FFFF` | 用户代码空间 |
| `0x8040.0000-0x807E.FFFF` | 用户数据空间 |
| `0x807F.0000-0x807F.FFFF` | 监控程序数据 |


### 启动

1. 引导：需要Neptunus的bootloader读取elf格式的监控程序。监控程序相当于专用途内核。
1. 启动过程中暂停中断处理。
1. 设置`CP0_STATUS(BEV)=0,CP0_CAUSE(IV)=0,EBase=0x8000.1000`，使用正常中断模式。
1. 设置`CP0_STATUS(ERL)=0`，使`eret`以`EPC`寄存器值为地址跳转。
1. 设置内核栈，`sp=0x8080.0000`。设置用户栈指针`0x807F.0000`。
1. 设置TCB，设置当前线程。
1. 如果打开TLB机制
    1. 从config1获得TLB大小，初始化TLB
    1. 设Context的PTEBase并填写页表
    1. PageMask设零
    1. 将用户栈指针设为`0x8000.0000`
    1. Wired设为二，设置对kseg2的映射。
1. 恢复中断响应。
1. 启动idle等待线程，启动shell主线程。
1. 向串口写入启动信息。

### 中断

#### 重启

- 入口`0xBFC0.0000`，执行bootloader重新启动。
- 启动入口`0x8000.0000`，跳转至启动程序。
- 当发生不能处理的中断时，表示出现严重错误，终止当前任务，自行重启。并且发送 **错误信号`0x80`** 提醒TERM。

#### TLB快速重填

- 入口`0x8000.1000`

#### 一般中断

- 入口`0x8000.1180`，跳转至中断处理程序。
- 串口硬件中断：唤醒shell线程。**为此，shell/user线程运行时屏蔽串口硬件中断，idle线程中打开。**
- 系统调用：shell线程调用SYS\_wait，CPU控制权转交idle线程。
- 中断帧保存29个通用寄存器（k0,k1不保存）及STATUS,CAUSE,EPC三个相关寄存器。32个字，128字节，0x80字节。
- 禁止发生嵌套中断。
- 支持SYS\_wait和SYS\_putc两个系统调用。写串口忙等待，与禁止嵌套中断不冲突。
- 退出中断处理前置`CP0_STATUS(ERL)=0`，否则`eret`在此位置一时不会使用`EPC`寄存器，而是跳到 *`ErrorEPC`寄存器所在的地址* 。

### TLB

为了简化，省去MMU，因此TLB实际的映射是线性映射。将RAM0的3MB放在kuseg地址最低端，将RAM1的剩余放在kuseg的地址最高端。4MB的地址映射在kseg2的页表里只需8KB的页表。因此设wired=2，TLB最低两项存kseg2地址翻译。

在一般中断处理中，需要处理TLB不合法异常。修改异常通过统一置D位为一避免。当访问无法映射的地址时，向串口发送地址访问违法信号，并重启。因为正常访问kseg2不会引发TLB异常，所以异常类型TLBL,TLBS,Mod(修改TLB只读页)都是严重错误，需要发送错误信号并重启。**错误信号`0x80`。**

> **kuseg的映射：**
> 
>   - `va[0x0000.0000, 0x002F.FFFF] = pa[0x0010.0000, 0x003F.FFFF]`
>   - `va[0x7FC1.0000, 0x7FFF.FFFF] = pa[0x0040.0000, 0x007E.FFFF]`
> 
> 页表：
> 
>   - `PTECODE: va(i*page_size)->[i]->RAM0UBASE[i]`
>   - `PTESTACK: va(KSEG0BASE+i*page_size-RAM1USIZE)->[i]->RAM1[i]`

### 线程调度

- 监控程序只支持两个线程。启动用户程序后，用户线程代替shell线程的活动。
- 线程控制块简化为中断帧指针。
- 用户空间寄存器：
    - 从`0x807F.0000`开始，到`0x807F.0077`连续120字节，依次保存$1到$30寄存器。
    - 每次`G`指令从上述地址装载寄存器值，用户程序运行结束后保存到上述地址。

### 命令交互

**传输均按照小端序，addr和num大小为一字。** *小端序：低地址低位，先传输低位。*

- `R`：按照$1至$30的顺序返回用户空间寄存器值。
- `D <addr> <num>`：按照小端序返回指定地址连续num字节。
- `A <addr> <num> <content>`：在指定地址写入content。约定content有num字节，并且num为4的倍数。
- `G <addr>`：执行指定地址的用户程序。ra传递正常退出地址。
- `T <num>`: 查看index=num的TLB项，依次回传ENTRYHI, ENTRYLO0, ENTRYLO1共12字节。

**用户线程执行时间统计：**

- `G`命令执行中，执行前发射计时器启动信号，结束后发射计时器停止信号。
- TERM可利用此特性实现CPU性能测试等功能。
- 信号约定：
    - 启动信号：`0x06(ACK)`
    - 停止信号：`0x07(BEL)`

### 用户编程

模仿用户空间，监控程序特地初始化了用户栈，用户栈指针(sp,fp)初始值见[启动]。并且，除了寄存器ra，其他30个寄存器都和内核空间做了隔离，方便使用。

因为给出了putc的系统调用，所以用户可以很方便的打印字符。

- 调用号：`SYS_putc = 30, SYS_wait = 3`
- 调用号保存在v0寄存器，打印字符参数保存在a0寄存器。
- 截取a0寄存器的低八位作为字符打印。

### 测试程序

- 内建测试程序，代码见`kern/test.S`。
- 可以通过命令`make show-utest`来查看测试程序入口地址。
- 通过`G`命令调用测试程序。


