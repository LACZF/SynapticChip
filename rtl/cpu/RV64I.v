
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

    /********** 算术逻辑运算 **********/
    always @(*) begin
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
            `ALU_OP_SHRL : begin // 逻辑右移 (SRL, SRLI)
                result_o    = in0_i >> in1_i[`ShAmountLoc];
            end
            `ALU_OP_SHLL : begin // 逻辑左移 (SLL, SLLI)
                result_o    = in0_i << in1_i[`ShAmountLoc];
            end
            default      : begin // 默认值 (No Operation)
                result_o    = in0_i;
            end
        endcase
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