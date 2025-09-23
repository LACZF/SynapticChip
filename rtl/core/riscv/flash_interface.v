// flash_interface.v
module flash_interface (
    input wire clk,
    input wire rst_n,

    // 缓存系统接口
    input wire [31:0] cache_addr,
    input wire [31:0] cache_data_in,
    output reg [31:0] cache_data_out,
    input wire cache_req,
    input wire cache_we,
    output reg cache_ack,
    output reg cache_busy,

    // 外部Flash物理接口
    output reg flash_cs_n,      // Flash片选
    output reg flash_clk,       // Flash时钟
    output reg flash_mosi,      // Master Out Slave In
    input wire flash_miso,      // Master In Slave Out
    output reg [3:0] flash_dq_o, // 数据线输出（QSPI模式）
    input wire [3:0] flash_dq_i, // 数据线输入
    output reg flash_dq_oe,     // 数据线输出使能

    // 状态指示
    output reg [2:0] state_out
);

    // Flash命令定义
    localparam CMD_READ_DATA = 8'h03;     // 读数据
    localparam CMD_FAST_READ = 8'h0B;     // 快速读
    localparam CMD_READ_DUAL = 8'h3B;     // 双线读
    localparam CMD_READ_QUAD = 8'h6B;     // 四线读
    localparam CMD_PAGE_PROGRAM = 8'h02;  // 页编程
    localparam CMD_QUAD_PAGE_PROGRAM = 8'h32; // 四线页编程
    localparam CMD_SECTOR_ERASE = 8'h20;  // 扇区擦除
    localparam CMD_BLOCK_ERASE = 8'hD8;   // 块擦除
    localparam CMD_CHIP_ERASE = 8'hC7;    // 整片擦除
    localparam CMD_WRITE_ENABLE = 8'h06;  // 写使能
    localparam CMD_WRITE_DISABLE = 8'h04; // 写禁止
    localparam CMD_READ_STATUS = 8'h05;   // 读状态寄存器
    localparam CMD_WRITE_STATUS = 8'h01;  // 写状态寄存器

    // 操作模式
    localparam MODE_SPI = 2'b00;    // 标准SPI
    localparam MODE_DUAL = 2'b01;   // 双线输出
    localparam MODE_QUAD = 2'b10;   // 四线I/O

    // 状态机状态
    localparam STATE_IDLE = 4'b0000;
    localparam STATE_CMD = 4'b0001;
    localparam STATE_ADDR = 4'b0010;
    localparam STATE_DUMMY = 4'b0011;
    localparam STATE_READ = 4'b0100;
    localparam STATE_WRITE = 4'b0101;
    localparam STATE_WAIT_BUSY = 4'b0110;
    localparam STATE_ERASE = 4'b0111;

    // 内部寄存器
    reg [3:0] state;
    reg [7:0] command;
    reg [31:0] address;
    reg [31:0] write_data;
    reg [5:0] bit_counter;
    reg [7:0] byte_counter;
    reg [15:0] wait_counter;
    reg [2:0] operation_mode;
    reg write_enable;

    // 状态输出
    assign state_out = state;

    // SPI时钟生成（分频）
    reg [3:0] clk_divider;
    reg spi_clk;
    reg spi_clk_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider <= 4'h0;
            spi_clk <= 1'b0;
        end else begin
            clk_divider <= clk_divider + 1;
            if (clk_divider == 4'h7) begin
                spi_clk <= ~spi_clk;
            end
        end
    end

    always @(posedge clk) begin
        spi_clk_prev <= spi_clk;
    end
    wire spi_clk_edge = spi_clk && !spi_clk_prev;

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cache_ack <= 1'b0;
            cache_busy <= 1'b0;
            flash_cs_n <= 1'b1;
            flash_mosi <= 1'b0;
            flash_dq_o <= 4'h0;
            flash_dq_oe <= 1'b0;
            command <= 8'h00;
            address <= 32'h0;
            write_data <= 32'h0;
            bit_counter <= 6'h0;
            byte_counter <= 8'h0;
            wait_counter <= 16'h0;
            operation_mode <= MODE_QUAD;  // 默认使用四线模式
            write_enable <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    cache_ack <= 1'b0;
                    cache_busy <= 1'b0;
                    flash_cs_n <= 1'b1;
                    flash_dq_oe <= 1'b0;

                    if (cache_req) begin
                        state <= STATE_CMD;
                        cache_busy <= 1'b1;
                        address <= cache_addr;
                        write_data <= cache_data_in;

                        if (cache_we) begin
                            // 写操作：需要先使能写操作
                            command <= CMD_WRITE_ENABLE;
                            state <= STATE_CMD;
                        end else begin
                            // 读操作：直接发送读命令
                            command <= (operation_mode == MODE_QUAD) ? CMD_READ_QUAD : CMD_READ_DATA;
                            state <= STATE_CMD;
                        end
                    end
                end

                STATE_CMD: begin
                    flash_cs_n <= 1'b0;

                    if (spi_clk_edge) begin
                        if (bit_counter < 8) begin
                            // 发送命令字节
                            if (operation_mode == MODE_SPI) begin
                                flash_mosi <= command[7 - bit_counter[2:0]];
                            end else if (operation_mode == MODE_QUAD) begin
                                flash_dq_oe <= 1'b1;
                                flash_dq_o <= {4{command[7 - bit_counter[2:0]]}};
                            end

                            bit_counter <= bit_counter + 1;
                        end else begin
                            bit_counter <= 6'h0;
                            if (command == CMD_WRITE_ENABLE) begin
                                // 写使能命令完成，开始实际写操作
                                flash_cs_n <= 1'b1;
                                wait_counter <= 16'h10;  // 短暂等待
                                state <= STATE_WAIT_BUSY;
                                command <= CMD_QUAD_PAGE_PROGRAM;
                            end else begin
                                state <= STATE_ADDR;
                            end
                        end
                    end
                end

                STATE_ADDR: begin
                    if (spi_clk_edge) begin
                        if (bit_counter < 24) begin  // 24位地址（3字节）
                            if (operation_mode == MODE_SPI) begin
                                flash_mosi <= address[23 - bit_counter[2:0]];
                            end else if (operation_mode == MODE_QUAD) begin
                                flash_dq_o <= {4{address[23 - bit_counter[2:0]]}};
                            end

                            bit_counter <= bit_counter + 1;
                        end else begin
                            bit_counter <= 6'h0;

                            if (command == CMD_READ_QUAD) begin
                                // 四线读需要 dummy cycle
                                state <= STATE_DUMMY;
                            end else if (command == CMD_QUAD_PAGE_PROGRAM) begin
                                state <= STATE_WRITE;
                            end else begin
                                state <= STATE_READ;
                            end
                        end
                    end
                end

                STATE_DUMMY: begin
                    if (spi_clk_edge) begin
                        if (bit_counter < 8) begin  // 8个dummy周期
                            if (operation_mode == MODE_QUAD) begin
                                flash_dq_oe <= 1'b0;  // 切换到输入模式
                            end
                            bit_counter <= bit_counter + 1;
                        end else begin
                            bit_counter <= 6'h0;
                            state <= STATE_READ;
                        end
                    end
                end

                STATE_READ: begin
                    if (spi_clk_edge) begin
                        if (operation_mode == MODE_SPI) begin
                            // SPI模式读取
                            cache_data_out <= {cache_data_out[30:0], flash_miso};
                        end else if (operation_mode == MODE_QUAD) begin
                            // 四线模式读取
                            cache_data_out <= {cache_data_out[27:0], flash_dq_i};
                        end

                        bit_counter <= bit_counter + (operation_mode == MODE_QUAD ? 4 : 1);

                        if (bit_counter >= 31) begin  // 读取32位完成
                            flash_cs_n <= 1'b1;
                            cache_ack <= 1'b1;
                            state <= STATE_IDLE;
                        end
                    end
                end

                STATE_WRITE: begin
                    if (spi_clk_edge) begin
                        if (operation_mode == MODE_QUAD) begin
                            flash_dq_oe <= 1'b1;
                            flash_dq_o <= write_data[31:28];
                            write_data <= {write_data[27:0], 4'h0};
                        end

                        bit_counter <= bit_counter + 4;

                        if (bit_counter >= 28) begin  // 写入32位完成
                            flash_cs_n <= 1'b1;
                            cache_ack <= 1'b1;

                            // 等待写操作完成
                            wait_counter <= 16'h100;
                            state <= STATE_WAIT_BUSY;
                        end
                    end
                end

                STATE_WAIT_BUSY: begin
                    if (wait_counter > 0) begin
                        wait_counter <= wait_counter - 1;
                    end else begin
                        if (command == CMD_WRITE_ENABLE) begin
                            // 写使能完成，开始实际写操作
                            state <= STATE_CMD;
                            command <= CMD_QUAD_PAGE_PROGRAM;
                        end else begin
                            // 写操作完成
                            state <= STATE_IDLE;
                        end
                    end
                end

                STATE_ERASE: begin
                    // 擦除操作（简化实现）
                    if (wait_counter > 0) begin
                        wait_counter <= wait_counter - 1;
                    end else begin
                        cache_ack <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

    // Flash时钟输出
    assign flash_clk = spi_clk;

endmodule
