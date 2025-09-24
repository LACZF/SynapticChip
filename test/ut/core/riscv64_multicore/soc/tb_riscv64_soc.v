// tb_riscv64_soc.v
`include "soc_params.v"

module tb_riscv64_soc;

    reg clk;
    reg rst_n;

    // Flash接口
    wire [23:0] flash_addr;
    reg [31:0] flash_data_in;
    wire [31:0] flash_data_out;
    wire flash_ce_n;
    wire flash_oe_n;
    wire flash_we_n;
    wire flash_wp_n;
    reg flash_ready;

    // UART接口
    wire uart_txd;
    reg uart_rxd;

    // GPIO接口
    reg [15:0] gpio_in;
    wire [15:0] gpio_out;

    // 系统控制
    reg [3:0] dip_switch;
    wire [3:0] led;
    wire soc_ready;

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

        // 初始化Flash内容
        $readmemh("flash_bootcode.hex", flash_memory);

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
        forever begin
            @(negedge uart_txd); // 检测起始位
            #8680; // 等待到第一个数据位中间（115200波特率，1/115200≈8.68us）

            // 接收8个数据位
            reg [7:0] uart_rx_byte;
            for (integer i = 0; i < 8; i = i + 1) begin
                #8680;
                uart_rx_byte[i] = uart_txd;
            end

            #8680; // 停止位
            $display("Time %0t: UART Tx: 0x%h (%c)", $time, uart_rx_byte, uart_rx_byte);
        end
    end

    task initialize_test_program;
        begin
            // 核心0启动代码
            flash_memory[0] = 32'h00000013; // nop
            flash_memory[1] = 32'h00000013; // nop
            flash_memory[2] = 32'h00000013; // nop
            flash_memory[3] = 32'h00000013; // nop

            // 简单的测试程序：将数据从Flash加载到寄存器并回显到UART
            flash_memory[4] = 32'hF0000117; // auipc x2, 0xF0000 (MMIO基地址)
            flash_memory[5] = 32'h00010113; // addi x2, x2, 0
            flash_memory[6] = 32'h04100293; // addi x5, x0, 65 ('A')
            flash_memory[7] = 32'h00510023; // sb x5, 0(x2) [UART数据寄存器]

            $display("Flash initialized with test program");
        end
    endtask

    // 系统监控
    integer cycle_count;
    reg [31:0] uart_tx_count;

    always @(posedge clk) begin
        if (rst_n && soc_ready) begin
            cycle_count = cycle_count + 1;

            // 每10000周期显示进度
            if (cycle_count % 10000 == 0) begin
                $display("Cycle %0d: SoC running...", cycle_count);
            end

            // 监控UART活动
            if (u_soc.u_mmio.u_uart.tx_start) begin
                uart_tx_count = uart_tx_count + 1;
                $display("Time %0t: UART transmission started", $time);
            end

            // 结束条件：UART发送一定数量字符或超时
            if (uart_tx_count > 10 || cycle_count > 100000) begin
                $display("SoC Test Completed");
                $display("Total Cycles: %0d", cycle_count);
                $display("UART Transmissions: %0d", uart_tx_count);
                $finish;
            end
        end
    end

    // 性能统计
    initial begin
        cycle_count = 0;
        uart_tx_count = 0;

        #10_000; // 等待测试完成或超时
        if (cycle_count >= 100000) begin
            $display("Test timed out after %0d cycles", cycle_count);
        end
        $finish;
    end

endmodule
