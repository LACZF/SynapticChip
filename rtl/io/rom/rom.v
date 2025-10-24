

`include "stddef.v"
`include "global_config.v"

`include "rom.v"

module rom (
	input  wire				   clk,
	input  wire				   reset,
	/********** 总线接口 **********/
	input  wire				   cs_,		// 片选信号
	input  wire				   as_,		// 地址选通
	input  wire [`RomAddrBus]  addr,	// 地址
	output wire [`WordDataBus] rd_data, // 读取的数据
	output reg				   rdy_		// 就绪信号
);

	/********** Xilinx FPGA Block RAM : 单端口ROM **********/
	x_s3e_sprom x_s3e_sprom (
		.clka  (clk),					// 时钟
		.addra (addr),					// 地址
		.douta (rd_data)				// 读取的数据
	);

	/********** 生成就绪信号 **********/
	always @(posedge clk or `RESET_EDGE reset) begin
		if (reset == `RESET_ENABLE) begin
			/* 异步复位 */
			rdy_ <= `DISABLE_N;
		end else begin
			/* 生成就绪信号 */
			if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N)) begin
				rdy_ <= `ENABLE_N;
			end else begin
				rdy_ <= `DISABLE_N;
			end
		end
	end

endmodule
