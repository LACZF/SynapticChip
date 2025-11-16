module spi_flash_controller (
    // 时钟和复位
    input  wire         clk,
    input  wire         rst_n,

    // OBI总线接口
    input  wire         req_i,
    output wire         gnt_o,
    output wire         rvalid_o,
    input  wire [31:0]  addr_i,
    input  wire         we_i,
    input  wire [3:0]   be_i,
    input  wire [31:0]  wdata_i,
    output wire [31:0]  rdata_o,

    // SPI接口
    output wire         spi_cs_n_o,
    output wire         spi_sck_o,
    output wire         spi_mosi_o,
    input  wire         spi_miso_i
);

    // 参数定义
    localparam IDLE            = 3'b000;
    localparam READ_CMD        = 3'b001;
    localparam READ_DATA       = 3'b010;
    localparam WRITE_CMD       = 3'b011;
    localparam WRITE_DATA      = 3'b100;
    localparam WRITE_WAIT      = 3'b101;

    // SPI Flash命令定义
    localparam CMD_READ        = 8'h03;  // 读数据
    localparam CMD_WRITE_EN    = 8'h06;  // 写使能
    localparam CMD_PAGE_PROG   = 8'h02;  // 页编程
    localparam CMD_STATUS      = 8'h05;  // 读状态寄存器
    localparam CMD_WRITE_SR    = 8'h01;  // 写状态寄存器
    localparam CMD_CHIP_ERASE  = 8'hC7;  // 整片擦除

    // 内部信号
    reg [2:0]                  state, next_state;
    reg [31:0]                 flash_addr;
    reg [31:0]                 write_buffer;
    reg                        busy;

    // OBI接口控制
    reg                        gnt_reg;
    reg                        rvalid_reg;
    reg [31:0]                 rdata_reg;

    // SPI控制器接口
    reg                        spi_start;
    reg                        spi_we;
    reg  [7:0]                 spi_cmd;
    reg  [31:0]                spi_addr;
    reg  [31:0]                spi_wdata;
    wire                       spi_done;
    wire [31:0]                spi_rdata;

    // OBI输出赋值
    assign gnt_o               = gnt_reg;
    assign rvalid_o            = rvalid_reg;
    assign rdata_o             = rdata_reg;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 下一状态逻辑
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (req_i && gnt_reg) begin
                    if (we_i) begin
                        next_state = WRITE_CMD;
                    end else begin
                        next_state = READ_CMD;
                    end
                end
            end

            READ_CMD: begin
                if (spi_done) begin
                    next_state = READ_DATA;
                end
            end

            READ_DATA: begin
                if (spi_done) begin
                    next_state = IDLE;
                end
            end

            WRITE_CMD: begin
                if (spi_done) begin
                    next_state = WRITE_DATA;
                end
            end

            WRITE_DATA: begin
                if (spi_done) begin
                    next_state = WRITE_WAIT;
                end
            end

            WRITE_WAIT: begin
                if (spi_done) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // OBI接口控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gnt_reg    <= 1'b0;
            rvalid_reg <= 1'b0;
            rdata_reg  <= 32'h0;
        end else begin
            // 授权逻辑：空闲状态且收到请求时授权
            gnt_reg <= req_i && (state == IDLE);

            // 读完成响应
            if (state == READ_DATA && spi_done) begin
                rvalid_reg <= 1'b1;
                rdata_reg  <= spi_rdata;
            end
            // 写完成响应
            else if (state == WRITE_WAIT && spi_done) begin
                rvalid_reg <= 1'b1;
            end else begin
                rvalid_reg <= 1'b0;
            end
        end
    end

    // SPI控制器控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_start <= 1'b0;
            spi_we <= 1'b0;
            spi_cmd <= 8'h0;
            spi_addr <= 32'h0;
            spi_wdata <= 32'h0;
            flash_addr <= 32'h0;
            write_buffer <= 32'h0;
            busy <= 1'b0;
        end else begin
            spi_start <= 1'b0;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (req_i && gnt_reg) begin
                        busy <= 1'b1;
                        flash_addr <= addr_i;

                        if (we_i) begin
                            // 写操作：保存写数据，先发送写使能命令
                            write_buffer <= wdata_i;
                            spi_cmd   <= CMD_WRITE_EN;
                            spi_we    <= 1'b0;
                            spi_start <= 1'b1;
                        end else begin
                            // 读操作：直接发送读命令
                            spi_cmd   <= CMD_READ;
                            spi_addr  <= addr_i;
                            spi_we    <= 1'b0;
                            spi_start <= 1'b1;
                        end
                    end
                end

                READ_CMD: begin
                    if (spi_done) begin
                        // 读命令发送完成，开始读取数据
                        spi_cmd   <= CMD_READ;
                        spi_addr  <= flash_addr;
                        spi_we    <= 1'b0;
                        spi_start <= 1'b1;
                    end
                end

                READ_DATA: begin
                    // 等待SPI控制器完成数据读取
                    // 不需要额外操作，等待spi_done信号
                end

                WRITE_CMD: begin
                    if (spi_done) begin
                        // 写使能完成，发送页编程命令
                        spi_cmd   <= CMD_PAGE_PROG;
                        spi_addr  <= flash_addr;
                        spi_wdata <= write_buffer;
                        spi_we    <= 1'b1;
                        spi_start <= 1'b1;
                    end
                end

                WRITE_DATA: begin
                    // 等待页编程命令完成
                    // 不需要额外操作，等待spi_done信号
                end

                WRITE_WAIT: begin
                    if (!spi_done) begin
                        // 检查状态寄存器，等待写操作完成
                        spi_cmd   <= CMD_STATUS;
                        spi_we    <= 1'b0;
                        spi_start <= 1'b1;
                    end
                end
            endcase
        end
    end

    // 实例化SPI控制器
    spi_controller u_spi_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .start(spi_start),
        .we(spi_we),
        .cmd(spi_cmd),
        .addr(spi_addr),
        .wdata(spi_wdata),
        .done(spi_done),
        .rdata(spi_rdata),
        .spi_cs_n_o(spi_cs_n_o),
        .spi_sck_o(spi_sck_o),
        .spi_mosi_o(spi_mosi_o),
        .spi_miso_i(spi_miso_i)
    );

endmodule

// SPI控制器模块（保持不变）
module spi_controller #(
    parameter CLK_DIV_VALUE = 8'd1
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        we,
    input  wire [7:0]  cmd,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg         done,
    output reg  [31:0] rdata,

    // SPI物理接口
    output reg         spi_cs_n_o,
    output reg         spi_sck_o,
    output reg         spi_mosi_o,
    input  wire        spi_miso_i
);

    // 状态定义
    localparam S_IDLE    = 4'b0000;
    localparam S_CMD     = 4'b0001;
    localparam S_ADDR    = 4'b0010;
    localparam S_WRITE   = 4'b0011;
    localparam S_READ    = 4'b0100;
    localparam S_DONE    = 4'b0101;

    // 时钟分频
    reg [7:0] clk_div;
    reg [7:0] clk_counter;
    reg       sck_enable;
    reg       sck_falling;

    // 控制信号
    reg [3:0]  state;
    reg [7:0]  bit_count;
    reg [2:0]  byte_count;
    reg [7:0]  shift_out;
    reg [7:0]  shift_in;
    reg [31:0] addr_reg;
    reg [31:0] wdata_reg;

    // 时钟分频逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= 8'h0;
            sck_falling <= 1'b0;
        end else begin
            if (sck_enable) begin
                if (clk_counter == clk_div) begin
                    clk_counter <= 8'h0;
                    sck_falling <= ~sck_falling;
                end else begin
                    clk_counter <= clk_counter + 1;
                    sck_falling <= 1'b0;
                end
            end else begin
                clk_counter <= 8'h0;
                sck_falling <= 1'b0;
            end
        end
    end

    // SPI SCK生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_sck_o <= 1'b0;
        end else begin
            if (sck_enable && sck_falling) begin
                spi_sck_o <= ~spi_sck_o;
            end else if (!sck_enable) begin
                spi_sck_o <= 1'b0;
            end
        end
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            spi_cs_n_o <= 1'b1;
            spi_mosi_o <= 1'b0;
            done <= 1'b0;
            rdata <= 32'h0;
            sck_enable <= 1'b0;
            bit_count <= 8'h0;
            byte_count <= 3'h0;
            shift_out <= 8'h0;
            shift_in <= 8'h0;
            addr_reg <= 32'h0;
            wdata_reg <= 32'h0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    spi_cs_n_o <= 1'b1;
                    spi_mosi_o <= 1'b0;
                    sck_enable <= 1'b0;
                    bit_count <= 8'h0;
                    byte_count <= 3'h0;

                    if (start) begin
                        state <= S_CMD;
                        spi_cs_n_o <= 1'b0;
                        sck_enable <= 1'b1;
                        shift_out <= cmd;
                        addr_reg <= addr;
                        wdata_reg <= wdata;
                    end
                end

                S_CMD: begin
                    if (sck_falling && !spi_sck_o) begin
                        // SCK下降沿发送数据
                        spi_mosi_o <= shift_out[7];
                        shift_out <= {shift_out[6:0], 1'b0};
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count <= 8'h0;
                            state <= S_ADDR;
                            shift_out <= addr_reg[31:24];
                        end
                    end
                end

                S_ADDR: begin
                    if (sck_falling && !spi_sck_o) begin
                        spi_mosi_o <= shift_out[7];
                        shift_out <= {shift_out[6:0], 1'b0};
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count <= 8'h0;
                            byte_count <= byte_count + 1;

                            case (byte_count)
                                3'h0: shift_out <= addr_reg[23:16];
                                3'h1: shift_out <= addr_reg[15:8];
                                3'h2: begin
                                    shift_out <= addr_reg[7:0];
                                    if (we) begin
                                        state <= S_WRITE;
                                    end else begin
                                        state <= S_READ;
                                    end
                                end
                            endcase
                        end
                    end
                end

                S_WRITE: begin
                    if (sck_falling && !spi_sck_o) begin
                        spi_mosi_o <= shift_out[7];
                        shift_out <= {shift_out[6:0], 1'b0};
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count <= 8'h0;
                            byte_count <= byte_count + 1;

                            case (byte_count)
                                3'h3: shift_out <= wdata_reg[31:24];
                                3'h4: shift_out <= wdata_reg[23:16];
                                3'h5: shift_out <= wdata_reg[15:8];
                                3'h6: begin
                                    shift_out <= wdata_reg[7:0];
                                    state <= S_DONE;
                                end
                            endcase
                        end
                    end
                end

                S_READ: begin
                    if (sck_falling && spi_sck_o) begin
                        // SCK上升沿采样数据
                        shift_in <= {shift_in[6:0], spi_miso_i};
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin
                            bit_count <= 8'h0;
                            byte_count <= byte_count + 1;

                            case (byte_count)
                                3'h3: rdata[31:24] <= {shift_in[6:0], spi_miso_i};
                                3'h4: rdata[23:16] <= {shift_in[6:0], spi_miso_i};
                                3'h5: rdata[15:8] <= {shift_in[6:0], spi_miso_i};
                                3'h6: begin
                                    rdata[7:0] <= {shift_in[6:0], spi_miso_i};
                                    state <= S_DONE;
                                end
                            endcase
                        end
                    end
                end

                S_DONE: begin
                    spi_cs_n_o <= 1'b1;
                    sck_enable <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= CLK_DIV_VALUE;
        end
    end

endmodule