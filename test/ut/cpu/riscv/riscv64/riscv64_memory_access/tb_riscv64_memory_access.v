`timescale 1ns/1ps

// RISC-V 64-bit Memory Access Unit Test Bench
module tb_riscv64_memory_access;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;
    reg         stall_i;
    reg         flush_i;

    // Input Signals from Execution Stage
    reg  [63:0] pc_in_i;
    reg  [31:0] instr_in_i;
    reg  [63:0] alu_result_i;
    reg  [63:0] rs2_data_i;
    reg  [15:0] ctrl_in_i;

    // Cache Interface Signals
    reg  [63:0] cache_rdata_i;
    reg         cache_ready_i;

    // Output Signals to Write Back Stage
    wire [63:0] pc_out_o;
    wire [31:0] instr_out_o;
    wire [63:0] mem_result_o;
    wire [15:0] ctrl_out_o;

    // Cache Output Signals
    wire [63:0] cache_addr_o;
    wire [63:0] cache_wdata_o;
    wire        cache_req_o;
    wire        cache_we_o;
    wire [7:0]  cache_byte_en_o;

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate Device Under Test (DUT)
    riscv64_memory_access u_riscv64_memory_access (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall_i      (stall_i),
        .flush_i      (flush_i),
        .pc_in_i      (pc_in_i),
        .instr_in_i   (instr_in_i),
        .alu_result_i (alu_result_i),
        .rs2_data_i   (rs2_data_i),
        .ctrl_in_i    (ctrl_in_i),
        .cache_addr_o (cache_addr_o),
        .cache_wdata_o(cache_wdata_o),
        .cache_rdata_i(cache_rdata_i),
        .cache_req_o  (cache_req_o),
        .cache_we_o   (cache_we_o),
        .cache_byte_en_o(cache_byte_en_o),
        .cache_ready_i(cache_ready_i),
        .pc_out_o     (pc_out_o),
        .instr_out_o  (instr_out_o),
        .mem_result_o (mem_result_o),
        .ctrl_out_o   (ctrl_out_o)
    );

    // Test Variables
    integer test_passed;
    integer total_tests;
    integer error_count;

    // Test Task: Check PC and Instruction Only
    task check_pc_and_instr(input integer test_name_id,
                           input [63:0] expected_pc,
                           input [31:0] expected_instr);
        reg [63:0] actual_pc;
        reg [31:0] actual_instr;
        reg [256:0] test_name;
        begin
            @(negedge clk);
            actual_pc = pc_out_o;
            actual_instr = instr_out_o;

            // Map test name ID to test name
            case (test_name_id)
                1: test_name = "Reset Operation";
                2: test_name = "Non-Memory Instruction";
                3: test_name = "Stall Function";
                4: test_name = "Flush Function";
                5: test_name = "Reset Again";
                6: test_name = "Basic Data Transfer";
                default: test_name = "Unknown Test";
            endcase

            total_tests = total_tests + 1;
            if (actual_pc === expected_pc && actual_instr === expected_instr) begin
                test_passed = test_passed + 1;
                $display("Time: %t - Pass: %s", $time, test_name);
            end else begin
                error_count = error_count + 1;
                $display("Time: %t - Error: %s", $time, test_name);
                $display("  Expected PC: 0x%h, Got: 0x%h", expected_pc, actual_pc);
                $display("  Expected Instr: 0x%h, Got: 0x%h", expected_instr, actual_instr);
            end
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        rst_n = 0;  // Start in reset state
        stall_i = 0;
        flush_i = 0;
        pc_in_i = 0;
        instr_in_i = 0;
        alu_result_i = 0;
        rs2_data_i = 0;
        ctrl_in_i = 0;
        cache_rdata_i = 0;
        cache_ready_i = 1'b1; // Always ready for simple tests
        test_passed = 0;
        total_tests = 0;
        error_count = 0;

        // Perform Reset
        $display("start test: riscv64_memory_access ut");
        $display("Test 1: Perform Reset Operation");
        // We're already in reset state, check outputs
        @(negedge clk);
        check_pc_and_instr(1, 64'b0, 32'h00000013);  // Reset sets NOP instruction

        // Deassert reset
        @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        // Test 2: Non-Memory Instruction (Basic Data Transfer)
        $display("Test 2: Non-Memory Instruction");
        @(posedge clk);
        pc_in_i = 64'h0000000000001000;
        instr_in_i = 32'h00100093;
        alu_result_i = 64'h1234567890ABCDEF;
        rs2_data_i = 64'h0;
        ctrl_in_i = 16'h0000;
        @(posedge clk);
        check_pc_and_instr(2, 64'h0000000000001000, 32'h00100093);

        // Test 3: Stall Function
        $display("Test 3: Stall Function");
        @(posedge clk);
        pc_in_i = 64'h0000000000001004;
        instr_in_i = 32'h00200113;
        alu_result_i = 64'h1111111111111111;
        rs2_data_i = 64'h0;
        ctrl_in_i = 16'h0000;
        @(posedge clk);
        @(negedge clk);
        // Apply stall
        stall_i = 1;
        // Change inputs during stall (should not be processed)
        pc_in_i = 64'h2000;
        instr_in_i = 32'h00300193;
        @(posedge clk);
        @(negedge clk);
        // Check outputs are held during stall
        if (pc_out_o === 64'h0000000000001004 && instr_out_o === 32'h00200113) begin
            test_passed = test_passed + 1;
            $display("Time: %t - Pass: Stall Function (during stall)", $time);
        end else begin
            error_count = error_count + 1;
            $display("Time: %t - Error: Stall Function (during stall)", $time);
            $display("  Expected PC: 0x%h, Got: 0x%h", 64'h0000000000001004, pc_out_o);
            $display("  Expected Instr: 0x%h, Got: 0x%h", 32'h00200113, instr_out_o);
        end
        total_tests = total_tests + 1;
        // Release stall
        stall_i = 0;
        @(posedge clk);
        check_pc_and_instr(3, 64'h0000000000001004, 32'h00200113);

        // Test 4: Flush Function
        $display("Test 4: Flush Function");
        @(posedge clk);
        pc_in_i = 64'h0000000000001008;
        instr_in_i = 32'h00400213;
        alu_result_i = 64'h3333333333333333;
        rs2_data_i = 64'h0;
        ctrl_in_i = 16'h0000;
        @(posedge clk);
        // Apply flush
        flush_i = 1;
        @(posedge clk);
        @(negedge clk);
        check_pc_and_instr(4, 64'h0000000000001008, 32'h00000013);  // Flush sets NOP, PC remains
        flush_i = 0;

        // Test 5: Reset Again
        $display("Test 5: Reset Again");
        @(posedge clk);
        rst_n = 0;
        @(negedge clk);
        check_pc_and_instr(5, 64'b0, 32'h00000013);  // Reset sets NOP instruction
        #20;
        @(posedge clk);
        rst_n = 1;

        // Test 6: Basic Data Transfer After Reset
        $display("Test 6: Basic Data Transfer After Reset");
        @(posedge clk);
        pc_in_i = 64'h000000000000100C;
        instr_in_i = 32'h00500293;
        @(posedge clk);
        check_pc_and_instr(6, 64'h000000000000100C, 32'h00500293);

        // Test Summary
        #100;
        $display("\n========================================");
        $display("Test Summary: riscv64_memory_access Unit Test");
        $display("Total Tests: %0d", total_tests);
        $display("Passed Tests: %0d", test_passed);
        $display("Failed Tests: %0d", error_count);
        $display("Test Result: %s", (error_count == 0) ? "PASS" : "FAIL");
        $display("========================================");

        $finish;
    end

    // Global Timeout Monitoring
    initial begin
        #10000;  // 10ms timeout
        $display("Error: Test execution timeout! Forcing simulation end.");
        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_riscv64_memory_access.vcd");
        $dumpvars(0, tb_riscv64_memory_access);
    end

endmodule