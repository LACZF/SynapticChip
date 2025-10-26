
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart_ctrl (
    input  wire                   clk,
    input  wire                   reset,

    /********** 总线接口 **********/
    input  wire                   cs_n_i,        // 片选信号
    input  wire                   as_n_i,        // 地址选通信号
    input  wire                   rw_i,          // Read / Write
    input  wire [`UartAddrBus]    addr_i,        // 地址
    input  wire [`WordDataBus]    wr_data_i,     // 写入的数据
    output reg  [`WordDataBus]    rd_data_o,     // 读取的数据
    output reg                    rdy_n_o,       // 就绪信号
    /********** 中断 **********/
    output reg                    irq_rx_o,      // 接收中断请求信号（接收控制器 0）
    output reg                    irq_tx_o,      // 发送中断请求信号（发送控制器 0）
    /********** 控制信号 **********/
    // 接收控制
    input  wire                   rx_busy_i,     // 接收中标志信号（控制寄存器 0）
    input  wire                   rx_end_i,      // 接收完成信号
    input  wire [`ByteDataBus]    rx_data_i,     // 接收的数据
    // 发送控制
    input  wire                   tx_busy_i,     // 发送中标志信号（控制寄存器 0）
    input  wire                   tx_end_i,      // 发送完成信号
    output reg                    tx_start_o,    // 发送开始信号
    output reg  [`ByteDataBus]    tx_data_o      // 发送的数据
);

    /********** 控制寄存器 **********/
    reg [`ByteDataBus]            rx_buf;     // 接收用数据缓冲区

    /********** UART控制逻辑电路 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            rd_data_o     <= `WORD_DATA_W'h0;
            rdy_n_o       <= `DISABLE_N;
            irq_rx_o      <= `DISABLE;
            irq_tx_o      <= `DISABLE;
            rx_buf        <= `BYTE_DATA_W'h0;
            tx_start_o    <= `DISABLE;
            tx_data_o     <= `BYTE_DATA_W'h0;
       end else begin
            /* 就绪信号的生成 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N)) begin
                rdy_n_o     <= `ENABLE_N;
            end else begin
                rdy_n_o     <= `DISABLE_N;
            end
            /* 读取访问 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) && (rw_i == `READ)) begin
                case (addr_i)
                    `UART_ADDR_STATUS     : begin // 控制寄存器 0
                        rd_data_o     <= {{`WORD_DATA_W-4{1'b0}}, tx_busy_i, rx_busy_i, irq_tx_o, irq_rx_o};
                    end
                    `UART_ADDR_DATA         : begin // 控制寄存器 1
                        rd_data_o     <= {{`BYTE_DATA_W*2{1'b0}}, rx_buf};
                    end
                endcase
            end else begin
                rd_data_o     <= `WORD_DATA_W'h0;
            end
            /* 写入访问 */
            // 控制寄存器 0 : 发送完成中断
            if (tx_end_i == `ENABLE) begin
                irq_tx_o<= `ENABLE;
            end else if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                         (rw_i == `WRITE) && (addr_i == `UART_ADDR_STATUS)) begin
                irq_tx_o<= wr_data_i[`UartCtrlIrqTx];
            end
            // 控制寄存器 0 : 写入发送完成中断位
            if (rx_end_i == `ENABLE) begin
                irq_rx_o<= `ENABLE;
            end else if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                         (rw_i == `WRITE) && (addr_i == `UART_ADDR_STATUS)) begin
                irq_rx_o<= wr_data_i[`UartCtrlIrqRx];
            end
            // 控制寄存器 1
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                (rw_i == `WRITE) && (addr_i == `UART_ADDR_DATA)) begin // 发送开始
                tx_start_o <= `ENABLE;
                tx_data_o  <= wr_data_i[`BYTE_MSB:`LSB];
            end else begin
                tx_start_o <= `DISABLE;
                tx_data_o  <= `BYTE_DATA_W'h0;
            end
            /* 接收数据 */
            if (rx_end_i == `ENABLE) begin
                rx_buf     <= rx_data_i;
            end
        end
    end

endmodule
