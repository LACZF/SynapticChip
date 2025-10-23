
`include "stddef.v"
`include "global_config.v"

/********** 单个头文件 **********/
`include "bus.v"

module bus_addr_dec # (
    parameter ADDR_WIDTH       = 30
)(
	input  wire [ADDR_WIDTH-1:0]   s_addr,
	output reg				       s0_cs_,
	output reg				       s1_cs_,
	output reg				       s2_cs_,
	output reg				       s3_cs_,
	output reg				       s4_cs_,
	output reg				       s5_cs_,
	output reg				       s6_cs_,
	output reg				       s7_cs_
);

	/********** 总线从属的索引 **********/
	wire [`BusSlaveIndexBus] s_index = s_addr[`BusSlaveIndexLoc];

	/********** 总线从属多路复用器 **********/
	always @(*) begin
		/* 初始化片选信号 */
		s0_cs_ = `DISABLE_N;
		s1_cs_ = `DISABLE_N;
		s2_cs_ = `DISABLE_N;
		s3_cs_ = `DISABLE_N;
		s4_cs_ = `DISABLE_N;
		s5_cs_ = `DISABLE_N;
		s6_cs_ = `DISABLE_N;
		s7_cs_ = `DISABLE_N;
		/* 选择地址对应的从属 */
		case (s_index)
			`BUS_SLAVE_0 : begin // 0号总线从属
				s0_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_1 : begin // 1号总线从属
				s1_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_2 : begin // 2号总线从属
				s2_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_3 : begin // 3号总线从属
				s3_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_4 : begin // 4号总线从属
				s4_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_5 : begin // 5号总线从属
				s5_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_6 : begin // 6号总线从属
				s6_cs_	= `ENABLE_N;
			end
			`BUS_SLAVE_7 : begin // 7号总线从属
				s7_cs_	= `ENABLE_N;
			end
		endcase
	end

endmodule
