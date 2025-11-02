
//======================================================================
// UART接收模块
//======================================================================
module uart_rx #(
    parameter SAMPLE_CYCLES = 16      // 每个位周期的采样次数
)(
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 复位信号
    input  wire        baud_clk_i,   // 波特率时钟
    input  wire        rx_i,         // UART接收信号
    output reg [7:0]   data_o,       // 输出数据
    output reg         busy_o,       // 接收准备好信号
    output reg         ready_o,      // 接收准备好信号
    output reg         error_o,      // 接收错误信号
    input  wire [3:0]  data_bits_i   // 数据位数量 (5-8)
);

    // 状态定义
    localparam IDLE = 3'b000;
    localparam START_BIT = 3'b001;
    localparam DATA_BITS = 3'b010;
    localparam STOP_BIT = 3'b011;

    // 计算采样计数器位宽
    localparam SAMPLE_CNT_WIDTH = $clog2(SAMPLE_CYCLES);
    // 定义中间采样位置
    localparam MIDDLE_SAMPLE = (SAMPLE_CYCLES / 2) - 1;
    // 定义结束采样位置
    localparam END_SAMPLE = SAMPLE_CYCLES - 1;

    reg [2:0] state;
    reg [7:0] rx_buffer;
    reg [2:0] bit_count;
    reg [SAMPLE_CNT_WIDTH-1:0] sample_count;  // 采样计数器
    reg       baud_clk_prev;
    reg       rx_sync1, rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready_o <= 1'b0;
            error_o <= 1'b0;
            data_o <= 8'h00;
            rx_buffer <= 8'h00;
            bit_count <= 3'd0;
            sample_count <= 0;
            baud_clk_prev <= 1'b0;
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            // 输入同步
            rx_sync1 <= rx_i;
            rx_sync2 <= rx_sync1;

            baud_clk_prev <= baud_clk_i;
            ready_o <= 1'b0;
            error_o <= 1'b0;

            // 仅在波特率时钟上升沿更新状态
            if (baud_clk_i && !baud_clk_prev) begin
                case (state)
                    IDLE: begin
                        busy_o <= 1'b0;
                        if (!rx_sync2) begin  // 检测到起始位
                            state <= START_BIT;
                            sample_count <= 1;
                        end
                    end

                    START_BIT: begin
                        busy_o <= 1'b1;
                        sample_count <= sample_count + 1;
                        if (sample_count == MIDDLE_SAMPLE) begin  // 在起始位中间采样
                            if (!rx_sync2) begin  // 如果仍然是低电平
                                state <= DATA_BITS;
                                bit_count <= 3'd0;
                                sample_count <= 0;
                            end else begin
                                state <= IDLE;  // 假起始位
                            end
                        end
                    end

                    DATA_BITS: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == END_SAMPLE) begin  // 在数据位中间采样
                            rx_buffer <= {rx_sync2, rx_buffer[7:1]};
                            bit_count <= bit_count + 3'd1;
                            sample_count <= 0;
                            if (bit_count == data_bits_i - 3'd1) begin
                                state <= STOP_BIT;
                            end
                        end
                    end

                    STOP_BIT: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == END_SAMPLE) begin  // 在停止位中间采样
                            data_o <= rx_buffer;
                            ready_o <= 1'b1;
                            busy_o <= 1'b0;
                            if (!rx_sync2) begin
                                error_o <= 1'b1;
                            end
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule
