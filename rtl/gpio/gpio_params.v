// gpio_params.v
// GPIO and Bus Parameter Configuration

// GPIO Parameters
`define ADDR_WIDTH 64      // Address Width
`define DATA_WIDTH 64      // Data Width
`define GPIO_WIDTH 32      // Number of GPIO Pins

// Register Address Offsets
`define REG_DATA   8'h00   // Data Register
`define REG_DIR    8'h04   // Direction Register (0=Input, 1=Output)
`define REG_INTEN  8'h08   // Interrupt Enable Register
`define REG_INTPOL 8'h0C   // Interrupt Polarity Register (0=Low/Falling, 1=High/Rising)
`define REG_INTTYPE 8'h10  // Interrupt Type Register (0=Level, 1=Edge)
`define REG_INTSTAT 8'h14  // Interrupt Status Register
`define REG_DEBOUNCE 8'h18 // Debounce Period Register

// Bus Parameters
`define NODES 16            // Number of Bus Nodes
`define NODE_ID_WIDTH 5    // Node ID Width

// Bus State Definitions
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11

// Operation Type Definitions
`define OP_READ  1'b0
`define OP_WRITE 1'b1