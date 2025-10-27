
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"
`include "riscv_isa.v"

module RV64I (
    input  wire                   clk,
    input  wire                   reset,

    input  wire [`WordAddrBus]    id_pc_i,
    input  wire [`WordDataBus]    id_insn_i,
    input  wire                   id_en_i,

    input  wire [`WordDataBus]    in0_i,
    input  wire [`WordDataBus]    in1_i,
    input  wire [`AluOpBus]       op_i,
    output reg  [`WordDataBus]    result_o,
    output reg                    overflow_o
);

    /********** 内部信号 **********/
    wire signed [`WordDataBus] s_in_0 = $signed(in0_i);
    wire signed [`WordDataBus] s_in_1 = $signed(in1_i);
    wire signed [`WordDataBus] s_out  = $signed(result_o);
    wire [6:0] opcode = id_insn_i[6:0];  // 提取指令的opcode
    wire is_32bit_inst;  // 是否为32位指令标志

    // 判断是否为32位指令（I-Type-W或R-Type-W）
    assign is_32bit_inst = (opcode == `RISCV_OPCODE_I_TYPE_W) || (opcode == `RISCV_OPCODE_R_TYPE_W);

    /********** 算术逻辑运算 **********/
    always @(*) begin
        // 先执行基本的64位运算
        case (op_i)
            `ALU_OP_AND  : begin // 逻辑与（AND）
                result_o    = in0_i & in1_i;
            end
            `ALU_OP_OR   : begin // 逻辑或（OR）
                result_o    = in0_i | in1_i;
            end
            `ALU_OP_XOR  : begin // 逻辑异或（XOR）
                result_o    = in0_i ^ in1_i;
            end
            `ALU_OP_ADDS : begin // 有符号加法 (ADD, ADDI)
                result_o    = in0_i + in1_i;
            end
            `ALU_OP_ADDU : begin // 无符号加法 (LUI, AUIPC)
                result_o    = in0_i + in1_i;
            end
            `ALU_OP_SUBS : begin // 有符号减法 (SUB, SLT, SLTI)
                result_o    = in0_i - in1_i;
            end
            `ALU_OP_SUBU : begin // 无符号减法 (SLTU, SLTIU)
                result_o    = in0_i - in1_i;
            end
            `ALU_OP_SHRL : begin
                // 区分逻辑右移(SRL/SRLI/SRLIW)和算术右移(SRA/SRAI/SRAIW)
                // 检查func7字段: 0000000表示逻辑右移，0100000表示算术右移
                if (id_insn_i[30] == 1'b1) begin
                    // 算术右移 (SRA, SRAI, SRAIW)
                    result_o = $signed(in0_i) >>> in1_i[`ShAmountLoc];
                end else begin
                    // 逻辑右移 (SRL, SRLI, SRLIW)
                    result_o = in0_i >> in1_i[`ShAmountLoc];
                end
            end
            `ALU_OP_SHLL : begin // 逻辑左移 (SLL, SLLI)
                result_o    = in0_i << in1_i[`ShAmountLoc];
            end
            default      : begin // 默认值 (No Operation)
                result_o    = in0_i;
            end
        endcase

        // 对于32位指令，截断结果到32位并符号扩展
        if (is_32bit_inst) begin
            // 先截断到32位
            result_o = {result_o[31:0]};
            // 然后进行符号扩展到64位
            result_o = {{32{result_o[31]}}, result_o[31:0]};
        end
    end

    /********** 溢出检测 **********/
    always @(*) begin
        case (op_i)
            `ALU_OP_ADDS : begin // 加法溢出检测 (ADD, ADDI)
                if (((s_in_0 > 0) && (s_in_1 > 0) && (s_out < 0)) ||
                    ((s_in_0 < 0) && (s_in_1 < 0) && (s_out > 0))) begin
                    overflow_o = `ENABLE;
                end else begin
                    overflow_o = `DISABLE;
                end
            end
            `ALU_OP_SUBS : begin // 减法溢出检测 (SUB)
                if (((s_in_0 < 0) && (s_in_1 > 0) && (s_out > 0)) ||
                    ((s_in_0 > 0) && (s_in_1 < 0) && (s_out < 0))) begin
                    overflow_o = `ENABLE;
                end else begin
                    overflow_o = `DISABLE;
                end
            end
            default     : begin // 默认值
                overflow_o = `DISABLE;
            end
        endcase
    end

endmodule