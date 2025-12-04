module spi_flash_ctrl (
    // 时钟和复位
    input clk,
    input rst_n,

    // 用户接口
    input [23:0] addr_i,
    input [7:0] cmd_i,
    input [31:0] wdata_i,
    output reg [31:0] rdata_o,
    input start_i,
    output reg ready_o,
    output reg done_o,
    input [1:0] data_len_i,

    input wire [3:0] dummy_cycle,

    // SPI时钟域接口
    input spi_clk,
    input clk_rising,
    input clk_falling,

    // SPI接口
    output reg spi_cs_n,
    output reg spi_mosi,
    input spi_miso
);

// 状态定义
localparam [3:0]
    STATE_IDLE     = 4'd0,
    STATE_CMD      = 4'd1,
    STATE_ADDR     = 4'd2,
    STATE_DUMMY    = 4'd3,
    STATE_DATA_RD  = 4'd4,
    STATE_DATA_WR  = 4'd5,
    STATE_FINISH   = 4'd6;

// 内部寄存器
reg [3:0] state;
reg [3:0] next_state;
reg [7:0] shift_out;
reg [7:0] shift_in;
reg [4:0] bit_cnt;
reg [2:0] byte_cnt;
reg [31:0] data_buf;
reg [23:0] addr_reg;
reg [7:0] cmd_reg;
reg [1:0] data_len_reg;
reg [3:0] dummy_cnt;

// 状态寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

// 下一状态逻辑
always @(*) begin
    next_state = state;

    case (state)
        STATE_IDLE: begin
            if (start_i && ready_o) begin
                next_state = STATE_CMD;
            end
        end

        STATE_CMD: begin
            if (bit_cnt == 5'd7 && clk_rising) begin
                next_state = STATE_ADDR;
            end
        end

        STATE_ADDR: begin
            if (bit_cnt == 5'd23 && clk_rising) begin
                if (cmd_reg == 8'h0B) begin  // FAST_READ
                    next_state = STATE_DUMMY;
                end else if (cmd_reg == 8'h02 || cmd_reg == 8'h0A) begin  // 写命令
                    next_state = STATE_DATA_WR;
                end else begin
                    next_state = STATE_DUMMY;
                end
            end
        end

        STATE_DUMMY: begin
            if (dummy_cnt == (dummy_cycle - 1) && clk_rising) begin
                next_state = STATE_DATA_RD;
            end
        end

        STATE_DATA_RD: begin
            if ((data_len_reg == 2'b00 && byte_cnt == 3'd0 && bit_cnt == 5'd7) ||
                (data_len_reg == 2'b01 && byte_cnt == 3'd1 && bit_cnt == 5'd7) ||
                (data_len_reg == 2'b10 && byte_cnt == 3'd3 && bit_cnt == 5'd7)) begin
                if (clk_falling) begin
                    next_state = STATE_FINISH;
                end
            end
        end

        STATE_DATA_WR: begin
            if ((data_len_reg == 2'b00 && byte_cnt == 3'd0 && bit_cnt == 5'd7) ||
                (data_len_reg == 2'b01 && byte_cnt == 3'd1 && bit_cnt == 5'd7) ||
                (data_len_reg == 2'b10 && byte_cnt == 3'd3 && bit_cnt == 5'd7)) begin
                if (clk_rising) begin
                    next_state = STATE_FINISH;
                end
            end
        end

        STATE_FINISH: begin
            next_state = STATE_IDLE;
        end

        default: begin
            next_state = STATE_IDLE;
        end
    endcase
end

// 控制逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spi_cs_n <= 1'b1;
        spi_mosi <= 1'b0;
        ready_o <= 1'b1;
        done_o <= 1'b0;
        shift_out <= 8'd0;
        shift_in <= 8'd0;
        bit_cnt <= 5'd0;
        byte_cnt <= 3'd0;
        data_buf <= 32'd0;
        dummy_cnt <= 4'd0;
        rdata_o <= 32'd0;
    end else begin
        done_o <= 1'b0;

        case (state)
            STATE_IDLE: begin
                ready_o <= 1'b1;
                spi_cs_n <= 1'b1;
                bit_cnt <= 5'd0;
                byte_cnt <= 3'd0;
                dummy_cnt <= 4'd0;

                if (start_i && ready_o) begin
                    ready_o <= 1'b0;
                    spi_cs_n <= 1'b0;
                    cmd_reg <= cmd_i;
                    addr_reg <= addr_i;
                    data_len_reg <= data_len_i;

                    // 加载命令到移位寄存器
                    shift_out <= cmd_i;
                end
            end

            STATE_CMD: begin
                if (clk_rising) begin
                    spi_mosi <= shift_out[7];
                    shift_out <= {shift_out[6:0], 1'b0};

                    if (bit_cnt == 5'd7) begin
                        bit_cnt <= 5'd0;
                        // 加载地址到移位寄存器
                        shift_out <= addr_reg[23:16];
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end

            STATE_ADDR: begin
                if (clk_rising) begin
                    spi_mosi <= shift_out[7];
                    shift_out <= {shift_out[6:0], 1'b0};

                    if (bit_cnt == 5'd7) begin
                        shift_out <= addr_reg[15:8];
                    end else if (bit_cnt == 5'd15) begin
                        shift_out <= addr_reg[7:0];
                    end else if (bit_cnt == 5'd23) begin
                        shift_out <= 8'd0;  // 为下一个阶段准备
                    end

                    if (bit_cnt == 5'd23) begin
                        bit_cnt <= 5'd0;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end

            STATE_DUMMY: begin
                if (clk_rising) begin
                    spi_mosi <= 1'b0;

                    if (dummy_cnt == (dummy_cycle-1)) begin
                        dummy_cnt <= 4'd0;
                    end else begin
                        dummy_cnt <= dummy_cnt + 1;
                    end
                end
            end

            STATE_DATA_RD: begin
                if (clk_falling) begin
                    // 在下降沿采样数据
                    shift_in <= {shift_in[6:0], spi_miso};

                    if (bit_cnt == 5'd7) begin
                        bit_cnt <= 5'd0;

                        // 存储接收到的字节
                        case (byte_cnt)
                            3'd0: data_buf[7:0] <= {shift_in[6:0], spi_miso};
                            3'd1: data_buf[15:8] <= {shift_in[6:0], spi_miso};
                            3'd2: data_buf[23:16] <= {shift_in[6:0], spi_miso};
                            3'd3: data_buf[31:24] <= {shift_in[6:0], spi_miso};
                        endcase

                        if ((data_len_reg == 2'b00 && byte_cnt == 3'd0) ||
                            (data_len_reg == 2'b01 && byte_cnt == 3'd1) ||
                            (data_len_reg == 2'b10 && byte_cnt == 3'd3)) begin
                            byte_cnt <= 3'd0;
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end

            STATE_DATA_WR: begin
                if (clk_rising) begin
                    spi_mosi <= shift_out[7];
                    shift_out <= {shift_out[6:0], 1'b0};

                    if (bit_cnt == 5'd7) begin
                        bit_cnt <= 5'd0;

                        if ((data_len_reg == 2'b00 && byte_cnt == 3'd0) ||
                            (data_len_reg == 2'b01 && byte_cnt == 3'd1) ||
                            (data_len_reg == 2'b10 && byte_cnt == 3'd3)) begin
                            byte_cnt <= 3'd0;
                        end else begin
                            byte_cnt <= byte_cnt + 1;

                            // 加载下一个字节（如果有）
                            if (byte_cnt == 3'd0) begin
                                shift_out <= wdata_i[15:8];
                            end else if (byte_cnt == 3'd1) begin
                                shift_out <= wdata_i[23:16];
                            end else if (byte_cnt == 3'd2) begin
                                shift_out <= wdata_i[31:24];
                            end
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            end

            STATE_FINISH: begin
                rdata_o <= data_buf;
                spi_cs_n <= 1'b1;
                done_o <= 1'b1;
                ready_o <= 1'b1;
            end
        endcase
    end
end

endmodule