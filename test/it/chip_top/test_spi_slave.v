`timescale 1ns/1ps

module test_spi_slave #(
    parameter SLAVE_ID = 0   // 从机ID，用于区分不同的从机
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  mode,  // SPI模式选择: 0=CPOL=0/CPHA=0, 1=CPOL=0/CPHA=1, 2=CPOL=1/CPHA=0, 3=CPOL=1/CPHA=1

    // SPI接口信号
    input  wire        spi_cs_n,
    input  wire        spi_clk,
    input  wire        spi_mosi,
    output wire        spi_miso,

    // 状态输出信号
    output wire        rx_complete, // 32位数据接收完成标志
    output wire        rx_ready      // 接收数据就绪标志（传输完成后的稳定数据）
);

    // 根据mode信号确定CPOL和CPHA的值
    reg cpol;
    reg cpha;
    always @(*) begin
        case(mode)
            2'b00: begin // SPI模式0
                cpol = 1'b0;
                cpha = 1'b0;
            end
            2'b01: begin // SPI模式1
                cpol = 1'b0;
                cpha = 1'b1;
            end
            2'b10: begin // SPI模式2
                cpol = 1'b1;
                cpha = 1'b0;
            end
            2'b11: begin // SPI模式3
                cpol = 1'b1;
                cpha = 1'b1;
            end
            default: begin // 默认模式0
                cpol = 1'b0;
                cpha = 1'b0;
            end
        endcase
    end

    // 内部信号定义
    parameter DATA_WIDTH = 32;   // 数据位宽

    reg [DATA_WIDTH-1:0] rx_data; // 接收的数据寄存器
    reg [DATA_WIDTH-1:0] tx_data; // 发送的数据寄存器
    reg [4:0] bit_count;    // 位计数器（最大支持32位）
    reg       miso_en;      // MISO输出使能
    reg       last_cs_n;    // 上一个时钟周期的片选信号
    reg       last_clk;     // 上一个时钟周期的时钟信号

    // 同步SPI时钟到系统时钟域，避免跨时钟域问题
    reg [1:0] spi_clk_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_clk_sync <= 2'b00;
        end else begin
            spi_clk_sync <= {spi_clk_sync[0], spi_clk};
        end
    end
    wire spi_clk_rising = (spi_clk_sync == 2'b01);
    wire spi_clk_falling = (spi_clk_sync == 2'b10);

    // 检测片选信号的下降沿（开始传输）
    reg [1:0] spi_cs_n_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_cs_n_sync <= 2'b11;
        end else begin
            spi_cs_n_sync <= {spi_cs_n_sync[0], spi_cs_n};
        end
    end
    wire cs_n_falling = (spi_cs_n_sync == 2'b10);

    // 发送数据逻辑：slave id+1作为基础，结合接收数据进行回传
    // 优化：确保在下一次传输开始前准备好正确的发送数据
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data <= {{(DATA_WIDTH-8){1'b0}}, 8'($unsigned(8'h00 + SLAVE_ID + 1))};  // 复位时，使用slave id+1作为发送数据
        end else if (cs_n_falling) begin
            // 每次新的传输开始时，使用固定的slave id+1作为发送数据，不再动态更新
            // 这样可以确保发送数据的一致性和可预测性
            tx_data <= {{(DATA_WIDTH-8){1'b0}}, 8'($unsigned(8'h00 + SLAVE_ID + 1))};
        end
    end

    // 根据SPI模式选择正确的采样和输出时钟沿
    wire sample_edge;   // 采样数据的时钟沿
    wire output_edge;   // 更新MISO的时钟沿

    assign sample_edge = (cpol == 1'b0 && cpha == 1'b0) ? spi_clk_rising :
                         (cpol == 1'b0 && cpha == 1'b1) ? spi_clk_falling :
                         (cpol == 1'b1 && cpha == 1'b0) ? spi_clk_falling :
                         (cpol == 1'b1 && cpha == 1'b1) ? spi_clk_rising :
                         spi_clk_rising; // 默认模式0

    assign output_edge = (cpol == 1'b0 && cpha == 1'b0) ? spi_clk_falling :
                         (cpol == 1'b0 && cpha == 1'b1) ? spi_clk_rising :
                         (cpol == 1'b1 && cpha == 1'b0) ? spi_clk_rising :
                         (cpol == 1'b1 && cpha == 1'b1) ? spi_clk_falling :
                         spi_clk_falling; // 默认模式0

    // SPI接收逻辑 - 根据SPI协议在正确的时钟沿采样数据
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= {DATA_WIDTH{1'b0}};
            bit_count <= 5'd0;
            miso_en <= 1'b0;
        end else begin
            if (spi_cs_n) begin
                // 片选无效，重置状态
                bit_count <= 5'd0;
                miso_en <= 1'b0;
            end else begin
                // 片选有效，进行SPI传输
                miso_en <= 1'b1;

                if (sample_edge) begin
                    // 根据当前SPI模式在正确的时钟沿采样数据
                    // MSB先发送，所以数据向右移位
                    rx_data <= {rx_data[DATA_WIDTH-2:0], spi_mosi};
                    bit_count <= bit_count + 5'd1;
                end
            end
        end
    end

    // MISO输出逻辑 - 根据SPI模式在正确的时钟沿更新输出
    reg miso_d; // 延迟的miso信号
    always @(negedge clk or posedge spi_cs_n) begin
        if (spi_cs_n) begin
            miso_d <= 1'b0;  // 片选无效时保持低电平
        end else if (output_edge) begin
            // 根据当前SPI模式在正确的时钟沿更新MISO输出
            // MSB先发送，所以从最高位开始发送
            miso_d <= tx_data[DATA_WIDTH-1 - bit_count];
        end
    end

    // 三态输出控制
    assign spi_miso = miso_en ? miso_d : 1'bz;

    // 更可靠的传输完成检测和调试信息输出
    // 避免仅通过片选信号的上升沿来判断传输完成，确保数据真正传输完成
    reg tx_complete_flag; // 标记传输是否真正完成
    reg [4:0] bit_count_at_cs_rise; // 保存片选上升沿时的bit_count值
    reg cs_edge_detected; // 标记是否检测到片选信号边沿

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_complete_flag <= 1'b0;
            bit_count_at_cs_rise <= 5'd0;
            cs_edge_detected <= 1'b0;
        end else begin
            // 当片选信号从0变为1时，保存当前的bit_count值
            if (!spi_cs_n) begin
                // 片选有效时，记录bit_count的最大值
                if (bit_count > bit_count_at_cs_rise) begin
                    bit_count_at_cs_rise <= bit_count;
                end
                cs_edge_detected <= 1'b0;
            end else if (!cs_edge_detected) begin
                // 片选从0变为1，且尚未处理过这个边沿
                cs_edge_detected <= 1'b1;

                // 传输完成条件：已经接收了数据位
                if (bit_count_at_cs_rise > 0) begin
                    tx_complete_flag <= 1'b1;
                end else begin
                    tx_complete_flag <= 1'b0;
                end
            end else begin
                // 处理完片选边沿后，重置标志
                tx_complete_flag <= 1'b0;
            end

            // 仅在真正完成一次有效传输时打印详细调试信息
            if (tx_complete_flag) begin
                $display("%t: SPI Slave %d - Transmission completed, Received: 0x%h, Sent: 0x%h, Total bits received: %d",
                         $time, SLAVE_ID, rx_data, tx_data, bit_count_at_cs_rise);
            end
        end
    end

    // 提供接收完成标志（32位传输完成）
    assign rx_complete = (bit_count == (DATA_WIDTH-1)) && sample_edge;

    // 提供接收数据就绪标志（传输完成后的稳定数据）
    assign rx_ready = spi_cs_n && (last_cs_n == 1'b0);

endmodule