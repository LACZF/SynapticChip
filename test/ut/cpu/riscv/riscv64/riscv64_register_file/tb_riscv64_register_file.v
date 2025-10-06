`timescale 1ns/1ps

// RISC-V 64位寄存器文件单元测试平台
module tb_riscv64_register_file;

    // 时钟和复位信号
    reg         clk;
    reg         rst_n;

    // 输入信号
    reg  [4:0]  rs1;
    reg  [4:0]  rs2;
    reg  [4:0]  rd;
    reg         we;
    reg  [63:0] wdata;

    // 输出信号
    wire [63:0] rs1_data;
    wire [63:0] rs2_data;

    // 时钟生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 实例化被测模块 (DUT)
    riscv64_register_file u_riscv64_register_file (
        .clk       (clk),
        .rst_n     (rst_n),
        .rs1       (rs1),
        .rs2       (rs2),
        .rd        (rd),
        .we        (we),
        .wdata     (wdata),
        .rs1_data  (rs1_data),
        .rs2_data  (rs2_data)
    );

    // 测试用例变量
    integer test_passed;
    integer total_tests;
    integer error_count;

    // 测试用例：写寄存器
    task write_register(input [4:0] reg_addr, input [63:0] data);
        begin
            @(posedge clk);
            rd = reg_addr;
            we = 1'b1;
            wdata = data;
            @(posedge clk);
            we = 1'b0;
        end
    endtask

    // 测试用例：读寄存器
    task read_register(input [4:0] reg_addr, output [63:0] data);
        begin
            @(posedge clk);
            rs1 = reg_addr;
            @(negedge clk);
            data = rs1_data;
        end
    endtask

    // 测试用例：验证寄存器值
    task verify_register(input [4:0] reg_addr, input [63:0] expected_value);
        reg [63:0] actual_value;
        begin
            read_register(reg_addr, actual_value);
            total_tests = total_tests + 1;
            if (actual_value === expected_value) begin
                test_passed = test_passed + 1;
                $display("时间: %t - 通过: 寄存器 x%0d 值为 0x%h (符合预期)", $time, reg_addr, actual_value);
            end else begin
                error_count = error_count + 1;
                $display("时间: %t - 错误: 寄存器 x%0d 预期值为 0x%h, 实际值为 0x%h", $time, reg_addr, expected_value, actual_value);
            end
        end
    endtask

    // 主测试程序
    initial begin
        // 初始化
        rst_n = 1;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        we = 0;
        wdata = 0;
        test_passed = 0;
        total_tests = 0;
        error_count = 0;

        // 执行复位
        $display("开始测试: riscv64_register_file 单元测试");
        $display("测试1: 执行复位操作");
        rst_n = 0;
        #20 rst_n = 1;
        #10;

        // 测试2: 验证x0寄存器总是0
        $display("测试2: 验证x0寄存器总是0");
        write_register(0, 64'h1234567890ABCDEF);  // 尝试写入x0寄存器
        verify_register(0, 64'h0000000000000000);  // 验证x0仍然为0

        // 测试3: 基本的寄存器读写测试
        $display("测试3: 基本的寄存器读写测试");
        write_register(1, 64'h1111111111111111);
        verify_register(1, 64'h1111111111111111);

        write_register(2, 64'h2222222222222222);
        verify_register(2, 64'h2222222222222222);

        write_register(31, 64'h3131313131313131);
        verify_register(31, 64'h3131313131313131);

        // 测试4: 同时读写多个寄存器
        $display("测试4: 同时读写多个寄存器");
        write_register(5, 64'h5555555555555555);
        write_register(6, 64'h6666666666666666);
        verify_register(5, 64'h5555555555555555);
        verify_register(6, 64'h6666666666666666);

        // 测试5: 覆盖写入测试
        $display("测试5: 覆盖写入测试");
        write_register(1, 64'hAAAAAAAAAAAAAAA);
        verify_register(1, 64'h0AAAAAAAAAAAAAAA);

        // 测试6: 数据前递测试（读取正在写入的寄存器）
        $display("测试6: 数据前递测试");
        @(posedge clk);
        rd = 8;
        we = 1'b1;
        wdata = 64'h8888888888888888;
        rs1 = 8;
        rs2 = 8;
        @(negedge clk);
        total_tests = total_tests + 2;
        if (rs1_data === wdata && rs2_data === wdata) begin
            test_passed = test_passed + 2;
            $display("时间: %t - 通过: 数据前递功能正常工作", $time);
        end else begin
            error_count = error_count + 2;
            $display("时间: %t - 错误: 数据前递功能异常, rs1_data=0x%h, rs2_data=0x%h, expected=0x%h",
                     $time, rs1_data, rs2_data, wdata);
        end
        @(posedge clk);
        we = 1'b0;

        // 测试7: 随机值测试
        $display("测试7: 随机值测试");
        write_register(10, 64'hA1B2C3D4E5F60718);
        verify_register(10, 64'hA1B2C3D4E5F60718);

        write_register(11, 64'h9182736455463728);
        verify_register(11, 64'h9182736455463728);

        // 测试8: 复位功能测试
        $display("测试8: 复位功能测试");
        rst_n = 0;
        #20 rst_n = 1;
        #10;

        // 验证所有寄存器在复位后的值
        verify_register(1, 64'h0000000000000000);
        verify_register(2, 64'h0000000000000000);
        verify_register(31, 64'h0000000000000000);

        // 测试总结
        #100;
        $display("\n========================================");
        $display("测试总结: riscv64_register_file 单元测试");
        $display("总测试数: %0d", total_tests);
        $display("通过测试: %0d", test_passed);
        $display("失败测试: %0d", error_count);
        $display("测试结果: %s", (error_count == 0) ? "PASS" : "FAIL");
        $display("========================================");

        $finish;
    end

    // 全局超时监控
    initial begin
        #10000;  // 10ms超时
        $display("错误: 测试执行超时! 强制结束仿真.");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_riscv64_register_file.vcd");
        $dumpvars(0, tb_riscv64_register_file);
    end

    // 实时监控
    always @(posedge clk) begin
        if (we) begin
            $display("时间: %t - 写操作: 寄存器 x%0d, 数据=0x%h", $time, rd, wdata);
        end
    end

endmodule