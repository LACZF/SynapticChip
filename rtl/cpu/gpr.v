
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"

module gpr (
	input  wire				   clk,
	input  wire				   reset,
	/********** 读取端口 0 **********/
	input  wire [`RegAddrBus]  rd_addr_0_i,		   // 读取的地址
	output wire [`WordDataBus] rd_data_0_o,		   // 读取的数据
	/********** 读取端口 1 **********/
	input  wire [`RegAddrBus]  rd_addr_1_i,		   // 读取的地址
	output wire [`WordDataBus] rd_data_1_o,		   // 读取的数据
	/********** 写入端口 **********/
	input  wire				   we_n_i,			   // 写入有效信号
	input  wire [`RegAddrBus]  wr_addr_i,		   // 写入的地址
	input  wire [`WordDataBus] wr_data_i		   // 写入的数据
);

	/********** 内部信号 **********/
	reg [`WordDataBus]		   gpr [`REG_NUM-1:0]; // 寄存器序列
	integer					   i;				   // 初始化用迭代器

	/********** 读取访问 (Write After Read) **********/
	// 读取端口 0
	assign rd_data_0_o = ((we_n_i == `ENABLE_N) && (wr_addr_i == rd_addr_0_i)) ?
			   wr_data_i : gpr[rd_addr_0_i];
	// 读取端口 1
	assign rd_data_1_o = ((we_n_i == `ENABLE_N) && (wr_addr_i == rd_addr_1_i)) ?
			   wr_data_i : gpr[rd_addr_1_i];

	/********** 写入访问 **********/
	always @ (posedge clk or `RESET_EDGE reset) begin
		if (reset == `RESET_ENABLE) begin
			/* 异步复位 */
			for (i = 0; i < `REG_NUM; i = i + 1) begin
				gpr[i] <= `WORD_DATA_W'h0;
			end
		end else begin
			/* 写入访问 */
			if (we_n_i == `ENABLE_N) begin
				gpr[wr_addr_i] <= wr_data_i;
			end
		end
	end

endmodule