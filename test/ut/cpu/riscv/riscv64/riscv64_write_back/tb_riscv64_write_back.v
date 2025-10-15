`timescale 1ns/1ps

// RISC-V 64-bit Write Back Unit Test Bench
module tb_riscv64_write_back;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;
    reg         stall_i;

    // Input Signals from Memory Access Stage
    reg  [63:0] pc_in_i;
    reg  [31:0] instr_in_i;
    reg  [63:0] alu_result_i;
    reg  [63:0] mem_result_i;
    reg  [15:0] ctrl_in_i;

    // Output Signals to Register File
    wire [4:0]  rd_o;
    wire        reg_we_o;
    wire [63:0] reg_wdata_o;

    // Debug Output Signals
    wire [63:0] pc_out_o;
    wire [31:0] instr_out_o;
    wire        wb_valid_o;

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate Device Under Test (DUT)
    riscv64_write_back u_riscv64_write_back (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall_i      (stall_i),
        .pc_in_i      (pc_in_i),
        .instr_in_i   (instr_in_i),
        .alu_result_i (alu_result_i),
        .mem_result_i (mem_result_i),
        .ctrl_in_i    (ctrl_in_i),
        .rd_o         (rd_o),
        .reg_we_o     (reg_we_o),
        .reg_wdata_o  (reg_wdata_o),
        .pc_out_o     (pc_out_o),
        .instr_out_o  (instr_out_o),
        .wb_valid_o   (wb_valid_o)
    );

    // Test Variables
    integer test_passed;
    integer total_tests;
    integer error_count;

    // Test Task: Check Outputs
    task check_outputs(input integer test_name_id,
                      input [4:0] expected_rd,
                      input expected_reg_we,
                      input [63:0] expected_reg_wdata,
                      input [63:0] expected_pc_out,
                      input [31:0] expected_instr_out,
                      input expected_wb_valid);
        reg [256:0] test_name;
        begin
            @(negedge clk);

            // Map test name ID to test name
            case (test_name_id)
                1: test_name = "Reset Operation";
                2: test_name = "LUI Instruction";
                3: test_name = "AUIPC Instruction";
                4: test_name = "JAL Instruction";
                5: test_name = "ALU Instruction";
                6: test_name = "Load Instruction";
                7: test_name = "Store Instruction (No Write)";
                8: test_name = "x0 Register Test";
                9: test_name = "Stall Function";
                default: test_name = "Unknown Test";
            endcase

            total_tests = total_tests + 1;
            if (rd_o === expected_rd &&
                reg_we_o === expected_reg_we &&
                reg_wdata_o === expected_reg_wdata &&
                pc_out_o === expected_pc_out &&
                instr_out_o === expected_instr_out &&
                wb_valid_o === expected_wb_valid) begin
                test_passed = test_passed + 1;
                $display("Time: %t - Pass: %s", $time, test_name);
            end else begin
                error_count = error_count + 1;
                $display("Time: %t - Error: %s", $time, test_name);
                if (rd_o !== expected_rd) begin
                    $display("  Expected RD: %0d, Got: %0d", expected_rd, rd_o);
                end
                if (reg_we_o !== expected_reg_we) begin
                    $display("  Expected Reg WE: %b, Got: %b", expected_reg_we, reg_we_o);
                end
                if (reg_wdata_o !== expected_reg_wdata) begin
                    $display("  Expected Reg WData: 0x%h, Got: 0x%h", expected_reg_wdata, reg_wdata_o);
                end
                if (pc_out_o !== expected_pc_out) begin
                    $display("  Expected PC Out: 0x%h, Got: 0x%h", expected_pc_out, pc_out_o);
                end
                if (instr_out_o !== expected_instr_out) begin
                    $display("  Expected Instr Out: 0x%h, Got: 0x%h", expected_instr_out, instr_out_o);
                end
                if (wb_valid_o !== expected_wb_valid) begin
                    $display("  Expected WB Valid: %b, Got: %b", expected_wb_valid, wb_valid_o);
                end
            end
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        rst_n = 1;
        stall_i = 0;
        pc_in_i = 0;
        instr_in_i = 0;
        alu_result_i = 0;
        mem_result_i = 0;
        ctrl_in_i = 0;
        test_passed = 0;
        total_tests = 0;
        error_count = 0;

        // Perform Reset
        $display("start test: riscv64_write_back ut");
        // Test 1: Reset Operation
        $display("Test 1: Perform Reset Operation");
        rst_n = 0;
        #20;
        // Check outputs during reset
        @(negedge clk);
        if (rd_o === 5'b0 && reg_we_o === 1'b0 && reg_wdata_o === 64'b0 &&
            pc_out_o === 64'b0 && instr_out_o === 32'h00000013 && wb_valid_o === 1'b0) begin
            test_passed = test_passed + 1;
            $display("Time: %t - Pass: Reset Operation (during reset)", $time);
        end else begin
            error_count = error_count + 1;
            $display("Time: %t - Error: Reset Operation (during reset)", $time);
            if (rd_o !== 5'b0) $display("  Expected RD: 0, Got: %0d", rd_o);
            if (reg_we_o !== 1'b0) $display("  Expected Reg WE: 0, Got: %b", reg_we_o);
            if (reg_wdata_o !== 64'b0) $display("  Expected Reg WData: 0x0, Got: 0x%h", reg_wdata_o);
            if (pc_out_o !== 64'b0) $display("  Expected PC Out: 0x0, Got: 0x%h", pc_out_o);
            if (instr_out_o !== 32'h00000013) $display("  Expected Instr Out: 0x00000013, Got: 0x%h", instr_out_o);
            if (wb_valid_o !== 1'b0) $display("  Expected WB Valid: 0, Got: %b", wb_valid_o);
        end
        total_tests = total_tests + 1;

        // Release reset and check post-reset behavior
        rst_n = 1;
        #10;
        @(negedge clk);
        check_outputs(1, 5'b0, 1'b0, 64'b0, 64'b0, 32'h00000000, 1'b1);

        // Test 2: LUI Instruction
        $display("Test 2: LUI Instruction");
        @(posedge clk);
        pc_in_i = 64'h1000;
        // LUI x5, 0x12345 (0x12345000)
        instr_in_i = 32'h123452b7; // 0x123452b7 = LUI x5, 0x12345
        alu_result_i = 64'h0;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0000; // reg_write=0, but LUI will override
        @(posedge clk);
        check_outputs(2, 5, 1'b1, 64'h12345000, 64'h1000, 32'h123452b7, 1'b1);

        // Test 3: AUIPC Instruction
        $display("Test 3: AUIPC Instruction");
        @(posedge clk);
        pc_in_i = 64'h1004;
        // AUIPC x6, 0x6789 (0x6789000 + PC)
        instr_in_i = 32'h06789317; // 0x06789317 = AUIPC x6, 0x6789
        alu_result_i = 64'h0;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0000;
        @(posedge clk);
        check_outputs(3, 6, 1'b1, 64'h678A004, 64'h1004, 32'h06789317, 1'b1);

        // Test 4: JAL Instruction
        $display("Test 4: JAL Instruction");
        @(posedge clk);
        pc_in_i = 64'h1008;
        // JAL x7, 0 (jump to PC)
        instr_in_i = 32'h000003ef; // JAL x7, 0
        alu_result_i = 64'h0;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0000;
        @(posedge clk);
        check_outputs(4, 7, 1'b1, 64'h100C, 64'h1008, 32'h000003ef, 1'b1);

        // Test 5: ALU Instruction (ADD)
        $display("Test 5: ALU Instruction");
        @(posedge clk);
        pc_in_i = 64'h100C;
        // ADD x8, x5, x6
        instr_in_i = 32'h00620433; // 0x00620433 = ADD x8, x5, x6
        alu_result_i = 64'h12345000 + 64'h678A004; // Sum of previous results
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0400; // reg_write=1 (bit 10 set)
        @(posedge clk);
        check_outputs(5, 8, 1'b1, alu_result_i, 64'h100C, 32'h00620433, 1'b1);

        // Test 6: Load Instruction (LW)
        $display("Test 6: Load Instruction");
        @(posedge clk);
        pc_in_i = 64'h0000000000001010;
        // LW x9, 0(x8)
        instr_in_i = 32'h00042483; // 0x00042483 = LW x9, 0(x8)
        alu_result_i = 64'h0;
        mem_result_i = 64'h0000000012345678; // Simulated memory data
        ctrl_in_i = 16'h0410; // reg_write=1, mem_to_reg=1 (bit 10 and 4 set)
        @(posedge clk);
        check_outputs(6, 9, 1'b1, 64'h0000000012345678, 64'h0000000000001010, 32'h00042483, 1'b1);

        // Test 7: Store Instruction (No Register Write)
        $display("Test 7: Store Instruction (No Write)");
        @(posedge clk);
        pc_in_i = 64'h0000000000001014;
        // SW x9, 0(x8)
        instr_in_i = 32'h00942023; // 0x00942023 = SW x9, 0(x8)
        alu_result_i = 64'h0;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0400; // reg_write=1, but store should override
        @(posedge clk);
        check_outputs(7, 0, 1'b0, 64'h0, 64'h0000000000001014, 32'h00942023, 1'b1);

        // Test 8: x0 Register Test (Should Not Be Written)
        $display("Test 8: x0 Register Test");
        @(posedge clk);
        pc_in_i = 64'h0000000000001018;
        // ADD x0, x5, x6 (Should not write to x0)
        instr_in_i = 32'h00620033; // 0x00620033 = ADD x0, x5, x6
        alu_result_i = 64'h1234567890ABCDEF;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0400; // reg_write=1
        @(posedge clk);
        check_outputs(8, 0, 1'b0, 64'h1234567890ABCDEF, 64'h0000000000001018, 32'h00620033, 1'b1);

        // Test 9: Stall Function
        $display("Test 9: Stall Function");
        @(posedge clk);
        pc_in_i = 64'h000000000000101C;
        // ADD x10, x5, x6
        instr_in_i = 32'h00620533; // 0x00620533 = ADD x10, x5, x6
        alu_result_i = 64'hFFFFFFFFFFFFFFFE;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0400; // reg_write=1
        @(posedge clk);
        // Apply stall
        stall_i = 1;
        // Change inputs during stall (should not be processed)
        pc_in_i = 64'h2000;
        instr_in_i = 32'h00000000;
        alu_result_i = 64'h0;
        mem_result_i = 64'h0;
        ctrl_in_i = 16'h0000;
        @(posedge clk);
        @(negedge clk);
        // Check outputs are held during stall (wb_valid should be 0)
        if (wb_valid_o === 1'b0) begin
            test_passed = test_passed + 1;
            $display("Time: %t - Pass: Stall Function (during stall)", $time);
        end else begin
            error_count = error_count + 1;
            $display("Time: %t - Error: Stall Function (during stall)", $time);
            $display("  Expected WB Valid: 0, Got: %b", wb_valid_o);
        end
        total_tests = total_tests + 1;
        // Release stall and wait for next cycle to process new data
        stall_i = 0;
        @(posedge clk);
        @(posedge clk);
        check_outputs(9, 0, 1'b0, 64'h0, 64'h0000000000002000, 32'h00000000, 1'b1);

        // Test Summary
        #100;
        $display("\n========================================");
        $display("Test Summary: riscv64_write_back Unit Test");
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
        $dumpfile("tb_riscv64_write_back.vcd");
        $dumpvars(0, tb_riscv64_write_back);
    end

endmodule