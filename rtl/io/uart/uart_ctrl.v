
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart_ctrl (
	input  wire				   clk,
	input  wire				   reset,
	/********** 总线接口 **********/
	input  wire				   cs_,		 // 片选信号
	input  wire				   as_,		 // 地址选通信号
	input  wire				   rw,		 // Read / Write
	input  wire [`UartAddrBus] addr,	 // 地址
	input  wire [`WordDataBus] wr_data,	 // 写入的数据
	output reg	[`WordDataBus] rd_data,	 // 读取的数据
	output reg				   rdy_,	 // 就绪信号
	/********** 中断 **********/
	output reg				   irq_rx,	 // 接收中断请求信号（接收控制器 0）
	output reg				   irq_tx,	 // 发送中断请求信号（发送控制器 0）
	/********** 控制信号 **********/
	// 接收控制
	input  wire				   rx_busy,	 // 接收中标志信号（控制寄存器 0）
	input  wire				   rx_end,	 // 接收完成信号
	input  wire [`ByteDataBus] rx_data,	 // 接收的数据
	// 发送控制
	input  wire				   tx_busy,	 // 发送中标志信号（控制寄存器 0）
	input  wire				   tx_end,	 // 发送完成信号
	output reg				   tx_start, // 发送开始信号
	output reg	[`ByteDataBus] tx_data	 // 发送的数据
);

	/********** 控制寄存器 **********/
	reg [`ByteDataBus]		   rx_buf;	 // 接收用数据缓冲区

	/********** UART控制逻辑电路 **********/
	always @(posedge clk or `RESET_EDGE reset) begin
		if (reset == `RESET_ENABLE) begin
			/* 异步复位 */
			rd_data	 <= `WORD_DATA_W'h0;
			rdy_	 <= `DISABLE_N;
			irq_rx	 <= `DISABLE;
			irq_tx	 <= `DISABLE;
			rx_buf	 <= `BYTE_DATA_W'h0;
			tx_start <= `DISABLE;
			tx_data	 <= `BYTE_DATA_W'h0;
	   end else begin
			/* 就绪信号的生成 */
			if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N)) begin
				rdy_	 <= `ENABLE_N;
			end else begin
				rdy_	 <= `DISABLE_N;
			end
			/* 读取访问 */
			if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) && (rw == `READ)) begin
				case (addr)
					`UART_ADDR_STATUS	 : begin // 控制寄存器 0
						rd_data	 <= {{`WORD_DATA_W-4{1'b0}}, tx_busy, rx_busy, irq_tx, irq_rx};
					end
					`UART_ADDR_DATA		 : begin // 控制寄存器 1
						rd_data	 <= {{`BYTE_DATA_W*2{1'b0}}, rx_buf};
					end
				endcase
			end else begin
				rd_data	 <= `WORD_DATA_W'h0;
			end
			/* 写入访问 */
			// 控制寄存器 0 : 发送完成中断
			if (tx_end == `ENABLE) begin
				irq_tx<= `ENABLE;
			end else if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
						 (rw == `WRITE) && (addr == `UART_ADDR_STATUS)) begin
				irq_tx<= wr_data[`UartCtrlIrqTx];
			end
			// 控制寄存器 0 : 写入发送完成中断位
			if (rx_end == `ENABLE) begin
				irq_rx<= `ENABLE;
			end else if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
						 (rw == `WRITE) && (addr == `UART_ADDR_STATUS)) begin
				irq_rx<= wr_data[`UartCtrlIrqRx];
			end
			// 控制寄存器 1
			if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
				(rw == `WRITE) && (addr == `UART_ADDR_DATA)) begin // 发送开始
				tx_start <= `ENABLE;
				tx_data	 <= wr_data[`BYTE_MSB:`LSB];
			end else begin
				tx_start <= `DISABLE;
				tx_data	 <= `BYTE_DATA_W'h0;
			end
			/* 接收数据 */
			if (rx_end == `ENABLE) begin
				rx_buf	 <= rx_data;
			end
		end
	end

endmodule
