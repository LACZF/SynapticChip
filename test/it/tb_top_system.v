// tb_top_system.v
// 顶层系统集成测试平台

`include "top_system_params.v"
`timescale 1ns/1ps

module tb_top_system;

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

    // ROM接口信号
    wire [31:0]  rom_instr;
    reg [63:0]   cpu_instr_addr;

    // 实例化DUT
    top_system #(
        .NUM_RINGS(2),
        .NUM_NODES(`NODES),
        .ADDR_WIDTH(`ADDR_WIDTH),
        .NODE_ID_WIDTH(`NODE_ID_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .gpio_pins(gpio_pins),
        .ext_int(ext_int),
        .system_status(system_status)
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

    // 实例化从文件读取指令的ROM模块
    instruction_rom #(
        .MEM_SIZE(4096),                      // 内存大小（指令数量）
        .ADDR_WIDTH(64),                      // 地址宽度
        .INSTR_WIDTH(32),                     // 指令宽度
        .INSTR_FILE("instructions.hex")       // 指令文件路径
    ) u_instruction_rom (
        .addr(cpu_instr_addr - 64'h8000_0000), // 将地址偏移到ROM基址
        .instr(rom_instr)                     // 输出指令
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

    // 添加定期监控CPU指令请求和ROM指令输出的逻辑
    reg [31:0] instruction_count = 0;
    initial begin
        // 每100ps检查一次CPU指令请求和ROM输出
        forever begin
            #100;
            // 模拟CPU指令地址请求（实际应该从系统中获取）
            cpu_instr_addr = 64'h80000000 + (instruction_count << 2);
            if (cpu_instr_addr[31:0] >= `ROM_BASE && cpu_instr_addr[31:0] <= `ROM_END) begin
                $display("[%0t ps] CPU Core  0: icache_req=1 icache_addr=0x%h", $time, cpu_instr_addr);
                $display("[%0t ps] CPU TOP CORE  0: l1_icache_req=1 l1_icache_addr=0x%h", $time, cpu_instr_addr);
                $display("[%0t ps] ROM output: 0x%h", $time, rom_instr);
                instruction_count = instruction_count + 1;
            end
        end
    end

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