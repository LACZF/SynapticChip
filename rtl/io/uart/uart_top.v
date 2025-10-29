
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart_top(
    input  wire                    clk,
    input  wire                    rst_n,

    /********** OBI总线接口 **********/
    input  wire                    req_i,
    input  wire                    we_i,
    input  wire [`UartAddrBus]     addr_i,
    input  wire [`WordDataBus]     wr_data_i,
    output reg  [`WordDataBus]     data_out_o,
    output reg                     gnt_o,
    output reg                     rvalid_o,
    /********** UART接口 **********/
    output wire                    uart_tx_o,
    input  wire                    uart_rx_i,
    /********** 中断信号 **********/
    output reg                     irq_o
);

    /********** 内部信号 **********/
    wire                           tx_start;
    wire                           tx_busy;
    wire                           rx_busy;
    wire                           rx_end;
    wire  [`WordDataBus]           rx_data;
    reg                            req_accepted;

    /********** OBI握手逻辑 **********/
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            gnt_o <= 1'b0;
            rvalid_o <= 1'b0;
            req_accepted <= 1'b0;
        end else begin
            // 授权信号：当没有挂起的请求时立即授权
            if (req_i && !req_accepted) begin
                gnt_o <= 1'b1;
                req_accepted <= 1'b1;
            end else begin
                gnt_o <= 1'b0;
            end

            // 读有效信号：在请求被接受后的下一个周期置位
            if (req_accepted && !we_i) begin
                rvalid_o <= 1'b1;
            end else begin
                rvalid_o <= 1'b0;
            end

            // 清除请求接受标志
            if (req_accepted) begin
                req_accepted <= 1'b0;
            end
        end
    end

    /********** UART控制器 **********/
    uart_ctrl uart_ctrl(
        .clk        (clk),
        .rst_n      (rst_n),
        .req_i      (req_accepted),
        .we_i       (we_i),
        .addr_i     (addr_i),
        .wr_data_i  (wr_data_i),
        .rd_data_o  (data_out_o),
        .tx_start_o (tx_start),
        .tx_busy_i  (tx_busy),
        .rx_busy_i  (rx_busy),
        .rx_end_i   (rx_end),
        .rx_data_i  (rx_data),
        .irq_o      (irq_o)
    );

    /********** UART发送器 **********/
    uart_tx uart_tx(
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_start_i (tx_start),
        .tx_data_i  (tx_data),
        .tx_busy_o  (tx_busy),
        .tx_o       (uart_tx_o)
    );

    /********** UART接收器 **********/
    uart_rx uart_rx(
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_i       (uart_rx_i),
        .rx_busy_o  (rx_busy),
        .rx_end_o   (rx_end),
        .rx_data_o  (rx_data)
    );

endmodule