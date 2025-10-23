`timescale 1ns/1ps

module tb_riscv64_cpu_core;
    reg clk;
    reg rst_n;

    // 指令存储器接口
    reg [31:0] inst_data;
    wire [63:0] inst_addr;

    // 数据存储器接口
    reg [63:0] mem_data_in;
    wire [63:0] mem_addr;
    wire [63:0] mem_data_out;
    wire mem_write_en;
    wire mem_read_en;
    wire [7:0] mem_byte_en;

    // 调试接口
    wire [63:0] debug_pc;
    wire [31:0] debug_inst;
    wire debug_stall;
    wire debug_flush;

    // 存储器定义
    reg [31:0] inst_mem [0:1023];  // 4KB指令存储器
    reg [63:0] data_mem [0:1023];  // 8KB数据存储器

    // 内存延迟控制器
    reg [3:0] mem_delay_counter;
    reg mem_delay_active;
    reg [63:0] pending_mem_addr;
    reg pending_mem_read;
    reg pending_mem_write;
    reg [63:0] pending_mem_data;
    reg [7:0] pending_mem_byte_en;

    // 测试控制
    integer test_phase;
    integer cycle_count;
    integer error_count;
    integer total_tests;
    integer passed_tests;

    // 性能统计
    integer total_instructions;
    integer stall_cycles;
    integer mem_delay_cycles;

    // CPU实例化
    riscv64_cpu_core uut (
        .clk(clk),
        .rst_n(rst_n),
        .inst_data(inst_data),
        .inst_addr(inst_addr),
        .mem_data_in(mem_data_in),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_write_en(mem_write_en),
        .mem_read_en(mem_read_en),
        .mem_byte_en(mem_byte_en),
        .debug_pc(debug_pc),
        .debug_inst(debug_inst),
        .debug_stall(debug_stall),
        .debug_flush(debug_flush)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 从hex文件加载指令（不修改指令内容）
    initial begin
        $readmemh("test_program.hex", inst_mem);
    end

    // 指令存储器读取（无延迟）
    always @(*) begin
        if (inst_addr >= 64'h8000_0000 && inst_addr < 64'h8000_1000) begin
            inst_data = inst_mem[(inst_addr - 64'h8000_0000) >> 2];
        end else begin
            inst_data = 32'h00000013; // NOP
        end
    end

    // 集成内存延迟模拟
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_delay_counter <= 4'b0;
            mem_delay_active <= 1'b0;
            pending_mem_addr <= 64'h0;
            pending_mem_read <= 1'b0;
            pending_mem_write <= 1'b0;
            pending_mem_data <= 64'h0;
            pending_mem_byte_en <= 8'b0;
            mem_data_in <= 64'h0;
        end else begin
            if (mem_delay_active) begin
                mem_delay_cycles <= mem_delay_cycles + 1;
                if (mem_delay_counter > 0) begin
                    mem_delay_counter <= mem_delay_counter - 1;
                end else begin
                    // 延迟结束，处理内存访问
                    mem_delay_active <= 1'b0;
                    if (pending_mem_read) begin
                        // 返回读取的数据
                        if (pending_mem_addr >= 64'h9000_0000 && pending_mem_addr < 64'h9000_1000) begin
                            mem_data_in <= data_mem[(pending_mem_addr - 64'h9000_0000) >> 3];
                        end else begin
                            // 对于其他地址，返回基于地址的伪数据
                            mem_data_in <= {32'h0, pending_mem_addr[31:0]} | 64'h1234567800000000;
                        end
                    end
                end
            end else begin
                // 检查新的内存请求
                if (mem_read_en || mem_write_en) begin
                    // 随机延迟：1-15个周期（测试极端情况）
                    mem_delay_counter <= $urandom_range(1, 15);
                    mem_delay_active <= 1'b1;
                    pending_mem_addr <= mem_addr;
                    pending_mem_read <= mem_read_en;
                    pending_mem_write <= mem_write_en;
                    pending_mem_data <= mem_data_out;
                    pending_mem_byte_en <= mem_byte_en;

                    // 处理写请求（立即更新内存，但延迟响应）
                    if (mem_write_en) begin
                        if (mem_addr >= 64'h9000_0000 && mem_addr < 64'h9000_1000) begin
                            case (mem_byte_en)
                                8'b0000_0001: data_mem[(mem_addr - 64'h9000_0000) >> 3][7:0] <= mem_data_out[7:0];
                                8'b0000_0011: data_mem[(mem_addr - 64'h9000_0000) >> 3][15:0] <= mem_data_out[15:0];
                                8'b0000_1111: data_mem[(mem_addr - 64'h9000_0000) >> 3][31:0] <= mem_data_out[31:0];
                                8'b1111_1111: data_mem[(mem_addr - 64'h9000_0000) >> 3] <= mem_data_out;
                                default: ; // 保持原值
                            endcase
                        end
                    end
                end
            end
        end
    end

    // 测试任务：检查寄存器值
    task check_register;
        input [4:0] reg_num;
        input [63:0] expected_value;
        input string reg_name;
        input integer test_id;
        begin
            total_tests = total_tests + 1;
            if (uut.reg_file[reg_num] === expected_value) begin
                $display("TEST %0d PASSED: Register %s (x%0d) = %h",
                         test_id, reg_name, reg_num, expected_value);
                passed_tests = passed_tests + 1;
            end else begin
                $display("TEST %0d FAILED: Register %s (x%0d) = %h, expected %h",
                         test_id, reg_name, reg_num, uut.reg_file[reg_num], expected_value);
                error_count = error_count + 1;
            end
        end
    endtask

    // 测试任务：检查内存值
    task check_memory;
        input [63:0] addr;
        input [63:0] expected_value;
        input string location;
        input integer test_id;
        begin
            total_tests = total_tests + 1;
            if (data_mem[(addr - 64'h9000_0000) >> 3] === expected_value) begin
                $display("TEST %0d PASSED: Memory %s = %h", test_id, location, expected_value);
                passed_tests = passed_tests + 1;
            end else begin
                $display("TEST %0d FAILED: Memory %s = %h, expected %h",
                         test_id, location, data_mem[(addr - 64'h9000_0000) >> 3], expected_value);
                error_count = error_count + 1;
            end
        end
    endtask

    // 测试任务：等待特定PC值
    task wait_for_pc;
        input [63:0] target_pc;
        input [63:0] timeout_cycles;
        input string description;
        integer timeout;
        begin
            timeout = 0;
            while (debug_pc !== target_pc && timeout < timeout_cycles) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (debug_stall) stall_cycles = stall_cycles + 1;
            end

            if (debug_pc === target_pc) begin
                $display("Reached PC: %h - %s", target_pc, description);
            end else begin
                $display("TIMEOUT: Failed to reach PC %h - %s", target_pc, description);
                error_count = error_count + 1;
            end
        end
    endtask

    // 测试任务：等待特定寄存器值
    task wait_for_register;
        input [4:0] reg_num;
        input [63:0] expected_value;
        input [63:0] timeout_cycles;
        input string description;
        integer timeout;
        begin
            timeout = 0;
            while (uut.reg_file[reg_num] !== expected_value && timeout < timeout_cycles) begin
                @(posedge clk);
                timeout = timeout + 1;
                if (debug_stall) stall_cycles = stall_cycles + 1;
            end

            if (uut.reg_file[reg_num] === expected_value) begin
                $display("Register x%0d = %h - %s", reg_num, expected_value, description);
            end else begin
                $display("TIMEOUT: Register x%0d = %h, expected %h - %s",
                         reg_num, uut.reg_file[reg_num], expected_value, description);
                error_count = error_count + 1;
            end
        end
    endtask

    // 主测试流程
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        test_phase = 0;
        cycle_count = 0;
        error_count = 0;
        total_tests = 0;
        passed_tests = 0;
        total_instructions = 0;
        stall_cycles = 0;
        mem_delay_cycles = 0;

        // 初始化数据存储器
        for (integer i = 0; i < 1024; i = i + 1) begin
            data_mem[i] = 64'h0;
        end

        // 设置测试数据模式
        data_mem[0] = 64'h0000000000001001;
        data_mem[1] = 64'h0000000000002002;
        data_mem[2] = 64'h0000000000003003;
        data_mem[3] = 64'h0000000000004004;
        data_mem[4] = 64'h0000000000005005;
        data_mem[5] = 64'h0000000000006006;
        data_mem[16] = 64'h0123456789ABCDEF; // 测试数据块
        data_mem[17] = 64'hFEDCBA9876543210;

        $display("==================================================");
        $display("Comprehensive RISC-V 64 CPU Core Test Suite");
        $display("==================================================");

        #100;
        rst_n = 1;
        $display("Reset released at cycle %0d", cycle_count);

        // ==================== 测试阶段1: 基础算术指令 ====================
        $display("\n[PHASE 1] Basic Arithmetic Instructions");
        test_phase = 1;

        // 等待测试程序执行到特定点
        wait_for_register(5'd1, 64'h3, 200, "ADD instruction completed");
        check_register(5'd1, 64'h3, "x1 (ADD result)", 1001);
        check_register(5'd2, 64'h1, "x2 (operand)", 1002);
        check_register(5'd3, 64'h2, "x3 (operand)", 1003);

        wait_for_register(5'd4, 64'hFFFFFFFFFFFFFFFE, 200, "SUB instruction completed");
        check_register(5'd4, 64'hFFFFFFFFFFFFFFFE, "x4 (SUB result)", 1004);

        // ==================== 测试阶段2: 逻辑运算指令 ====================
        $display("\n[PHASE 2] Logical Instructions");
        test_phase = 2;

        wait_for_register(5'd5, 64'h1, 200, "AND instruction completed");
        check_register(5'd5, 64'h1, "x5 (AND result)", 2001);

        wait_for_register(5'd6, 64'h3, 200, "OR instruction completed");
        check_register(5'd6, 64'h3, "x6 (OR result)", 2002);

        wait_for_register(5'd7, 64'h2, 200, "XOR instruction completed");
        check_register(5'd7, 64'h2, "x7 (XOR result)", 2003);

        // ==================== 测试阶段3: 移位指令 ====================
        $display("\n[PHASE 3] Shift Instructions");
        test_phase = 3;

        wait_for_register(5'd8, 64'h4, 200, "SLL instruction completed");
        check_register(5'd8, 64'h4, "x8 (SLL result)", 3001);

        wait_for_register(5'd9, 64'h1, 200, "SRL instruction completed");
        check_register(5'd9, 64'h1, "x9 (SRL result)", 3002);

        // ==================== 测试阶段4: 内存加载指令（可变延迟） ====================
        $display("\n[PHASE 4] Load Instructions with Variable Delay");
        test_phase = 4;

        wait_for_register(5'd10, 64'h1001, 500, "LW instruction completed");
        check_register(5'd10, 64'h1001, "x10 (LW result)", 4001);

        wait_for_register(5'd11, 64'h2002, 500, "Second LW completed");
        check_register(5'd11, 64'h2002, "x11 (LW result)", 4002);

        // ==================== 测试阶段5: 内存存储指令（可变延迟） ====================
        $display("\n[PHASE 5] Store Instructions with Variable Delay");
        test_phase = 5;

        wait_for_register(5'd12, 64'h3003, 500, "Store address ready");
        check_memory(64'h9000_0020, 64'h3003, "SW result 1", 5001);
        check_memory(64'h9000_0028, 64'h4004, "SW result 2", 5002);

        // ==================== 测试阶段6: 条件分支指令 ====================
        $display("\n[PHASE 6] Conditional Branch Instructions");
        test_phase = 6;

        wait_for_register(5'd13, 64'hA, 300, "Branch test completed");
        check_register(5'd13, 64'hA, "x13 (Branch result)", 6001);
        check_register(5'd14, 64'h1, "x14 (Branch taken flag)", 6002);

        // ==================== 测试阶段7: 无条件跳转指令 ====================
        $display("\n[PHASE 7] Unconditional Jump Instructions");
        test_phase = 7;

        wait_for_register(5'd15, 64'h80000050, 300, "JAL completed");
        check_register(5'd15, 64'h80000050, "x15 (JAL return addr)", 7001);

        // ==================== 测试阶段8: 数据冒险测试 ====================
        $display("\n[PHASE 8] Data Hazard Tests");
        test_phase = 8;

        wait_for_register(5'd16, 64'h6, 300, "RAW hazard resolved");
        check_register(5'd16, 64'h6, "x16 (RAW result)", 8001);

        wait_for_register(5'd17, 64'h4, 300, "Forwarding test completed");
        check_register(5'd17, 64'h4, "x17 (Forwarding result)", 8002);

        // ==================== 测试阶段9: Load-Use冒险测试 ====================
        $display("\n[PHASE 9] Load-Use Hazard Tests");
        test_phase = 9;

        wait_for_register(5'd18, 64'h2002, 500, "Load-use completed");
        check_register(5'd18, 64'h2002, "x18 (Load-use result)", 9001);

        // ==================== 测试阶段10: 控制冒险测试 ====================
        $display("\n[PHASE 10] Control Hazard Tests");
        test_phase = 10;

        wait_for_register(5'd19, 64'h14, 300, "Control hazard resolved");
        check_register(5'd19, 64'h14, "x19 (Control hazard result)", 10001);

        // ==================== 测试阶段11: 边界情况测试 ====================
        $display("\n[PHASE 11] Corner Case Tests");
        test_phase = 11;

        wait_for_register(5'd20, 64'h0, 200, "Zero register test");
        check_register(5'd0, 64'h0, "x0 (Hardwired zero)", 11001);
        check_register(5'd20, 64'h0, "x20 (Zero operation)", 11002);

        // ==================== 测试阶段12: 复杂内存操作 ====================
        $display("\n[PHASE 12] Complex Memory Operations");
        test_phase = 12;

        wait_for_register(5'd21, 64'h20, 500, "Complex memory op completed");
        check_register(5'd21, 64'h20, "x21 (Memory calculation)", 12001);
        check_memory(64'h9000_0100, 64'h1234, "Complex store 1", 12002);

        // 最终测试总结
        #200;
        $display("\n==================================================");
        $display("Test Suite Complete - Performance Statistics");
        $display("==================================================");
        $display("Total Clock Cycles: %0d", cycle_count);
        $display("Total Instructions Executed: ~%0d", total_instructions);
        $display("Stall Cycles: %0d (%.1f%%)", stall_cycles, (stall_cycles * 100.0) / cycle_count);
        $display("Memory Delay Cycles: %0d (%.1f%%)", mem_delay_cycles, (mem_delay_cycles * 100.0) / cycle_count);
        $display("Total Tests: %0d", total_tests);
        $display("Passed Tests: %0d", passed_tests);
        $display("Failed Tests: %0d", error_count);
        $display("Success Rate: %.1f%%", (passed_tests * 100.0) / total_tests);

        if (error_count == 0) begin
            $display("\n*** ALL TESTS PASSED! ***");
        end else begin
            $display("\n*** %0d TEST(S) FAILED! ***", error_count);
        end

        $finish;
    end

    // 时钟周期计数和指令计数
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            // 简单指令计数：当PC变化且不stall时计数
            if (!debug_stall && (debug_pc !== debug_pc)) begin
                total_instructions <= total_instructions + 1;
            end
        end
    end

    // 波形记录
    initial begin
        $dumpfile("riscv64_cpu_core_comprehensive.vcd");
        $dumpvars(0, tb_riscv64_cpu_core);
    end

    // 实时监控（减少输出频率）
    always @(posedge clk) begin
        if (rst_n && (cycle_count % 50 == 0)) begin
            $display("Cycle: %4d, PC: %h, Inst: %h, Phase: %0d",
                     cycle_count, debug_pc, debug_inst, test_phase);
        end

        // 监控内存操作和延迟
        if (mem_read_en || mem_write_en) begin
            $display("Cycle: %4d, Mem %s: addr=%h, delay=%0d cycles",
                     cycle_count, mem_write_en ? "WRITE" : "READ",
                     mem_addr, mem_delay_active ? mem_delay_counter : 0);
        end

        // 监控冒险情况
        if (debug_stall) begin
            $display("Cycle: %4d, STALL detected - Hazard handling", cycle_count);
        end
        if (debug_flush) begin
            $display("Cycle: %4d, FLUSH detected - Control hazard", cycle_count);
        end
    end

endmodule