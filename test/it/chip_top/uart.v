// UART RX/TX modules for chip_top_test

// UART Receiver Module
module test_uart_rx # (
    parameter SAMPLE_CYCLES  = 16,
    parameter UART_DIV_RATE  = 2
) (
    input  wire        clk,
    input  wire        rst_n,

    output reg         rx_busy_o,
    output reg         rx_end_o,
    output reg [7:0]   rx_data_o,

    input  wire        rx_i
);
    wire               baud_clk;        // 波特率时钟

    uart_clk_gen u_uart_clk_gen(
        .clk              (clk),
        .rst_n            (rst_n),
        .sample_cycles_i  (8'(SAMPLE_CYCLES)),
        .baud_div_i       (16'(UART_DIV_RATE)),
        .baud_clk_o       (baud_clk)
    );

    uart_rx rx_module (
        .clk              (clk),
        .rst_n            (rst_n),
        .baud_clk_i       (baud_clk),
        .rx_i             (rx_i),
        .busy_o           (rx_busy_o),
        .data_o           (rx_data_o),
        .ready_o          (rx_end_o),
        .error_o          (),
        .sample_cycles_i  (8'(SAMPLE_CYCLES)),
        .data_bits_i      (4'h8)  // 5-8 data bits (3-bit port)
    );
endmodule

// UART Transmitter Module
module test_uart_tx # (
    parameter SAMPLE_CYCLES  = 16,
    parameter UART_DIV_RATE  = 2
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        tx_start_i,
    input  wire [7:0]  tx_data_i,
    output reg         tx_busy_o,
    output reg         tx_end_o,

    output reg         tx_o
);
    wire               baud_clk;        // 波特率时钟

    uart_clk_gen u_uart_clk_gen(
        .clk              (clk),
        .rst_n            (rst_n),
        .sample_cycles_i  (8'(SAMPLE_CYCLES)),
        .baud_div_i       (16'(UART_DIV_RATE)),
        .baud_clk_o       (baud_clk)
    );

    uart_tx tx_module (
        .clk              (clk),
        .rst_n            (rst_n),
        .baud_clk_i       (baud_clk),
        .data_i           (tx_data_i),
        .start_i          (tx_start_i),
        .busy_o           (tx_busy_o),
        .tx_o             (tx_o),
        .tx_end_o         (tx_end_o),
        .sample_cycles_i  (8'(SAMPLE_CYCLES)),
        .data_bits_i      (4'h8)  // 5-8 data bits (3-bit port)
    );
endmodule