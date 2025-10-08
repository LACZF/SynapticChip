// tb_top_system_direct_single_core.v
// 顶层系统集成测试平台 - 单核心+Direct总线+无L2/L3缓存配置

`include "top_system_params.v"
`include "spi_params.v"
`timescale 1ns/1ps

// SPI Flash模型 - 模拟SPI ROM设备
module spi_flash_model(input wire cs_n, input wire sclk, input wire mosi, output wire miso);
    parameter MEM_SIZE = 4096; // 内存大小（指令数量）
    parameter INSTR_FILE = "instructions.hex"; // 指令文件路径

    // 内部存储器
    reg [31:0] mem [0:MEM_SIZE-1];
    reg [31:0] current_addr;
    reg [7:0] current_cmd;
    reg [1:0] state;
    reg [4:0] bit_count;
    reg [31:0] rx_data;
    reg [31:0] tx_data;
    reg miso_reg;

    localparam IDLE = 2'b00;
    localparam CMD = 2'b01;
    localparam ADDR = 2'b10;
    localparam DATA = 2'b11;

    // 初始化从文件加载指令
    initial begin
        $readmemh(INSTR_FILE, mem);
        state = IDLE;
        miso_reg = 1'b0;
    end

    // SPI通信处理
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            state = IDLE;
            bit_count = 0;
            miso_reg = 1'b0;
        end else begin
            case (state)
                IDLE:
                    begin
                        state = CMD;
                        bit_count = 0;
                        current_cmd = 0;
                    end
                CMD:
                    begin
                        current_cmd = {current_cmd[6:0], mosi};
                        bit_count = bit_count + 1;
                        if (bit_count == 8) begin
                            bit_count = 0;
                            if (current_cmd == `SPI_CMD_READ_DATA || current_cmd == `SPI_CMD_FAST_READ) begin
                                state = ADDR;
                                current_addr = 0;
                            end
                        end
                    end
                ADDR:
                    begin
                        current_addr = {current_addr[29:0], mosi};
                        bit_count = bit_count + 1;
                        if (bit_count == 24) begin
                            bit_count = 0;
                            state = DATA;
                            // 将字节地址转换为指令索引 (除以4)
                            tx_data = mem[current_addr / 4];
                        end
                    end
                DATA:
                    begin
                        // 从最高位开始发送数据
                        miso_reg = tx_data[31 - bit_count];
                        bit_count = bit_count + 1;
                        if (bit_count == 32) begin
                            // 读取完一个指令后，自动增加地址读取下一个
                            current_addr = current_addr + 4;
                            tx_data = mem[current_addr / 4];
                            bit_count = 0;
                        end
                    end
            endcase
        end
    end

    // 输出MISO信号
    assign miso = cs_n ? 1'bz : miso_reg;
endmodule

module tb_top_system_direct_1core;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // UART接口
    wire uart_txd;
    reg uart_rxd;

    // GPIO接口
    wire [`DATA_WIDTH-1:0] gpio_pins;
    reg [`DATA_WIDTH-1:0] gpio_ext_drive;
    assign gpio_pins = gpio_ext_drive;

    // 外部中断
    reg ext_int;

    // 状态输出
    wire [`DATA_WIDTH-1:0] system_status;

    // SPI物理接口（连接到SPI Flash模型）
    wire spi_cs_n;
    wire spi_clk;
    wire spi_mosi;
    wire spi_miso;

    // 实例化DUT - 配置为Direct总线、1个核心、无L2/L3缓存
    top_system #(
        .BUS_TYPE(`BUS_TYPE_DIRECT),
        .NUM_RINGS(1),
        .NUM_NODES(`NODES),
        .ADDR_WIDTH(`ADDR_WIDTH),
        .NODE_ID_WIDTH(`NODE_ID_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .NUM_PES(`NUM_PES),
        .PE_ARRAY_ROWS(`PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(`PE_ARRAY_COLS),
        .INST_WIDTH(`INST_WIDTH),
        .PE_ID_WIDTH(`PE_ID_WIDTH),
        .NUM_CORES(1),             // 1个核心
        .ENABLE_L2_CACHE(0),       // 禁用L2缓存
        .ENABLE_L3_CACHE(0)        // 禁用L3缓存
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .gpio_pins(gpio_pins),
        .ext_int(ext_int),
        .system_status(system_status),
        // SPI接口连接到SPI Flash模型
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：通过UART发送数据
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // 起始位
            uart_rxd <= 1'b0;
            #8680; // 115200波特率的位时间

            // 数据位
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd <= data[i];
                #8680;
            end

            // 停止位
            uart_rxd <= 1'b1;
            #8680;
        end
    endtask

    // 实例化SPI Flash模型，连接到SPI物理接口
    spi_flash_model #(
        .MEM_SIZE(4096),
        .INSTR_FILE("instructions.hex")
    ) u_spi_flash_model (
        .cs_n(spi_cs_n),
        .sclk(spi_clk),
        .mosi(spi_mosi),
        .miso(spi_miso)
    );

    // 主测试程序
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        uart_rxd = 1'b1;
        gpio_ext_drive = 0;
        ext_int = 0;

        // 打开波形文件
        $dumpfile("top_system_direct_1core.vcd");
        $dumpvars(0, tb_top_system_direct_1core);

        // 复位
        #20 rst_n = 1;

        $display("Starting Top System Integration Test - Direct Bus, Single Core, No L2/L3 Cache");

        // 测试1: 系统启动和初始化
        $display("Test 1: System startup and initialization");
        #100;
        $display("System status: 0x%h", system_status);

        // 测试2: GPIO测试
        $display("Test 2: GPIO test");
        // 通过外部驱动GPIO引脚
        #1000;
        gpio_ext_drive = 32'h12345678;
        #100;
        $display("GPIO pins driven to: 0x%h", gpio_ext_drive);

        // 测试3: UART通信测试
        $display("Test 3: UART communication test");
        #1000;
        $display("Sending test data via UART");
        uart_send_byte(8'h48); // 'H'
        uart_send_byte(8'h65); // 'e'
        uart_send_byte(8'h6C); // 'l'
        uart_send_byte(8'h6C); // 'l'
        uart_send_byte(8'h6F); // 'o'
        uart_send_byte(8'h0A); // '\n'

        // 测试4: 外部中断测试
        $display("Test 4: External interrupt test");
        #2000;
        ext_int = 1;
        #100;
        ext_int = 0;
        #100;
        $display("External interrupt triggered");

        // 等待一段时间以观察系统响应
        #5000;

        $display("All tests completed!");
        $finish;
    end

endmodule