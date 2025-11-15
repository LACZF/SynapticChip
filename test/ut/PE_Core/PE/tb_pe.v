// tb_pe_new.v
// PE Test Bench for Refactored PE Module

`timescale 1ns/1ps

module tb_pe;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter TIMEOUT_CYCLES = 1000;

    // Error counter
    integer error_count = 0;

    // Clock and Reset
    reg                   clk;
    reg                   rst_n;
    reg                   enable;
    reg                   start;

    // Operands and Configuration
    reg  [DATA_WIDTH-1:0] operand1;
    reg  [DATA_WIDTH-1:0] operand2;
    reg  [DATA_WIDTH-1:0] config_data;

    // Inter-PE Inputs
    reg  [DATA_WIDTH-1:0] north_in;
    reg  [DATA_WIDTH-1:0] south_in;
    reg  [DATA_WIDTH-1:0] east_in;
    reg  [DATA_WIDTH-1:0] west_in;
    reg                   north_valid_in;
    reg                   south_valid_in;
    reg                   east_valid_in;
    reg                   west_valid_in;

    // Outputs
    wire [DATA_WIDTH-1:0] result;
    wire                  result_valid;

    // Instantiate DUT
    pe #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .start(start),
        .operand1(operand1),
        .operand2(operand2),
        .config_data(config_data),
        .north_in(north_in),
        .south_in(south_in),
        .east_in(east_in),
        .west_in(west_in),
        .north_valid_in(north_valid_in),
        .south_valid_in(south_valid_in),
        .east_valid_in(east_valid_in),
        .west_valid_in(west_valid_in),
        .result(result),
        .result_valid(result_valid)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: Configure PE Operation
    task configure_pe;
        input [7:0] opcode;
        input       use_external_operands;
        input [2:0] src1_sel;
        input [2:0] src2_sel;
        begin
            config_data = {18'b0, src2_sel, src1_sel, use_external_operands, 1'b0, opcode};
            @(posedge clk);
        end
    endtask

    // Test Task: Set External Operands
    task set_external_operands;
        input [DATA_WIDTH-1:0] op1;
        input [DATA_WIDTH-1:0] op2;
        begin
            operand1 = op1;
            operand2 = op2;
            @(posedge clk);
        end
    endtask

    // Test Task: Set Inter-PE Inputs
    task set_inter_pe_inputs;
        input [DATA_WIDTH-1:0] north;
        input [DATA_WIDTH-1:0] south;
        input [DATA_WIDTH-1:0] east;
        input [DATA_WIDTH-1:0] west;
        input north_valid;
        input south_valid;
        input east_valid;
        input west_valid;
        begin
            north_in       = north;
            south_in       = south;
            east_in        = east;
            west_in        = west;
            north_valid_in = north_valid;
            south_valid_in = south_valid;
            east_valid_in  = east_valid;
            west_valid_in  = west_valid;
            @(posedge clk);
        end
    endtask

    // Test Task: Start Computation
    task start_computation;
        begin
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
        end
    endtask

    // Test Task: Wait for Result
    task wait_for_result;
        integer timeout;
        begin
            timeout = 0;
            while (!result_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Timeout waiting for result");
                error_count = error_count + 1;
            end else begin
                @(posedge clk);
            end
        end
    endtask

    // Test Task: Verify Result
    task verify_result;
        input [DATA_WIDTH-1:0] expected;
        input integer test_num;
        begin
            if (result !== expected) begin
                $display("ERROR: Test %d - Expected 0x%h, Got 0x%h", test_num, expected, result);
                error_count = error_count + 1;
            end else begin
                $display("PASS: Test %d - Result 0x%h matches expected", test_num, result);
            end
        end
    endtask

    // Main Test Program
    initial begin
        // Initialize
        clk            = 0;
        rst_n          = 0;
        enable         = 0;
        start          = 0;
        operand1       = 0;
        operand2       = 0;
        config_data    = 0;
        north_in       = 0;
        south_in       = 0;
        east_in        = 0;
        west_in        = 0;
        north_valid_in = 0;
        south_valid_in = 0;
        east_valid_in  = 0;
        west_valid_in  = 0;
        error_count    = 0;

        // Reset
        #20 rst_n = 1;
        enable = 1;

        $display("Starting PE Test for Refactored Module");
        $display("=====================================");

        // Test 1: Basic Arithmetic with External Operands
        $display("Test 1: Basic Arithmetic with External Operands");
        configure_pe(8'h01, 1'b1, 3'b101, 3'b110); // ADD with external operands (src1=operand1, src2=operand2)
        set_external_operands(32'h00000005, 32'h00000003); // 5 + 3
        start_computation();
        wait_for_result();
        verify_result(32'h00000008, 1); // Expected: 8
        #20;

        // Test 2: Subtraction
        $display("Test 2: Subtraction");
        configure_pe(8'h02, 1'b1, 3'b101, 3'b110); // SUB with external operands
        set_external_operands(32'h0000000A, 32'h00000004); // 10 - 4
        start_computation();
        wait_for_result();
        verify_result(32'h00000006, 2); // Expected: 6
        #20;

        // Test 3: Multiplication
        $display("Test 3: Multiplication");
        configure_pe(8'h06, 1'b1, 3'b101, 3'b110); // MUL with external operands
        set_external_operands(32'h00000006, 32'h00000007); // 6 * 7
        start_computation();
        wait_for_result();
        verify_result(32'h0000002A, 3); // Expected: 42
        #20;

        // Test 4: Bitwise AND
        $display("Test 4: Bitwise AND");
        configure_pe(8'h03, 1'b1, 3'b101, 3'b110); // AND with external operands
        set_external_operands(32'hF0F0F0F0, 32'h0F0F0F0F);
        start_computation();
        wait_for_result();
        verify_result(32'h00000000, 4); // Expected: 0
        #20;

        // Test 5: Bitwise OR
        $display("Test 5: Bitwise OR");
        configure_pe(8'h04, 1'b1, 3'b101, 3'b110); // OR with external operands
        set_external_operands(32'hF0F0F0F0, 32'h0F0F0F0F);
        start_computation();
        wait_for_result();
        verify_result(32'hFFFFFFFF, 5); // Expected: 0xFFFFFFFF
        #20;

        // Test 6: Inter-PE Communication (North Input)
        $display("Test 6: Inter-PE Communication (North Input)");
        configure_pe(8'h01, 1'b0, 3'b100, 3'b101); // ADD with North input and operand1
        set_inter_pe_inputs(32'h0000000A, 32'h00000000, 32'h00000000, 32'h00000000, 1'b1, 1'b0, 1'b0, 1'b0);
        set_external_operands(32'h00000005, 32'h00000000); // Use North input (10) + operand1 (5)
        start_computation();
        wait_for_result();
        verify_result(32'h0000000F, 6); // Expected: 15
        #20;

        // Test 7: Shift Left
        $display("Test 7: Shift Left");
        configure_pe(8'h09, 1'b1, 3'b101, 3'b110); // SHL with external operands
        set_external_operands(32'h00000001, 32'h00000004); // 1 << 4
        start_computation();
        wait_for_result();
        verify_result(32'h00000010, 7); // Expected: 16
        #20;

        // Test 8: Shift Right
        $display("Test 8: Shift Right");
        configure_pe(8'h0A, 1'b1, 3'b101, 3'b110); // SHR with external operands
        set_external_operands(32'h00000010, 32'h00000002); // 16 >> 2
        start_computation();
        wait_for_result();
        verify_result(32'h00000004, 8); // Expected: 4
        #20;

        // Test 9: Minimum
        $display("Test 9: Minimum");
        configure_pe(8'h07, 1'b1, 3'b101, 3'b110); // MIN with external operands
        set_external_operands(32'h0000000A, 32'h00000005); // min(10, 5)
        start_computation();
        wait_for_result();
        verify_result(32'h00000005, 9); // Expected: 5
        #20;

        // Test 10: Maximum
        $display("Test 10: Maximum");
        configure_pe(8'h08, 1'b1, 3'b101, 3'b110); // MAX with external operands
        set_external_operands(32'h0000000A, 32'h00000005); // max(10, 5)
        start_computation();
        wait_for_result();
        verify_result(32'h0000000A, 10); // Expected: 10
        #20;

        // Test 11: Reset Test
        $display("Test 11: Reset Test");
        @(posedge clk);
        rst_n = 0;
        #20;
        rst_n = 1;
        enable = 1;
        #20;

        // Verify that PE is properly reset
        if (result_valid !== 1'b0) begin
            $display("ERROR: Test 11 - result_valid should be 0 after reset");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 11 - PE properly reset");
        end
        #20;

        // Final Test Results
        $display("=====================================");
        if (error_count == 0) begin
            $display("TEST PASSED: All %d tests completed successfully", 11);
        end else begin
            $display("TEST FAILED: %d errors detected", error_count);
        end
        $display("=====================================");

        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_pe.vcd");
        $dumpvars(0, tb_pe);
    end

endmodule