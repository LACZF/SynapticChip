`timescale 1ns/1ps

module riscv_cpu_tb;

    // 时钟和复位信号
    reg clk;
    reg rst_n;

    // UART信号
    reg uart_rx;
    wire uart_tx;

    // 测试控制信号
    reg [7:0] uart_test_data;
    reg uart_send_enable;
    wire uart_send_done;
    wire [7:0] uart_received_data;
    wire uart_received_valid;

    // 内存接口信号
    wire [31:0] imem_addr;
    wire [31:0] imem_data;
    wire imem_en;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire dmem_wen;
    wire dmem_ren;
    wire [3:0] dmem_be;

    // 测试状态
    integer test_pass_count = 0;
    integer test_fail_count = 0;
    integer test_case_index = 0;

    // 测试用例定义
    typedef struct {
        logic [7:0] send_data;
        logic [7:0] expected_data;
        integer timeout_cycles;
    } test_case_t;

    // 定义测试用例数组
    localparam NUM_TEST_CASES = 5;
    test_case_t test_cases[NUM_TEST_CASES] = '{
        '{8'h41, 8'h61, 10000},  // 测试大小写转换 A -> a
        '{8'h42, 8'h62, 10000},  // B -> b
        '{8'h31, 8'h31, 10000},  // 数字保持不变 1 -> 1
        '{8'h0D, 8'h0A, 10000},  // 回车 -> 换行
        '{8'h00, 8'h00, 10000}   // 空字符
    };

    // 实例化RISC-V CPU
    riscv_cpu u_cpu (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_en(imem_en),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_wen(dmem_wen),
        .dmem_ren(dmem_ren),
        .dmem_be(dmem_be)
    );

    // 实例化指令存储器
    imem_controller u_imem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(imem_addr),
        .rdata(imem_data),
        .en(imem_en)
    );

    // 实例化数据存储器
    dmem_controller u_dmem (
        .clk(clk),
        .rst_n(rst_n),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata),
        .wen(dmem_wen),
        .ren(dmem_ren),
        .be(dmem_be)
    );

    // 实例化UART发送模拟
    uart_tx_sim u_uart_tx_sim (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(uart_test_data),
        .tx_enable(uart_send_enable),
        .tx_done(uart_send_done),
        .uart_rx(uart_rx)
    );

    // 实例化UART接收模拟
    uart_rx_sim u_uart_rx_sim (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx),
        .rx_data(uart_received_data),
        .rx_valid(uart_received_valid)
    );

    // 时钟生成
    always #5 clk = ~clk;  // 100MHz时钟

    // 主测试任务
    task run_test_case(input integer case_index);
        automatic integer timeout_counter = 0;
        automatic logic test_passed = 0;

        $display("=== 开始测试用例 %0d ===", case_index);
        $display("发送数据: 0x%02h, 期望接收: 0x%02h",
                 test_cases[case_index].send_data,
                 test_cases[case_index].expected_data);

        // 发送UART数据
        uart_test_data = test_cases[case_index].send_data;
        uart_send_enable = 1'b1;
        @(posedge clk);
        uart_send_enable = 1'b0;

        // 等待发送完成
        wait(uart_send_done);
        $display("UART数据发送完成");

        // 等待接收响应或超时
        while (timeout_counter < test_cases[case_index].timeout_cycles) begin
            @(posedge clk);
            timeout_counter = timeout_counter + 1;

            if (uart_received_valid) begin
                if (uart_received_data == test_cases[case_index].expected_data) begin
                    test_passed = 1'b1;
                    $display("测试用例 %0d 通过! 接收到正确数据: 0x%02h",
                             case_index, uart_received_data);
                end else begin
                    $display("测试用例 %0d 失败! 期望: 0x%02h, 实际: 0x%02h",
                             case_index, test_cases[case_index].expected_data,
                             uart_received_data);
                end
                break;
            end
        end

        if (!test_passed) begin
            if (timeout_counter >= test_cases[case_index].timeout_cycles) begin
                $display("测试用例 %0d 超时失败!", case_index);
            end
        end

        // 更新测试统计
        if (test_passed) begin
            test_pass_count = test_pass_count + 1;
        end else begin
            test_fail_count = test_fail_count + 1;
        end

        // 测试间隔
        repeat(1000) @(posedge clk);
    endtask

    // 主测试流程
    initial begin
        // 初始化信号
        clk = 0;
        rst_n = 0;
        uart_rx = 1'b1;
        uart_send_enable = 1'b0;
        uart_test_data = 8'h00;

        $display("=== RISC-V CPU测试开始 ===");

        // 复位
        $display("应用复位...");
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(100) @(posedge clk);

        $display("CPU复位完成，开始执行测试程序");

        // 等待CPU初始化完成（可根据需要调整等待时间）
        repeat(10000) @(posedge clk);

        // 执行所有测试用例
        for (test_case_index = 0; test_case_index < NUM_TEST_CASES; test_case_index++) begin
            run_test_case(test_case_index);
        end

        // 测试完成
        $display("=== 测试完成 ===");
        $display("通过测试: %0d", test_pass_count);
        $display("失败测试: %0d", test_fail_count);

        if (test_fail_count == 0) begin
            $display("*** 所有测试通过! ***");
        end else begin
            $display("*** 有测试失败! ***");
        end

        // 结束仿真
        #1000;
        $finish;
    end

    // 监控关键信号
    always @(posedge clk) begin
        if (uart_received_valid) begin
            $display("时间 %0t: 接收到UART数据: 0x%02h", $time, uart_received_data);
        end
    end

    // 超时保护
    initial begin
        #5000000;  // 5ms超时
        $display("!!! 测试超时 !!!");
        $display("通过测试: %0d", test_pass_count);
        $display("失败测试: %0d", test_fail_count);
        $finish;
    end

endmodule

// 指令存储器控制器
module imem_controller (
    input clk,
    input rst_n,
    input [31:0] addr,
    output reg [31:0] rdata,
    input en
);

    reg [31:0] memory [0:16383];  // 16KB指令存储器

    initial begin
        $readmemh("program.hex", memory);
        $display("从program.hex加载指令到指令存储器");
    end

    always @(posedge clk) begin
        if (en && rst_n) begin
            if (addr[31:2] < 16384) begin
                rdata <= memory[addr[31:2]];
            end else begin
                rdata <= 32'h00000013;  // nop
            end
        end
    end

endmodule

// 数据存储器控制器
module dmem_controller (
    input clk,
    input rst_n,
    input [31:0] addr,
    input [31:0] wdata,
    output reg [31:0] rdata,
    input wen,
    input ren,
    input [3:0] be
);

    reg [7:0] memory [0:65535];  // 64KB数据存储器

    always @(posedge clk) begin
        if (rst_n) begin
            if (wen) begin
                // 字节使能写入
                if (be[0]) memory[addr[15:0] + 0] <= wdata[7:0];
                if (be[1]) memory[addr[15:0] + 1] <= wdata[15:8];
                if (be[2]) memory[addr[15:0] + 2] <= wdata[23:16];
                if (be[3]) memory[addr[15:0] + 3] <= wdata[31:24];
            end
            if (ren) begin
                // 读取数据
                rdata <= {memory[addr[15:0] + 3],
                         memory[addr[15:0] + 2],
                         memory[addr[15:0] + 1],
                         memory[addr[15:0] + 0]};
            end
        end
    end

endmodule

// UART发送模拟模块
module uart_tx_sim (
    input clk,
    input rst_n,
    input [7:0] tx_data,
    input tx_enable,
    output reg tx_done,
    output reg uart_rx
);

    localparam CLK_FREQ = 100_000_000;
    localparam BAUD_RATE = 115200;
    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    reg [3:0] bit_count;
    reg [15:0] bit_timer;
    reg [7:0] shift_reg;
    reg transmitting;

    initial begin
        uart_rx = 1'b1;
        tx_done = 1'b0;
        transmitting = 1'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_rx <= 1'b1;
            tx_done <= 1'b0;
            transmitting <= 1'b0;
            bit_count <= 0;
            bit_timer <= 0;
        end else begin
            tx_done <= 1'b0;

            if (tx_enable && !transmitting) begin
                // 开始发送
                transmitting <= 1'b1;
                shift_reg <= tx_data;
                bit_count <= 0;
                bit_timer <= 0;
                uart_rx <= 1'b0;  // 起始位
            end

            if (transmitting) begin
                bit_timer <= bit_timer + 1;

                if (bit_timer >= BIT_PERIOD - 1) begin
                    bit_timer <= 0;

                    case (bit_count)
                        0,1,2,3,4,5,6,7: begin
                            // 数据位
                            uart_rx <= shift_reg[bit_count];
                            bit_count <= bit_count + 1;
                        end
                        8: begin
                            // 停止位
                            uart_rx <= 1'b1;
                            bit_count <= bit_count + 1;
                        end
                        9: begin
                            // 发送完成
                            transmitting <= 1'b0;
                            tx_done <= 1'b1;
                            uart_rx <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule

// UART接收模拟模块
module uart_rx_sim (
    input clk,
    input rst_n,
    input uart_tx,
    output reg [7:0] rx_data,
    output reg rx_valid
);

    localparam CLK_FREQ = 100_000_000;
    localparam BAUD_RATE = 115200;
    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT_PERIOD = BIT_PERIOD / 2;

    reg [3:0] bit_count;
    reg [15:0] bit_timer;
    reg [7:0] shift_reg;
    reg receiving;
    reg uart_tx_sync;
    reg uart_tx_prev;

    initial begin
        rx_data <= 8'h00;
        rx_valid <= 1'b0;
        receiving <= 1'b0;
    end

    // 同步输入信号
    always @(posedge clk) begin
        uart_tx_prev <= uart_tx;
        uart_tx_sync <= uart_tx_prev;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data <= 8'h00;
            rx_valid <= 1'b0;
            receiving <= 1'b0;
            bit_count <= 0;
            bit_timer <= 0;
        end else begin
            rx_valid <= 1'b0;

            if (!receiving) begin
                // 检测起始位
                if (uart_tx_sync == 1'b0) begin
                    receiving <= 1'b1;
                    bit_count <= 0;
                    bit_timer <= HALF_BIT_PERIOD;  // 在比特中间采样
                end
            end else begin
                bit_timer <= bit_timer + 1;

                if (bit_timer >= BIT_PERIOD - 1) begin
                    bit_timer <= 0;

                    case (bit_count)
                        0,1,2,3,4,5,6,7: begin
                            // 采样数据位
                            shift_reg[bit_count] <= uart_tx_sync;
                            bit_count <= bit_count + 1;
                        end
                        8: begin
                            // 停止位
                            if (uart_tx_sync == 1'b1) begin
                                // 有效的停止位
                                rx_data <= shift_reg;
                                rx_valid <= 1'b1;
                            end
                            receiving <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end

endmodule