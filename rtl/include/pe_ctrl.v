`ifndef __PE_CTRL__
    `define __PE_CTRL__

    // System Parameters
    `define DATA_WIDTH 32
    `define ADDR_WIDTH 32
    `define PE_ID_WIDTH 4

    // PE Array Dimensions
    `define ARRAY_ROWS 4
    `define ARRAY_COLS 4
    `define NUM_PES 16

    // Instruction Width and Fields
    `define INST_WIDTH 32
    `define OPCODE_WIDTH 6
    `define REG_ADDR_WIDTH 4

    // Opcode Definitions
    `define OP_NOP   6'b000000
    `define OP_CFG_PE 6'b010000  // Configure PE
    `define OP_CFG_ROUTE 6'b010001  // Configure Routing
    `define OP_READ_STAT 6'b010010  // Read Status
    `define OP_START_PE 6'b010011   // Start PE
    `define OP_STOP_PE 6'b010100    // Stop PE
    `define OP_RESET_PE 6'b010101   // Reset PE

    // Register Address Mapping
    `define REG_PE_CTRL 16'h0000  // PE Control Register
    `define REG_PE_STAT 16'h0004  // PE Status Register
    `define REG_ROUTE_CFG 16'h0008 // Route Configuration Register
    `define REG_PE_INST 16'h000C   // PE Instruction Register
    `define REG_PE_DATA 16'h0010   // PE Data Register

    // Ring Bus Parameters
    `define NODES 16
    `define NODE_ID_WIDTH 5

    // Bus State Definitions
    `define STATE_IDLE 2'b00
    `define STATE_ARB  2'b01
    `define STATE_DATA 2'b10
    `define STATE_ACK  2'b11
`endif