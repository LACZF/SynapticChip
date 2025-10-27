`ifndef __RISCV_ISA_HEADER__
`define __RISCV_ISA_HEADER__

/********** 包含头文件 **********/
`include "stddef.v"

/********** RISC-V 指令格式定义 **********/
// R-Type 指令
`define RISCV_OPCODE_R_TYPE    7'b0110011
`define RISCV_OPCODE_R_TYPE_W  7'b0111011  // 32位寄存器-寄存器运算指令（如addw）的opcode
`define RISCV_R_TYPE_FUNC3_LOC 14:12
`define RISCV_R_TYPE_FUNC7_LOC 31:25
`define RISCV_R_TYPE_RD_LOC    11:7
`define RISCV_R_TYPE_RS1_LOC   19:15
`define RISCV_R_TYPE_RS2_LOC   24:20

// I-Type 指令
`define RISCV_OPCODE_I_TYPE    7'b0010011
`define RISCV_OPCODE_I_TYPE_W  7'b0011011  // 32位立即数运算指令（如addiw）的opcode
`define RISCV_I_TYPE_FUNC3_LOC 14:12
`define RISCV_I_TYPE_RD_LOC    11:7
`define RISCV_I_TYPE_RS1_LOC   19:15
`define RISCV_I_TYPE_IMM_LOC   31:20

// S-Type 指令
`define RISCV_OPCODE_S_TYPE    7'b0100011
`define RISCV_S_TYPE_FUNC3_LOC 14:12
`define RISCV_S_TYPE_RS1_LOC   19:15
`define RISCV_S_TYPE_RS2_LOC   24:20
`define RISCV_S_TYPE_IMM_LO_LOC 11:7
`define RISCV_S_TYPE_IMM_HI_LOC 31:25

// B-Type 指令
`define RISCV_OPCODE_B_TYPE    7'b1100011
`define RISCV_B_TYPE_FUNC3_LOC 14:12
`define RISCV_B_TYPE_RS1_LOC   19:15
`define RISCV_B_TYPE_RS2_LOC   24:20
`define RISCV_B_TYPE_IMM11_LOC 7
`define RISCV_B_TYPE_IMM4_1_LOC 11:8
`define RISCV_B_TYPE_IMM10_5_LOC 30:25
`define RISCV_B_TYPE_IMM12_LOC 31

// U-Type 指令
`define RISCV_OPCODE_U_TYPE    7'b0110111
`define RISCV_U_TYPE_RD_LOC    11:7
`define RISCV_U_TYPE_IMM_LOC   31:12

// J-Type 指令
`define RISCV_OPCODE_J_TYPE    7'b1101111
`define RISCV_J_TYPE_RD_LOC    11:7
`define RISCV_J_TYPE_IMM20_LOC 31
`define RISCV_J_TYPE_IMM10_1_LOC 30:21
`define RISCV_J_TYPE_IMM11_LOC 20
`define RISCV_J_TYPE_IMM19_12_LOC 19:12

// 加载/存储指令
`define RISCV_OPCODE_LOAD      7'b0000011
`define RISCV_OPCODE_STORE     7'b0100011

// 特殊指令
`define RISCV_OPCODE_FENCE     7'b0001111
`define RISCV_OPCODE_SYSTEM    7'b1110011
`define RISCV_OPCODE_JALR      7'b1100111

/********** 功能码定义 **********/
// R-Type 功能码
`define RISCV_FUNC3_ADD_SUB    3'b000
`define RISCV_FUNC3_SLL        3'b001
`define RISCV_FUNC3_SLT        3'b010
`define RISCV_FUNC3_SLTU       3'b011
`define RISCV_FUNC3_XOR        3'b100
`define RISCV_FUNC3_SRL_SRA    3'b101
`define RISCV_FUNC3_OR         3'b110
`define RISCV_FUNC3_AND        3'b111

`define RISCV_FUNC7_ADD        7'b0000000
`define RISCV_FUNC7_SUB        7'b0100000
`define RISCV_FUNC7_SRL        7'b0000000
`define RISCV_FUNC7_SRA        7'b0100000

// R-Type-W 32位寄存器-寄存器运算指令功能码
`define RISCV_FUNC3_ADDW       3'b000  // ADDW 使用与 ADD 相同的 func3
`define RISCV_FUNC3_SUBW       3'b000  // SUBW 使用与 SUB 相同的 func3
`define RISCV_FUNC3_SLLW       3'b001  // SLLW 使用与 SLL 相同的 func3
`define RISCV_FUNC3_SRLW       3'b101  // SRLW 使用与 SRL 相同的 func3
`define RISCV_FUNC3_SRAW       3'b101  // SRAW 使用与 SRA 相同的 func3
`define RISCV_FUNC7_W          7'b0000001  // 32位指令的func7标识位

// I-Type 功能码
`define RISCV_FUNC3_ADDI       3'b000
`define RISCV_FUNC3_ADDIW      3'b000  // ADDIW 使用与 ADDI 相同的 func3
`define RISCV_FUNC3_SLLIW      3'b001  // SLLIW 使用与 SLLI 相同的 func3
`define RISCV_FUNC3_SRLIW      3'b101  // SRLIW 使用与 SRLI 相同的 func3
`define RISCV_FUNC3_SRAIW      3'b101  // SRAIW 使用与 SRAI 相同的 func3
`define RISCV_FUNC3_SLTI       3'b010
`define RISCV_FUNC3_SLTIU      3'b011
`define RISCV_FUNC3_XORI       3'b100
`define RISCV_FUNC3_ORI        3'b110
`define RISCV_FUNC3_ANDI       3'b111
`define RISCV_FUNC3_SLLI       3'b001
`define RISCV_FUNC3_SRLI_SRAI  3'b101

// 加载/存储功能码
`define RISCV_FUNC3_LB         3'b000
`define RISCV_FUNC3_LH         3'b001
`define RISCV_FUNC3_LW         3'b010
`define RISCV_FUNC3_LBU        3'b100
`define RISCV_FUNC3_LHU        3'b101
`define RISCV_FUNC3_SB         3'b000
`define RISCV_FUNC3_SH         3'b001
`define RISCV_FUNC3_SW         3'b010

// 分支功能码
`define RISCV_FUNC3_BEQ        3'b000
`define RISCV_FUNC3_BNE        3'b001
`define RISCV_FUNC3_BLT        3'b100
`define RISCV_FUNC3_BGE        3'b101
`define RISCV_FUNC3_BLTU       3'b110
`define RISCV_FUNC3_BGEU       3'b111

// 系统指令功能码
`define RISCV_FUNC3_ECALL_EBREAK 3'b000

/********** 异常代码 **********/
`define RISCV_EXP_NO_EXP       5'd0
`define RISCV_EXP_INSN_ADDR_MISS 5'd1
`define RISCV_EXP_INSN_ACCESS_FAULT 5'd2
`define RISCV_EXP_ILLEGAL_INSN 5'd3
`define RISCV_EXP_BREAKPOINT   5'd4
`define RISCV_EXP_LOAD_ADDR_MISS 5'd5
`define RISCV_EXP_LOAD_ACCESS_FAULT 5'd6
`define RISCV_EXP_STORE_ADDR_MISS 5'd7
`define RISCV_EXP_STORE_ACCESS_FAULT 5'd8
`define RISCV_EXP_ECALL_U      5'd9
`define RISCV_EXP_ECALL_S      5'd10
`define RISCV_EXP_ECALL_M      5'd11

`endif // __RISCV_ISA_HEADER__