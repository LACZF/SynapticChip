
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"
`include "riscv_isa.v"

module RV64I (
	input  wire			       clk,
	input  wire			       reset,
	input  wire [`WordDataBus] id_insn_i,

	input  wire [`WordDataBus] in_0_i,  // 输入 0
	input  wire [`WordDataBus] in_1_i,  // 输入 1
	input  wire [`AluOpBus]    op_i,    // 操作
	output reg  [`WordDataBus] out_o,   // 输出
	output reg                 of_o     // 溢出
);

	/********** 内部信号 **********/
	wire signed [`WordDataBus] s_in_0 = $signed(in_0_i); // 有符号输入 0
	wire signed [`WordDataBus] s_in_1 = $signed(in_1_i); // 有符号输入 1
	wire signed [`WordDataBus] s_out  = $signed(out_o);  // 有符号输出

	/********** 算术逻辑运算 **********/
	always @(*) begin
		case (op_i)
			`ALU_OP_AND  : begin // 逻辑与（AND）
				out_o    = in_0_i & in_1_i;
			end
			`ALU_OP_OR   : begin // 逻辑或（OR）
				out_o    = in_0_i | in_1_i;
			end
			`ALU_OP_XOR  : begin // 逻辑异或（XOR）
				out_o    = in_0_i ^ in_1_i;
			end
			`ALU_OP_ADDS : begin // 有符号加法 (ADD, ADDI)
				out_o    = in_0_i + in_1_i;
			end
			`ALU_OP_ADDU : begin // 无符号加法 (LUI, AUIPC)
				out_o    = in_0_i + in_1_i;
			end
			`ALU_OP_SUBS : begin // 有符号减法 (SUB, SLT, SLTI)
				out_o    = in_0_i - in_1_i;
			end
			`ALU_OP_SUBU : begin // 无符号减法 (SLTU, SLTIU)
				out_o    = in_0_i - in_1_i;
			end
			`ALU_OP_SHRL : begin // 逻辑右移 (SRL, SRLI)
				out_o    = in_0_i >> in_1_i[`ShAmountLoc];
			end
			`ALU_OP_SHLL : begin // 逻辑左移 (SLL, SLLI)
				out_o    = in_0_i << in_1_i[`ShAmountLoc];
			end
			default      : begin // 默认值 (No Operation)
				out_o    = in_0_i;
			end
		endcase
	end

	/********** 溢出检测 **********/
	always @(*) begin
		case (op_i)
			`ALU_OP_ADDS : begin // 加法溢出检测 (ADD, ADDI)
				if (((s_in_0 > 0) && (s_in_1 > 0) && (s_out < 0)) ||
					((s_in_0 < 0) && (s_in_1 < 0) && (s_out > 0))) begin
					of_o = `ENABLE;
				end else begin
					of_o = `DISABLE;
				end
			end
			`ALU_OP_SUBS : begin // 减法溢出检测 (SUB)
				if (((s_in_0 < 0) && (s_in_1 > 0) && (s_out > 0)) ||
					((s_in_0 > 0) && (s_in_1 < 0) && (s_out < 0))) begin
					of_o = `ENABLE;
				end else begin
					of_o = `DISABLE;
				end
			end
			default     : begin // 默认值
				of_o = `DISABLE;
			end
		endcase
	end

endmodule