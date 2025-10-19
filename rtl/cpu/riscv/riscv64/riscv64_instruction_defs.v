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
`define FUNCT3_BLT       3'b100  // BLT
`define FUNCT3_BGE       3'b101  // BGE
`define FUNCT3_BLTU      3'b110  // BLTU
`define FUNCT3_BGEU      3'b111  // BGEU

// 乘法指令专用宏定义
`define FUNCT3_MUL       3'b000  // MUL
`define FUNCT3_MULH      3'b001  // MULH
`define FUNCT3_MULHSU    3'b010  // MULHSU
`define FUNCT3_MULHU     3'b011  // MULHU
`define FUNCT3_DIV       3'b100  // DIV
`define FUNCT3_DIVU      3'b101  // DIVU
`define FUNCT3_REM       3'b110  // REM
`define FUNCT3_REMU      3'b111  // REMU

// 原子操作指令专用宏定义
`define FUNCT3_LR_D      3'b010  // LR.D
`define FUNCT3_SC_D      3'b010  // SC.D
`define FUNCT3_AMOSWAP_D 3'b001  // AMOSWAP.D
`define FUNCT3_AMOADD_D  3'b010  // AMOADD.D
`define FUNCT3_AMOXOR_D  3'b011  // AMOXOR.D
`define FUNCT3_AMOAND_D  3'b100  // AMOAND.D
`define FUNCT3_AMOOR_D   3'b101  // AMOOR.D
`define FUNCT3_AMOMIN_D  3'b110  // AMOMIN.D
`define FUNCT3_AMOMINU_D 3'b111  // AMOMINU.D
`define FUNCT3_AMOMAX_D  3'b110  // AMOMAX.D (复用AMOMIN_D的funct3，通过funct7区分)
`define FUNCT3_AMOMAXU_D 3'b111  // AMOMAXU_D (复用AMOMINU_D的funct3，通过funct7区分)

// 浮点指令专用宏定义
`define FUNCT3_FADD_S    3'b000  // FADD.S
`define FUNCT3_FSUB_S    3'b000  // FSUB.S
`define FUNCT3_FMUL_S    3'b001  // FMUL.S
`define FUNCT3_FDIV_S    3'b010  // FDIV.S
`define FUNCT3_FSQRT_S   3'b011  // FSQRT.S
`define FUNCT3_FCMP_S    3'b010  // FCMP.S
`define FUNCT3_FCVT_W_S  3'b101  // FCVT.W.S
`define FUNCT3_FCVT_WU_S 3'b111  // FCVT.WU.S
`define FUNCT3_FCVT_S_W  3'b101  // FCVT.S.W
`define FUNCT3_FCVT_S_WU 3'b111  // FCVT.S.WU

`define FUNCT3_FADD_D    3'b000  // FADD.D
`define FUNCT3_FSUB_D    3'b000  // FSUB.D
`define FUNCT3_FMUL_D    3'b001  // FMUL.D
`define FUNCT3_FDIV_D    3'b010  // FDIV.D
`define FUNCT3_FSQRT_D   3'b011  // FSQRT.D
`define FUNCT3_FCMP_D    3'b010  // FCMP.D
`define FUNCT3_FCVT_L_D  3'b101  // FCVT.L.D
`define FUNCT3_FCVT_LU_D 3'b111  // FCVT.LU.D
`define FUNCT3_FCVT_D_L  3'b101  // FCVT.D.L
`define FUNCT3_FCVT_D_LU 3'b111  // FCVT.D.LU
`define FUNCT3_FCVT_D_S  3'b100  // FCVT.D.S
`define FUNCT3_FCVT_S_D  3'b100  // FCVT.S.D

`define FUNCT3_FADD_Q    3'b000  // FADD.Q
`define FUNCT3_FSUB_Q    3'b000  // FSUB.Q
`define FUNCT3_FMUL_Q    3'b001  // FMUL.Q
`define FUNCT3_FDIV_Q    3'b010  // FDIV.Q
`define FUNCT3_FSQRT_Q   3'b011  // FSQRT.Q
`define FUNCT3_FCMP_Q    3'b010  // FCMP.Q
`define FUNCT3_FCVT_Q_D  3'b100  // FCVT.Q.D
`define FUNCT3_FCVT_D_Q  3'b100  // FCVT.D.Q

// Zfh半精度浮点指令专用宏定义
`define FUNCT3_FADD_H    3'b000  // FADD.H
`define FUNCT3_FSUB_H    3'b000  // FSUB.H
`define FUNCT3_FMUL_H    3'b001  // FMUL.H
`define FUNCT3_FDIV_H    3'b010  // FDIV.H
`define FUNCT3_FSQRT_H   3'b011  // FSQRT.H
`define FUNCT3_FCMP_H    3'b010  // FCMP.H
`define FUNCT3_FCVT_W_H  3'b101  // FCVT.W.H
`define FUNCT3_FCVT_WU_H 3'b111  // FCVT.WU.H
`define FUNCT3_FCVT_H_W  3'b101  // FCVT.H.W
`define FUNCT3_FCVT_H_WU 3'b111  // FCVT.H.WU
`define FUNCT3_FCVT_S_H  3'b100  // FCVT.S.H
`define FUNCT3_FCVT_H_S  3'b100  // FCVT.H.S
`define FUNCT3_FCVT_D_H  3'b100  // FCVT.D.H
`define FUNCT3_FCVT_H_D  3'b100  // FCVT.H.D

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

// 扩展指令集opcode定义
`define OPCODE_ATOMIC     7'b0101111  // 原子操作指令
`define OPCODE_FLOAT_ARITH 7'b1010011 // 单精度浮点算术指令
`define OPCODE_DOUBLE_ARITH 7'b1010011 // 双精度浮点算术指令（与单精度复用opcode，通过funct7区分）
`define OPCODE_QUAD_ARITH 7'b1010011  // 四精度浮点算术指令（与单精度复用opcode，通过funct7区分）
`define OPCODE_HALF_FLOAT_ARITH 7'b1010011 // 半精度浮点算术指令（与单精度复用opcode，通过funct7区分）
`define OPCODE_VECTOR_ARITH 7'b1010111 // 向量指令opcode

// Zifencei扩展指令定义
`define FENCE_I_OPCODE    7'b0001111  // FENCE.I指令opcode
`define FENCE_I_FUNCT3    3'b001      // FENCE.I指令funct3

// Zicsr扩展指令定义
`define CSRRW_OPCODE      7'b1110011  // CSRRW指令opcode
`define CSRRS_OPCODE      7'b1110011  // CSRRS指令opcode
`define CSRRC_OPCODE      7'b1110011  // CSRRC指令opcode
`define CSRRWI_OPCODE     7'b1110011  // CSRRWI指令opcode
`define CSRRSI_OPCODE     7'b1110011  // CSRRSI指令opcode
`define CSRRCI_OPCODE     7'b1110011  // CSRRCI指令opcode

`define CSRRW_FUNCT3      3'b001      // CSRRW指令funct3
`define CSRRS_FUNCT3      3'b010      // CSRRS指令funct3
`define CSRRC_FUNCT3      3'b011      // CSRRC指令funct3
`define CSRRWI_FUNCT3     3'b101      // CSRRWI指令funct3
`define CSRRSI_FUNCT3     3'b110      // CSRRSI指令funct3
`define CSRRCI_FUNCT3     3'b111      // CSRRCI指令funct3

// ---------- RV64V 向量指令专用宏定义 ----------
`define FUNCT3_VADD_VV    3'b000  // 向量-向量加法
`define FUNCT3_VSUB_VV    3'b000  // 向量-向量减法
`define FUNCT3_VMUL_VV    3'b001  // 向量-向量乘法
`define FUNCT3_VDIV_VV    3'b010  // 向量-向量除法
`define FUNCT3_VSLL_VV    3'b011  // 向量-向量逻辑左移
`define FUNCT3_VSRL_VV    3'b011  // 向量-向量逻辑右移
`define FUNCT3_VSRA_VV    3'b011  // 向量-向量算术右移
`define FUNCT3_VAND_VV    3'b111  // 向量-向量按位与
`define FUNCT3_VOR_VV     3'b110  // 向量-向量按位或
`define FUNCT3_VXOR_VV    3'b100  // 向量-向量按位异或
`define FUNCT3_VSLT_VV    3'b101  // 向量-向量有符号比较小于
`define FUNCT3_VSLTU_VV   3'b101  // 向量-向量无符号比较小于
`define FUNCT3_VCMPEQ_VV  3'b010  // 向量-向量等于比较
`define FUNCT3_VCMPNE_VV  3'b010  // 向量-向量不等于比较
`define FUNCT3_VCMPEQ_VX  3'b010  // 向量-标量等于比较
`define FUNCT3_VCMPNE_VX  3'b010  // 向量-标量不等于比较
`define FUNCT3_VADD_VX    3'b000  // 向量-标量加法
`define FUNCT3_VSUB_VX    3'b000  // 向量-标量减法
`define FUNCT3_VMUL_VX    3'b001  // 向量-标量乘法
`define FUNCT3_VDIV_VX    3'b010  // 向量-标量除法
`define FUNCT3_VSLL_VX    3'b011  // 向量-标量逻辑左移
`define FUNCT3_VSRL_VX    3'b011  // 向量-标量逻辑右移
`define FUNCT3_VSRA_VX    3'b011  // 向量-标量算术右移
`define FUNCT3_VAND_VX    3'b111  // 向量-标量按位与
`define FUNCT3_VOR_VX     3'b110  // 向量-标量按位或
`define FUNCT3_VXOR_VX    3'b100  // 向量-标量按位异或
`define FUNCT3_VSLT_VX    3'b101  // 向量-标量有符号比较小于
`define FUNCT3_VSLTU_VX   3'b101  // 向量-标量无符号比较小于
`define FUNCT3_VLOAD      3'b010  // 向量加载指令
`define FUNCT3_VSTORE     3'b010  // 向量存储指令

// 向量指令的funct7定义
`define FUNCT7_VADD       7'b0000001  // VADD指令的funct7
`define FUNCT7_VSUB       7'b0000101  // VSUB指令的funct7
`define FUNCT7_VMUL       7'b0001001  // VMUL指令的funct7
`define FUNCT7_VDIV       7'b0001101  // VDIV指令的funct7
`define FUNCT7_VSLL       7'b0010001  // VSLL指令的funct7
`define FUNCT7_VSRL       7'b0100001  // VSRL指令的funct7
`define FUNCT7_VSRA       7'b0110001  // VSRA指令的funct7
`define FUNCT7_VAND       7'b0000001  // VAND指令的funct7
`define FUNCT7_VOR        7'b0000001  // VOR指令的funct7
`define FUNCT7_VXOR       7'b0000001  // VXOR指令的funct7
`define FUNCT7_VSLT       7'b0000001  // VSLT指令的funct7
`define FUNCT7_VSLTU      7'b0000001  // VSLTU指令的funct7
`define FUNCT7_VCMPEQ     7'b0000001  // VCMP.EQ指令的funct7
`define FUNCT7_VCMPNE     7'b0000101  // VCMP.NE指令的funct7

// ---------- 功能码定义 ----------
// funct7 用于区分 ADD/SUB, SRL/SRA 等指令
`define FUNCT7_ADD       1'b0  // ADD 指令的 funct7 位
`define FUNCT7_SUB       1'b1  // SUB 指令的 funct7 位
`define FUNCT7_SRL       1'b0  // SRL 指令的 funct7 位
`define FUNCT7_SRA       1'b1  // SRA 指令的 funct7 位

// ---------- RV64C 压缩指令集定义 ----------
// 压缩指令的opcode（16位指令格式）
`define OPCODE_C_RTYPE    2'b01  // C.R-type 指令
`define OPCODE_C_ITYPE    2'b00  // C.I-type 指令
`define OPCODE_C_STYPE    2'b10  // C.S-type 指令
`define OPCODE_C_BTYPE    2'b11  // C.B-type 指令
`define OPCODE_C_JAL      2'b01  // C.JAL 指令
`define OPCODE_C_LUI      2'b01  // C.LUI 指令
`define OPCODE_C_ADDI4SPN 2'b00  // C.ADDI4SPN 指令

// C.R-type 指令的funct4字段
`define FUNCT4_C_ADD      4'b0000  // C.ADD
`define FUNCT4_C_SUB      4'b1000  // C.SUB
`define FUNCT4_C_XOR      4'b0001  // C.XOR
`define FUNCT4_C_OR       4'b0010  // C.OR
`define FUNCT4_C_AND      4'b0011  // C.AND
`define FUNCT4_C_SLL      4'b0100  // C.SLL
`define FUNCT4_C_SRL      4'b0101  // C.SRL
`define FUNCT4_C_SRA      4'b1101  // C.SRA
`define FUNCT4_C_SLT      4'b0110  // C.SLT
`define FUNCT4_C_SLTU     4'b0111  // C.SLTU

// C.I-type 加载指令的funct3字段
`define FUNCT3_C_LW       3'b010  // C.LW
`define FUNCT3_C_LD       3'b011  // C.LD

// C.S-type 存储指令的funct3字段
`define FUNCT3_C_SW       3'b010  // C.SW
`define FUNCT3_C_SD       3'b011  // C.SD

// C.B-type 分支指令的funct3字段
`define FUNCT3_C_BEQZ     3'b000  // C.BEQZ
`define FUNCT3_C_BNEZ     3'b001  // C.BNEZ
`define FUNCT3_C_BLTZ     3'b100  // C.BLTZ
`define FUNCT3_C_BGEZ     3'b101  // C.BGEZ

// ---------- 控制信号位定义 ----------
// 用于标识指令类型和操作
`define REG_OP_BIT       15  // 标识是否为寄存器算术指令
`define ALU_OP_BITS      14:12  // ALU操作类型位
`define ALU_SRC_BIT      11  // ALU第二操作数来源选择

`endif