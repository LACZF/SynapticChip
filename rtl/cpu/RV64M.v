
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"
`include "riscv_isa.v"

module RV64M (
	input  wire			       clk,
	input  wire			       reset,
	input  wire [`WordDataBus] id_insn_i,

	input  wire [`WordDataBus] in0_i,  // 输入 0
	input  wire [`WordDataBus] in1_i,  // 输入 1
	input  wire [`AluOpBus]    op_i,    // 操作
	output reg  [`WordDataBus] result_o    // 输出
);

	/********** 内部信号 **********/
	wire signed [`WordDataBus] s_in_0 = $signed(in0_i); // 有符号输入 0
	wire signed [`WordDataBus] s_in_1 = $signed(in1_i); // 有符号输入 1

	// 用于存储64位乘法结果的临时变量
	reg [63:0] mul_result;
	// 用于存储有符号×无符号乘法结果的临时变量
	reg [63:0] mulhsu_result;
	// 用于存储无符号×无符号乘法结果的临时变量
	reg [63:0] mulhu_result;

	/********** 乘除法运算 **********/
	always @(*) begin
		// 计算各种乘法结果，以备后续使用
		mul_result = {{32{in0_i[31]}}, in0_i} * {{32{in1_i[31]}}, in1_i}; // 有符号×有符号
		mulhsu_result = {{32{in0_i[31]}}, in0_i} * {32'b0, in1_i}; // 有符号×无符号
		mulhu_result = {32'b0, in0_i} * {32'b0, in1_i}; // 无符号×无符号

		case (op_i)
			`ALU_OP_MUL : begin // 乘法（结果低32位）
				result_o = mul_result[31:0];
			end
			`ALU_OP_MULH : begin // 高位乘法（有符号×有符号）
				result_o = mul_result[63:32];
			end
			`ALU_OP_MULHSU : begin // 高位乘法（有符号×无符号）
				result_o = mulhsu_result[63:32];
			end
			`ALU_OP_MULHU : begin // 高位乘法（无符号×无符号）
				result_o = mulhu_result[63:32];
			end
			`ALU_OP_DIV : begin // 有符号除法
				if (in1_i == 0) begin
					// 除以零，根据RISC-V规范返回全1
					result_o = {`WORD_DATA_W{1'b1}};
				end else if (in0_i == {1'b1, {31{1'b0}}} && in1_i == {32{1'b1}}) begin
					// -2^31 / -1，根据RISC-V规范返回-2^31
					result_o = {1'b1, {31{1'b0}}};
				end else begin
					result_o = $signed(in0_i) / $signed(in1_i);
				end
			end
			`ALU_OP_DIVU : begin // 无符号除法
				if (in1_i == 0) begin
					// 除以零，根据RISC-V规范返回全1
					result_o = {`WORD_DATA_W{1'b1}};
				end else begin
					result_o = in0_i / in1_i;
				end
			end
			default : begin // 默认值
				result_o = 0;
			end
		endcase
	end

endmodule