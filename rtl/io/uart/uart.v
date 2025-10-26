
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart (
    input  wire                   clk,
    input  wire                   reset,

    input  wire                   cs_n_i,
    input  wire                   as_n_i,
    input  wire                   rw_i,
    input  wire [`UartAddrBus]    addr_i,
    input  wire [`WordDataBus]    wr_data_i,
    output wire [`WordDataBus]    rd_data_o,
    output wire                   rdy_n_o,

    output wire                   irq_rx_o,
    output wire                   irq_tx_o,

    input  wire                   rx_i,
    output wire                   tx_o
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
        .clk           (clk),
        .reset         (reset),

        .cs_n_i        (cs_n_i),
        .as_n_i        (as_n_i),
        .rw_i          (rw_i),
        .addr_i        (addr_i),
        .wr_data_i     (wr_data_i),
        .rd_data_o     (rd_data_o),
        .rdy_n_o       (rdy_n_o),

        .irq_rx_o      (irq_rx_o),
        .irq_tx_o      (irq_tx_o),

        .rx_busy_i     (rx_busy),
        .rx_end_i      (rx_end),
        .rx_data_i     (rx_data),

        .tx_busy_i     (tx_busy),
        .tx_end_i      (tx_end),
        .tx_start_o    (tx_start),
        .tx_data_o     (tx_data)
    );

    /********** UART发送模块 **********/
    uart_tx u_uart_tx (
        .clk           (clk),
        .reset         (reset),

        .tx_start_i    (tx_start),
        .tx_data_i     (tx_data),
        .tx_busy_o     (tx_busy),
        .tx_end_o      (tx_end),

        .tx_o          (tx_o)
    );

    /********** UART接收模块 **********/
    uart_rx u_uart_rx (
        .clk           (clk),
        .reset         (reset),

        .rx_busy_o     (rx_busy),
        .rx_end_o      (rx_end),
        .rx_data_o     (rx_data),

        .rx_i          (rx_i)
    );

endmodule
