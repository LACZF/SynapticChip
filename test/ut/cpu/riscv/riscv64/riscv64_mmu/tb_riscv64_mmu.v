// MMU测试模块
`timescale 1ps/1ps

module tb_riscv64_mmu;
    // 参数定义
    parameter ADDR_WIDTH = 64;
    parameter CLK_PERIOD = 1000; // 1ns时钟周期
    parameter TIMEOUT_CYCLES = 100; // 超时周期数

    // 信号定义
    reg clk;
    reg rst_n;
    reg enable_i;
    reg [ADDR_WIDTH-1:0] virt_addr_i;
    reg [1:0] priv_mode_i;
    reg inst_access_i;
    reg write_access_i;
    wire [ADDR_WIDTH-1:0] phys_addr_o;
    wire page_fault_o;
    wire translation_ready_o;
    // MMU控制寄存器
    reg [ADDR_WIDTH-1:0] satp_i;
    reg [ADDR_WIDTH-1:0] status_i;

    // 全局变量用于超时检测
    reg timeout_flag;
    integer timeout_count_global;

    // 实例化被测模块
    riscv64_mmu #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(enable_i),
        .virt_addr_i(virt_addr_i),
        .priv_mode_i(priv_mode_i),
        .inst_access_i(inst_access_i),
        .write_access_i(write_access_i),
        .phys_addr_o(phys_addr_o),
        .page_fault_o(page_fault_o),
        .translation_ready_o(translation_ready_o),
        // MMU控制寄存器
        .satp_i(satp_i),
        .status_i(status_i)
    );

    // 时钟生成
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end

    // 带超时的循环任务
    task timeout_loop;
        input signal;
        input integer timeout_cycles;
        begin
            timeout_flag = 0;
            timeout_count_global = 0;
            while (!signal && timeout_count_global < timeout_cycles) begin
                @(posedge clk);
                timeout_count_global = timeout_count_global + 1;
            end
            if (timeout_count_global >= timeout_cycles) begin
                timeout_flag = 1;
            end
        end
    endtask

    // 任务定义
    task reset_dut;
        begin
            rst_n = 1'b0;
            enable_i = 1'b0;
            virt_addr_i = 64'b0;
            priv_mode_i = 2'b00;
            inst_access_i = 1'b0;
            write_access_i = 1'b0;
            satp_i = 64'b0;
            status_i = 64'b0;
            #(CLK_PERIOD * 10);
            rst_n = 1'b1;
            #(CLK_PERIOD * 5);
        end
    endtask

    task test_translation;
        input [ADDR_WIDTH-1:0] virt_addr;
        input [1:0] priv_mode;
        input write_access;
        input [ADDR_WIDTH-1:0] expected_phys_addr;
        input expected_page_fault;
        integer timeout_count;
        begin
            timeout_count = 0;
            @(posedge clk);
            virt_addr_i = virt_addr;
            priv_mode_i = priv_mode;
            write_access_i = write_access;
            enable_i = 1'b1;

            // 等待转换完成或超时
            while (!translation_ready_o && timeout_count < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            @(posedge clk);

            // 检查结果
            if (timeout_count >= TIMEOUT_CYCLES) begin
                $display("FAIL (TIMEOUT): virt_addr=0x%h, priv_mode=%d, write_access=%b - Translation timed out",
                         virt_addr, priv_mode, write_access);
            end else if (phys_addr_o == expected_phys_addr && page_fault_o == expected_page_fault) begin
                $display("PASS: virt_addr=0x%h, priv_mode=%d, write_access=%b -> phys_addr=0x%h, page_fault=%b",
                         virt_addr, priv_mode, write_access, phys_addr_o, page_fault_o);
            end else begin
                $display("FAIL: virt_addr=0x%h, priv_mode=%d, write_access=%b -> phys_addr=0x%h (expected 0x%h), page_fault=%b (expected %b)",
                         virt_addr, priv_mode, write_access, phys_addr_o, expected_phys_addr, page_fault_o, expected_page_fault);
            end

            // 清除使能信号
            enable_i = 1'b0;
            timeout_count = 0;
            // 等待translation_ready_o变低或超时
            while (translation_ready_o && timeout_count < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (timeout_count >= TIMEOUT_CYCLES) begin
                $display("WARNING: Failed to clear translation_ready_o signal");
            end
        end
    endtask

    // 测试用例
    initial begin
        // 打开波形文件
        $dumpfile("tb_riscv64_mmu.vcd");
        $dumpvars(0, tb_riscv64_mmu);

        $display("Starting MMU tests...");

        // 复位DUT
        reset_dut;

        // 测试MMU禁用状态
        @(posedge clk);
        enable_i = 1'b0;
        virt_addr_i = 64'h12345678;
        priv_mode_i = 2'b00;
        @(posedge clk);
        if (phys_addr_o == 64'h12345678 && page_fault_o == 1'b0) begin
            $display("PASS: MMU disabled - virt_addr=0x%h -> phys_addr=0x%h", virt_addr_i, phys_addr_o);
        end else begin
            $display("FAIL: MMU disabled - virt_addr=0x%h -> phys_addr=0x%h (expected 0x%h)", virt_addr_i, phys_addr_o, virt_addr_i);
        end

        // 测试通过status寄存器控制MMU使能
        @(posedge clk);
        enable_i = 1'b0;
        status_i[0] = 1'b1; // 设置status第0位为1，期望使能MMU
        virt_addr_i = 64'h1000;
        priv_mode_i = 2'b00;
        @(posedge clk);

        // 使用循环实现带超时的等待
        timeout_loop(translation_ready_o, TIMEOUT_CYCLES);
        if (timeout_flag) begin
            $display("FAIL (TIMEOUT): MMU enabled via status - Translation timed out");
        end else begin
            @(posedge clk);
            if (phys_addr_o == 64'h1000 && page_fault_o == 1'b0) begin
                $display("PASS: MMU enabled via status - virt_addr=0x%h -> phys_addr=0x%h", virt_addr_i, phys_addr_o);
            end else begin
                $display("FAIL: MMU enabled via status - virt_addr=0x%h -> phys_addr=0x%h (expected 0x%h)", virt_addr_i, phys_addr_o, virt_addr_i);
            end
        end
        status_i[0] = 1'b0; // 关闭MMU

        // 等待translation_ready_o变低
        timeout_loop(!translation_ready_o, TIMEOUT_CYCLES);

        // 测试用户模式下低地址映射
        test_translation(64'h1000, 2'b00, 1'b0, 64'h1000, 1'b0); // 用户空间低地址，读访问
        test_translation(64'h1000, 2'b00, 1'b1, 64'h1000, 1'b0); // 用户空间低地址，写访问

        // 测试用户模式下内核空间写访问（预期页错误）
        test_translation(64'h80000000, 2'b00, 1'b1, 64'h80000000, 1'b1); // 用户模式写内核空间

        // 测试特权模式下内核空间访问
        test_translation(64'h80000000, 2'b11, 1'b0, 64'h80000000, 1'b0); // 特权模式读内核空间
        test_translation(64'h80000000, 2'b11, 1'b1, 64'h80000000, 1'b0); // 特权模式写内核空间

        $display("All MMU tests completed");
        $finish;
    end

endmodule