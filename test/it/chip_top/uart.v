// UART RX/TX modules for chip_top_test

`include "stddef.v"

// UART Receiver Module
module test_uart_rx (
    input  wire        clk,
    input  wire        rst_n,

    output reg         rx_busy_o,
    output reg         rx_end_o,
    output reg [7:0]   rx_data_o,

    input  wire        rx_i
);

    parameter BAUD_DIV = 100000000 / 115200 / 16; // Assuming 100MHz clock, 115200 baud

    reg [3:0]   state;
    reg [7:0]   rx_data;
    reg [3:0]   bit_cnt;
    reg [15:0]  baud_cnt;
    reg         baud_tick;

    localparam IDLE       = 4'd0;
    localparam START_BIT  = 4'd1;
    localparam DATA_BITS  = 4'd2;
    localparam STOP_BIT   = 4'd3;

    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 16'd0;
            baud_tick <= 1'b0;
        end else begin
            if (baud_cnt >= BAUD_DIV - 1) begin
                baud_cnt <= 16'd0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt <= baud_cnt + 1;
                baud_tick <= 1'b0;
            end
        end
    end

    // RX FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_busy_o <= `DISABLE;
            rx_end_o <= `DISABLE;
            rx_data_o <= 8'h00;
            rx_data <= 8'h00;
            bit_cnt <= 4'd0;
        end else begin
            rx_end_o <= `DISABLE;

            case (state)
                IDLE: begin
                    rx_busy_o <= `DISABLE;
                    if (rx_i == 1'b0) begin // Start bit detected
                        state <= START_BIT;
                        rx_busy_o <= `ENABLE;
                        baud_cnt <= 16'd0;
                    end
                end

                START_BIT: begin
                    if (baud_tick && baud_cnt >= BAUD_DIV/2) begin
                        state <= DATA_BITS;
                        bit_cnt <= 4'd0;
                        baud_cnt <= 16'd0;
                    end else if (baud_tick) begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                DATA_BITS: begin
                    if (baud_tick) begin
                        if (bit_cnt < 4'd8) begin
                            rx_data[bit_cnt] <= rx_i;
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            state <= STOP_BIT;
                            bit_cnt <= 4'd0;
                        end
                    end
                end

                STOP_BIT: begin
                    if (baud_tick && bit_cnt >= 4'd1) begin
                        state <= IDLE;
                        rx_data_o <= rx_data;
                        rx_end_o <= `ENABLE;
                    end else if (baud_tick) begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            endcase
        end
    end
endmodule

// UART Transmitter Module
module test_uart_tx (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        tx_start_i,
    input  wire [7:0]  tx_data_i,
    output reg         tx_busy_o,
    output reg         tx_end_o,

    output reg         tx_o
);

    parameter BAUD_DIV = 100000000 / 115200; // Assuming 100MHz clock, 115200 baud

    reg [3:0]   state;
    reg [7:0]   tx_data;
    reg [3:0]   bit_cnt;
    reg [15:0]  baud_cnt;
    reg         baud_tick;

    localparam IDLE       = 4'd0;
    localparam START_BIT  = 4'd1;
    localparam DATA_BITS  = 4'd2;
    localparam STOP_BIT   = 4'd3;

    // Baud rate generator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 16'd0;
            baud_tick <= 1'b0;
        end else begin
            if (baud_cnt >= BAUD_DIV - 1) begin
                baud_cnt <= 16'd0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt <= baud_cnt + 1;
                baud_tick <= 1'b0;
            end
        end
    end

    // TX FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_busy_o <= `DISABLE;
            tx_end_o <= `DISABLE;
            tx_o <= 1'b1;
            tx_data <= 8'h00;
            bit_cnt <= 4'd0;
        end else begin
            tx_end_o <= `DISABLE;

            case (state)
                IDLE: begin
                    tx_o <= 1'b1; // Idle state is high
                    if (tx_start_i && !tx_busy_o) begin
                        state <= START_BIT;
                        tx_busy_o <= `ENABLE;
                        tx_data <= tx_data_i;
                        bit_cnt <= 4'd0;
                    end
                end

                START_BIT: begin
                    if (baud_tick) begin
                        tx_o <= 1'b0;
                        state <= DATA_BITS;
                        bit_cnt <= 4'd0;
                    end
                end

                DATA_BITS: begin
                    if (baud_tick) begin
                        if (bit_cnt < 4'd8) begin
                            tx_o <= tx_data[bit_cnt];
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            state <= STOP_BIT;
                        end
                    end
                end

                STOP_BIT: begin
                    if (baud_tick) begin
                        tx_o <= 1'b1;
                        state <= IDLE;
                        tx_busy_o <= `DISABLE;
                        tx_end_o <= `ENABLE;
                    end
                end
            endcase
        end
    end
endmodule