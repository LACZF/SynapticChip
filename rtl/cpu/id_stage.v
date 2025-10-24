
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module id_stage (
	input  wire			         clk,
	input  wire			         reset,
	/********** GPR接口 **********/
	input  wire [`WordDataBus]	 gpr_rd_data0_i,	 // 读取数据 0
	input  wire [`WordDataBus]	 gpr_rd_data1_i,	 // 读取数据 1
	output wire [`RegAddrBus]	 gpr_rd_addr0_o,	 // 读取地址 0
	output wire [`RegAddrBus]	 gpr_rd_addr1_o,	 // 读取地址 1
	/********** 数据直通 **********/
	// 来自EX阶段的数据直通
	input  wire			         ex_en_i,		    // 流水线数据有效
	input  wire [`WordDataBus]	 ex_fwd_data_i,	    // 数据直通
	input  wire [`RegAddrBus]	 ex_dst_addr_i,	    // 写入地址
	input  wire			         ex_gpr_we_n_i,	    // 写入有效
	// 来自MEM阶段的数据直通
	input  wire [`WordDataBus]	 mem_fwd_data_i,
	/********** 控制寄存器接口 **********/
	input  wire [`CpuExeModeBus] exe_mode_i,		 // 执行模式
	input  wire [`WordDataBus]	 creg_rd_data_i,	 // 读取的数据
	output wire [`RegAddrBus]	 creg_rd_addr_o,	 // 读取的地址
	/********** 流水线控制信号 **********/
	input  wire			         stall_i,
	input  wire			         flush_i,
	output wire [`WordAddrBus]	 br_addr_o,
	output wire			         br_taken_o,
	output wire			         ld_hazard_o,
	/********** IF/ID流水线寄存器 **********/
	input  wire [`WordAddrBus]	 if_pc_i,
	input  wire [`WordDataBus]	 if_insn_i,
	input  wire			         if_en_i,
	/********** ID/EX流水线寄存器 **********/
	output wire [`WordAddrBus]	 id_pc_o,
	output wire [`WordDataBus]	 id_insn_o,
	output wire			         id_en_o,
	output wire [`AluOpBus]		 id_alu_op_o,		 // ALU操作
	output wire [`WordDataBus]	 id_alu_in_0_o,	 // ALU输入 0
	output wire [`WordDataBus]	 id_alu_in_1_o,	 // ALU输入 1
	output wire			         id_br_flag_o,
	output wire [`MemOpBus]		 id_mem_op_o,
	output wire [`WordDataBus]	 id_mem_wr_data_o,
	output wire [`CtrlOpBus]	 id_ctrl_op_o,
	output wire [`RegAddrBus]	 id_dst_addr_o,	 // GPR写入地址
	output wire			         id_gpr_we_n_o,	 // GPR写入有效
	output wire [`IsaExpBus]	 id_exp_code_o
);

	/********** 解码信号 **********/
	wire  [`AluOpBus]			 alu_op;		 // ALU操作
	wire  [`WordDataBus]		 alu_in_0;		 // ALU输入 0
	wire  [`WordDataBus]		 alu_in_1;		 // ALU输入 1
	wire						 br_flag;
	wire  [`MemOpBus]			 mem_op;
	wire  [`WordDataBus]		 mem_wr_data;
	wire  [`CtrlOpBus]			 ctrl_op;
	wire  [`RegAddrBus]			 dst_addr;		 // GPR写入地址
	wire						 gpr_we_;		 // GPR写入有效
	wire  [`IsaExpBus]			 exp_code;

	assign id_insn_o = if_insn_i;

	/********** 指令解码器 **********/
	decoder decoder (
		/********** IF/ID流水线寄存器 **********/
		.if_pc_i		    (if_pc_i),
		.if_insn_i		    (if_insn_i),
		.if_en_i		    (if_en_i),
		/********** GPR接口 **********/
		.gpr_rd_data0_i	    (gpr_rd_data0_i),  // 读取数据 0
		.gpr_rd_data1_i	    (gpr_rd_data1_i),  // 读取数据 1
		.gpr_rd_addr0_o	    (gpr_rd_addr0_o),  // 读取地址 0
		.gpr_rd_addr1_o	    (gpr_rd_addr1_o),  // 读取地址 1
		/********** 数据直通 **********/
		// 来自ID阶段的数据直通
		.id_en_i		    (id_en_o),
		.id_dst_addr_i		(id_dst_addr_o),
		.id_gpr_we_n_i		(id_gpr_we_n_o),
		.id_mem_op_i		(id_mem_op_o),
		// 来自EX阶段的数据直通
		.ex_en_i		    (ex_en_i),
		.ex_fwd_data_i		(ex_fwd_data_i),
		.ex_dst_addr_i		(ex_dst_addr_i),
		.ex_gpr_we_n_i		(ex_gpr_we_n_i),
		// 来自MEM阶段的数据直通
		.mem_fwd_data_i		(mem_fwd_data_i),
		/********** 控制寄存器接口 **********/
		.exe_mode_i		    (exe_mode_i),
		.creg_rd_data_i		(creg_rd_data_i),
		.creg_rd_addr_o		(creg_rd_addr_o),
		/********** 解码结果 **********/
		.alu_op_o		    (alu_op),	  // ALU操作
		.alu_in_0_o		    (alu_in_0),	  // ALU输入 0
		.alu_in_1_o		    (alu_in_1),	  // ALU输入 1
		.br_addr_o		    (br_addr_o),
		.br_taken_o		    (br_taken_o),
		.br_flag_o		    (br_flag),
		.mem_op_o		    (mem_op),
		.mem_wr_data_o	    (mem_wr_data),
		.ctrl_op_o		    (ctrl_op),
		.dst_addr_o		    (dst_addr),
		.gpr_we_n_o		    (gpr_we_),
		.exp_code_o		    (exp_code),
		.ld_hazard_o		(ld_hazard_o)
	);

	/********** 流水线寄存器 **********/
	id_reg id_reg (
		.clk		      (clk),
		.reset		      (reset),
		/********** 解码结果 **********/
		.alu_op_i	      (alu_op),
		.alu_in_0_i	      (alu_in_0),
		.alu_in_1_i	      (alu_in_1),
		.br_flag_i	      (br_flag),
		.mem_op_i	      (mem_op),
		.mem_wr_data_i	  (mem_wr_data),
		.ctrl_op_i	      (ctrl_op),
		.dst_addr_i	      (dst_addr),
		.gpr_we_n_i	      (gpr_we_),
		.exp_code_i	      (exp_code),
		/********** 流水线控制信号 **********/
		.stall_i	      (stall_i),
		.flush_i	      (flush_i),
		/********** IF/ID流水线寄存器 **********/
		.if_pc_i	      (if_pc_i),
		.if_en_i	      (if_en_i),
		/********** ID/EX流水线寄存器 **********/
		.id_pc_o	      (id_pc_o),
		.id_en_o	      (id_en_o),
		.id_alu_op_o	  (id_alu_op_o),
		.id_alu_in_0_o	  (id_alu_in_0_o),
		.id_alu_in_1_o	  (id_alu_in_1_o),
		.id_br_flag_o	  (id_br_flag_o),
		.id_mem_op_o	  (id_mem_op_o),
		.id_mem_wr_data_o (id_mem_wr_data_o),
		.id_ctrl_op_o	  (id_ctrl_op_o),
		.id_dst_addr_o	  (id_dst_addr_o),
		.id_gpr_we_n_o	  (id_gpr_we_n_o),
		.id_exp_code_o	  (id_exp_code_o)
	);

endmodule