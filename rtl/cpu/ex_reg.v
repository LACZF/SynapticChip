/********** 通用头文件 **********/

`include "global_config.v"
`include "stddef.v"

/********** 单个头文件 **********/
`include "isa.v"
`include "cpu.v"

/********** 模块 **********/
module ex_reg (
	/********** 时钟 & 复位 **********/
	input  wire				   clk,			   // 时钟
	input  wire				   reset,		   // 异步复位
	/********** ALU的输出 **********/
	input  wire [`WordDataBus] alu_out,		   // 运算结果
	input  wire				   alu_of,		   // 溢出
	/********** 流水线控制信号 **********/
	input  wire				   stall,		   // 延迟
	input  wire				   flush,		   // 刷新
	input  wire				   int_detect,	   // 中断检测
	/********** ID/EX流水线寄存器 **********/
	input  wire [`WordAddrBus] id_pc,		   // 程序计数器
	input  wire				   id_en,		   // 流水线的数据是否有效
	input  wire				   id_br_flag,	   // 分支标志位
	input  wire [`MemOpBus]	   id_mem_op,	   // 内存操作
	input  wire [`WordDataBus] id_mem_wr_data, // 内存写入数据
	input  wire [`CtrlOpBus]   id_ctrl_op,	   // 控制寄存器操作
	input  wire [`RegAddrBus]  id_dst_addr,	   // 通用寄存器写入地址
	input  wire				   id_gpr_we_,	   // 通用寄存器写入有效
	input  wire [`IsaExpBus]   id_exp_code,	   // 异常代码
	/********** EX/MEM流水线寄存器 **********/
	output reg	[`WordAddrBus] ex_pc,		   // 程序计数器
	output reg				   ex_en,		   // 流水线的数据是否有效
	output reg				   ex_br_flag,	   // 分支标志位
	output reg	[`MemOpBus]	   ex_mem_op,	   // 内存操作
	output reg	[`WordDataBus] ex_mem_wr_data, // 内存写入数据
	output reg	[`CtrlOpBus]   ex_ctrl_op,	   // 控制寄存器操作
	output reg	[`RegAddrBus]  ex_dst_addr,	   // 通用寄存器写入地址
	output reg				   ex_gpr_we_,	   // 通用寄存器写入有效
	output reg	[`IsaExpBus]   ex_exp_code,	   // 异常代码
	output reg	[`WordDataBus] ex_out		   // 处理结果
);

	/********** 流水线寄存器 **********/
	always @(posedge clk or `RESET_EDGE reset) begin
		/* 异步复位 */
		if (reset == `RESET_ENABLE) begin
			ex_pc		   <= `WORD_ADDR_W'h0;
			ex_en		   <= `DISABLE;
			ex_br_flag	   <= `DISABLE;
			ex_mem_op	   <= `MEM_OP_NOP;
			ex_mem_wr_data <= `WORD_DATA_W'h0;
			ex_ctrl_op	   <= `CTRL_OP_NOP;
			ex_dst_addr	   <= `REG_ADDR_W'd0;
			ex_gpr_we_	   <= `DISABLE_N;
			ex_exp_code	   <= `ISA_EXP_NO_EXP;
			ex_out		   <= `WORD_DATA_W'h0;
		end else begin
			/* 流水线寄存器的更新 */
			if (stall == `DISABLE) begin
				if (flush == `ENABLE) begin				  // 刷新
					ex_pc		   <= `WORD_ADDR_W'h0;
					ex_en		   <= `DISABLE;
					ex_br_flag	   <= `DISABLE;
					ex_mem_op	   <= `MEM_OP_NOP;
					ex_mem_wr_data <= `WORD_DATA_W'h0;
					ex_ctrl_op	   <= `CTRL_OP_NOP;
					ex_dst_addr	   <= `REG_ADDR_W'd0;
					ex_gpr_we_	   <= `DISABLE_N;
					ex_exp_code	   <= `ISA_EXP_NO_EXP;
					ex_out		   <= `WORD_DATA_W'h0;
				end else if (int_detect == `ENABLE) begin // 中断检测
					ex_pc		   <= id_pc;
					ex_en		   <= id_en;
					ex_br_flag	   <= id_br_flag;
					ex_mem_op	   <= `MEM_OP_NOP;
					ex_mem_wr_data <= `WORD_DATA_W'h0;
					ex_ctrl_op	   <= `CTRL_OP_NOP;
					ex_dst_addr	   <= `REG_ADDR_W'd0;
					ex_gpr_we_	   <= `DISABLE_N;
					ex_exp_code	   <= `ISA_EXP_EXT_INT;
					ex_out		   <= `WORD_DATA_W'h0;
				end else if (alu_of == `ENABLE) begin	  // 算术溢出
					ex_pc		   <= id_pc;
					ex_en		   <= id_en;
					ex_br_flag	   <= id_br_flag;
					ex_mem_op	   <= `MEM_OP_NOP;
					ex_mem_wr_data <= `WORD_DATA_W'h0;
					ex_ctrl_op	   <= `CTRL_OP_NOP;
					ex_dst_addr	   <= `REG_ADDR_W'd0;
					ex_gpr_we_	   <= `DISABLE_N;
					ex_exp_code	   <= `ISA_EXP_OVERFLOW;
					ex_out		   <= `WORD_DATA_W'h0;
				end else begin							  // 下一个数据
					ex_pc		   <= id_pc;
					ex_en		   <= id_en;
					ex_br_flag	   <= id_br_flag;
					ex_mem_op	   <= id_mem_op;
					ex_mem_wr_data <= id_mem_wr_data;
					ex_ctrl_op	   <= id_ctrl_op;
					ex_dst_addr	   <= id_dst_addr;
					ex_gpr_we_	   <= id_gpr_we_;
					ex_exp_code	   <= id_exp_code;
					ex_out		   <= alu_out;
				end
			end
		end
	end

endmodule
