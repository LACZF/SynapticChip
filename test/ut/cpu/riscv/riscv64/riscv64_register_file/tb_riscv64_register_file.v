`timescale 1ns/1ps

// RISC-V 64-bit Register File Unit Test Bench
module tb_riscv64_register_file;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;

    // Input Signals
    reg  [4:0]  rs1;
    reg  [4:0]  rs2;
    reg  [4:0]  rd;
    reg         we;
    reg  [63:0] wdata;

    // Output Signals
    wire [63:0] rs1_data;
    wire [63:0] rs2_data;

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate Device Under Test (DUT)
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

    // Test Variables
    integer test_passed;
    integer total_tests;
    integer error_count;

    // Test Task: Write Register
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

    // Test Task: Read Register
    task read_register(input [4:0] reg_addr, output [63:0] data);
        begin
            @(posedge clk);
            rs1 = reg_addr;
            @(negedge clk);
            data = rs1_data;
        end
    endtask

    // Test Task: Verify Register Value
    task verify_register(input [4:0] reg_addr, input [63:0] expected_value);
        reg [63:0] actual_value;
        begin
            read_register(reg_addr, actual_value);
            total_tests = total_tests + 1;
            if (actual_value === expected_value) begin
                test_passed = test_passed + 1;
            `ifdef DEBUG
                $display("Time: %t - Pass: Register x%0d value is 0x%h (as expected)", $time, reg_addr, actual_value);
            `endif
            end else begin
                error_count = error_count + 1;
            `ifdef DEBUG
                $display("Time: %t - Error: Register x%0d expected 0x%h, got 0x%h", $time, reg_addr, expected_value, actual_value);
            `endif
            end
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        rst_n = 1;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        we = 0;
        wdata = 0;
        test_passed = 0;
        total_tests = 0;
        error_count = 0;

        // Perform Reset
        $display("start test: riscv64_register_file ut");
        $display("Test 1: Perform Reset Operation");
        rst_n = 0;
        #20 rst_n = 1;
        #10;

        // Test 2: Verify x0 Register Always Zero
        $display("Test 2: Verify x0 Register Always Zero");
        write_register(0, 64'h1234567890ABCDEF);  // Attempt to write to x0 register
        verify_register(0, 64'h0000000000000000);  // Verify x0 remains 0

        // Test 3: Basic Register Read/Write Test
        $display("Test 3: Basic Register Read/Write Test");
        write_register(1, 64'h1111111111111111);
        verify_register(1, 64'h1111111111111111);

        write_register(2, 64'h2222222222222222);
        verify_register(2, 64'h2222222222222222);

        write_register(31, 64'h3131313131313131);
        verify_register(31, 64'h3131313131313131);

        // Test 4: Simultaneous Read/Write of Multiple Registers
        $display("Test 4: Simultaneous Read/Write of Multiple Registers");
        write_register(5, 64'h5555555555555555);
        write_register(6, 64'h6666666666666666);
        verify_register(5, 64'h5555555555555555);
        verify_register(6, 64'h6666666666666666);

        // Test 5: Overwrite Test
        $display("Test 5: Overwrite Test");
        write_register(1, 64'hAAAAAAAAAAAAAAA);
        verify_register(1, 64'h0AAAAAAAAAAAAAAA);

        // Test 6: Data Forwarding Test (Reading Register While Writing)
        $display("Test 6: Data Forwarding Test");
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
            $display("Time: %t - Pass: Data forwarding working correctly", $time);
        end else begin
            error_count = error_count + 2;
            $display("Time: %t - Error: Data forwarding not working correctly, rs1_data=0x%h, rs2_data=0x%h, expected=0x%h",
                     $time, rs1_data, rs2_data, wdata);
        end
        @(posedge clk);
        we = 1'b0;

        // Test 7: Random Value Test
        $display("Test 7: Random Value Test");
        write_register(10, 64'hA1B2C3D4E5F60718);
        verify_register(10, 64'hA1B2C3D4E5F60718);

        write_register(11, 64'h9182736455463728);
        verify_register(11, 64'h9182736455463728);

        // Test 8: Reset Functionality Test
        $display("Test 8: Reset Functionality Test");
        rst_n = 0;
        #20 rst_n = 1;
        #10;

        // Verify All Registers After Reset
        verify_register(1, 64'h0000000000000000);
        verify_register(2, 64'h0000000000000000);
        verify_register(31, 64'h0000000000000000);

        // Test Summary
        #100;
        $display("\n========================================");
        $display("Test Summary: riscv64_register_file Unit Test");
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
        $dumpfile("tb_riscv64_register_file.vcd");
        $dumpvars(0, tb_riscv64_register_file);
    end

`ifdef DEBUG
    // Real-time Monitoring
    always @(posedge clk) begin
        if (we) begin
            $display("Time: %t - Write Operation: Register x%0d, Data=0x%h", $time, rd, wdata);
        end
    end
`endif

endmodule