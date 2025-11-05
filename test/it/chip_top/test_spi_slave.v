`timescale 1ns/1ps

module test_spi_slave #(
    parameter SLAVE_ID = 0  // 从机ID，用于区分不同的从机
)(
    input  wire        clk,
    input  wire        rst_n,

    // SPI接口信号
    input  wire        spi_cs_n,
    input  wire        spi_clk,
    input  wire        spi_mosi,
    output wire        spi_miso
);

    // 内部信号定义
    reg [7:0] rx_data;      // 接收的数据寄存器
    reg [7:0] tx_data;      // 发送的数据寄存器
    reg [2:0] bit_count;    // 位计数器
    reg       miso_en;      // MISO输出使能
    reg       last_cs_n;    // 上一个时钟周期的片选信号
    reg       last_clk;     // 上一个时钟周期的时钟信号

    // 检测片选信号的下降沿（开始传输）
    wire cs_n_falling = (last_cs_n == 1'b1) && (spi_cs_n == 1'b0);

    // 检测时钟信号的上升沿（采样数据）
    wire clk_rising = (last_clk == 1'b0) && (spi_clk == 1'b1);

    // 检测时钟信号的下降沿（输出数据）
    wire clk_falling = (last_clk == 1'b1) && (spi_clk == 1'b0);

    // 存储上一个时钟周期的控制信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_cs_n <= 1'b1;
            last_clk <= 1'b0;
        end else begin
            last_cs_n <= spi_cs_n;
            last_clk <= spi_clk;
        end
    end

    // 发送数据逻辑：slave id+1作为基础，结合接收数据进行回传
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data <= 8'h00 + SLAVE_ID + 1;  // 复位时，使用slave id+1作为发送数据
        end else if (cs_n_falling) begin
            tx_data <= 8'h00 + SLAVE_ID + 1;  // 每次新的传输开始时，使用slave id+1作为发送数据
        end else if (bit_count == 3'd7 && clk_rising) begin
            // 回传接收到的数据，加上从机ID的标识
            tx_data <= rx_data + SLAVE_ID + 1;
        end
    end

    // SPI接收和发送逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 8'h00;
            bit_count <= 3'd0;
            miso_en <= 1'b0;
        end else begin
            if (spi_cs_n) begin
                // 片选无效，重置状态
                bit_count <= 3'd0;
                miso_en <= 1'b0;
            end else begin
                // 片选有效，进行SPI传输
                miso_en <= 1'b1;

                if (clk_rising) begin
                    // 上升沿采样数据（CPHA=0模式）
                    rx_data <= {rx_data[6:0], spi_mosi};
                    bit_count <= bit_count + 3'd1;
                end
            end
        end
    end

    // MISO输出（在时钟下降沿更新输出数据）
    reg miso_d; // 延迟的miso信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miso_d <= 1'b0;
        end else if (clk_falling) begin
            miso_d <= tx_data[7 - bit_count];
        end
    end

    // 三态输出控制
    assign spi_miso = miso_en ? miso_d : 1'bz;

    // 简单的调试信息输出
    always @(negedge spi_cs_n) begin
        if (rst_n) begin
            $display("%t: SPI Slave %d - Transmission completed, Received: 0x%h, Sent: 0x%h", $time, SLAVE_ID, rx_data, tx_data);
        end
    end

endmodule