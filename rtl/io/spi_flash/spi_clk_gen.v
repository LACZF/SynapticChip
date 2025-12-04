`timescale 1ns/1ps

module spi_clk_gen (
    input       clk,
    input       rst_n,
    input       enable,
    output reg  spi_clk,
    output reg  clk_rising,
    output reg  clk_falling
);

    // 参数
    parameter DIV_WIDTH = 8;
    parameter DIV_VALUE = 8'd8;  // 分频系数，实际SPI时钟频率 = clk频率 / (DIV_VALUE * 2)

    // 内部信号
    reg [DIV_WIDTH-1:0] counter;
    reg                 spi_clk_int;

    // 分频计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter     <= {DIV_WIDTH{1'b0}};
            spi_clk_int <= 1'b0;
            clk_rising  <= 1'b0;
            clk_falling <= 1'b0;
        end else begin
            clk_rising  <= 1'b0;
            clk_falling <= 1'b0;

            if (enable) begin
                if (counter == DIV_VALUE - 1) begin
                    counter     <= {DIV_WIDTH{1'b0}};
                    spi_clk_int <= ~spi_clk_int;

                    // 生成边沿指示信号
                    if (~spi_clk_int) begin
                        clk_rising <= 1'b1;   // 即将变为高电平
                    end else begin
                        clk_falling <= 1'b1;  // 即将变为低电平
                    end
                end else begin
                    counter <= counter + 1;
                end
            end else begin
                counter     <= {DIV_WIDTH{1'b0}};
                spi_clk_int <= 1'b0;
            end
        end
    end

    // 输出SPI时钟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk <= 1'b0;
        end else begin
            spi_clk <= spi_clk_int;
        end
    end

endmodule