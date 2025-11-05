`ifndef __SPI_V__
    `define __SPI_V__
    // Data Width Parameters
    `define SPI_DATA_WIDTH 32      // Data Width
    `define SPI_ADDR_WIDTH 32      // Address Width
    `define SPI_NODE_ID_WIDTH 5    // Node ID Width

    // SPI Register Address Offsets
    `define SPI_REG_CONTROL  8'h00  // Control Register
    `define SPI_REG_STATUS   8'h04  // Status Register
    `define SPI_REG_DATA     8'h08  // Data Register
    `define SPI_REG_ADDR     8'h0C  // Address Register
    `define SPI_REG_CMD      8'h10  // Command Register
    `define SPI_REG_CLK_DIV  8'h14  // Clock Divider Register
    `define SPI_REG_CONFIG   8'h18  // Configuration Register
    `define SPI_REG_CS_SEL   8'h1C  // Chip Select Register

    // Control Register Bit Definitions
    `define SPI_CTRL_EN       0     // Enable Bit
    `define SPI_CTRL_IRQ_EN   1     // Interrupt Enable Bit
    `define SPI_CTRL_BUSY     2     // Busy Flag Bit
    `define SPI_CTRL_READY    3     // Ready Flag Bit
    `define SPI_CTRL_MASTER   4     // Master Mode Bit

    // Status Register Bit Definitions
    `define SPI_STATUS_TX_READY  0     // Transmit Ready
    `define SPI_STATUS_RX_READY  1     // Receive Ready
    `define SPI_STATUS_BUSY      2     // Busy Status
    `define SPI_STATUS_ERROR     3     // Error Flag
    `define SPI_STATUS_IRQ_PEND  4     // Interrupt Pending

    // SPI Operation Modes
    `define SPI_MODE_0 2'b00   // CPOL=0, CPHA=0
    `define SPI_MODE_1 2'b01   // CPOL=0, CPHA=1
    `define SPI_MODE_2 2'b10   // CPOL=1, CPHA=0
    `define SPI_MODE_3 2'b11   // CPOL=1, CPHA=1

    // Operation Type Definitions
    `define SPI_OP_READ  1'b0
    `define SPI_OP_WRITE 1'b1

    // SPI Command Definitions
    `define SPI_CMD_READ_DATA    8'h03  // Standard SPI Read Data
    `define SPI_CMD_FAST_READ    8'h0B  // Fast Read
    `define SPI_CMD_READ_DUAL    8'h3B  // Dual Line Read
    `define SPI_CMD_READ_QUAD    8'h6B  // Quad Line Read
    `define SPI_CMD_WRITE_ENABLE 8'h06  // Write Enable
    `define SPI_CMD_WRITE_DATA   8'h02  // Page Program
    `define SPI_CMD_TRANSFER     8'h04  // Simultaneous Read and Write

    // State Machine State Definitions
    `define SPI_STATE_IDLE      3'b000
    `define SPI_STATE_CMD       3'b001
    `define SPI_STATE_ADDR      3'b010
    `define SPI_STATE_DUMMY     3'b011
    `define SPI_STATE_READ      3'b100
    `define SPI_STATE_WRITE     3'b101
    `define SPI_STATE_TRANSFER  3'b110
    `define SPI_STATE_DONE      3'b111

    // FIFO Parameters
    `define SPI_FIFO_DEPTH    16    // FIFO Depth
    `define SPI_FIFO_ADDR_WIDTH 4   // FIFO Address Width

`endif