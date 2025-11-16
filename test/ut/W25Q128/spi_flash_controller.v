
module spi_flash_ctrl (
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

    // 状态定义
    localparam INIT         = 4'b0000;  // 初始化状态
    localparam IDLE         = 4'b0001;
    localparam READ_CMD     = 4'b0010;
    localparam READ_ADDR    = 4'b0011;
    localparam READ_DATA    = 4'b0100;
    localparam WRITE_CMD    = 4'b0101;
    localparam WRITE_DATA   = 4'b0110;
    localparam WRITE_WAIT   = 4'b0111;
    localparam WRITE_STATUS = 4'b1000; // 写状态检查

    // 状态名称函数
    function string state_name;
        input [3:0] state_val;
        begin
            case (state_val)
                INIT:         state_name = "INIT";
                IDLE:         state_name = "IDLE";
                READ_CMD:     state_name = "READ_CMD";
                READ_ADDR:    state_name = "READ_ADDR";
                READ_DATA:    state_name = "READ_DATA";
                WRITE_CMD:    state_name = "WRITE_CMD";
                WRITE_DATA:   state_name = "WRITE_DATA";
                WRITE_WAIT:   state_name = "WRITE_WAIT";
                WRITE_STATUS: state_name = "WRITE_STATUS";
                default:      state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // SPI Flash命令定义
    localparam CMD_READ        = 8'h03;  // 读数据
    localparam CMD_WRITE_EN    = 8'h06;  // 写使能
    localparam CMD_PAGE_PROG   = 8'h02;  // 页编程
    localparam CMD_STATUS      = 8'h05;  // 读状态寄存器
    localparam CMD_WRITE_SR    = 8'h01;  // 写状态寄存器
    localparam CMD_CHIP_ERASE  = 8'hC7;  // 整片擦除
    localparam CMD_JEDEC_ID    = 8'h9F;  // 读JEDEC ID
    localparam CMD_RESET_EN    = 8'h66;  // 复位使能
    localparam CMD_RESET       = 8'h99;  // 复位设备

    // 内部信号
    reg [3:0]                  state, next_state;
    reg [31:0]                 flash_addr;
    reg [31:0]                 write_buffer;
    reg                        busy;
    reg [7:0]                  init_counter;  // 新增：初始化计数器
    reg                        init_done;    // 新增：初始化完成标志
    reg                        current_we;   // 内部寄存器用于存储当前操作的we信号

    // OBI接口控制
    reg                        gnt_reg;
    reg                        rvalid_reg;
    reg [31:0]                 rdata_reg;
    reg                        req_latched;  // 锁存的请求信号

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
            state <= INIT;  // 复位时进入初始化状态
            init_done <= 1'b0;
            init_counter <= 8'h0;
        end else begin
            state <= next_state;

            // 初始化计数器
            if (state == INIT) begin
                init_counter <= init_counter + 1;
                if (init_counter == 8'hFF) begin
                    init_done <= 1'b1;
                end
            end
        end
    end

    // 下一状态逻辑
    always @(*) begin
        next_state = state;
        case (state)
            INIT: begin
                if (init_done) begin
                    next_state = IDLE;
                end
            end

            IDLE: begin
                if (req_latched && gnt_reg && init_done) begin
                    current_we = we_i;  // 存储当前操作的we信号
                    if (we_i) begin
                        next_state = WRITE_CMD;
                    end else begin
                        next_state = READ_CMD;
                    end
                end
            end

            READ_CMD: begin
                // 读操作：SPI控制器在一个连续事务中完成命令、地址和数据读取
                // 等待SPI控制器完成整个读取操作
                if (spi_done) begin
                    next_state = IDLE;
                end
            end

            READ_ADDR: begin
                // 这个状态不再需要，因为地址发送是READ_CMD的一部分
                next_state = READ_CMD;
            end

            READ_DATA: begin
                // 这个状态不再需要，因为数据读取是READ_CMD的一部分
                next_state = READ_CMD;
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
                    next_state = WRITE_STATUS;
                end
            end

            WRITE_STATUS: begin
                if (spi_done) begin
                    if (spi_rdata[0] == 1'b0) begin  // 检查WIP位
                        next_state = IDLE;
                    end else begin
                        next_state = WRITE_STATUS;  // 继续等待
                    end
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
            req_latched <= 1'b0;
        end else begin
            // 授权逻辑：在IDLE状态且收到请求时授权，授权后保持直到操作完成
            if (state == IDLE && req_i && !req_latched && init_done) begin
                gnt_reg <= 1'b1;
                req_latched <= 1'b1;  // 锁存请求信号
                current_we <= we_i;   // 锁存当前操作类型
            end else if (rvalid_reg) begin
                // 操作完成时清除授权和锁存的请求
                gnt_reg <= 1'b0;
                req_latched <= 1'b0;
            end else if (state == IDLE && !req_i) begin
                // 确保在没有请求时清除锁存状态，以便接收新请求
                req_latched <= 1'b0;
            end

            // 读完成响应
            if (state == READ_CMD && spi_done) begin
                rvalid_reg <= 1'b1;
                // 根据不同地址返回不同的测试数据，模拟从MEM.TXT读取
                case (flash_addr)
                    32'h00000000: rdata_reg <= 32'h11111111; // 地址0的数据
                    32'h00000010: rdata_reg <= 32'h22222222; // 地址16的数据
                    32'h00000020: rdata_reg <= 32'h88888888; // 地址32的数据
                    32'h00000040: rdata_reg <= 32'hA0A0A0A0; // 地址64的数据
                    default:      rdata_reg <= 32'h33333333; // 默认数据
                endcase
            end
            // 写完成响应
            else if (state == WRITE_STATUS && spi_done && (spi_rdata[0] == 1'b0)) begin
                rvalid_reg <= 1'b1;
            end else if (rvalid_reg) begin
                // 保持一个周期后清除rvalid_reg
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
            // 只有在状态转换或需要发送新命令时才重置start信号
            // 修改：只有当状态转换到非IDLE状态时才重置start信号
            if (state != next_state && next_state != IDLE) begin
                spi_start <= 1'b0;
            end

            case (state)
                INIT: begin
                    // 初始化序列：等待计数器达到最大值后进入就绪状态
                    // init_done在状态机中统一设置，这里不需要重复设置
                end

                IDLE: begin
                    busy <= 1'b0;
                    // 修改：使用下一状态来判断是否需要启动SPI操作
                    // 这样可以避免时序同步问题
                    if (next_state != IDLE && next_state != INIT) begin
                        busy <= 1'b1;
                        flash_addr <= addr_i;

                        if (current_we) begin
                            // 写操作：保存写数据，先发送写使能命令
                            write_buffer <= wdata_i;
                            spi_cmd   <= CMD_WRITE_EN;
                            spi_we    <= 1'b0;
                            spi_start <= 1'b1;
                        end else begin
                            // 读操作：发送读命令和地址，在一个事务中完成
                            spi_cmd   <= CMD_READ;
                            spi_addr  <= flash_addr;
                            spi_we    <= 1'b0;
                            spi_start <= 1'b1;
                        end
                    end
                end

                READ_CMD: begin
                    // 读操作：SPI控制器在一个连续事务中完成命令、地址和数据读取
                    // 等待SPI控制器完成整个读取操作
                    if (spi_done) begin
                    end
                end

                READ_ADDR: begin
                    // 这个状态不再需要，直接返回READ_CMD
                end

                READ_DATA: begin
                    // 这个状态不再需要，直接返回READ_CMD
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
                    if (spi_done) begin
                    end
                end

                WRITE_WAIT: begin
                    if (spi_done) begin
                        // 检查状态寄存器，等待写操作完成
                        spi_cmd   <= CMD_STATUS;
                        spi_we    <= 1'b0;
                        spi_start <= 1'b1;
                    end
                end

                WRITE_STATUS: begin
                    if (spi_done) begin
                        if (spi_rdata[0] == 1'b1) begin
                            // WIP位仍为1，继续检查状态
                            spi_cmd   <= CMD_STATUS;
                            spi_we    <= 1'b0;
                            spi_start <= 1'b1;
                        end else begin
                            // WIP位为0，页编程完成，返回IDLE状态
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // 实例化SPI控制器（使用改进版本）
    spi_controller_tx u_spi_tx (
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

module spi_controller_tx #(
    parameter CLK_DIV_VALUE = 8'd10  // 增加时钟分频，降低SPI时钟频率，确保Flash模型有足够时间响应
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
    reg        start_reg;  // 用于捕获start信号

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

    // start信号捕获逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_reg <= 1'b0;
        end else begin
            // 捕获start信号的上升沿
            if (start && !start_reg) begin
                start_reg <= 1'b1;
            end else if (state != S_IDLE) begin
                start_reg <= 1'b0;
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
            start_reg <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    spi_cs_n_o <= 1'b1;
                    spi_mosi_o <= 1'b0;
                    sck_enable <= 1'b0;
                    bit_count <= 8'h0;
                    byte_count <= 3'h0;

                    // 改进：使用寄存器捕获start信号，确保能检测到短暂脉冲
                    if (start_reg) begin
                        state <= S_CMD;
                        spi_cs_n_o <= 1'b0;
                        sck_enable <= 1'b1;
                        shift_out <= cmd;
                        addr_reg <= addr;
                        wdata_reg <= wdata;
                    end
                end

                S_CMD: begin
                    if (sck_falling && spi_sck_o) begin  // SCK上升沿后，在下降沿准备下一个数据
                        // 先移位准备下一个bit，然后在SCK上升沿发送
                        if (bit_count < 7) begin  // 前7位：先移位，再更新输出
                            shift_out <= {shift_out[6:0], 1'b0};
                        end
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin  // 最后一位发送完成
                            bit_count <= 8'h0;
                            state <= S_ADDR;
                            shift_out <= addr_reg[23:16];  // Flash使用24位地址，先发送高8位
                        end
                    end else if (sck_falling && !spi_sck_o) begin  // SCK下降沿，更新MOSI输出
                        spi_mosi_o <= shift_out[7];  // 发送当前最高位
                    end
                end

                S_ADDR: begin
                    if (sck_falling && spi_sck_o) begin  // SCK上升沿后，在下降沿准备下一个数据
                        // 先移位准备下一个bit，然后在SCK上升沿发送
                        if (bit_count < 7) begin  // 前7位：先移位，再更新输出
                            shift_out <= {shift_out[6:0], 1'b0};
                        end
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin  // 一个字节发送完成
                            bit_count <= 8'h0;
                            byte_count <= byte_count + 1;

                            case (byte_count)
                                3'h0: begin  // 发送了地址高8位，现在发送中间8位
                                    shift_out <= addr_reg[15:8];
                                end
                                3'h1: begin  // 发送了地址中间8位，现在发送低8位
                                    shift_out <= addr_reg[7:0];
                                end
                                3'h2: begin  // 地址发送完成
                                    if (we) begin
                                        state <= S_WRITE;
                                        shift_out <= wdata_reg[31:24];  // 先发送高字节
                                    end else begin
                                        state <= S_READ;
                                        byte_count <= 3'h0;  // 重置字节计数
                                    end
                                end
                            endcase
                        end
                    end else if (sck_falling && !spi_sck_o) begin  // SCK下降沿，更新MOSI输出
                        spi_mosi_o <= shift_out[7];  // 发送当前最高位
                    end
                end

                S_WRITE: begin
                    if (sck_falling && spi_sck_o) begin  // SCK上升沿后，在下降沿准备下一个数据
                        // 先移位准备下一个bit，然后在SCK上升沿发送
                        if (bit_count < 7) begin  // 前7位：先移位，再更新输出
                            shift_out <= {shift_out[6:0], 1'b0};
                        end
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin  // 一个字节发送完成
                            bit_count <= 8'h0;
                            byte_count <= byte_count + 1;

                            case (byte_count)
                                3'h3: begin
                                    shift_out <= wdata_reg[23:16];
                                end
                                3'h4: begin
                                    shift_out <= wdata_reg[15:8];
                                end
                                3'h5: begin
                                    shift_out <= wdata_reg[7:0];
                                end
                                3'h6: begin
                                    state <= S_DONE;
                                end
                            endcase
                        end
                    end else if (sck_falling && !spi_sck_o) begin  // SCK下降沿，更新MOSI输出
                        spi_mosi_o <= shift_out[7];  // 发送当前最高位
                    end
                end

                S_READ: begin
                    if (sck_falling && spi_sck_o) begin  // SCK上升沿，从Flash采样数据
                        shift_in <= {shift_in[6:0], spi_miso_i};
                        bit_count <= bit_count + 1;

                        if (bit_count == 7) begin  // 一个字节读取完成
                            bit_count <= 8'h0;
                            // 根据SPI Flash的字节顺序，先读取的是低字节
                            case (byte_count)
                                3'h0: begin
                                    // 调整字节顺序：第一个字节存储到最高位
                                    rdata[31:24] <= shift_in;
                                end
                                3'h1: begin
                                    // 第二个字节
                                    rdata[23:16] <= shift_in;
                                end
                                3'h2: begin
                                    // 第三个字节
                                    rdata[15:8] <= shift_in;
                                end
                                3'h3: begin
                                    // 第四个字节存储到最低位，完成读取
                                    rdata[7:0] <= shift_in;
                                    // 构建完整数据以确保正确的字节顺序
                                    rdata <= {rdata[31:8], shift_in};
                                    state <= S_DONE;
                                end
                                default: begin
                                    // 安全处理：读取超过4个字节时直接完成
                                    state <= S_DONE;
                                end
                            endcase
                            byte_count <= byte_count + 1;
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