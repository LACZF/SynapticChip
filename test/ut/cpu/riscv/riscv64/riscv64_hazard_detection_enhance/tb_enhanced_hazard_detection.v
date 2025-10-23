`timescale 1ns/1ps

module tb_enhanced_hazard_detection_unit;
    // 输入信号
    reg [31:0] if_id_inst;
    reg [31:0] id_ex_inst;
    reg [31:0] ex_mem_inst;

    reg [4:0]  id_rs1;
    reg [4:0]  id_rs2;
    reg [4:0]  id_rd;
    reg        id_reg_write;

    reg [4:0]  ex_rd;
    reg        ex_reg_write;
    reg [1:0]  ex_mem_to_reg;

    reg [4:0]  mem_rd;
    reg        mem_reg_write;
    reg [1:0]  mem_mem_to_reg;

    reg [4:0]  wb_rd;
    reg        wb_reg_write;

    reg        branch_taken;
    reg        jump_taken;

    // 输出信号
    wire [2:0] hazard_type;
    wire       stall;
    wire       flush;
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire [3:0] raw_conflicts;
    wire       has_waw;
    wire       has_war;

    // 模块实例化
    riscv64_enhanced_hazard_detection_unit uut (
        .if_id_inst(if_id_inst),
        .id_ex_inst(id_ex_inst),
        .ex_mem_inst(ex_mem_inst),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .id_rd(id_rd),
        .id_reg_write(id_reg_write),
        .ex_rd(ex_rd),
        .ex_reg_write(ex_reg_write),
        .ex_mem_to_reg(ex_mem_to_reg),
        .mem_rd(mem_rd),
        .mem_reg_write(mem_reg_write),
        .mem_mem_to_reg(mem_mem_to_reg),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .branch_taken(branch_taken),
        .jump_taken(jump_taken),
        .hazard_type(hazard_type),
        .stall(stall),
        .flush(flush),
        .forward_a(forward_a),
        .forward_b(forward_b),
        .raw_conflicts(raw_conflicts),
        .has_waw(has_waw),
        .has_war(has_war)
    );

    // 测试控制
    integer test_num;
    integer passed_tests;
    integer failed_tests;

    // 时钟生成（用于时序测试）
    reg clk;
    always #5 clk = ~clk;

    // 测试任务：检查输出并报告
    task check_output;
        input [2:0] expected_hazard_type;
        input       expected_stall;
        input       expected_flush;
        input [1:0] expected_forward_a;
        input [1:0] expected_forward_b;
        input       expected_has_waw;
        input       expected_has_war;
        input string test_name;
        begin
            if (hazard_type === expected_hazard_type &&
                stall === expected_stall &&
                flush === expected_flush &&
                forward_a === expected_forward_a &&
                forward_b === expected_forward_b &&
                has_waw === expected_has_waw &&
                has_war === expected_has_war) begin
                $display("TEST %0d PASSED: %s", test_num, test_name);
                passed_tests = passed_tests + 1;
            end else begin
                $display("TEST %0d FAILED: %s", test_num, test_name);
                $display("  Expected: hazard_type=%b, stall=%b, flush=%b, forward_a=%b, forward_b=%b, has_waw=%b, has_war=%b",
                        expected_hazard_type, expected_stall, expected_flush, expected_forward_a, expected_forward_b, expected_has_waw, expected_has_war);
                $display("  Got:      hazard_type=%b, stall=%b, flush=%b, forward_a=%b, forward_b=%b, has_waw=%b, has_war=%b",
                        hazard_type, stall, flush, forward_a, forward_b, has_waw, has_war);
                failed_tests = failed_tests + 1;
            end
            test_num = test_num + 1;
        end
    endtask

    // 初始化测试环境
    initial begin
        // 初始化信号
        clk = 0;
        test_num = 1;
        passed_tests = 0;
        failed_tests = 0;

        if_id_inst = 32'h0;
        id_ex_inst = 32'h0;
        ex_mem_inst = 32'h0;
        id_rs1 = 5'b0;
        id_rs2 = 5'b0;
        id_rd = 5'b0;
        id_reg_write = 1'b0;
        ex_rd = 5'b0;
        ex_reg_write = 1'b0;
        ex_mem_to_reg = 2'b0;
        mem_rd = 5'b0;
        mem_reg_write = 1'b0;
        mem_mem_to_reg = 2'b0;
        wb_rd = 5'b0;
        wb_reg_write = 1'b0;
        branch_taken = 1'b0;
        jump_taken = 1'b0;

        #10; // 等待稳定

        $display("Starting Enhanced Hazard Detection Unit Test Suite");
        $display("=================================================");

        // 测试用例1: 无冒险情况
        $display("\nTest Case 1: No Hazards");
        // ID: add x1, x2, x3
        id_rs1 = 5'd2;
        id_rs2 = 5'd3;
        id_rd = 5'd1;
        id_reg_write = 1'b1;
        // EX: sub x4, x5, x6
        ex_rd = 5'd4;
        ex_reg_write = 1'b1;
        ex_mem_to_reg = 2'b0;
        // MEM: and x7, x8, x9
        mem_rd = 5'd7;
        mem_reg_write = 1'b1;
        mem_mem_to_reg = 2'b0;
        // WB: or x10, x11, x12
        wb_rd = 5'd10;
        wb_reg_write = 1'b1;

        #10;
        check_output(3'b000, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, "No hazards");

        // 测试用例2: EX阶段RAW冲突(rs1)
        $display("\nTest Case 2: EX Stage RAW Hazard (rs1)");
        // ID: add x1, x2, x3  (使用x2)
        id_rs1 = 5'd2;
        id_rs2 = 5'd3;
        // EX: add x2, x4, x5  (写入x2)
        ex_rd = 5'd2;
        ex_reg_write = 1'b1;
        ex_mem_to_reg = 2'b0;

        #10;
        check_output(3'b001, 1'b0, 1'b0, 2'b10, 2'b00, 1'b0, 1'b0, "EX stage RAW hazard on rs1");

        // 测试用例3: EX阶段RAW冲突(rs2)
        $display("\nTest Case 3: EX Stage RAW Hazard (rs2)");
        // ID: add x1, x2, x3  (使用x3)
        id_rs1 = 5'd2;
        id_rs2 = 5'd3;
        // EX: add x3, x4, x5  (写入x3)
        ex_rd = 5'd3;

        #10;
        check_output(3'b001, 1'b0, 1'b0, 2'b00, 2'b10, 1'b0, 1'b0, "EX stage RAW hazard on rs2");

        // 测试用例4: MEM阶段RAW冲突(load指令结果)
        $display("\nTest Case 4: MEM Stage RAW Hazard (Load Result)");
        // ID: add x1, x2, x3  (使用x2)
        id_rs1 = 5'd2;
        // MEM: lw x2, 0(x10)  (从内存加载到x2)
        mem_rd = 5'd2;
        mem_reg_write = 1'b1;
        mem_mem_to_reg = 2'b01; // load指令

        #10;
        check_output(3'b001, 1'b0, 1'b0, 2'b01, 2'b00, 1'b0, 1'b0, "MEM stage RAW hazard with load result");

        // 测试用例5: MEM阶段RAW冲突(ALU结果)
        $display("\nTest Case 5: MEM Stage RAW Hazard (ALU Result)");
        // ID: add x1, x2, x3  (使用x2)
        id_rs1 = 5'd2;
        // MEM: add x2, x4, x5  (ALU结果写入x2)
        mem_rd = 5'd2;
        mem_mem_to_reg = 2'b00; // ALU结果

        #10;
        check_output(3'b001, 1'b0, 1'b0, 2'b11, 2'b00, 1'b0, 1'b0, "MEM stage RAW hazard with ALU result");

        // 测试用例6: Load-Use冒险
        $display("\nTest Case 6: Load-Use Hazard");
        // ID: add x1, x2, x3  (使用x2)
        id_rs1 = 5'd2;
        // EX: lw x2, 0(x10)   (load指令写入x2)
        ex_rd = 5'd2;
        ex_reg_write = 1'b1;
        ex_mem_to_reg = 2'b01; // load指令

        #10;
        check_output(3'b100, 1'b1, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, "Load-Use hazard");

        // 测试用例7: 多个同时的RAW冲突
        $display("\nTest Case 7: Multiple Simultaneous RAW Hazards");
        // ID: add x1, x2, x3  (同时使用x2和x3)
        id_rs1 = 5'd2;
        id_rs2 = 5'd3;
        // EX: add x2, x4, x5  (写入x2)
        ex_rd = 5'd2;
        // MEM: add x3, x6, x7  (写入x3)
        mem_rd = 5'd3;

        #10;
        check_output(3'b001, 1'b0, 1'b0, 2'b10, 2'b11, 1'b0, 1'b0, "Multiple RAW hazards");

        // 测试用例8: 控制冒险(分支)
        $display("\nTest Case 8: Control Hazard (Branch)");
        branch_taken = 1'b1;

        #10;
        check_output(3'b010, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, "Control hazard from branch");
        branch_taken = 1'b0; // 重置

        // 测试用例9: 控制冒险(跳转)
        $display("\nTest Case 9: Control Hazard (Jump)");
        jump_taken = 1'b1;

        #10;
        check_output(3'b010, 1'b0, 1'b1, 2'b00, 2'b00, 1'b0, 1'b0, "Control hazard from jump");
        jump_taken = 1'b0; // 重置

        // 测试用例10: WAW冲突
        $display("\nTest Case 10: WAW Hazard");
        // ID: add x1, x2, x3  (写入x1)
        id_rd = 5'd1;
        id_reg_write = 1'b1;
        // EX: sub x1, x4, x5  (也写入x1)
        ex_rd = 5'd1;
        ex_reg_write = 1'b1;

        #10;
        check_output(3'b000, 1'b0, 1'b0, 2'b00, 2'b00, 1'b1, 1'b0, "WAW hazard");

        // 测试用例11: WAR冲突
        $display("\nTest Case 11: WAR Hazard");
        // ID: add x1, x2, x3  (写入x1)
        id_rd = 5'd1;
        id_reg_write = 1'b1;
        // EX: add x4, x1, x5  (读取x1)
        // 注意：这里需要设置id_ex_inst的rs1字段为1
        id_ex_inst = 32'h005080b3; // add x1, x1, x5 格式示例

        #10;
        check_output(3'b000, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b1, "WAR hazard");

        // 测试用例12: 寄存器x0的特殊情况(不应产生冲突)
        $display("\nTest Case 12: Register x0 Special Case");
        // ID: add x0, x2, x3  (写入x0 - 应该被忽略)
        id_rd = 5'd0;
        id_reg_write = 1'b1;
        // EX: add x0, x4, x5  (写入x0 - 应该被忽略)
        ex_rd = 5'd0;
        ex_reg_write = 1'b1;
        // ID使用x0作为源寄存器
        id_rs1 = 5'd0;
        id_rs2 = 5'd0;

        #10;
        check_output(3'b000, 1'b0, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, "Register x0 should not cause hazards");

        // 测试用例13: 优先级测试 - Load-Use优先于数据前向
        $display("\nTest Case 13: Priority Test - Load-Use vs Data Forwarding");
        // ID: add x1, x2, x3  (使用x2)
        id_rs1 = 5'd2;
        // EX: lw x2, 0(x10)   (load指令 - 应触发stall)
        ex_rd = 5'd2;
        ex_reg_write = 1'b1;
        ex_mem_to_reg = 2'b01;
        // MEM: add x2, x4, x5  (也写入x2 - 但优先级较低)
        mem_rd = 5'd2;
        mem_reg_write = 1'b1;

        #10;
        check_output(3'b100, 1'b1, 1'b0, 2'b00, 2'b00, 1'b0, 1'b0, "Load-Use should have higher priority");

        // 测试用例14: 复杂场景 - 混合冒险
        $display("\nTest Case 14: Complex Scenario - Mixed Hazards");
        // 重置所有信号
        id_rs1 = 5'd2;
        id_rs2 = 5'd3;
        id_rd = 5'd1;
        id_reg_write = 1'b1;
        ex_rd = 5'd2;
        ex_reg_write = 1'b1;
        ex_mem_to_reg = 2'b00;
        mem_rd = 5'd3;
        mem_reg_write = 1'b1;
        mem_mem_to_reg = 2'b00;
        branch_taken = 1'b1; // 同时有控制冒险

        #10;
        // 控制冒险应该优先
        check_output(3'b010, 1'b0, 1'b1, 2'b10, 2'b11, 1'b0, 1'b0, "Control hazard should have highest priority");
        branch_taken = 1'b0;

        // 测试用例15: 前向控制信号验证
        $display("\nTest Case 15: Forwarding Control Signals Verification");
        // 测试各种前向组合
        id_rs1 = 5'd1;
        id_rs2 = 5'd2;

        // 情况1: EX阶段前向
        ex_rd = 5'd1;
        mem_rd = 5'd2;
        #10;
        if (forward_a === 2'b10 && forward_b === 2'b11) begin
            $display("TEST %0d PASSED: Forwarding control - EX to rs1, MEM to rs2", test_num);
            passed_tests = passed_tests + 1;
        end else begin
            $display("TEST %0d FAILED: Forwarding control", test_num);
            failed_tests = failed_tests + 1;
        end
        test_num = test_num + 1;

        // 最终测试总结
        #10;
        $display("\nTest Summary");
        $display("=============");
        $display("Total Tests: %0d", test_num - 1);
        $display("Passed: %0d", passed_tests);
        $display("Failed: %0d", failed_tests);

        if (failed_tests == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end

        $finish;
    end

    // 波形记录
    initial begin
        $dumpfile("tb_enhanced_hazard_detection_unit.vcd");
        $dumpvars(0, tb_enhanced_hazard_detection_unit);
    end

endmodule