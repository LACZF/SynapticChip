/********** 通用头文件 **********/

`include "global_config.v"
`include "stddef.v"

/********** 单个头文件 **********/
`include "cpu.v"
`include "riscv_isa.v"

/********** 模块 **********/
module alu (
	input  wire [`WordDataBus] in_0,  // 输入 0
	input  wire [`WordDataBus] in_1,  // 输入 1
	input  wire [`AluOpBus]    op,    // 操作
	output reg  [`WordDataBus] out,   // 输出
	output reg                 of     // 溢出
);
	// 内部信号
	wire [`WordDataBus] base_out;
	wire base_of;
	wire [`WordDataBus] muldiv_out;

	// 实例化基本ALU模块（RV64I指令集）
	RV64I rv64i (
		.in_0(in_0),
		.in_1(in_1),
		.op(op),
		.out(base_out),
		.of(base_of)
	);

	// 实例化乘除法ALU模块（RV64M指令集）
	`ifdef SUPPORT_RV64M
		RV64M rv64m (
			.in_0(in_0),
			.in_1(in_1),
			.op(op),
			.out(muldiv_out)
		);
	`else
		// 如果不支持RV64M，将乘除输出设为0
		assign muldiv_out = 0;
	`endif

	// 根据操作码选择输出
	always @(*) begin
		`ifdef SUPPORT_RV64M
			case (op)
				// 选择乘除法操作的输出
				`ALU_OP_MUL, `ALU_OP_MULH, `ALU_OP_MULHSU, `ALU_OP_MULHU,
				`ALU_OP_DIV, `ALU_OP_DIVU: begin
					out = muldiv_out;
					of = `DISABLE;
				end
				// 其他操作使用基本ALU的输出
				default: begin
					out = base_out;
					of = base_of;
				end
			endcase
		`else
			// 如果不支持RV64M，始终使用基本ALU的输出
			out = base_out;
			of = base_of;
		`endif
	end

endmodule