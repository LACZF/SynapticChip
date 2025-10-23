`ifnde __PE_V__
    `define __PE_V__
    // Data width
    `define DATA_WIDTH 64
    `define ADDR_WIDTH 64

    // Instruction width and fields
    `define INST_WIDTH 32
    `define OPCODE_WIDTH 6
    `define REG_ADDR_WIDTH 4

    // Opcode definitions
    `define OP_NOP   6'b000000
    `define OP_ADD   6'b000001
    `define OP_SUB   6'b000010
    `define OP_MUL   6'b000011
    `define OP_AND   6'b000100
    `define OP_OR    6'b000101
    `define OP_XOR   6'b000110
    `define OP_NOT   6'b000111
    `define OP_SHL   6'b001000
    `define OP_SHR   6'b001001
    `define OP_LOAD  6'b001010
    `define OP_STORE 6'b001011
    `define OP_MOVE  6'b001100
    `define OP_JUMP  6'b001101
    `define OP_BEQ   6'b001110
    `define OP_BNE   6'b001111
    `define OP_BLT   6'b010000
    `define OP_BGT   6'b010001

    // PE modes
    `define MODE_COMPUTE 2'b00
    `define MODE_MEMORY  2'b01
    `define MODE_COMM    2'b10
    `define MODE_IDLE    2'b11

    // Number of registers
    `define NUM_REGS 16

    // Memory depth
    `define MEM_DEPTH 256
`endif