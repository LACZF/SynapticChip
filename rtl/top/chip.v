/********** 通用头文件 **********/

`include "stddef.v"
`include "global_config.v"

/********** 单个头文件 **********/
`include "cpu.v"
`include "bus.v"
`include "rom.v"
`include "timer.v"
`include "uart.v"
`include "gpio.v"
`include "jtag_addr.v"

/********** 模块 **********/
module chip (
	/********** 时钟 & 复位 **********/
	input  wire				         clk,
	input  wire				         clk_,
	input  wire				         reset

`ifdef IMPLEMENT_JTAG
	/********** JTAG  **********/
	, input  wire				     tck
	, input  wire				     tms
	, input  wire				     tdi
	, output wire				     tdo
	, output wire				     tdo_en
`endif

`ifdef IMPLEMENT_UART
	/********** UART  **********/
	, input	 wire					 uart_rx
	, output wire					 uart_tx
`endif

`ifdef IMPLEMENT_GPIO // GPIO实现
	/********** GPIO  **********/
`ifdef GPIO_IN_CH	 // 输入端口的实现
	, input wire [`GPIO_IN_CH-1:0]	 gpio_in	  // 输入端口
`endif
`ifdef GPIO_OUT_CH	 // 输出端口实现
	, output wire [`GPIO_OUT_CH-1:0] gpio_out	  // 输出端口
`endif
`ifdef GPIO_IO_CH	 // 输入/输出端口的实现
	, inout wire [`GPIO_IO_CH-1:0]	 gpio_io	  // 输入输出端口
`endif
`endif
);

	wire [`WordDataBus] m_rd_data;
	wire				m_rdy_;

	wire				m0_req_;
	wire [`WordAddrBus] m0_addr;
	wire				m0_as_;
	wire				m0_rw;
	wire [`WordDataBus] m0_wr_data;
	wire				m0_grnt_;

	wire				m1_req_;
	wire [`WordAddrBus] m1_addr;
	wire				m1_as_;
	wire				m1_rw;
	wire [`WordDataBus] m1_wr_data;
	wire				m1_grnt_;

	wire				m2_req_;
	wire [`WordAddrBus] m2_addr;
	wire				m2_as_;
	wire				m2_rw;
	wire [`WordDataBus] m2_wr_data;
	wire				m2_grnt_;

	wire				m3_req_;
	wire [`WordAddrBus] m3_addr;
	wire				m3_as_;
	wire				m3_rw;
	wire [`WordDataBus] m3_wr_data;
	wire				m3_grnt_;

	wire [`WordAddrBus] s_addr;
	wire				s_as_;
	wire				s_rw;
	wire [`WordDataBus] s_wr_data;

	wire [`WordDataBus] s0_rd_data;
	wire				s0_rdy_;
	wire				s0_cs_;

	wire [`WordDataBus] s1_rd_data;
	wire				s1_rdy_;
	wire				s1_cs_;

	wire [`WordDataBus] s2_rd_data;
	wire				s2_rdy_;
	wire				s2_cs_;

	wire [`WordDataBus] s3_rd_data;
	wire				s3_rdy_;
	wire				s3_cs_;

	wire [`WordDataBus] s4_rd_data;
	wire				s4_rdy_;
	wire				s4_cs_;

	wire [`WordDataBus] s5_rd_data;
	wire				s5_rdy_;
	wire				s5_cs_;

	wire [`WordDataBus] s6_rd_data;
	wire				s6_rdy_;
	wire				s6_cs_;

	wire [`WordDataBus] s7_rd_data;
	wire				s7_rdy_;
	wire				s7_cs_;

	wire				   irq_timer;
	wire				   irq_uart_rx;
	wire				   irq_uart_tx;
	wire [`CPU_IRQ_CH-1:0] cpu_irq;

	assign cpu_irq = {{`CPU_IRQ_CH-3{`LOW}},
					  irq_uart_rx, irq_uart_tx, irq_timer};

	/********** CPU **********/
	cpu cpu (
		.clk			 (clk),
		.clk_			 (clk_),
		.reset			 (reset),

		// IF Stage
		.if_bus_rd_data	 (m_rd_data),
		.if_bus_rdy_	 (m_rdy_),
		.if_bus_grnt_	 (m0_grnt_),
		.if_bus_req_	 (m0_req_),
		.if_bus_addr	 (m0_addr),
		.if_bus_as_		 (m0_as_),
		.if_bus_rw		 (m0_rw),
		.if_bus_wr_data	 (m0_wr_data),
		// MEM Stage
		.mem_bus_rd_data (m_rd_data),
		.mem_bus_rdy_	 (m_rdy_),
		.mem_bus_grnt_	 (m1_grnt_),
		.mem_bus_req_	 (m1_req_),
		.mem_bus_addr	 (m1_addr),
		.mem_bus_as_	 (m1_as_),
		.mem_bus_rw		 (m1_rw),
		.mem_bus_wr_data (m1_wr_data),

		.cpu_irq		 (cpu_irq)
	);

	/* 暂未使用 */
	assign m2_addr	  = `WORD_ADDR_W'h0;
	assign m2_as_	  = `DISABLE_N;
	assign m2_rw	  = `READ;
	assign m2_wr_data = `WORD_DATA_W'h0;
	assign m2_req_	  = `DISABLE_N;

	/* 暂未使用 */
	assign m3_addr	  = `WORD_ADDR_W'h0;
	assign m3_as_	  = `DISABLE_N;
	assign m3_rw	  = `READ;
	assign m3_wr_data = `WORD_DATA_W'h0;
	assign m3_req_	  = `DISABLE_N;

	/********** ROM **********/
	rom rom (
		.clk			 (clk),
		.reset			 (reset),

		.cs_			 (s0_cs_),
		.as_			 (s_as_),
		.addr			 (s_addr[`RomAddrLoc]),
		.rd_data		 (s0_rd_data),
		.rdy_			 (s0_rdy_)
	);

	assign s1_rd_data = `WORD_DATA_W'h0;
	assign s1_rdy_	  = `DISABLE_N;

`ifdef IMPLEMENT_TIMER
	/********** TIMER **********/
	timer timer (
		.clk			 (clk),
		.reset			 (reset),

		.cs_			 (s2_cs_),
		.as_			 (s_as_),
		.addr			 (s_addr[`TimerAddrLoc]),
		.rw				 (s_rw),
		.wr_data		 (s_wr_data),
		.rd_data		 (s2_rd_data),
		.rdy_			 (s2_rdy_),

		.irq			 (irq_timer)
	 );
`else
	assign s2_rd_data = `WORD_DATA_W'h0;
	assign s2_rdy_	  = `DISABLE_N;
	assign irq_timer  = `DISABLE;
`endif

`ifdef IMPLEMENT_UART
	/********** UART **********/
	uart uart (
		.clk			 (clk),
		.reset			 (reset),

		.cs_			 (s3_cs_),
		.as_			 (s_as_),
		.rw				 (s_rw),
		.addr			 (s_addr[`UartAddrLoc]),
		.wr_data		 (s_wr_data),
		.rd_data		 (s3_rd_data),
		.rdy_			 (s3_rdy_),

		.irq_rx			 (irq_uart_rx),
		.irq_tx			 (irq_uart_tx),

		.rx				 (uart_rx),
		.tx				 (uart_tx)
	);
`else
	assign s3_rd_data  = `WORD_DATA_W'h0;
	assign s3_rdy_	   = `DISABLE_N;
	assign irq_uart_rx = `DISABLE;
	assign irq_uart_tx = `DISABLE;
`endif

`ifdef IMPLEMENT_GPIO
	/********** GPIO **********/
	gpio gpio (
		.clk			 (clk),
		.reset			 (reset),

		.cs_			 (s4_cs_),
		.as_			 (s_as_),
		.rw				 (s_rw),
		.addr			 (s_addr[`GpioAddrLoc]),
		.wr_data		 (s_wr_data),
		.rd_data		 (s4_rd_data),
		.rdy_			 (s4_rdy_)

`ifdef GPIO_IN_CH
		, .gpio_in		 (gpio_in)
`endif
`ifdef GPIO_OUT_CH
		, .gpio_out		 (gpio_out)
`endif
`ifdef GPIO_IO_CH
		, .gpio_io		 (gpio_io)
`endif
	);
`else
	assign s4_rd_data = `WORD_DATA_W'h0;
	assign s4_rdy_	  = `DISABLE_N;
`endif

	/* 暂未使用 */
	assign s5_rd_data = `WORD_DATA_W'h0;
	assign s5_rdy_	  = `DISABLE_N;

	/* 暂未使用 */
	assign s6_rd_data = `WORD_DATA_W'h0;
	assign s6_rdy_	  = `DISABLE_N;

`ifdef IMPLEMENT_JTAG
	/********** JTAG **********/
	jtag #(
		.ADDR_WIDTH	(64),
		.DATA_WIDTH	(32),
		.INST_WIDTH	(4)
	) jtag (
		.clk			(clk),
		.rst_n			(reset == `RESET_DISABLE ? 1'b1 : 1'b0),

		.tck_i			(tck),
		.tms_i			(tms),
		.tdi_i			(tdi),
		.tdo_o			(tdo),
		.tdo_en_o		(tdo_en),

		.req_i			(s7_cs_),
		.we_i			(s_rw),
		.addr_i			({{(64-`WORD_ADDR_W){1'b0}}, s_addr}),
		.data_in_i		(s_wr_data),
		.data_out_o		(s7_rd_data[`WORD_DATA_W-1:0]),
		.ack_o			(s7_rdy_),

		.debug_data_o	(),
		.debug_valid_o	()
	);
`else
	assign s7_rd_data = `WORD_DATA_W'h0;
	assign s7_rdy_	  = `DISABLE_N;
	assign tdo		  = `LOW;
	assign tdo_en	  = `LOW;
`endif

	/********** BUS **********/
	bus bus (
		.clk			 (clk),
		.reset			 (reset),

		.m_rd_data		 (m_rd_data),
		.m_rdy_			 (m_rdy_),

		.m0_req_		 (m0_req_),
		.m0_addr		 (m0_addr),
		.m0_as_			 (m0_as_),
		.m0_rw			 (m0_rw),
		.m0_wr_data		 (m0_wr_data),
		.m0_grnt_		 (m0_grnt_),

		.m1_req_		 (m1_req_),
		.m1_addr		 (m1_addr),
		.m1_as_			 (m1_as_),
		.m1_rw			 (m1_rw),
		.m1_wr_data		 (m1_wr_data),
		.m1_grnt_		 (m1_grnt_),

		.m2_req_		 (m2_req_),
		.m2_addr		 (m2_addr),
		.m2_as_			 (m2_as_),
		.m2_rw			 (m2_rw),
		.m2_wr_data		 (m2_wr_data),
		.m2_grnt_		 (m2_grnt_),

		.m3_req_		 (m3_req_),
		.m3_addr		 (m3_addr),
		.m3_as_			 (m3_as_),
		.m3_rw			 (m3_rw),
		.m3_wr_data		 (m3_wr_data),
		.m3_grnt_		 (m3_grnt_),

		.s_addr			 (s_addr),
		.s_as_			 (s_as_),
		.s_rw			 (s_rw),
		.s_wr_data		 (s_wr_data),

		.s0_rd_data		 (s0_rd_data),
		.s0_rdy_		 (s0_rdy_),
		.s0_cs_			 (s0_cs_),

		.s1_rd_data		 (s1_rd_data),
		.s1_rdy_		 (s1_rdy_),
		.s1_cs_			 (s1_cs_),

		.s2_rd_data		 (s2_rd_data),
		.s2_rdy_		 (s2_rdy_),
		.s2_cs_			 (s2_cs_),

		.s3_rd_data		 (s3_rd_data),
		.s3_rdy_		 (s3_rdy_),
		.s3_cs_			 (s3_cs_),

		.s4_rd_data		 (s4_rd_data),
		.s4_rdy_		 (s4_rdy_),
		.s4_cs_			 (s4_cs_),

		.s5_rd_data		 (s5_rd_data),
		.s5_rdy_		 (s5_rdy_),
		.s5_cs_			 (s5_cs_),

		.s6_rd_data		 (s6_rd_data),
		.s6_rdy_		 (s6_rdy_),
		.s6_cs_			 (s6_cs_),

		.s7_rd_data		 (s7_rd_data),
		.s7_rdy_		 (s7_rdy_),
		.s7_cs_			 (s7_cs_)
	);

endmodule