
`include "global_config.v"
`include "stddef.v"

`include "riscv_isa.v"
`include "cpu.v"

module decoder (
    input  wire                   clk,
    input  wire                   reset,

    /********** IF/ID流水线寄存器 **********/
    input  wire [`WordAddrBus]    if_pc_i,             // 程序计数器
    input  wire [`WordDataBus]    if_insn_i,           // 指令
    input  wire                   if_en_i,             // 流水线数据的有效标志位
    /********** GPR接口 **********/
    input  wire [`WordDataBus]    gpr_rd_data0_i,     // 读取数据 0
    input  wire [`WordDataBus]    gpr_rd_data1_i,     // 读取数据 1
    output wire [`RegAddrBus]     gpr_rd_addr0_o,     // 读取地址 0
    output wire [`RegAddrBus]     gpr_rd_addr1_o,     // 读取地址 1
    /********** 数据直通 **********/
    // 来自ID阶段的数据直通
    input  wire                   id_en_i,             // 流水线数据有效
    input  wire [`RegAddrBus]     id_dst_addr_i,       // 写入地址
    input  wire                   id_gpr_we_n_i,        // 写入有效
    input  wire [`MemOpBus]       id_mem_op_i,         // 内存操作
    // 来自EX阶段的数据直通
    input  wire                   ex_en_i,             // 流水线数据有效
    input  wire [`RegAddrBus]     ex_dst_addr_i,       // 写入地址
    input  wire                   ex_gpr_we_n_i,        // 写入有效
    input  wire [`WordDataBus]    ex_fwd_data_i,       // 数据直通
    // 来自MEM阶段的数据直通
    input  wire [`WordDataBus]    mem_fwd_data_i,      // 数据直通
    /********** 控制寄存器接口 **********/
    input  wire [`CpuExeModeBus]  exe_mode_i,          // 执行模式
    input  wire [`WordDataBus]    creg_rd_data_i,      // 读取的数据
    output wire [`RegAddrBus]     creg_rd_addr_o,      // 读取的地址
    /********** 解码结果 **********/
    output reg   [`AluOpBus]      alu_op_o,            // ALU操作
    output reg   [`WordDataBus]   alu_in_0_o,          // ALU输入 0
    output reg   [`WordDataBus]   alu_in_1_o,          // ALU输入 1
    output reg   [`WordAddrBus]   br_addr_o,           // 分支地址
    output reg                    br_taken_o,          // 分支成立
    output reg                    br_flag_o,           // 分支标志位
    output reg   [`MemOpBus]      mem_op_o,            // 内存操作
    output wire  [`WordDataBus]   mem_wr_data_o,       // 内存写入数据
    output reg   [`CtrlOpBus]     ctrl_op_o,           // 控制操作
    output reg   [`RegAddrBus]    dst_addr_o,          // 通用寄存器写入地址
    output reg                    gpr_we_n_o,          // 通用寄存器写入有效
    output reg   [`IsaExpBus]     exp_code_o,          // 异常代码
    output reg                    ld_hazard_o          // Load冒险
);

    /********** 指令字段 **********/
    wire [6:0]        opcode    = if_insn_i[6:0];           // 操作码
    wire [4:0]        rd        = if_insn_i[11:7];          // 目标寄存器地址
    wire [2:0]        func3     = if_insn_i[14:12];         // 功能码3
    wire [4:0]        rs1       = if_insn_i[19:15];         // 源寄存器1地址
    wire [4:0]        rs2       = if_insn_i[24:20];         // 源寄存器2地址
    wire [6:0]        func7     = if_insn_i[31:25];         // 功能码7

    // I型立即数
    wire [`WordDataBus] i_imm    = {{20{if_insn_i[31]}}, if_insn_i[31:20]};
    // S型立即数
    wire [`WordDataBus] s_imm    = {{20{if_insn_i[31]}}, if_insn_i[31:25], if_insn_i[11:7]};
    // B型立即数
    wire [`WordDataBus] b_imm    = {{19{if_insn_i[31]}}, if_insn_i[31], if_insn_i[7], if_insn_i[30:25], if_insn_i[11:8], 1'b0};
    // U型立即数
    wire [`WordDataBus] u_imm    = {if_insn_i[31:12], 12'b0};
    // J型立即数
    wire [`WordDataBus] j_imm    = {{31{if_insn_i[31]}}, if_insn_i[31], if_insn_i[19:12], if_insn_i[20], if_insn_i[30:21], 1'b0};

    /********** 寄存器读取地址 **********/
    assign gpr_rd_addr0_o  = rs1; // 寄存器读取地址 0
    assign gpr_rd_addr1_o  = rs2; // 寄存器读取地址 1
    assign creg_rd_addr_o  = rs1; // 控制寄存器读取地址
    /********** 从通用寄存器读取的数据 **********/
    reg         [`WordDataBus]  ra_data;                           // Ra寄存器读取的数据（无符号）
    wire signed [`WordDataBus]  s_ra_data     = $signed(ra_data);  // Ra寄存器读取的数据（有符号）
    reg         [`WordDataBus]  rb_data;                           // Rb寄存器读取的数据（无符号）
    wire signed [`WordDataBus]  s_rb_data     = $signed(rb_data);  // Rb寄存器读取的数据（有符号）
    assign                      mem_wr_data_o = rb_data;           // 内存写入数据
    /********** 地址 **********/
    wire [`WordDataBus] alu_result; // 中间结果信号
    assign              alu_result = ra_data + i_imm;
    wire [`WordAddrBus] ret_addr   = if_pc_i;                           // 返回地址
    wire [`WordAddrBus] br_target  = if_pc_i + b_imm[`WORD_ADDR_MSB:0];     // 分支目标地址
    wire [`WordAddrBus] jr_target  = alu_result[`WordAddrLoc];              // 跳转目标地址 (JALR)
    wire [`WordAddrBus] j_target   = if_pc_i + j_imm[`WORD_ADDR_MSB:0] - 4; // JAL目标地址

    /********** 数据直通 **********/
    always @(*) begin
        /* Ra寄存器 */
        if ((id_en_i == `ENABLE) && (id_gpr_we_n_i == `ENABLE_N) &&
            (id_dst_addr_i == rs1)) begin
            ra_data = ex_fwd_data_i;     // 来自EX阶段的数据直通
        end else if ((ex_en_i == `ENABLE) && (ex_gpr_we_n_i == `ENABLE_N) &&
             (ex_dst_addr_i == rs1)) begin
            ra_data = mem_fwd_data_i;     // 来自MEM阶段的数据直通
        end else begin
            ra_data = gpr_rd_data0_i; // 从寄存器堆读取
        end
        /* Rb寄存器 */
        if ((id_en_i == `ENABLE) && (id_gpr_we_n_i == `ENABLE_N) &&
            (id_dst_addr_i == rs2)) begin
            rb_data = ex_fwd_data_i;     // 来自EX阶段的数据直通
        end else if ((ex_en_i == `ENABLE) && (ex_gpr_we_n_i == `ENABLE_N) &&
             (ex_dst_addr_i == rs2)) begin
            rb_data = mem_fwd_data_i;     // 来自MEM阶段的数据直通
        end else begin
            rb_data = gpr_rd_data1_i; // 从寄存器堆读取
        end
    end

    /********** Load冒险检测 **********/
    always @(*) begin
        if ((id_en_i == `ENABLE) && (id_mem_op_i == `MEM_OP_LDW) &&
            ((id_dst_addr_i == rs1) || (id_dst_addr_i == rs2))) begin
            ld_hazard_o = `ENABLE;  // Load冒险
        end else begin
            ld_hazard_o = `DISABLE; // 冒险未发生
        end
    end

    /********** 指令解码 **********/
    always @(*) begin
        /* 默认值 */
        alu_op_o    = `ALU_OP_NOP;
        alu_in_0_o  = ra_data;
        alu_in_1_o  = rb_data;
        br_taken_o  = `DISABLE;
        br_flag_o   = `DISABLE;
        br_addr_o   = {`WORD_ADDR_W{1'b0}};
        mem_op_o    = `MEM_OP_NOP;
        ctrl_op_o   = `CTRL_OP_NOP;
        dst_addr_o  = rd;
        gpr_we_n_o  = `DISABLE_N;
        exp_code_o  = `RISCV_EXP_NO_EXP;

        if (if_en_i == `ENABLE) begin
            case (opcode)
                // R-Type 指令
                `RISCV_OPCODE_R_TYPE: begin
                    case (func3)
                        `RISCV_FUNC3_ADD_SUB: begin
                            if (func7 == `RISCV_FUNC7_ADD) begin
                                // ADD 指令
                                alu_op_o   = `ALU_OP_ADDS;
                                gpr_we_n_o = `ENABLE_N;
                            end else if (func7 == `RISCV_FUNC7_SUB) begin
                                // SUB 指令
                                alu_op_o   = `ALU_OP_SUBS;
                                gpr_we_n_o = `ENABLE_N;
                            end
                        end
                        `RISCV_FUNC3_SLL: begin
                            // SLL 指令
                            alu_op_o   = `ALU_OP_SHLL;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SLT: begin
                            // SLT 指令
                            alu_op_o   = `ALU_OP_SUBS;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SLTU: begin
                            // SLTU 指令
                            alu_op_o   = `ALU_OP_SUBU;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_XOR: begin
                            // XOR 指令
                            alu_op_o   = `ALU_OP_XOR;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SRL_SRA: begin
                            if (func7 == `RISCV_FUNC7_SRL) begin
                                // SRL 指令
                                alu_op_o   = `ALU_OP_SHRL;
                                gpr_we_n_o = `ENABLE_N;
                            end else if (func7 == `RISCV_FUNC7_SRA) begin
                                // SRA 指令
                                alu_op_o   = `ALU_OP_SHRL;
                                gpr_we_n_o = `ENABLE_N;
                            end
                        end
                        `RISCV_FUNC3_OR: begin
                            // OR 指令
                            alu_op_o   = `ALU_OP_OR;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_AND: begin
                            // AND 指令
                            alu_op_o   = `ALU_OP_AND;
                            gpr_we_n_o = `ENABLE_N;
                        end
                    endcase
                end

                // I-Type 指令
                `RISCV_OPCODE_I_TYPE: begin
                    case (func3)
                        `RISCV_FUNC3_ADDI: begin
                            // ADDI 指令
                            alu_op_o   = `ALU_OP_ADDS;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SLTI: begin
                            // SLTI 指令
                            alu_op_o   = `ALU_OP_SUBS;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SLTIU: begin
                            // SLTIU 指令
                            alu_op_o   = `ALU_OP_SUBU;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_XORI: begin
                            // XORI 指令
                            alu_op_o   = `ALU_OP_XOR;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_ORI: begin
                            // ORI 指令
                            alu_op_o   = `ALU_OP_OR;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_ANDI: begin
                            // ANDI 指令
                            alu_op_o   = `ALU_OP_AND;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SLLI: begin
                            // SLLI 指令
                            alu_op_o   = `ALU_OP_SHLL;
                            alu_in_1_o = i_imm;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_SRLI_SRAI: begin
                            if (func7 == 7'b0000000) begin
                                // SRLI 指令
                                alu_op_o   = `ALU_OP_SHRL;
                                alu_in_1_o = i_imm;
                                gpr_we_n_o = `ENABLE_N;
                            end else if (func7 == 7'b0100000) begin
                                // SRAI 指令
                                alu_op_o   = `ALU_OP_SHRL;
                                alu_in_1_o = i_imm;
                                gpr_we_n_o = `ENABLE_N;
                            end
                        end
                    endcase
                end

                // 加载指令
                `RISCV_OPCODE_LOAD: begin
                    case (func3)
                        `RISCV_FUNC3_LB: begin
                            // LB 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = i_imm;
                            mem_op_o   = `MEM_OP_LDW;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_LH: begin
                            // LH 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = i_imm;
                            mem_op_o   = `MEM_OP_LDW;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_LW: begin
                            // LW 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = i_imm;
                            mem_op_o   = `MEM_OP_LDW;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_LBU: begin
                            // LBU 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = i_imm;
                            mem_op_o   = `MEM_OP_LDW;
                            gpr_we_n_o = `ENABLE_N;
                        end
                        `RISCV_FUNC3_LHU: begin
                            // LHU 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = i_imm;
                            mem_op_o   = `MEM_OP_LDW;
                            gpr_we_n_o = `ENABLE_N;
                        end
                    endcase
                end

                // 存储指令
                `RISCV_OPCODE_STORE: begin
                    case (func3)
                        `RISCV_FUNC3_SB: begin
                            // SB 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = s_imm;
                            mem_op_o   = `MEM_OP_STW;
                        end
                        `RISCV_FUNC3_SH: begin
                            // SH 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = s_imm;
                            mem_op_o   = `MEM_OP_STW;
                        end
                        `RISCV_FUNC3_SW: begin
                            // SW 指令
                            alu_op_o   = `ALU_OP_ADDU;
                            alu_in_1_o = s_imm;
                            mem_op_o   = `MEM_OP_STW;
                        end
                    endcase
                end

                // 分支指令
                `RISCV_OPCODE_B_TYPE: begin
                    br_flag_o = `ENABLE;
                    br_addr_o = br_target;
                    case (func3)
                        `RISCV_FUNC3_BEQ: begin
                            // BEQ 指令
                            br_taken_o = (ra_data == rb_data) ? `ENABLE : `DISABLE;
                        end
                        `RISCV_FUNC3_BNE: begin
                            // BNE 指令
                            br_taken_o = (ra_data != rb_data) ? `ENABLE : `DISABLE;
                        end
                        `RISCV_FUNC3_BLT: begin
                            // BLT 指令
                            br_taken_o = (s_ra_data < s_rb_data) ? `ENABLE : `DISABLE;
                        end
                        `RISCV_FUNC3_BGE: begin
                            // BGE 指令
                            br_taken_o = (s_ra_data >= s_rb_data) ? `ENABLE : `DISABLE;
                        end
                        `RISCV_FUNC3_BLTU: begin
                            // BLTU 指令
                            br_taken_o = (ra_data < rb_data) ? `ENABLE : `DISABLE;
                        end
                        `RISCV_FUNC3_BGEU: begin
                            // BGEU 指令
                            br_taken_o = (ra_data >= rb_data) ? `ENABLE : `DISABLE;
                        end
                    endcase
                end

                // JAL 指令
                `RISCV_OPCODE_J_TYPE: begin
                    // JAL 指令
                    br_flag_o  = `ENABLE;
                    br_addr_o  = j_target;
                    br_taken_o = `ENABLE;
                    // alu_in_0_o = {ret_addr, {`BYTE_OFFSET_W{1'b0}}};
                    alu_in_0_o = ret_addr;
                    gpr_we_n_o = `ENABLE_N;
                end

                // JALR 指令
                `RISCV_OPCODE_JALR: begin
                    // JALR 指令
                    br_flag_o  = `ENABLE;
                    br_addr_o  = jr_target;
                    br_taken_o = `ENABLE;
                    // alu_in_0_o = {ret_addr, {`BYTE_OFFSET_W{1'b0}}};
                    alu_in_0_o = ret_addr;
                    gpr_we_n_o = `ENABLE_N;
                end

                // LUI 指令
                `RISCV_OPCODE_U_TYPE: begin
                    // LUI 指令
                    alu_in_0_o = {`WORD_DATA_W{1'b0}};
                    alu_in_1_o = u_imm;
                    alu_op_o   = `ALU_OP_ADDU;
                    gpr_we_n_o = `ENABLE_N;
                end

                // 系统指令
                `RISCV_OPCODE_SYSTEM: begin
                    if (func3 == `RISCV_FUNC3_ECALL_EBREAK && rs1 == 5'b0 && rd == 5'b0) begin
                        if (rs2 == 5'b0) begin
                            // ECALL 指令
                            exp_code_o = `RISCV_EXP_ECALL_U;
                        end else if (rs2 == 5'b00001) begin
                            // EBREAK 指令
                            exp_code_o = `RISCV_EXP_BREAKPOINT;
                        end
                    end
                end

                // 默认值：未定义指令
                default: begin
                    exp_code_o = `RISCV_EXP_ILLEGAL_INSN;
                end
            endcase
        end
    end

endmodule