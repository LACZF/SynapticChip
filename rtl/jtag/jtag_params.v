// jtag_params.v
// JTAG and bus parameter configuration

// JTAG parameters
`define DATA_WIDTH 64
`define ADDR_WIDTH 64
`define INSTR_WIDTH 4

// JTAG TAP state machine state definitions
`define TEST_LOGIC_RESET 4'h0
`define RUN_TEST_IDLE    4'h1
`define SELECT_DR_SCAN   4'h2
`define CAPTURE_DR       4'h3
`define SHIFT_DR         4'h4
`define EXIT1_DR         4'h5
`define PAUSE_DR         4'h6
`define EXIT2_DR         4'h7
`define UPDATE_DR        4'h8
`define SELECT_IR_SCAN   4'h9
`define CAPTURE_IR       4'hA
`define SHIFT_IR         4'hB
`define EXIT1_IR         4'hC
`define PAUSE_IR         4'hD
`define EXIT2_IR         4'hE
`define UPDATE_IR        4'hF

// JTAG instruction definitions
`define IDCODE   4'b0001  // IDCODE instruction
`define BYPASS   4'b1111  // BYPASS instruction
`define SAMPLE   4'b0010  // SAMPLE/PRELOAD instruction
`define EXTEST   4'b0000  // EXTEST instruction

// Register address offsets
`define REG_JTAG_CTRL  16'h0000  // JTAG control register
`define REG_JTAG_DATA  16'h0004  // JTAG data register
`define REG_JTAG_STAT  16'h0008  // JTAG status register

// Bus parameters
`define NODES 16
`define NODE_ID_WIDTH 5

// Operation type definitions
`define OP_READ  1'b0
`define OP_WRITE 1'b1

`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11