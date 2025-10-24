/********** 通用头文件 **********/

`include "global_config.v"
`include "stddef.v"

/********** 单个头文件 **********/
`include "cpu.v"
`include "riscv_isa.v"

/********** 模块 **********/
module RV64M (
	input  wire [`WordDataBus] in_0,  // 输入 0
	input  wire [`WordDataBus] in_1,  // 输入 1
	input  wire [`AluOpBus]    op,    // 操作
	output reg  [`WordDataBus] out    // 输出
);

	/********** 内部信号 **********/
	wire signed [`WordDataBus] s_in_0 = $signed(in_0); // 有符号输入 0
	wire signed [`WordDataBus] s_in_1 = $signed(in_1); // 有符号输入 1

	// 用于存储64位乘法结果的临时变量
	reg [63:0] mul_result;
	// 用于存储有符号×无符号乘法结果的临时变量
	reg [63:0] mulhsu_result;
	// 用于存储无符号×无符号乘法结果的临时变量
	reg [63:0] mulhu_result;

	/********** 乘除法运算 **********/
	always @(*) begin
		// 计算各种乘法结果，以备后续使用
		mul_result = {{32{in_0[31]}}, in_0} * {{32{in_1[31]}}, in_1}; // 有符号×有符号
		mulhsu_result = {{32{in_0[31]}}, in_0} * {32'b0, in_1}; // 有符号×无符号
		mulhu_result = {32'b0, in_0} * {32'b0, in_1}; // 无符号×无符号

		case (op)
			`ALU_OP_MUL : begin // 乘法（结果低32位）
				out = mul_result[31:0];
			end
			`ALU_OP_MULH : begin // 高位乘法（有符号×有符号）
				out = mul_result[63:32];
			end
			`ALU_OP_MULHSU : begin // 高位乘法（有符号×无符号）
				out = mulhsu_result[63:32];
			end
			`ALU_OP_MULHU : begin // 高位乘法（无符号×无符号）
				out = mulhu_result[63:32];
			end
			`ALU_OP_DIV : begin // 有符号除法
				if (in_1 == 0) begin
					// 除以零，根据RISC-V规范返回全1
					out = {`WORD_DATA_W{1'b1}};
				end else if (in_0 == {1'b1, {31{1'b0}}} && in_1 == {32{1'b1}}) begin
					// -2^31 / -1，根据RISC-V规范返回-2^31
					out = {1'b1, {31{1'b0}}};
				end else begin
					out = $signed(in_0) / $signed(in_1);
				end
			end
			`ALU_OP_DIVU : begin // 无符号除法
				if (in_1 == 0) begin
					// 除以零，根据RISC-V规范返回全1
					out = {`WORD_DATA_W{1'b1}};
				end else begin
					out = in_0 / in_1;
				end
			end
			default : begin // 默认值
				out = 0;
			end
		endcase
	end

endmodule