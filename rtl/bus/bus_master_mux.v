
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_master_mux (
	/********** 总线主控信号 **********/
	// 0号总线主控
	input  wire [`WordAddrBus] m0_addr_i,	   // 地址
	input  wire		           m0_as_n_i,	   // 地址选通
	input  wire		           m0_rw_i,	       // 读/写
	input  wire [`WordDataBus] m0_wr_data_i,   // 写入的数据
	input  wire		           m0_grnt_n_i,    // 赋予总线
	// 1号总线主控
	input  wire [`WordAddrBus] m1_addr_i,	   // 地址
	input  wire		           m1_as_n_i,	   // 地址选通
	input  wire		           m1_rw_i,	       // 读/写
	input  wire [`WordDataBus] m1_wr_data_i,   // 写入的数据
	input  wire		           m1_grnt_n_i,    // 赋予总线
	// 2号总线主控
	input  wire [`WordAddrBus] m2_addr_i,	   // 地址
	input  wire		           m2_as_n_i,	   // 地址选通
	input  wire		           m2_rw_i,	       // 读/写
	input  wire [`WordDataBus] m2_wr_data_i,   // 写入的数据
	input  wire		           m2_grnt_n_i,    // 赋予总线
	// 3号总线主控
	input  wire [`WordAddrBus] m3_addr_i,	   // 地址
	input  wire		           m3_as_n_i,	   // 地址选通
	input  wire		           m3_rw_i,	       // 读/写
	input  wire [`WordDataBus] m3_wr_data_i,   // 写入的数据
	input  wire		           m3_grnt_n_i,    // 赋予总线
	/********** 共享信号总线从属 **********/
	output reg	[`WordAddrBus] s_addr_o,	   // 地址
	output reg		           s_as_n_o,	   // 地址选通
	output reg		           s_rw_o,	       // 读/写
	output reg	[`WordDataBus] s_wr_data_o     // 写入的数据
);

	/********** 总线主控多路复用器 **********/
	always @(*) begin
		/* 选择持有总线使用权的主控 */
		if (m0_grnt_n_i == `ENABLE_N) begin			// 0号总线主控
			s_addr_o	  = m0_addr_i;
			s_as_n_o	  = m0_as_n_i;
			s_rw_o	      = m0_rw_i;
			s_wr_data_o   = m0_wr_data_i;
		end else if (m1_grnt_n_i == `ENABLE_N) begin // 1号总线主控
			s_addr_o	  = m1_addr_i;
			s_as_n_o	  = m1_as_n_i;
			s_rw_o	      = m1_rw_i;
			s_wr_data_o   = m1_wr_data_i;
		end else if (m2_grnt_n_i == `ENABLE_N) begin // 2号总线主控
			s_addr_o	  = m2_addr_i;
			s_as_n_o	  = m2_as_n_i;
			s_rw_o	      = m2_rw_i;
			s_wr_data_o   = m2_wr_data_i;
		end else if (m3_grnt_n_i == `ENABLE_N) begin // 3号总线主控
			s_addr_o	  = m3_addr_i;
			s_as_n_o	  = m3_as_n_i;
			s_rw_o	      = m3_rw_i;
			s_wr_data_o   = m3_wr_data_i;
		end else begin							// 默认值
			s_addr_o	  = `WORD_ADDR_W'h0;
			s_as_n_o	  = `DISABLE_N;
			s_rw_o	      = `READ;
			s_wr_data_o   = `WORD_DATA_W'h0;
		end
	end

endmodule