`include "common.v"

// SPI Flash控制器模块
// 对接OBI总线系统，将来自OBI总线的读写操作转换为对SPI Flash的直接读写
module spi_flash_top #(
    parameter DATA_WIDTH             = 32,
    parameter ADDR_WIDTH             = 32,
    parameter FLASH_SIZE             = 8 * 1024 * 1024,
    parameter FLASH_ADDR_WIDTH       = 24
) (
    input  wire                      clk,
    input  wire                      rst_n,

    // OBI总线接口
    input  wire                      req_i,
    input  wire                      we_i,
    input  wire [ADDR_WIDTH-1:0]     addr_i,
    input  wire [DATA_WIDTH-1:0]     data_in_i,
    output reg  [DATA_WIDTH-1:0]     data_out_o,
    output reg                       gnt_o,
    output reg                       rvalid_o,

    // SPI Flash物理接口
    output reg                       spi_cs_n_o,
    output reg                       spi_clk_o,
    output reg                       spi_mosi_o,
    input  wire                      spi_miso_i
);

    // SPI Flash命令定义
    localparam CMD_WRITE_ENABLE       = 8'h06;  // 写使能
    localparam CMD_WRITE_DISABLE      = 8'h04;  // 写禁止
    localparam CMD_READ_STATUS        = 8'h05;  // 读状态寄存器
    localparam CMD_WRITE_STATUS       = 8'h01;  // 写状态寄存器
    localparam CMD_READ_DATA          = 8'h03;  // 标准读数据
    localparam CMD_FAST_READ          = 8'h0B;  // 快速读数据
    localparam CMD_PAGE_PROGRAM       = 8'h02;  // 页编程
    localparam CMD_SECTOR_ERASE       = 8'h20;  // 扇区擦除
    localparam CMD_BLOCK_ERASE_32K    = 8'h52;  // 32K块擦除
    localparam CMD_BLOCK_ERASE_64K    = 8'hD8;  // 64K块擦除
    localparam CMD_CHIP_ERASE         = 8'hC7;  // 整片擦除
    localparam CMD_POWER_DOWN         = 8'hB9;  // 掉电
    localparam CMD_RELEASE_POWER_DOWN = 8'hAB; // 释放掉电
    localparam CMD_DEVICE_ID          = 8'hAB;  // 器件ID
    localparam CMD_JEDEC_ID           = 8'h9F;  // JEDEC ID
    localparam CMD_READ_UNIQUE_ID     = 8'h4B;  // 读唯一ID
    localparam CMD_ENABLE_RESET       = 8'h66;  // 使能复位
    localparam CMD_RESET_DEVICE       = 8'h99;  // 复位器件

    // 状态寄存器位定义
    localparam STATUS_BUSY            = 0;      // 忙标志
    localparam STATUS_WEL             = 1;      // 写使能锁存
    localparam STATUS_BP0             = 2;      // 块保护位0
    localparam STATUS_BP1             = 3;      // 块保护位1
    localparam STATUS_BP2             = 4;      // 块保护位2
    localparam STATUS_TB              = 5;      // 顶部/底部保护
    localparam STATUS_SEC             = 6;      // 扇区/块保护
    localparam STATUS_SRP0            = 7;      // 状态寄存器保护0

    // 控制器状态定义
    localparam STATE_IDLE             = 4'b0000;
    localparam STATE_READ_CMD         = 4'b0001;
    localparam STATE_READ_ADDR        = 4'b0010;
    localparam STATE_READ_DATA        = 4'b0011;
    localparam STATE_WRITE_CMD        = 4'b0100;
    localparam STATE_WRITE_ADDR       = 4'b0101;
    localparam STATE_WRITE_DATA       = 4'b0110;
    localparam STATE_WRITE_ENABLE     = 4'b0111;
    localparam STATE_WRITE_WAIT       = 4'b1000;
    localparam STATE_ERASE_CMD        = 4'b1001;
    localparam STATE_ERASE_ADDR       = 4'b1010;
    localparam STATE_ERASE_WAIT       = 4'b1011;
    localparam STATE_STATUS_READ      = 4'b1100;
    localparam STATE_ID_READ          = 4'b1101;

    // 内部寄存器
    reg [3:0]                         state;
    reg [3:0]                         next_state;
    reg [7:0]                         bit_counter;
    reg [7:0]                         byte_counter;
    reg [7:0]                         current_cmd;
    reg [FLASH_ADDR_WIDTH-1:0]        current_addr;
    reg [DATA_WIDTH-1:0]              tx_data;
    reg [DATA_WIDTH-1:0]              rx_data;
    reg [7:0]                         status_reg;
    reg                               write_enable;
    reg                               req_accepted;
    reg                               operation_pending;
    reg [ADDR_WIDTH-1:0]              pending_addr;
    reg [DATA_WIDTH-1:0]              pending_data;
    reg                               pending_we;

    // SPI时钟生成
    reg [7:0]                         clk_divider;
    reg                               spi_clk_internal;

    // SPI时钟分频设置（默认分频为8）
    localparam CLK_DIVIDER = 8'h07;

    // OBI握手逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_accepted <= 1'b0;
            gnt_o <= 1'b0;
            rvalid_o <= 1'b0;
        end else begin
            // Grant逻辑
            if (req_i && !req_accepted && !operation_pending) begin
                gnt_o <= 1'b1;
                req_accepted <= 1'b1;
                pending_addr <= addr_i;
                pending_data <= data_in_i;
                pending_we <= we_i;
                operation_pending <= 1'b1;
            end else if (req_accepted && state == STATE_IDLE) begin
                gnt_o <= 1'b0;
                req_accepted <= 1'b0;
            end else if (rvalid_o) begin
                gnt_o <= 1'b0;
                req_accepted <= 1'b0;
                operation_pending <= 1'b0;
            end else begin
                gnt_o <= 1'b0;
            end
        end
    end

    // SPI时钟生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider <= 8'h0;
            spi_clk_internal <= 1'b0;
            spi_clk_o <= 1'b0;
        end else if (state != STATE_IDLE) begin
            clk_divider <= clk_divider + 1;
            if (clk_divider == CLK_DIVIDER) begin
                clk_divider <= 8'h0;
                spi_clk_internal <= ~spi_clk_internal;
                spi_clk_o <= spi_clk_internal;
            end
        end else begin
            clk_divider <= 8'h0;
            spi_clk_internal <= 1'b0;
            spi_clk_o <= 1'b0;
        end
    end

    // 状态机主逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            spi_cs_n_o <= 1'b1;
            spi_mosi_o <= 1'b0;
            bit_counter <= 8'h0;
            byte_counter <= 8'h0;
            current_cmd <= 8'h0;
            current_addr <= {FLASH_ADDR_WIDTH{1'b0}};
            tx_data <= {DATA_WIDTH{1'b0}};
            rx_data <= {DATA_WIDTH{1'b0}};
            status_reg <= 8'h0;
            write_enable <= 1'b0;
            data_out_o <= {DATA_WIDTH{1'b0}};
            rvalid_o <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    spi_cs_n_o <= 1'b1;
                    spi_mosi_o <= 1'b0;
                    bit_counter <= 8'h0;
                    byte_counter <= 8'h0;
                    rvalid_o <= 1'b0;

                    if (operation_pending) begin
                        // 解析地址和操作类型
                        if (pending_addr[31:24] == 8'h00) begin
                            // Flash地址空间：直接读写Flash
                            current_addr <= pending_addr[FLASH_ADDR_WIDTH-1:0];

                            if (pending_we) begin
                                // 写操作：需要先使能写，然后执行页编程
                                state <= STATE_WRITE_ENABLE;
                                tx_data <= pending_data;
                            end else begin
                                // 读操作：直接读取数据
                                state <= STATE_READ_CMD;
                                current_cmd <= CMD_READ_DATA;
                            end
                        end else if (pending_addr[31:24] == 8'h01) begin
                            // 控制寄存器空间
                            case (pending_addr[7:0])
                                8'h00: begin // 状态寄存器
                                    if (pending_we) begin
                                        // 写状态寄存器
                                        state <= STATE_WRITE_ENABLE;
                                        current_cmd <= CMD_WRITE_STATUS;
                                        tx_data <= {24'h0, pending_data[7:0]};
                                    end else begin
                                        // 读状态寄存器
                                        state <= STATE_STATUS_READ;
                                    end
                                end
                                8'h04: begin // 器件ID
                                    if (!pending_we) begin
                                        state <= STATE_ID_READ;
                                    end
                                end
                                default: begin
                                    // 无效地址，直接返回
                                    data_out_o <= 32'hDEADBEEF;
                                    rvalid_o <= 1'b1;
                                    state <= STATE_IDLE;
                                end
                            endcase
                        end
                    end
                end

                STATE_WRITE_ENABLE: begin
                    spi_cs_n_o <= 1'b0;

                    if (bit_counter < 8) begin
                        // 发送写使能命令
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= CMD_WRITE_ENABLE[7 - bit_counter[2:0]];
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        // 写使能命令完成
                        spi_cs_n_o <= 1'b1;
                        bit_counter <= 8'h0;

                        // 等待写使能生效
                        state <= STATE_WRITE_WAIT;
                        write_enable <= 1'b1;
                    end
                end

                STATE_WRITE_WAIT: begin
                    // 等待写使能生效（简单延时）
                    if (byte_counter < 8'h10) begin
                        byte_counter <= byte_counter + 1;
                    end else begin
                        byte_counter <= 8'h0;

                        // 根据当前命令决定下一步
                        if (current_cmd == CMD_WRITE_STATUS) begin
                            state <= STATE_WRITE_CMD;
                        end else begin
                            // Flash写操作
                            state <= STATE_WRITE_CMD;
                            current_cmd <= CMD_PAGE_PROGRAM;
                        end
                    end
                end

                STATE_WRITE_CMD: begin
                    spi_cs_n_o <= 1'b0;

                    if (bit_counter < 8) begin
                        // 发送命令
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= current_cmd[7 - bit_counter[2:0]];
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        bit_counter <= 8'h0;
                        state <= STATE_WRITE_ADDR;
                    end
                end

                STATE_WRITE_ADDR: begin
                    if (bit_counter < FLASH_ADDR_WIDTH) begin
                        // 发送地址
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= current_addr[FLASH_ADDR_WIDTH-1 - bit_counter];
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        bit_counter <= 8'h0;
                        state <= STATE_WRITE_DATA;
                    end
                end

                STATE_WRITE_DATA: begin
                    if (bit_counter < 32) begin
                        // 发送数据
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= tx_data[31 - bit_counter[4:0]];
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        // 写操作完成
                        spi_cs_n_o <= 1'b1;
                        bit_counter <= 8'h0;
                        data_out_o <= 32'h0; // 写操作返回0表示成功
                        rvalid_o <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                STATE_READ_CMD: begin
                    spi_cs_n_o <= 1'b0;

                    if (bit_counter < 8) begin
                        // 发送读命令
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= current_cmd[7 - bit_counter[2:0]];
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        bit_counter <= 8'h0;
                        state <= STATE_READ_ADDR;
                    end
                end

                STATE_READ_ADDR: begin
                    if (bit_counter < FLASH_ADDR_WIDTH) begin
                        // 发送地址
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= current_addr[FLASH_ADDR_WIDTH-1 - bit_counter];
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        bit_counter <= 8'h0;
                        state <= STATE_READ_DATA;
                    end
                end

                STATE_READ_DATA: begin
                    if (bit_counter < 32) begin
                        // 读取数据
                        if (clk_divider == CLK_DIVIDER && spi_clk_internal) begin
                            rx_data[31 - bit_counter[4:0]] <= spi_miso_i;
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        // 读操作完成
                        spi_cs_n_o <= 1'b1;
                        bit_counter <= 8'h0;
                        data_out_o <= rx_data;
                        rvalid_o <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                STATE_STATUS_READ: begin
                    spi_cs_n_o <= 1'b0;

                    if (bit_counter < 8) begin
                        // 发送读状态命令
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= CMD_READ_STATUS[7 - bit_counter[2:0]];
                            bit_counter <= bit_counter + 1;
                        end
                    end else if (bit_counter < 16) begin
                        // 读取状态寄存器
                        if (clk_divider == CLK_DIVIDER && spi_clk_internal) begin
                            status_reg[15 - bit_counter[3:0]] <= spi_miso_i;
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        // 状态读取完成
                        spi_cs_n_o <= 1'b1;
                        bit_counter <= 8'h0;
                        data_out_o <= {24'h0, status_reg[7:0]};
                        rvalid_o <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                STATE_ID_READ: begin
                    spi_cs_n_o <= 1'b0;

                    if (bit_counter < 8) begin
                        // 发送读ID命令
                        if (clk_divider == CLK_DIVIDER && !spi_clk_internal) begin
                            spi_mosi_o <= CMD_JEDEC_ID[7 - bit_counter[2:0]];
                            bit_counter <= bit_counter + 1;
                        end
                    end else if (bit_counter < 32) begin
                        // 读取ID数据（制造商ID、存储器类型、容量）
                        if (clk_divider == CLK_DIVIDER && spi_clk_internal) begin
                            rx_data[31 - bit_counter[4:0]] <= spi_miso_i;
                            bit_counter <= bit_counter + 1;
                        end
                    end else begin
                        // ID读取完成
                        spi_cs_n_o <= 1'b1;
                        bit_counter <= 8'h0;
                        data_out_o <= rx_data;
                        rvalid_o <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule