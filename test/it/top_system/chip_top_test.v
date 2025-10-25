/*
 -- ============================================================================
 -- FILE NAME	: chip_top_test.v
 -- DESCRIPTION :
 -- ----------------------------------------------------------------------------
 -- ============================================================================
*/

/********** 时间尺度 **********/
`timescale 1ns/1ps					 // 时间尺度

/********** 通用头文件 **********/

`include "stddef.v"
`include "global_config.v"

/********** 单个头文件 **********/
`include "bus.v"
`include "cpu.v"
`include "gpio.v"

/********** 模块 **********/
module chip_top_test;
	/********** 输入/输出信号 **********/
	// 时钟 & 复位
	reg						clk_ref;	   // 主时钟
	reg						reset_sw;	   // 全局复位
	// UART
`ifdef IMPLEMENT_UART // UART実装
	wire					uart_rx;	   // UART接收信号
	wire					uart_tx;	   // UART发送信号
`endif
	// 通用输入/输出端口
`ifdef IMPLEMENT_GPIO // GPIO实现
`ifdef GPIO_IN_CH	 //
	wire [`GPIO_IN_CH-1:0]	gpio_in = {`GPIO_IN_CH{1'b0}}; // 输入端口
`endif
`ifdef GPIO_OUT_CH	 //
	wire [`GPIO_OUT_CH-1:0] gpio_out;					   // 输出端口
`endif
`ifdef GPIO_IO_CH	 //
	wire [`GPIO_IO_CH-1:0]	gpio_io = {`GPIO_IO_CH{1'bz}}; // 输入输出端口
`endif
`endif

	/********** UART模型 **********/
`ifdef IMPLEMENT_UART // UART实现
	wire					 rx_busy;		  // 接收中标志
	wire					 rx_end;		  // 接收完成标志
	wire [`ByteDataBus]		 rx_data;		  // 接收的数据
`endif

	/********** 时钟生成 **********/
    always #5 clk_ref = ~clk_ref;

	/********** 实例化chip_top **********/
	chip_top u_chip_top (
		/********** 时钟 & 复位 **********/
		.clk_ref	(clk_ref), // 主时钟
		.reset_sw	(reset_sw) //
		/********** UART **********/
`ifdef IMPLEMENT_UART // UART
		, .uart_rx	(uart_rx)  // UART受信信号
		, .uart_tx	(uart_tx)  // UART送信信号
`endif
	/********** 通用输入/输出端口 **********/
`ifdef IMPLEMENT_GPIO // GPIO
`ifdef GPIO_IN_CH			   //
		, .gpio_in	(gpio_in)  //
`endif
`ifdef GPIO_OUT_CH	 //
		, .gpio_out (gpio_out) //
`endif
`ifdef GPIO_IO_CH	 //
		, .gpio_io	(gpio_io)  //
`endif
`endif
);

	/********** GPIO的监测 **********/
`ifdef IMPLEMENT_GPIO // 搭载GPIO
`ifdef GPIO_IN_CH	 // 搭载输入输出端口
	always @(gpio_in) begin	 // gpio_in值变化后打印输出
		$display($time, " gpio_in changed  : %b", gpio_in);
	end
`endif
`ifdef GPIO_OUT_CH	 // 搭载输出端口
	always @(gpio_out) begin // gpio_out值变化后打印输出
		$display($time, " gpio_out changed : %b", gpio_out);
	end
`endif
`ifdef GPIO_IO_CH	 // 搭载输入输出端口
	always @(gpio_io) begin // gpio_io值变化后打印输出
		$display($time, " gpio_io changed  : %b", gpio_io);
	end
`endif
`endif

	/********** UART模型的实例化 **********/
`ifdef IMPLEMENT_UART // 搭载UART
	/********** 接收信号 **********/
	assign uart_rx = `HIGH;		// 空闲
//	  assign uart_rx = uart_tx; // 回送

	/********** UART模型 **********/
	uart_rx u_uart_model (
		/********** 时钟 & 复位 **********/
		.clk	  (u_chip_top.clk),		   // 时钟
		.reset	  (u_chip_top.chip_reset), // 异步复位
		/********** 控制信号 **********/
		.rx_busy  (rx_busy),			   // 接收中标志位
		.rx_end	  (rx_end),				   // 接收完成信号
		.rx_data  (rx_data),			   // 接收的数据
		/********** Receive Signal **********/
		.rx		  (uart_tx)				   // UART接收信号
	);

	/********** 发送信号的监测 **********/
	always @(posedge u_chip_top.clk) begin
		if (rx_end == `ENABLE) begin // 输出接收到的文字
			$write("%c", rx_data);
		end
	end
`endif

	/********** 测试用例 **********/
	initial begin
		$readmemh(`ROM_PRG, u_chip_top.u_chip.u_rom.u_x_s3e_sprom.mem);
		$readmemh(`SPM_PRG, u_chip_top.u_chip.u_cpu.u_spm.u_x_s3e_dpram.mem);

		clk_ref	 <= `LOW;
		reset_sw <= `RESET_ENABLE;

        @(posedge clk_ref);
		reset_sw <= `RESET_DISABLE;

		# `SIM_CYCLE $finish;
	end

	/********** 输出波形 **********/
	initial begin
		$dumpfile("chip_top_test.vcd");
		$dumpvars(0, chip_top_test);
	end

endmodule
