`ifndef RISCV64_INSTRUCTION_DEFS_V
`define RISCV64_INSTRUCTION_DEFS_V

// ------------ RISC-V 64 指令格式定义 ------------

// ---------- funct3 字段定义 ----------
// 操作数相关宏定义
`define FUNCT3_ADD_SUB   3'b000  // ADD/SUB
`define FUNCT3_SLL       3'b001  // SLL
`define FUNCT3_SLT       3'b010  // SLT
`define FUNCT3_SLTU      3'b011  // SLTU
`define FUNCT3_XOR       3'b100  // XOR
`define FUNCT3_SRL_SRA   3'b101  // SRL/SRA
`define FUNCT3_OR        3'b110  // OR
`define FUNCT3_AND       3'b111  // AND

// 分支指令专用宏定义
`define FUNCT3_BEQ       3'b000  // BEQ
`define FUNCT3_BNE       3'b001  // BNE
`define FUNCT3_BLT       3'b010  // BLT
`define FUNCT3_BGE       3'b100  // BGE
`define FUNCT3_BLTU      3'b011  // BLTU
`define FUNCT3_BGEU      3'b101  // BGEU

// ---------- alu_op 字段定义 ----------
`define ALU_OP_ADD       3'b000  // ADD
`define ALU_OP_SUB       3'b001  // SUB
`define ALU_OP_AND       3'b010  // AND
`define ALU_OP_OR        3'b011  // OR
`define ALU_OP_XOR       3'b100  // XOR
`define ALU_OP_SLT       3'b101  // SLT
`define ALU_OP_SLTU      3'b110  // SLTU
`define ALU_OP_SLL       3'b111  // SLL
`define ALU_OP_SRL       3'b101  // SRL (与SLT复用，通过funct7区分)
`define ALU_OP_SRA       3'b101  // SRA (与SLT复用，通过funct7区分)

// ---------- 指令类型定义 ----------
`define OPCODE_LUI       7'b0110111  // 立即数加载高位
`define OPCODE_AUIPC     7'b0010111  // 立即数加法到PC
`define OPCODE_JAL       7'b1101111  // 无条件跳转并链接
`define OPCODE_JALR      7'b1100111  // 寄存器间接跳转并链接
`define OPCODE_BRANCH    7'b1100011  // 条件分支指令
`define OPCODE_LOAD      7'b0000011  // 加载指令
`define OPCODE_STORE     7'b0100011  // 存储指令
`define OPCODE_IMM_ARITH 7'b0010011  // 立即数算术指令
`define OPCODE_REG_ARITH 7'b0110011  // 寄存器算术指令
`define OPCODE_SYSTEM    7'b1110011  // 系统指令
`define OPCODE_FENCE     7'b0001111  // 内存屏障指令

// ---------- 功能码定义 ----------
// funct7 用于区分 ADD/SUB, SRL/SRA 等指令
`define FUNCT7_ADD       1'b0  // ADD 指令的 funct7 位
`define FUNCT7_SUB       1'b1  // SUB 指令的 funct7 位
`define FUNCT7_SRL       1'b0  // SRL 指令的 funct7 位
`define FUNCT7_SRA       1'b1  // SRA 指令的 funct7 位

// ---------- 控制信号位定义 ----------
// 用于标识指令类型和操作
`define REG_OP_BIT       15  // 标识是否为寄存器算术指令
`define ALU_OP_BITS      14:12  // ALU操作类型位
`define ALU_SRC_BIT      11  // ALU第二操作数来源选择

`endif