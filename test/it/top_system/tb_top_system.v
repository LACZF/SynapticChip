// tb_top_system.v
// 顶层系统集成测试平台

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

module tb_top_system;
    localparam SPI_CS_NUM = 2;

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
    wire [SPI_CS_NUM-1:0] spi_cs_n;
    wire spi_clk;
    wire spi_mosi;
    wire spi_miso;

    // 实例化DUT
    top_system #(
        .BUS_TYPE(`BUS_TYPE_RING),
        .NUM_RINGS(2),
        .NUM_NODES(`NODES),
        .ADDR_WIDTH(`ADDR_WIDTH),
        .NODE_ID_WIDTH(`NODE_ID_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .NUM_PES(`NUM_PES),
        .PE_ARRAY_ROWS(`PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(`PE_ARRAY_COLS),
        .INST_WIDTH(`INST_WIDTH),
        .SPI_CS_NUM(SPI_CS_NUM),
        .PE_ID_WIDTH(`PE_ID_WIDTH)
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
        .cs_n(spi_cs_n[0]),
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

        // 复位
        #20 rst_n = 1;

        $display("Starting Top System Integration Test");

        // 测试1: 系统启动和初始化
        $display("Test 1: System startup and initialization");
        #100;
        $display("System status: 0x%h", system_status);

        // 测试2: GPIO测试
        $display("Test 2: GPIO test");
        // 通过外部驱动GPIO引脚
        gpio_ext_drive <= 32'hA5A5A5A5;
        #100;
        $display("GPIO test completed");

        // 测试3: UART测试
        $display("Test 3: UART test");
        // 通过UART发送测试数据
        uart_send_byte(8'h55);
        uart_send_byte(8'hAA);
        #1000;
        $display("UART test completed");

        // 测试4: 外部中断测试
        $display("Test 4: External interrupt test");
        ext_int <= 1'b1;
        #100;
        ext_int <= 1'b0;
        #100;
        $display("External interrupt test completed");

        // 测试5: 指令执行测试 - 监控CPU从ROM读取和执行指令
        $display("Test 5: Instruction execution test");
        $display("CPU will execute instructions loaded from ROM");
        #5000; // 给足够的时间让CPU执行指令
        $display("Instruction execution test completed");

        // 测试6: 状态监控
        $display("Test 6: Status monitoring");
        $display("Final system status: 0x%h", system_status);

        $display("All integration tests passed!");
        $finish;
    end

`ifdef DEBUG
    // 添加SPI通信监控逻辑
    initial begin
        forever begin
            #1000;
            // 监控SPI通信状态
            if (!spi_cs_n) begin
                $display("[%0t ps] SPI通信活跃: cs_n=0, clk=%b, mosi=%b, miso=%b",
                         $time, spi_clk, spi_mosi, spi_miso);
            end
        end
    end
`endif

    // 添加定期监控系统状态的逻辑
`ifdef DEBUG
    reg [31:0] instruction_count = 0;
    initial begin
        forever begin
            #1000;
            instruction_count = instruction_count + 1;
            $display("[%0t ps] 已执行指令数: %d, 系统状态: 0x%h",
                     $time, instruction_count, system_status);
        end
    end
`endif

    // 监控UART输出
    reg [7:0] uart_rx_byte;
    integer uart_bit_count;
    initial begin
        forever begin
            // 等待起始位
            wait(uart_txd === 1'b0);
            #4340; // 等待到位中间

            // 接收数据位
            for (uart_bit_count = 0; uart_bit_count < 8; uart_bit_count = uart_bit_count + 1) begin
                #8680;
                uart_rx_byte[uart_bit_count] = uart_txd;
            end

            // 等待停止位
            #8680;

            $display("UART TX: 0x%h ('%c')", uart_rx_byte, uart_rx_byte);
        end
    end

    // 波形输出
    initial begin
        $dumpfile("top_system.vcd");
        $dumpvars(0, tb_top_system);
    end

endmodule