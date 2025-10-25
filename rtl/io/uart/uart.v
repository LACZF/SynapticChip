
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart (
    input  wire                   clk,
    input  wire                   reset,

    input  wire                   cs_,
    input  wire                   as_,
    input  wire                   rw,
    input  wire [`UartAddrBus]    addr,
    input  wire [`WordDataBus]    wr_data,
    output wire [`WordDataBus]    rd_data,
    output wire                   rdy_,

    output wire                   irq_rx,
    output wire                   irq_tx,

    input  wire                   rx,
    output wire                   tx
);

    wire                          rx_busy;
    wire                          rx_end;
    wire [`ByteDataBus]           rx_data;

    wire                          tx_busy;
    wire                          tx_end;
    wire                          tx_start;
    wire [`ByteDataBus]           tx_data;

    /********** UART控制模块 **********/
    uart_ctrl u_uart_ctrl (
        .clk         (clk),
        .reset       (reset),

        .cs_         (cs_),
        .as_         (as_),
        .rw          (rw),
        .addr        (addr),
        .wr_data     (wr_data),
        .rd_data     (rd_data),
        .rdy_        (rdy_),

        .irq_rx      (irq_rx),
        .irq_tx      (irq_tx),

        .rx_busy     (rx_busy),
        .rx_end      (rx_end),
        .rx_data     (rx_data),

        .tx_busy     (tx_busy),
        .tx_end      (tx_end),
        .tx_start    (tx_start),
        .tx_data     (tx_data)
    );

    /********** UART发送模块 **********/
    uart_tx u_uart_tx (
        .clk         (clk),
        .reset       (reset),

        .tx_start    (tx_start),
        .tx_data     (tx_data),
        .tx_busy     (tx_busy),
        .tx_end      (tx_end),

        .tx          (tx)
    );

    /********** UART接收模块 **********/
    uart_rx u_uart_rx (
        .clk         (clk),
        .reset       (reset),

        .rx_busy     (rx_busy),
        .rx_end      (rx_end),
        .rx_data     (rx_data),

        .rx          (rx)
    );

endmodule
