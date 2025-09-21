// riscv_core_params.v
// RISC-V核心和总线参数配置

// RISC-V相关参数
`define XLEN 32
`define REG_COUNT 32
`define INST_WIDTH 32
`define OPCODE_WIDTH 7

// 总线参数
`define NODES 4
`define DATA_WIDTH 32
`define ADDR_WIDTH 32
`define NODE_ID_WIDTH 2

// 指令类型定义
`define OPCODE_LOAD     7'b0000011
`define OPCODE_STORE    7'b0100011
`define OPCODE_OP       7'b0110011
`define OPCODE_OP_IMM   7'b0010011
`define OPCODE_BRANCH   7'b1100011
`define OPCODE_JAL      7'b1101111
`define OPCODE_JALR     7'b1100111
`define OPCODE_AUIPC    7'b0010111
`define OPCODE_LUI      7'b0110111

// 功能码定义
`define FUNCT3_ADD_SUB  3'b000
`define FUNCT3_SLL      3'b001
`define FUNCT3_SLT      3'b010
`define FUNCT3_SLTU     3'b011
`define FUNCT3_XOR      3'b100
`define FUNCT3_SRL_SRA  3'b101
`define FUNCT3_OR       3'b110
`define FUNCT3_AND      3'b111

// Ring总线状态定义
`define STATE_IDLE      2'b00
`define STATE_ARB       2'b01
`define STATE_DATA      2'b10
`define STATE_ACK       2'b11

// 内存映射
`define MEM_BASE        32'h0000_0000
`define MEM_SIZE        32'h0001_0000
`define IO_BASE         32'h1000_0000
`define IO_SIZE         32'h0001_0000
