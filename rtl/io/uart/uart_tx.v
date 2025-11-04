//======================================================================
// UART发送模块
//======================================================================
module uart_tx (
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 复位信号
    input  wire        baud_clk_i,   // 波特率时钟
    input  wire [7:0]  data_i,       // 输入数据
    input  wire        start_i,      // 开始发送信号
    output reg         busy_o,       // 发送忙信号
    output reg         tx_o,         // UART发送信号
    output reg         tx_end_o,     // UART发送信号
    input  wire [3:0]  data_bits_i,  // 数据位数量 (5-8)
    input  wire [7:0]  sample_cycles_i // 每个位周期的采样次数
);

    // 状态定义
    localparam IDLE = 2'b00;
    localparam START_BIT = 2'b01;
    localparam DATA_BITS = 2'b10;
    localparam STOP_BIT = 2'b11;

    // 采样计数器位宽固定为8位（足够覆盖常见采样次数）
    localparam SAMPLE_CNT_WIDTH = 8;

    wire [7:0] MIDDLE_SAMPLE = (sample_cycles_i / 2) - 1;  // 中间采样位置
    wire [7:0] END_SAMPLE = sample_cycles_i - 1;           // 结束采样位置

    reg [1:0] state;
    reg [7:0] tx_buffer;
    reg [2:0] bit_count;
    reg [SAMPLE_CNT_WIDTH-1:0] sample_count;  // 采样计数器
    reg       baud_clk_prev;
    reg       start_i_d0;      // start_i信号延迟一拍
    reg       start_i_pulse;   // start_i脉冲信号，用于边沿检测

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy_o <= 1'b0;
            tx_end_o <= 1'b0;
            tx_o <= 1'b1;
            tx_buffer <= 8'h00;
            bit_count <= 3'd0;
            sample_count <= 0;
            baud_clk_prev <= 1'b0;
            start_i_d0 <= 1'b0;
            start_i_pulse <= 1'b0;
        end else begin
            // 对start_i进行边沿检测，确保不会漏掉任何请求
            start_i_d0 <= start_i;
            if (start_i && !start_i_d0) begin
                start_i_pulse <= 1'b1;
            end else if (baud_clk_i && !baud_clk_prev) begin
                start_i_pulse <= 1'b0;
            end

            baud_clk_prev <= baud_clk_i;
            tx_end_o <= 1'b0;

            // 仅在波特率时钟上升沿更新状态
            if (baud_clk_i && !baud_clk_prev) begin
                case (state)
                    IDLE: begin
                        tx_o <= 1'b1;  // 空闲状态为高电平
                        busy_o <= 1'b0;
                        sample_count <= 0;
                        if (start_i_pulse) begin
                            state <= START_BIT;
                            busy_o <= 1'b1;
                            tx_buffer <= data_i;
                        end
                    end

                    START_BIT: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == 0) begin
                            tx_o <= 1'b0;  // 起始位为低电平
                        end
                        if (sample_count == END_SAMPLE) begin
                            state <= DATA_BITS;
                            bit_count <= 3'd0;
                            sample_count <= 0;
                        end
                    end

                    DATA_BITS: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == 0) begin
                            tx_o <= tx_buffer[0];
                        end
                        if (sample_count == END_SAMPLE) begin
                            tx_buffer <= {1'b0, tx_buffer[7:1]};
                            bit_count <= bit_count + 3'd1;
                            sample_count <= 0;
                            if (bit_count == data_bits_i - 3'd1) begin
                                state <= STOP_BIT;
                            end
                        end
                    end

                    STOP_BIT: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == 0) begin
                            tx_o <= 1'b1;  // 停止位为高电平
                        end
                        if (sample_count == END_SAMPLE) begin
                            tx_end_o <= 1'b1;
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule