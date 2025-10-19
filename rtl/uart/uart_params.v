// uart_params.v
// UART and bus parameter configuration

// UART parameters
`define DATA_WIDTH 64      // Data width
`define ADDR_WIDTH 64      // Address width

// Register address offsets
`define REG_RBR 8'h00      // Receive Buffer Register (read-only)
`define REG_THR 8'h00      // Transmit Holding Register (write-only)
`define REG_IER 8'h04      // Interrupt Enable Register
`define REG_IIR 8'h08      // Interrupt Identification Register (read-only)
`define REG_FCR 8'h08      // FIFO Control Register (write-only)
`define REG_LCR 8'h0C      // Line Control Register
`define REG_MCR 8'h10      // Modem Control Register
`define REG_LSR 8'h14      // Line Status Register (read-only)
`define REG_MSR 8'h18      // Modem Status Register (read-only)
`define REG_SCR 8'h1C      // Scratch Register
`define REG_DLL 8'h00      // Divisor Latch Low (when LCR[7]=1)
`define REG_DLM 8'h04      // Divisor Latch High (when LCR[7]=1)

// Interrupt types
`define INT_NONE 4'b0000   // No interrupt
`define INT_RX   4'b0100   // Receive data available
`define INT_TX   4'b0010   // Transmit holding register empty
`define INT_LS   4'b0110   // Receive line status
`define INT_MS   4'b0000   // Modem status (not usually used)

// Bus parameters
`define NODES 16            // Number of bus nodes
`define NODE_ID_WIDTH 5    // Node ID width

// Bus state definitions
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11

// Operation type definitions
`define OP_READ  1'b0
`define OP_WRITE 1'b1

// FIFO parameters
`define FIFO_DEPTH 16      // FIFO depth
`define FIFO_ADDR_WIDTH 4  // FIFO address width