// tb_riscv64_soc.v
`include "soc_params.v"

module tb_riscv64_soc;
    // 时钟和复位
    reg clk;
    reg rst_n;

    // 系统监控变量
    integer cycle_count;
    integer uart_tx_count;
    reg soc_ready;
    reg test_done;

    // 外设接口
    wire uart_txd;
    reg uart_rxd;
    reg [15:0] gpio_in;
    wire [15:0] gpio_out;
    reg [3:0] dip_switch;
    wire [3:0] led;

    // Flash接口
    wire [23:0] flash_addr;
    reg [31:0] flash_data_in;
    wire [31:0] flash_data_out;
    wire flash_ce_n;
    wire flash_oe_n;
    wire flash_we_n;
    wire flash_wp_n;
    reg flash_ready;

    // 使用soc_params.v中定义的UART0_BASE，不再本地定义
    // 核心0启动代码 - 简单的UART回显测试
    // 我们直接使用soc_params.v中定义的UART地址 `UART0_BASE = 64'hF000_1000

    // 时钟生成
    always #5 clk = ~clk;

    // SoC实例
    riscv64_soc u_soc (
        .clk(clk),
        .rst_n(rst_n),
        .flash_addr(flash_addr),
        .flash_data_in(flash_data_in),
        .flash_data_out(flash_data_out),
        .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n),
        .flash_we_n(flash_we_n),
        .flash_wp_n(flash_wp_n),
        .flash_ready(flash_ready),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .dip_switch(dip_switch),
        .led(led),
        .soc_ready(soc_ready)
    );

    // Flash模拟模型
    reg [31:0] flash_memory [0:1048575]; // 4MB Flash (16MB地址空间，但32位数据)

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        uart_rxd = 1'b1;
        gpio_in = 16'b0;
        dip_switch = 4'b0000;
        flash_ready = 1'b0;
        test_done = 1'b0;

        // 初始化Flash内容
        // 尝试读取bootcode文件，如果失败则跳过
        $display("Initializing Flash memory...");
        // 先清空Flash
        for (integer i = 0; i < 1048576; i = i + 1) begin
            flash_memory[i] = 32'h00000013; // NOP指令
        end

        // 加载测试程序到Flash
        initialize_test_program();

        #100 rst_n = 1;

        // Flash访问模拟
        forever begin
            @(negedge flash_ce_n);

            if (!flash_oe_n) begin
                // 读操作
                #100; // Flash读取延迟
                flash_data_in = flash_memory[flash_addr];
                flash_ready = 1'b1;

                @(posedge clk);
                flash_ready = 1'b0;
            end else if (!flash_we_n) begin
                // 写操作（在实际Flash中需要更复杂的命令序列）
                #1000; // Flash写入延迟
                flash_memory[flash_addr] = flash_data_out;
                flash_ready = 1'b1;

                @(posedge clk);
                flash_ready = 1'b0;
            end
        end
    end

    // UART监控
    initial begin
        $display("UART monitor started. Waiting for transmissions...");
        forever begin
            // 接收8个数据位
            reg [7:0] uart_rx_byte;

            $display("Debug: Waiting for UART transmission...");
            @(negedge uart_txd); // 检测起始位
            $display("Debug: Detected UART start bit at time %0t", $time);
            #8680; // 等待到第一个数据位中间（115200波特率，1/115200≈8.68us）

            for (integer i = 0; i < 8; i = i + 1) begin
                #8680;
                uart_rx_byte[i] = uart_txd;
            end

            #8680; // 停止位
            $display("Time %0t: UART Tx: 0x%h (%c)", $time, uart_rx_byte, uart_rx_byte);
            uart_tx_count = uart_tx_count + 1;
        end
    end

    task initialize_test_program;
        begin
            $display("Loading test program into Flash...");

            // 核心0启动代码 - 简单的UART回显测试
            // 我们直接使用soc_params.v中定义的UART地址
            // $MMIO_BASE_ADDR + 64'h0000_1000 = 64'hF000_1000
            // 但在32位指令中，我们需要使用auipc和addi组合来构造这个地址

            // 核心0测试程序:
            // 1. 设置UART地址到x2 (正确构造64位UART地址)
            // 使用正确的指令构造UART地址 64'hF000_1000
            flash_memory[0] = 32'hF0000117; // auipc x2, 0xF0000 (高20位)
            flash_memory[1] = 32'h10010113; // addi x2, x2, 0x1000 (低12位)
            // 2. 向UART发送字符'A'到'E'
            flash_memory[2] = 32'h04100293; // addi x5, x0, 65 ('A')
            flash_memory[3] = 32'h00510023; // sb x5, 0(x2) [UART数据寄存器]
            flash_memory[4] = 32'h04200293; // addi x5, x0, 66 ('B')
            flash_memory[5] = 32'h00510023; // sb x5, 0(x2)
            flash_memory[6] = 32'h04300293; // addi x5, x0, 67 ('C')
            flash_memory[7] = 32'h00510023; // sb x5, 0(x2)
            flash_memory[8] = 32'h04400293; // addi x5, x0, 68 ('D')
            flash_memory[9] = 32'h00510023; // sb x5, 0(x2)
            flash_memory[10] = 32'h04500293; // addi x5, x0, 69 ('E')
            flash_memory[11] = 32'h04600293; // addi x5, x0, 70 ('F')
            flash_memory[12] = 32'h00510023; // sb x5, 0(x2)

            // 3. 添加等待延迟，确保UART有足够时间发送数据
            flash_memory[13] = 32'h00000013; // NOP
            flash_memory[14] = 32'h00000013; // NOP
            flash_memory[15] = 32'h00000013; // NOP
            flash_memory[16] = 32'h00000013; // NOP
            flash_memory[17] = 32'h00000013; // NOP

            $display("Flash initialized with test program");
            $display("Test program starts at address 0x0 for Core 0");
        end
    endtask

    // 系统监控
    initial begin
        cycle_count = 0;
        uart_tx_count = 0;
        $display("Test started: Loading test program...");
    end

    // 周期计数
    always @(posedge clk) begin
        cycle_count = cycle_count + 1;

        // 调试信息
        if (cycle_count % 10000 == 0) begin
            $display("Cycle %d: SoC running...", cycle_count);
        end

        // 每50000周期打印一次UART状态
        if (cycle_count % 50000 == 0) begin
            $display("Debug: Current uart_tx_count = %d soc_ready = %d", uart_tx_count, soc_ready);
            $display("Debug: UART0 address from soc_params.v = 0x%x", `UART0_BASE);
        end

        // 结束条件：UART发送足够字符或超时
        if (uart_tx_count >= 6 && !test_done) begin
            test_done = 1'b1;
            $display("Test PASSED: UART transmitted %0d characters", uart_tx_count);
            $display("Total Cycles: %0d", cycle_count);
            $finish;
        end

        if (cycle_count > 50000 && !test_done) begin
            $display("Test FAILED: Timed out after %0d cycles", cycle_count);
            $display("Only received %0d UART transmissions", uart_tx_count);
            $finish;
        end
    end

endmodule