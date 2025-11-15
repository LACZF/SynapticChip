`timescale 1ns/1ps

module spi_flash_model #(
    parameter FLASH_SIZE    = 8 * 1024 * 1024,  // 8MB Flash容量
    parameter PAGE_SIZE     = 256,
    parameter SECTOR_SIZE   = 4 * 1024,
    parameter BLOCK_SIZE    = 64 * 1024,
    parameter PROGRAM_FILE  = "program.hex"
) (
    input  wire        clk,           // 时钟信号
    input  wire        rst_n,         // 复位信号
    input  wire        cs_n,          // 片选信号（低有效）
    input  wire        sck,           // 串行时钟
    input  wire        mosi,          // 主机输出从机输入
    output reg         miso           // 主机输入从机输出
);

    // Flash状态寄存器
    reg  [7:0]                 status_reg     = 8'h00;       // 状态寄存器
    reg  [7:0]                 config_reg     = 8'h00;       // 配置寄存器
    reg  [7:0]                 security_reg   = 8'h00;       // 安全寄存器

    // Flash操作状态
    reg  [2:0]                 state          = 3'b000;      // 状态机
    reg  [7:0]                 command        = 8'h00;       // 当前命令
    reg  [23:0]                address        = 0;           // 当前地址（24位地址）
    reg  [7:0]                 data_buffer [0:255];          // 数据缓冲区（固定256字节）
    reg  [7:0]                 write_buffer [0:255];          // 写缓冲区（固定256字节）
    reg  [7:0]                 read_buffer [0:255];           // 读缓冲区（固定256字节）

    // 内部计数器
    reg  [7:0]                 bit_count      = 0;           // 位计数器
    reg  [7:0]                 byte_count     = 0;           // 字节计数器
    reg  [7:0]                 wait_count     = 0;           // 等待计数器

    // Flash存储器数组（32位存储，与QSPI Flash模型保持一致）
    reg [31:0] flash_mem[0:(FLASH_SIZE/4)-1];

    // 初始化Flash存储器
    integer i;
    initial begin
        for (i = 0; i < FLASH_SIZE/4; i = i + 1) begin
            flash_mem[i] = 32'hFFFFFFFF;  // Flash初始值为0xFFFFFFFF
        end

        // 加载测试程序到Flash
        $readmemh(PROGRAM_FILE, flash_mem);
        `ifdef DEBUG
            $display("SPI Flash Model: Initialized with %0d bytes", FLASH_SIZE);
            $display("SPI Flash Model: Program loaded from %s", PROGRAM_FILE);

            // 调试：显示前几个字节的内容
            $display("SPI Flash Model: First 16 bytes:");
            for (i = 0; i < 16; i = i + 1) begin
                $display("  Address 0x%06h: 0x%02h", i, flash_mem[i]);
            end
        `endif
    end

    // 状态定义
    localparam STATE_IDLE       = 3'b000;
    localparam STATE_CMD        = 3'b001;
    localparam STATE_ADDR       = 3'b010;
    localparam STATE_DUMMY      = 3'b011;
    localparam STATE_READ       = 3'b100;
    localparam STATE_WRITE      = 3'b101;
    localparam STATE_WAIT       = 3'b110;

    // SPI命令定义
    localparam CMD_READ         = 8'h03;  // 标准读
    localparam CMD_FAST_READ    = 8'h0B;  // 快速读
    localparam CMD_WRITE_EN     = 8'h06;  // 写使能
    localparam CMD_WRITE_DIS    = 8'h04;  // 写禁止
    localparam CMD_READ_STATUS  = 8'h05;  // 读状态
    localparam CMD_WRITE_STATUS = 8'h01;  // 写状态
    localparam CMD_PAGE_PROG    = 8'h02;  // 页编程
    localparam CMD_SECTOR_ERASE = 8'h20;  // 扇区擦除
    localparam CMD_BLOCK_ERASE  = 8'hD8;  // 块擦除
    localparam CMD_CHIP_ERASE   = 8'h60;  // 整片擦除
    localparam CMD_POWER_DOWN   = 8'hB9;  // 掉电
    localparam CMD_RELEASE_PD   = 8'hAB;  // 释放掉电
    localparam CMD_JEDEC_ID     = 8'h9F;  // JEDEC ID

    // 制造商ID和器件ID
    localparam MANUFACTURER_ID  = 8'hEF;  // Winbond
    localparam MEMORY_TYPE      = 8'h40;  // SPI Flash
    localparam CAPACITY         = 8'h17;  // 8MB容量

    // 状态机
    always @(posedge sck or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            command <= 8'h00;
            address <= 0;
            bit_count <= 0;
            byte_count <= 0;
            wait_count <= 0;
            miso <= 1'b0;
        end else if (!cs_n) begin
            case (state)
                STATE_IDLE: begin
                    if (bit_count < 8) begin
                        // 接收命令
                        command[7-bit_count] <= mosi;
                        bit_count <= bit_count + 1;
                    end else begin
                        state <= STATE_ADDR;
                        bit_count <= 0;
                        byte_count <= 0;

                        // 根据命令设置后续状态
                        case (command)
                            CMD_READ, CMD_FAST_READ: begin
                                state <= STATE_ADDR;
                            end
                            CMD_READ_STATUS: begin
                                state <= STATE_READ;
                            end
                            CMD_JEDEC_ID: begin
                                state <= STATE_READ;
                            end
                            CMD_WRITE_EN, CMD_WRITE_DIS: begin
                                // 立即执行
                                if (command == CMD_WRITE_EN)
                                    status_reg[1] <= 1'b1;  // 设置写使能位
                                else
                                    status_reg[1] <= 1'b0;  // 清除写使能位
                                state <= STATE_IDLE;
                            end
                            default: begin
                                state <= STATE_IDLE;
                            end
                        endcase
                    end
                end

                STATE_ADDR: begin
                    if (bit_count < 24) begin
                        // 接收地址（24位）
                        address[23-bit_count] <= mosi;
                        bit_count <= bit_count + 1;
                    end else begin
                        if (command == CMD_FAST_READ) begin
                            state <= STATE_DUMMY;
                        end else begin
                            state <= STATE_READ;
                        end
                        bit_count <= 0;
                    end
                end

                STATE_DUMMY: begin
                    if (bit_count < 8) begin
                        bit_count <= bit_count + 1;
                    end else begin
                        state <= STATE_READ;
                        bit_count <= 0;
                        byte_count <= 0;
                    end
                end

                STATE_READ: begin
                    case (command)
                        CMD_READ_STATUS: begin
                            // 读状态寄存器
                            miso <= status_reg[7-byte_count];
                            if (bit_count < 7) begin
                                bit_count <= bit_count + 1;
                            end else begin
                                bit_count <= 0;
                                byte_count <= byte_count + 1;
                                if (byte_count >= 7) begin
                                    state <= STATE_IDLE;
                                end
                            end
                        end

                        CMD_JEDEC_ID: begin
                            // 读JEDEC ID
                            case (byte_count)
                                0: miso <= MANUFACTURER_ID[7-bit_count];
                                1: miso <= MEMORY_TYPE[7-bit_count];
                                2: miso <= CAPACITY[7-bit_count];
                                default: miso <= 1'b0;
                            endcase

                            if (bit_count < 7) begin
                                bit_count <= bit_count + 1;
                            end else begin
                                bit_count <= 0;
                                byte_count <= byte_count + 1;
                                if (byte_count >= 2) begin
                                    state <= STATE_IDLE;
                                end
                            end
                        end

                        default: begin
                            // 读Flash数据（32位存储）
                            integer word_addr, byte_offset;
                            word_addr = (address + byte_count) / 4;
                            byte_offset = (address + byte_count) % 4;
                            if (word_addr < FLASH_SIZE/4) begin
                                // 根据字节偏移选择正确的字节（小端序）
                                case (byte_offset)
                                    0: miso <= flash_mem[word_addr][7-bit_count];   // 字节0 (LSB)
                                    1: miso <= flash_mem[word_addr][15-bit_count];  // 字节1
                                    2: miso <= flash_mem[word_addr][23-bit_count];  // 字节2
                                    3: miso <= flash_mem[word_addr][31-bit_count];  // 字节3 (MSB)
                                endcase
                            end else begin
                                miso <= 1'b0;  // 地址越界，返回0
                            end

                            if (bit_count < 7) begin
                                bit_count <= bit_count + 1;
                            end else begin
                                bit_count <= 0;
                                byte_count <= byte_count + 1;
                                // 连续读取，直到CS变高
                            end
                        end
                    endcase
                end

                STATE_WRITE: begin
                    // 写操作（简化实现）
                    if (status_reg[1]) begin  // 检查写使能
                        if (bit_count < 7) begin
                            // 使用位操作构建字节
                            data_buffer[byte_count] <= {data_buffer[byte_count][6:0], mosi};
                            bit_count <= bit_count + 1;
                        end else begin
                            bit_count <= 0;
                            byte_count <= byte_count + 1;
                            if (byte_count >= 255) begin  // 固定256字节页大小
                                // 执行页编程（32位存储）
                                for (i = 0; i < 256; i = i + 1) begin
                                    integer write_word_addr, write_byte_offset;
                                    write_word_addr = (address + i) / 4;
                                    write_byte_offset = (address + i) % 4;
                                    if (write_word_addr < FLASH_SIZE/4) begin
                                        // 根据字节偏移更新正确的字节（小端序）
                                        case (write_byte_offset)
                                            0: flash_mem[write_word_addr][7:0] <= data_buffer[i];   // 字节0 (LSB)
                                            1: flash_mem[write_word_addr][15:8] <= data_buffer[i];  // 字节1
                                            2: flash_mem[write_word_addr][23:16] <= data_buffer[i]; // 字节2
                                            3: flash_mem[write_word_addr][31:24] <= data_buffer[i]; // 字节3 (MSB)
                                        endcase
                                    end
                                end
                                state <= STATE_WAIT;
                                wait_count <= 10;  // 10个时钟周期的编程时间
                            end
                        end
                    end
                end

                STATE_WAIT: begin
                    if (wait_count > 0) begin
                        wait_count <= wait_count - 1;
                    end else begin
                        state <= STATE_IDLE;
                        status_reg[0] <= 1'b0;  // 清除忙标志
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end else begin
            // CS变高，复位状态机
            state <= STATE_IDLE;
            bit_count <= 0;
            byte_count <= 0;
            miso <= 1'b0;
        end
    end

    // 状态寄存器更新
    always @(posedge sck or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= 8'h00;
        end else if (state == STATE_WAIT) begin
            status_reg[0] <= 1'b1;  // 设置忙标志
        end
    end

    // 调试信息
    always @(posedge sck) begin
        if (!cs_n) begin
            case (state)
                STATE_IDLE: begin
                    if (bit_count == 7) begin
                        $display("SPI Flash: Received command 0x%02h", command);
                    end
                end
                STATE_ADDR: begin
                    if (bit_count == 23) begin
                        $display("SPI Flash: Address 0x%06h", address);
                    end
                end
                STATE_READ: begin
                    if (command == CMD_READ && bit_count == 7) begin
                        integer debug_word_addr, debug_byte_offset;
                        debug_word_addr = (address + byte_count - 1) / 4;
                        debug_byte_offset = (address + byte_count - 1) % 4;
                        if (debug_word_addr < FLASH_SIZE/4) begin
                            // 根据字节偏移选择正确的字节（小端序）
                            case (debug_byte_offset)
                                0: $display("SPI Flash: Reading data from 0x%06h = 0x%02h",
                                           address + byte_count - 1, flash_mem[debug_word_addr][7:0]);
                                1: $display("SPI Flash: Reading data from 0x%06h = 0x%02h",
                                           address + byte_count - 1, flash_mem[debug_word_addr][15:8]);
                                2: $display("SPI Flash: Reading data from 0x%06h = 0x%02h",
                                           address + byte_count - 1, flash_mem[debug_word_addr][23:16]);
                                3: $display("SPI Flash: Reading data from 0x%06h = 0x%02h",
                                           address + byte_count - 1, flash_mem[debug_word_addr][31:24]);
                            endcase
                        end
                    end
                end
            endcase
        end
    end

endmodule