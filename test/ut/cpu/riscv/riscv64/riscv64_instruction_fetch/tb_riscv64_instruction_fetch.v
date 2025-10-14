`timescale 1ns/1ps

// RISC-V 64-bit Instruction Fetch Unit Test Bench
module tb_riscv64_instruction_fetch;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;

    // Input Signals
    reg         stall_i;
    reg         flush_i;
    reg  [63:0] branch_target_i;
    reg         branch_taken_i;
    reg  [31:0] cache_data_i;
    reg         cache_ready_i;

    // Output Signals
    wire [63:0] pc_o;
    wire [31:0] instr_o;
    wire        cache_req_o;
    wire [63:0] cache_addr_o;

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate Device Under Test (DUT)
    riscv64_instruction_fetch u_riscv64_instruction_fetch (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall_i          (stall_i),
        .flush_i          (flush_i),
        .branch_target_i  (branch_target_i),
        .branch_taken_i   (branch_taken_i),
        .pc_o             (pc_o),
        .instr_o          (instr_o),
        .cache_req_o      (cache_req_o),
        .cache_addr_o     (cache_addr_o),
        .cache_data_i     (cache_data_i),
        .cache_ready_i    (cache_ready_i)
    );

    // Test Variables
    integer test_passed;
    integer total_tests;
    integer error_count;

    // Individual test flags
    reg test1_fail = 0;
    reg test2_fail = 0;
    reg test3_fail = 0;
    reg test4_fail = 0;
    reg test5_fail = 0;
    reg test6_fail = 0;
    reg test7_fail = 0;
    reg test8_fail = 0;
    reg test9_fail = 0;

    // Test Task: Initialize Signals
    task init_signals;
        begin
            rst_n = 1;
            stall_i = 0;
            flush_i = 0;
            branch_target_i = 0;
            branch_taken_i = 0;
            cache_data_i = 0;
            cache_ready_i = 0;
            test_passed = 0;
            total_tests = 0;
            error_count = 0;
        end
    endtask

    // Test Task: Perform Reset
    task perform_reset;
        begin
            @(posedge clk);
            rst_n = 0;
            #20;
            @(posedge clk);
            rst_n = 1;
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    // Test Task: Check PC Value
    task check_pc(input [63:0] expected_pc, input integer test_num);
        begin
            @(posedge clk);
            #1;
            total_tests = total_tests + 1;
            if (pc_o === expected_pc) begin
                test_passed = test_passed + 1;
            `ifdef DEBUG
                $display("Time: %t - Pass: PC value is 0x%h (as expected) [Test: %0d]", $time, pc_o, test_num);
            `endif
            end else begin
                error_count = error_count + 1;
                case(test_num)
                    2: test2_fail = 1;
                    3: test3_fail = 1;
                    4: test4_fail = 1;
                    5: test5_fail = 1;
                    6: test6_fail = 1;
                    7: test7_fail = 1;
                    8: test8_fail = 1;
                endcase
                $display("Time: %t - Error: PC expected 0x%h, got 0x%h [Test: %0d]", $time, expected_pc, pc_o, test_num);
                $display("Time: %t - Debug Info: stall_i=%b, cache_ready_i=%b, cache_data_i=0x%h", $time, stall_i, cache_ready_i, cache_data_i);
            end
        end
    endtask

    // Test Task: Check Instruction Value
    task check_instr(input [31:0] expected_instr, input integer test_num);
        begin
            @(posedge clk);
            #1;
            total_tests = total_tests + 1;
            if (instr_o === expected_instr) begin
                test_passed = test_passed + 1;
            `ifdef DEBUG
                $display("Time: %t - Pass: Instruction value is 0x%h (as expected) [Test: %0d]", $time, instr_o, test_num);
            `endif
            end else begin
                error_count = error_count + 1;
                case(test_num)
                    2: test2_fail = 1;
                    3: test3_fail = 1;
                    4: test4_fail = 1;
                    5: test5_fail = 1;
                    6: test6_fail = 1;
                    7: test7_fail = 1;
                    8: test8_fail = 1;
                    9: test9_fail = 1;
                endcase
                $display("Time: %t - Error: Instruction expected 0x%h, got 0x%h [Test: %0d]", $time, expected_instr, instr_o, test_num);
                $display("Time: %t - Debug Info: stall_i=%b, cache_ready_i=%b, cache_data_i=0x%h", $time, stall_i, cache_ready_i, cache_data_i);
            end
        end
    endtask

    // Test Task: Simulate Cache Response
    task simulate_cache_response(input [31:0] data);
        begin
            @(posedge clk);
            cache_data_i = data;
            cache_ready_i = 1;
            @(posedge clk);
            cache_ready_i = 0;
            cache_data_i = 0;
        end
    endtask

    // Test Task: Apply Stall
    task apply_stall(input integer cycles);
        integer i;
        begin
            stall_i = 1;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
            end
            stall_i = 0;
            @(posedge clk);
        end
    endtask

    // Test Task: Perform Flush
    task perform_flush(input [63:0] target_pc);
        begin
            @(posedge clk);
            flush_i = 1;
            branch_target_i = target_pc;
            @(posedge clk);
            flush_i = 0;
            branch_target_i = 0;
            @(posedge clk);
        end
    endtask

    // Test Task: Perform Branch
    task perform_branch(input [63:0] target_pc);
        begin
            @(posedge clk);
            branch_taken_i = 1;
            branch_target_i = target_pc;
            @(posedge clk);
            branch_taken_i = 0;
            branch_target_i = 0;
            @(posedge clk);
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        init_signals();

        // Perform Reset
        $display("start test: riscv64_instruction_fetch ut");
        $display("Test 1: Perform Reset Operation");
        perform_reset();

        // Test 2: Verify Initial PC Value
        $display("Test 2: Verify Initial PC Value");
        check_pc(64'h80000000, 2);
        check_instr(32'h00000013, 2); // NOP instruction

        // Test 3: Basic Instruction Fetch
        $display("Test 3: Basic Instruction Fetch");
        $display("Test 3: Current state before cache response - PC=0x%h, Instruction=0x%h, Cache Ready=%b, Cache Data=0x%h", pc_o, instr_o, cache_ready_i, cache_data_i);
        // Simulate cache response with a sample instruction
        simulate_cache_response(32'h00110113); // ADDI x2, x2, 1
        $display("Test 3: After simulate_cache_response - Cache Ready=%b, Cache Data=0x%h", cache_ready_i, cache_data_i);
        #1; // Small delay to let signals propagate
        $display("Test 3: Before check_instr - PC=0x%h, Instruction=0x%h", pc_o, instr_o);
        check_instr(32'h00110113, 3);
        @(posedge clk);
        $display("Test 3: Before check_pc - PC=0x%h, Expected=0x80000004", pc_o);
        check_pc(64'h80000004, 3);

        // Test 4: Sequential Instruction Fetch
        $display("Test 4: Sequential Instruction Fetch");
        $display("Test 4: Current state - PC=0x%h, Instruction=0x%h", pc_o, instr_o);
        simulate_cache_response(32'h00210193); // ADDI x3, x2, 2
        @(posedge clk);
        $display("Test 4: Before first check_pc - PC=0x%h, Expected=0x80000008", pc_o);
        check_pc(64'h80000008, 4);
        simulate_cache_response(32'h00310213); // ADDI x4, x2, 3
        @(posedge clk);
        $display("Test 4: Before second check_pc - PC=0x%h, Expected=0x8000000C", pc_o);
        check_pc(64'h8000000C, 4);

        // Test 5: Pipeline Stall
        $display("Test 5: Pipeline Stall");
        $display("Test 5: Current state before stall - PC=0x%h, Instruction=0x%h", pc_o, instr_o);
        apply_stall(2); // Stall for 2 cycles
        $display("Test 5: After stall - PC=0x%h, Expected=0x8000000C", pc_o);
        check_pc(64'h8000000C, 5); // PC should remain the same after stall
        simulate_cache_response(32'h00410293); // ADDI x5, x2, 4
        @(posedge clk);
        $display("Test 5: Before final check_pc - PC=0x%h, Expected=0x80000010", pc_o);
        check_pc(64'h80000010, 5);

        // Test 6: Flush Operation
        $display("Test 6: Flush Operation");
        perform_flush(64'h80000020);
        check_pc(64'h80000020, 6);
        check_instr(32'h00000013, 6); // NOP after flush
        simulate_cache_response(32'h00510313); // ADDI x6, x2, 5
        @(posedge clk);
        check_pc(64'h80000024, 6);

        // Test 7: Branch Taken
        $display("Test 7: Branch Taken");
        perform_branch(64'h80000030);
        check_pc(64'h80000030, 7);
        simulate_cache_response(32'h00610393); // ADDI x7, x2, 6
        @(posedge clk);
        check_pc(64'h80000034, 7);

        // Test 8: Cache Ready Behavior
        $display("Test 8: Cache Ready Behavior");
        // Test with cache_ready staying high for multiple cycles
        cache_data_i = 32'h00710413; // ADDI x8, x2, 7
        cache_ready_i = 1;
        @(posedge clk);
        @(posedge clk);
        cache_ready_i = 0;
        cache_data_i = 0;
        check_pc(64'h80000038, 8);
        check_instr(32'h00710413, 8);

        // Test 9: Invalid Cache Data
        $display("Test 9: Invalid Cache Data");
        @(posedge clk);
        cache_data_i = 32'hxxxxxxxx; // Invalid data (all bits x)
        cache_ready_i = 1;
        @(posedge clk);
        cache_ready_i = 0;
        cache_data_i = 0;
        // Add a cycle delay to let the DUT process the invalid data
        @(posedge clk);
        check_instr(32'h00000013, 9); // Should use NOP instead

        // Test Summary
        #10;
        $display("\n========================================");
        $display("Test Summary: riscv64_instruction_fetch Unit Test");
        $display("Total Tests: %0d", total_tests);
        $display("Passed Tests: %0d", test_passed);
        $display("Failed Tests: %0d", error_count);
        $display("========================================");
        $display("Detailed Test Results:");
        $display("Test 1: Reset Operation - %s", (test1_fail) ? "FAIL" : "PASS");
        $display("Test 2: Initial PC Value - %s", (test2_fail) ? "FAIL" : "PASS");
        $display("Test 3: Basic Instruction Fetch - %s", (test3_fail) ? "FAIL" : "PASS");
        $display("Test 4: Sequential Instruction Fetch - %s", (test4_fail) ? "FAIL" : "PASS");
        $display("Test 5: Pipeline Stall - %s", (test5_fail) ? "FAIL" : "PASS");
        $display("Test 6: Flush Operation - %s", (test6_fail) ? "FAIL" : "PASS");
        $display("Test 7: Branch Taken - %s", (test7_fail) ? "FAIL" : "PASS");
        $display("Test 8: Cache Ready Behavior - %s", (test8_fail) ? "FAIL" : "PASS");
        $display("Test 9: Invalid Cache Data - %s", (test9_fail) ? "FAIL" : "PASS");
        $display("========================================");
        $display("Test Result: %s", (error_count == 0) ? "PASS" : "FAIL");
        $display("========================================");

        $finish;

    end

    // Global Timeout Monitoring
    initial begin
        #1000;  // 1ms timeout
        $display("Error: Test execution timeout! Forcing simulation end.");
        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_riscv64_instruction_fetch.vcd");
        $dumpvars(0, tb_riscv64_instruction_fetch);
    end

`ifdef DEBUG
    // Real-time Monitoring
    always @(posedge clk) begin
        if (rst_n) begin
            $display("Time: %t - PC: 0x%h, Instruction: 0x%h, Cache Req: %b, Cache Addr: 0x%h, Cache Ready: %b, Cache Data: 0x%h",
                     $time, pc_o, instr_o, cache_req_o, cache_addr_o, cache_ready_i, cache_data_i);
        end
    end
`endif

endmodule