/* Qemu serial constants */
#define COM1                0x10000000
#define COM_RBR_OFFSET      0   /* In:  Recieve Buffer Register */
#define COM_THR_OFFSET      0   /* Out: Transmitter Holding Register */
#define COM_DLL_OFFSET      0   /* Out: Divisor Latch Low */
#define COM_IER_OFFSET      1   /* I/O: Interrupt Enable Register */
#define COM_DLM_OFFSET      1   /* Out: Divisor Latch High */
#define COM_FCR_OFFSET      2   /* Out: FIFO Control Register */
#define COM_IIR_OFFSET      2   /* I/O: Interrupt Identification Register */
#define COM_LCR_OFFSET      3   /* Out: Line Control Register */
#define COM_MCR_OFFSET      4   /* Out: Modem Control Register */
#define COM_LSR_OFFSET      5   /* In:  Line Status Register */
#define COM_MSR_OFFSET      6   /* In:  Modem Status Register */
#define COM_SCR_OFFSET      7   /* I/O: Scratch Register */
#define COM_MDR1_OFFSET     8   /* I/O:  Mode Register */

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
#define COM_DLL_VAL         (115200 / 9600)
#define COM_LCR_WLEN8       0x03
#define COM_LCR_CONFIG      (COM_LCR_WLEN8 & ~(COM_LCR_DLAB))
#define COM_IER_RDI         0x01
