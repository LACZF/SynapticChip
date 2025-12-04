module ip4_spi_flash_top (
    // 时钟和复位
    input              clk,
    input              rst_n,

    // OBI总线接口
    input              req_i,
    input              we_i,
    input       [31:0] addr_i,
    input       [31:0] wdata_i,
    input       [3:0]  be_i,

    output reg         gnt_o,
    output reg         rvalid_o,
    output reg  [31:0] rdata_o,

    // SPI接口
    output             spi_cs_n_o,
    output             spi_sck_o,
    output             spi_mosi_o,
    input              spi_miso_i
);

    // 内部信号
    wire [31:0] ctrl_rdata;
    wire        ctrl_ready;
    wire        ctrl_done;
    reg         ctrl_start;
    reg  [23:0] ctrl_addr;
    reg  [7:0]  ctrl_cmd;
    reg  [31:0] ctrl_wdata;
    reg  [1:0]  ctrl_data_len;

    wire        spi_clk;
    wire        clk_rising;
    wire        clk_falling;

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
    ip4_spi_clk_gen #(
        .DIV_WIDTH(8),
        .DIV_VALUE(8'd8)  // 分频系数，SPI时钟频率 = clk频率 / 16
    ) u_spi_clk_gen (
        .clk(clk),
        .rst_n(rst_n),
        .enable(!spi_cs_n_o),  // 当CS为低时使能时钟
        .spi_clk(spi_clk),
        .clk_rising(clk_rising),
        .clk_falling(clk_falling)
    );

    // SPI Flash控制器
    ip4_spi_flash_ctrl u_spi_flash_ctrl (
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

        .dummy_cycle_i(dummy_cycle),

        .spi_sck_o(spi_clk),
        .clk_rising_i(clk_rising),
        .clk_falling_i(clk_falling),

        .spi_cs_n_o(spi_cs_n_o),
        .spi_mosi_o(spi_mosi_o),
        .spi_miso_i(spi_miso_i)
    );

    // OBI状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= OBI_IDLE;
            gnt_o    <= 1'b0;
            rvalid_o <= 1'b0;
            rdata_o  <= 32'd0;
            ctrl_start   <= 1'b0;
            dummy_cycle  <= 4'h0;
        end else begin
            state <= next_state;

            case (state)
                OBI_IDLE: begin
                    rvalid_o <= 1'b0;
                    if (req_i && ctrl_ready) begin
                        gnt_o <= 1'b1;
                        ctrl_addr <= addr_i[23:0];
                        ctrl_wdata <= wdata_i;
                        ctrl_data_len <= 2'b10;  // 32位数据

                        // 根据地址最高位确定命令
                        if (we_i) begin
                            if (addr_i[24]) begin
                                ctrl_cmd <= 8'h20;  // 扇区擦除
                            end else begin
                                ctrl_cmd <= 8'h02;  // 页编程
                            end
                            dummy_cycle <= 4'h8;
                        end else begin
                            if (addr_i[24]) begin
                                case (addr_i[23:0])
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
                    gnt_o <= 1'b0;
                    if (ctrl_ready) begin
                        ctrl_start <= 1'b1;
                    end
                end

                OBI_WAIT: begin
                    ctrl_start <= 1'b0;
                    if (ctrl_done) begin
                        rdata_o <= ctrl_rdata;
                    end
                end

                OBI_RESPONSE: begin
                    rvalid_o <= 1'b1;
                end
            endcase
        end
    end

    // 下一状态逻辑
    always @(*) begin
        next_state = state;

        case (state)
            OBI_IDLE: begin
                if (req_i && ctrl_ready) begin
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
    assign spi_sck_o = spi_clk;

endmodule