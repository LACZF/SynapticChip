module spi_flash_top (
    // 时钟和复位
    input clk,
    input rst_n,

    // OBI总线接口
    input obi_req_i,
    input obi_we_i,
    input [31:0] obi_addr_i,
    input [31:0] obi_wdata_i,
    input [3:0] obi_be_i,

    output reg obi_gnt_o,
    output reg obi_rvalid_o,
    output reg [31:0] obi_rdata_o,
    output reg obi_err_o,

    // SPI接口
    output spi_cs_n,
    output spi_sck,
    output spi_mosi,
    input spi_miso
);

// 内部信号
wire [31:0] ctrl_rdata;
wire ctrl_ready;
wire ctrl_done;
reg ctrl_start;
reg [23:0] ctrl_addr;
reg [7:0] ctrl_cmd;
reg [31:0] ctrl_wdata;
reg [1:0] ctrl_data_len;

wire spi_clk;
wire clk_rising;
wire clk_falling;

// 状态机
localparam [2:0]
    OBI_IDLE      = 3'd0,
    OBI_CMD       = 3'd1,
    OBI_WAIT      = 3'd2,
    OBI_RESPONSE  = 3'd3;

reg [2:0] state;
reg [2:0] next_state;
reg [3:0] dummy_cycle;

// SPI时钟生成器
spi_clk_gen #(
    .DIV_WIDTH(8),
    .DIV_VALUE(8'd8)  // 分频系数，SPI时钟频率 = clk频率 / 16
) u_spi_clk_gen (
    .clk(clk),
    .rst_n(rst_n),
    .enable(!spi_cs_n),  // 当CS为低时使能时钟
    .spi_clk(spi_clk),
    .clk_rising(clk_rising),
    .clk_falling(clk_falling)
);

// SPI Flash控制器
spi_flash_ctrl u_spi_flash_ctrl (
    .clk(clk),
    .rst_n(rst_n),

    .addr_i(ctrl_addr),
    .cmd_i(ctrl_cmd),
    .wdata_i(ctrl_wdata),
    .rdata_o(ctrl_rdata),
    .start_i(ctrl_start),
    .ready_o(ctrl_ready),
    .done_o(ctrl_done),
    .data_len_i(ctrl_data_len),

    .dummy_cycle(dummy_cycle),

    .spi_clk(spi_clk),
    .clk_rising(clk_rising),
    .clk_falling(clk_falling),

    .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso)
);

// OBI状态机
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= OBI_IDLE;
        obi_gnt_o <= 1'b0;
        obi_rvalid_o <= 1'b0;
        obi_err_o <= 1'b0;
        obi_rdata_o <= 32'd0;
        ctrl_start <= 1'b0;
        dummy_cycle <= 4'h0;
    end else begin
        state <= next_state;

        case (state)
            OBI_IDLE: begin
                obi_rvalid_o <= 1'b0;
                if (obi_req_i && ctrl_ready) begin
                    obi_gnt_o <= 1'b1;
                    ctrl_addr <= obi_addr_i[23:0];
                    ctrl_wdata <= obi_wdata_i;
                    ctrl_data_len <= 2'b10;  // 32位数据

                    // 根据地址最高位确定命令
                    if (obi_we_i) begin
                        if (obi_addr_i[24]) begin
                            ctrl_cmd <= 8'h20;  // 扇区擦除
                        end else begin
                            ctrl_cmd <= 8'h02;  // 页编程
                        end
                        dummy_cycle <= 4'h8;
                    end else begin
                        if (obi_addr_i[24]) begin
                            case (obi_addr_i[23:0])
                                24'h04 : ctrl_cmd <= 8'h9F;  // 读ID
                                24'h08 : ctrl_cmd <= 8'h05;  // 读status
                                24'h0c : ctrl_cmd <= 8'h35;  // 读status2
                                24'h10 : ctrl_cmd <= 8'h15;  // 读status3
                                default: ctrl_cmd <= 8'h05;  // 读status
                            endcase
                        end else begin
                            ctrl_cmd <= 8'h03;  // 读数据
                        end
                        dummy_cycle <= 4'h1;
                    end
                end
            end

            OBI_CMD: begin
                obi_gnt_o <= 1'b0;
                if (ctrl_ready) begin
                    ctrl_start <= 1'b1;
                end
            end

            OBI_WAIT: begin
                ctrl_start <= 1'b0;
                if (ctrl_done) begin
                    obi_rdata_o <= ctrl_rdata;
                end
            end

            OBI_RESPONSE: begin
                obi_rvalid_o <= 1'b1;
            end
        endcase
    end
end

// 下一状态逻辑
always @(*) begin
    next_state = state;

    case (state)
        OBI_IDLE: begin
            if (obi_req_i && ctrl_ready) begin
                next_state = OBI_CMD;
            end
        end

        OBI_CMD: begin
            if (ctrl_start) begin
                next_state = OBI_WAIT;
            end
        end

        OBI_WAIT: begin
            if (ctrl_done) begin
                next_state = OBI_RESPONSE;
            end
        end

        OBI_RESPONSE: begin
            next_state = OBI_IDLE;
        end
    endcase
end

// 输出SPI时钟
assign spi_sck = spi_clk;

endmodule