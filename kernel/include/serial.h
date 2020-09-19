/* Serial constants */

// For QEMU, use 0x10000000
// For AXI Uart16550, use base+0x1000
#define COM1                0x10000000

// For AXI Uart16550, use 4
// For QEMU, use 1
#define COM_MULTIPLY        1

// ref: https://www.lammertbies.nl/comm/info/serial-uart
#define COM_RBR_OFFSET      (0 * COM_MULTIPLY)   /* In:  Recieve Buffer Register */
#define COM_THR_OFFSET      (0 * COM_MULTIPLY)   /* Out: Transmitter Holding Register */
#define COM_DLL_OFFSET      (0 * COM_MULTIPLY)   /* Out: Divisor Latch Low */
#define COM_IER_OFFSET      (1 * COM_MULTIPLY)   /* I/O: Interrupt Enable Register */
#define COM_DLM_OFFSET      (1 * COM_MULTIPLY)   /* Out: Divisor Latch High */
#define COM_FCR_OFFSET      (2 * COM_MULTIPLY)   /* Out: FIFO Control Register */
#define COM_IIR_OFFSET      (2 * COM_MULTIPLY)   /* I/O: Interrupt Identification Register */
#define COM_LCR_OFFSET      (3 * COM_MULTIPLY)   /* Out: Line Control Register */
#define COM_MCR_OFFSET      (4 * COM_MULTIPLY)   /* Out: Modem Control Register */
#define COM_LSR_OFFSET      (5 * COM_MULTIPLY)   /* In:  Line Status Register */
#define COM_MSR_OFFSET      (6 * COM_MULTIPLY)   /* In:  Modem Status Register */
#define COM_SCR_OFFSET      (7 * COM_MULTIPLY)   /* I/O: Scratch Register */
#define COM_MDR1_OFFSET     (8 * COM_MULTIPLY)   /* I/O:  Mode Register */

#define COM_LSR_FIFOE       0x80    /* Fifo error */
#define COM_LSR_TEMT        0x40    /* Transmitter empty */
#define COM_LSR_THRE        0x20    /* Transmit-hold-register empty */
#define COM_LSR_BI          0x10    /* Break interrupt indicator */
#define COM_LSR_FE          0x08    /* Frame error indicator */
#define COM_LSR_PE          0x04    /* Parity error indicator */
#define COM_LSR_OE          0x02    /* Overrun error indicator */
#define COM_LSR_DR          0x01    /* Receiver data ready */
#define COM_LSR_BRK_ERROR_BITS 0x1E    /* BI, FE, PE, OE bits */

#define COM_FCR_CONFIG      0x7     /* FIFO Enable and FIFO Reset */
#define COM_LCR_DLAB        0x80
// For AXI Uart16550, use clk_freq / 16 / baudrate
// For QEMU, use 115200 / 9600
#define COM_DLL_VAL         (115200 / 9600)
#define COM_LCR_WLEN8       0x03
#define COM_LCR_CONFIG      (COM_LCR_WLEN8 & ~(COM_LCR_DLAB))
#define COM_IER_RDI         0x01
