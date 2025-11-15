`timescale 1ns/1ps

module qspi_flash_model #(
    parameter FLASH_SIZE   = 16 * 1024 * 1024,
    parameter PAGE_SIZE    = 256,
    parameter SECTOR_SIZE  = 4 * 1024,
    parameter BLOCK_SIZE   = 64 * 1024,
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter PROGRAM_FILE = "program.hex"
) (
    input  wire              clk,           // 时钟信号
    input  wire              rst_n,         // 复位信号
    input  wire              cs_n,          // 片选信号（低有效）
    input  wire              sck,           // 串行时钟
    input  wire [3:0]        io_in,         // QSPI输入数据线
    output reg  [3:0]        io_out,        // QSPI输出数据线
    output reg               io_oe          // 输出使能
);

    // Flash状态寄存器
    reg [7:0] status_reg = 8'h00;           // 状态寄存器
    reg [7:0] config_reg = 8'h00;           // 配置寄存器
    reg [7:0] security_reg = 8'h00;         // 安全寄存器

    // Flash操作状态
    reg [2:0] state = 3'b000;               // 状态机
    reg [7:0] command = 8'h00;              // 当前命令
    reg [ADDR_WIDTH-1:0] address = 0;       // 当前地址
    reg [7:0] data_buffer[0:PAGE_SIZE-1];   // 数据缓冲区
    reg [7:0] write_buffer[0:PAGE_SIZE-1];  // 写缓冲区
    reg [7:0] read_buffer[0:PAGE_SIZE-1];   // 读缓冲区

    // 内部计数器
    reg [7:0] bit_count = 0;                 // 位计数器
    reg [7:0] byte_count = 0;               // 字节计数器
    reg [7:0] wait_count = 0;               // 等待计数器

    // Flash存储器数组
    reg [DATA_WIDTH-1:0] flash_mem[0:FLASH_SIZE-1];

    // 初始化Flash存储器
    integer i;
    initial begin
        for (i = 0; i < FLASH_SIZE; i = i + 1) begin
            flash_mem[i] = 8'hFF;  // Flash初始值为0xFF
        end

        // 加载测试程序到Flash
        $readmemh(PROGRAM_FILE, flash_mem);
    end

    // 状态定义
    localparam STATE_IDLE      = 3'b000;
    localparam STATE_CMD       = 3'b001;
    localparam STATE_ADDR      = 3'b010;
    localparam STATE_DUMMY     = 3'b011;
    localparam STATE_READ      = 3'b100;
    localparam STATE_WRITE     = 3'b101;
    localparam STATE_WAIT      = 3'b110;

    // QSPI命令定义
    localparam CMD_READ        = 8'h03;  // 标准读
    localparam CMD_FAST_READ   = 8'h0B;  // 快速读
    localparam CMD_DUAL_READ   = 8'h3B;  // 双线读
    localparam CMD_QUAD_READ   = 8'h6B;  // 四线读
    localparam CMD_WRITE_EN    = 8'h06;  // 写使能
    localparam CMD_WRITE_DIS   = 8'h04;  // 写禁止
    localparam CMD_READ_STATUS = 8'h05;  // 读状态
    localparam CMD_WRITE_STATUS= 8'h01;  // 写状态
    localparam CMD_PAGE_PROG   = 8'h02;  // 页编程
    localparam CMD_SECTOR_ERASE= 8'h20;  // 扇区擦除
    localparam CMD_BLOCK_ERASE  = 8'hD8;  // 块擦除
    localparam CMD_CHIP_ERASE   = 8'h60;  // 整片擦除
    localparam CMD_POWER_DOWN   = 8'hB9;  // 掉电
    localparam CMD_RELEASE_PD   = 8'hAB;  // 释放掉电
    localparam CMD_MANUF_ID     = 8'h90;  // 制造商ID
    localparam CMD_JEDEC_ID     = 8'h9F;  // JEDEC ID

    // 制造商ID和器件ID
    localparam MANUFACTURER_ID = 8'hEF;  // Winbond
    localparam MEMORY_TYPE     = 8'h40;  // QSPI Flash
    localparam CAPACITY        = 8'h17;  // 16MB容量

    // 状态机
    always @(posedge sck or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            command <= 8'h00;
            address <= 0;
            bit_count <= 0;
            byte_count <= 0;
            wait_count <= 0;
            io_out <= 4'b0000;
            io_oe <= 1'b0;
        end else if (!cs_n) begin
            case (state)
                STATE_IDLE: begin
                    if (bit_count < 8) begin
                        // 接收命令
                        command[7-bit_count] <= io_in[0];
                        bit_count <= bit_count + 1;
                    end else begin
                        state <= STATE_ADDR;
                        bit_count <= 0;
                        byte_count <= 0;

                        // 根据命令设置后续状态
                        case (command)
                            CMD_READ, CMD_FAST_READ, CMD_DUAL_READ, CMD_QUAD_READ: begin
                                state <= STATE_ADDR;
                            end
                            CMD_READ_STATUS: begin
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
                    if (bit_count < ADDR_WIDTH) begin
                        // 接收地址
                        address[ADDR_WIDTH-1-bit_count] <= io_in[0];
                        bit_count <= bit_count + 1;
                    end else begin
                        state <= STATE_DUMMY;
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
                    if (command == CMD_READ_STATUS) begin
                        // 读状态寄存器
                        io_out <= {4{status_reg[7-byte_count]}};
                        io_oe <= 1'b1;
                        if (bit_count < 7) begin
                            bit_count <= bit_count + 1;
                        end else begin
                            bit_count <= 0;
                            byte_count <= byte_count + 1;
                            if (byte_count >= 7) begin
                                state <= STATE_IDLE;
                                io_oe <= 1'b0;
                            end
                        end
                    end else begin
                        // 读Flash数据
                        io_out <= {4{flash_mem[address + byte_count][7-bit_count]}};
                        io_oe <= 1'b1;
                        if (bit_count < 7) begin
                            bit_count <= bit_count + 1;
                        end else begin
                            bit_count <= 0;
                            byte_count <= byte_count + 1;
                            // 连续读取，直到CS变高
                        end
                    end
                end

                STATE_WRITE: begin
                    // 写操作（简化实现）
                    if (status_reg[1]) begin  // 检查写使能
                        if (bit_count < 7) begin
                            data_buffer[byte_count][7-bit_count] <= io_in[0];
                            bit_count <= bit_count + 1;
                        end else begin
                            bit_count <= 0;
                            byte_count <= byte_count + 1;
                            if (byte_count >= PAGE_SIZE) begin
                                // 执行页编程
                                for (i = 0; i < PAGE_SIZE; i = i + 1) begin
                                    flash_mem[address + i] <= data_buffer[i];
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
            io_oe <= 1'b0;
        end
    end

    // 状态寄存器位定义
    // bit 0: WIP (Write In Progress) - 写操作进行中
    // bit 1: WEL (Write Enable Latch) - 写使能锁存
    // bit 2-7: 保留
    always @(*) begin
        status_reg[0] = (state == STATE_WAIT);  // 忙标志
    end

endmodule