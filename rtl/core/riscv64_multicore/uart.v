// uart.v
module uart #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
) (
    input wire clk,
    input wire rst_n,
    output reg txd,
    input wire rxd,
    input wire [7:0] tx_data,
    input wire tx_start,
    output reg tx_busy,
    output reg [7:0] rx_data,
    output reg rx_done,
    output reg rx_error
);

    localparam CLK_DIVIDER = CLK_FREQ / BAUD_RATE;

    // 发送器
    reg [15:0] tx_counter;
    reg [3:0] tx_bit_count;
    reg [8:0] tx_shift_reg; // 包含起始位和停止位

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txd <= 1'b1;
            tx_busy <= 1'b0;
            tx_counter <= 16'b0;
            tx_bit_count <= 4'b0;
        end else begin
            if (tx_start && !tx_busy) begin
                tx_busy <= 1'b1;
                tx_shift_reg <= {1'b1, tx_data, 1'b0}; // 停止位 + 数据 + 起始位
                tx_bit_count <= 4'b0;
                tx_counter <= CLK_DIVIDER - 16'b1;
            end else if (tx_busy) begin
                if (tx_counter == 0) begin
                    tx_counter <= CLK_DIVIDER - 16'b1;
                    txd <= tx_shift_reg[0];
                    tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};

                    if (tx_bit_count == 9) begin
                        tx_busy <= 1'b0;
                    end else begin
                        tx_bit_count <= tx_bit_count + 4'b1;
                    end
                end else begin
                    tx_counter <= tx_counter - 16'b1;
                end
            end
        end
    end

    // 接收器
    reg [15:0] rx_counter;
    reg [3:0] rx_bit_count;
    reg [7:0] rx_shift_reg;
    reg rx_sampling;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_done <= 1'b0;
            rx_error <= 1'b0;
            rx_counter <= 16'b0;
            rx_bit_count <= 4'b0;
            rx_sampling <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            if (!rx_sampling && !rxd) begin
                // 检测到起始位
                rx_sampling <= 1'b1;
                rx_counter <= CLK_DIVIDER / 2 - 16'b1; // 采样在比特中间
                rx_bit_count <= 4'b0;
            end else if (rx_sampling) begin
                if (rx_counter == 0) begin
                    rx_counter <= CLK_DIVIDER - 16'b1;

                    if (rx_bit_count == 0) begin
                        // 验证起始位
                        if (rxd != 1'b0) begin
                            rx_error <= 1'b1;
                            rx_sampling <= 1'b0;
                        end
                    end else if (rx_bit_count <= 8) begin
                        // 数据位
                        rx_shift_reg[rx_bit_count-1] <= rxd;
                    end else begin
                        // 停止位
                        rx_sampling <= 1'b0;
                        if (rxd == 1'b1) begin
                            rx_data <= rx_shift_reg;
                            rx_done <= 1'b1;
                        end else begin
                            rx_error <= 1'b1;
                        end
                    end

                    rx_bit_count <= rx_bit_count + 4'b1;
                end else begin
                    rx_counter <= rx_counter - 16'b1;
                end
            end
        end
    end

endmodule
