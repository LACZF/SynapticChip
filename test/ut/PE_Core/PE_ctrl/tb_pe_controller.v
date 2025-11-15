// tb_pe_ctrl_new.v
// PE Control Test Bench for Refactored Module

`timescale 1ns/1ps

module tb_pe_ctrl;

    // Parameters
    parameter PE_ARRAY_X = 4;
    parameter PE_ARRAY_Y = 4;
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 16;
    parameter HIGH_BW_DW = 320;
    parameter TIMEOUT_CYCLES = 1000;

    // Error counter
    integer error_count = 0;

    // Clock and Reset
    reg                   clk;
    reg                   rst_n;

    // OBI Bus Interface
    reg                   req_i;
    reg                   we_i;
    reg  [31:0]           addr_i;
    reg  [DATA_WIDTH-1:0] wdata_i;
    wire                  gnt_o;
    wire                  rvalid_o;
    wire [DATA_WIDTH-1:0] rdata_o;

    // PE Control
    wire                  start_computation;
    reg                   computation_done;

    // High Bandwidth Memory Interface
    wire                  high_bw_req_o;
    wire                  high_bw_we_o;
    wire [31:0]           high_bw_addr_o;
    wire [HIGH_BW_DW-1:0] high_bw_data_o;
    reg                   high_bw_ack_i;
    reg  [HIGH_BW_DW-1:0] high_bw_data_i;

    // PE Result Interface
    reg [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_result;
    reg [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 pe_result_valid;

    // PE Operand and Config Outputs
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand1;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand2;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_config;

    // Instantiate DUT
    pe_control #(
        .PE_ARRAY_X(PE_ARRAY_X),
        .PE_ARRAY_Y(PE_ARRAY_Y),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .HIGH_BW_DW(HIGH_BW_DW)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(req_i),
        .we_i(we_i),
        .addr_i(addr_i),
        .wdata_i(wdata_i),
        .gnt_o(gnt_o),
        .rvalid_o(rvalid_o),
        .rdata_o(rdata_o),
        .start_computation(start_computation),
        .computation_done(computation_done),
        .high_bw_req_o(high_bw_req_o),
        .high_bw_we_o(high_bw_we_o),
        .high_bw_addr_o(high_bw_addr_o),
        .high_bw_data_o(high_bw_data_o),
        .high_bw_ack_i(high_bw_ack_i),
        .high_bw_data_i(high_bw_data_i),
        .pe_result(pe_result),
        .pe_result_valid(pe_result_valid),
        .pe_operand1(pe_operand1),
        .pe_operand2(pe_operand2),
        .pe_config(pe_config)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: OBI Bus Write
    task obi_write;
        input [31:0] addr;
        input [DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            @(posedge clk);
            req_i   = 1'b1;
            we_i    = 1'b1;
            addr_i  = addr;
            wdata_i = data;
            timeout = 0;

            while (!gnt_o && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: OBI write timeout for address 0x%h", addr);
                error_count = error_count + 1;
            end

            @(posedge clk);
            req_i = 1'b0;
            we_i  = 1'b0;
        end
    endtask

    // Test Task: OBI Bus Read
    task obi_read;
        input [31:0] addr;
        output [DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            @(posedge clk);
            req_i   = 1'b1;
            we_i    = 1'b0;
            addr_i  = addr;
            timeout = 0;

            while (!gnt_o && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: OBI read grant timeout for address 0x%h", addr);
                error_count = error_count + 1;
                data        = {DATA_WIDTH{1'b0}};
            end

            timeout = 0;
            while (!rvalid_o && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: OBI read response timeout for address 0x%h", addr);
                error_count = error_count + 1;
                data        = {DATA_WIDTH{1'b0}};
            end else begin
                data        = rdata_o;
            end

            @(posedge clk);
            req_i = 1'b0;
        end
    endtask

    // Test Task: Set PE Results
    task set_pe_results;
        input [DATA_WIDTH-1:0] result_value;
        input integer pe_count;
        integer i;
        begin
            for (i = 0; i < pe_count; i = i + 1) begin
                pe_result[i]       = result_value + i;
                pe_result_valid[i] = 1'b1;
            end
            @(posedge clk);
        end
    endtask

    // Test Task: Clear PE Results
    task clear_pe_results;
        integer i;
        begin
            for (i = 0; i < PE_ARRAY_X * PE_ARRAY_Y; i = i + 1) begin
                pe_result_valid[i] = 1'b0;
            end
            @(posedge clk);
        end
    endtask

    // Test Task: Verify Register Value
    task verify_register;
        input [31:0] addr;
        input [DATA_WIDTH-1:0] expected;
        input integer test_num;
        reg [DATA_WIDTH-1:0] read_value;
        begin
            obi_read(addr, read_value);
            if (read_value !== expected) begin
                $display("ERROR: Test %d - Address 0x%h: Expected 0x%h, Got 0x%h",
                         test_num, addr, expected, read_value);
                error_count = error_count + 1;
            end else begin
                $display("PASS: Test %d - Register 0x%h value verified", test_num, addr);
            end
        end
    endtask

    // Address Definitions
    localparam CONTROL_REG_ADDR   = 32'h00000000;
    localparam STATUS_REG_ADDR    = 32'h00000004;
    localparam PE_ENABLE_ADDR     = 32'h00000008;
    localparam HIGH_BW_WRITE_ADDR = 32'h00001000;
    localparam HIGH_BW_READ_ADDR  = 32'h00002000;

    // Main Test Program
    reg [DATA_WIDTH-1:0] read_value;
    integer i;

    initial begin
        // Initialize
        clk              = 0;
        rst_n            = 0;
        req_i            = 0;
        we_i             = 0;
        addr_i           = 0;
        wdata_i          = 0;
        // mem_rdata is no longer used
        computation_done = 0;
        high_bw_ack_i    = 0;
        high_bw_data_i   = 0;

        for (i = 0; i < PE_ARRAY_X * PE_ARRAY_Y; i = i + 1) begin
            pe_result[i]       = 0;
            pe_result_valid[i] = 0;
        end
        error_count = 0;

        // Reset
        #20 rst_n = 1;

        $display("Starting PE Control Test for Refactored Module");
        $display("===========================================");

        // Test 1: Read Status Register
        $display("Test 1: Read Status Register");
        obi_read(STATUS_REG_ADDR, read_value);
        if (read_value[0] !== 1'b0) begin
            $display("ERROR: Test 1 - Status register computation_done bit should be 0");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 1 - Status register read successfully");
        end
        #20;

        // Test 2: Write Control Register
        $display("Test 2: Write Control Register");
        obi_write(CONTROL_REG_ADDR, 32'h00000001); // Set start bit
        verify_register(CONTROL_REG_ADDR, 32'h00000001, 2);
        #20;

        // Test 3: Write PE Enable Register
        $display("Test 3: Write PE Enable Register");
        obi_write(PE_ENABLE_ADDR, 32'h0000000F); // Enable first 4 PEs
        verify_register(PE_ENABLE_ADDR, 32'h0000000F, 3);
        #20;

        // Test 4: Memory Write Operation
        $display("Test 4: Memory Write Operation");
        obi_write(32'h00000010, 32'h12345678); // Write to memory address 0x10
        #20;

        // Test 5: Memory Read Operation
        $display("Test 5: Memory Read Operation");
        // mem_rdata is no longer used
        obi_read(32'h00000010, read_value);
        if (read_value !== 32'h12345678) begin
            $display("ERROR: Test 5 - Memory read mismatch: Expected 0x12345678, Got 0x%h", read_value);
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 5 - Memory read operation successful");
        end
        #20;

        // Test 6: High Bandwidth Write Request
        $display("Test 6: High Bandwidth Write Request");
        obi_write(HIGH_BW_WRITE_ADDR, 32'h00010000); // Length=1, Address=0x0000
        #20;

        // Check if high bandwidth request is generated
        if (high_bw_req_o !== 1'b1 || high_bw_we_o !== 1'b1) begin
            $display("ERROR: Test 6 - High bandwidth write request not generated correctly");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 6 - High bandwidth write request generated");
        end

        // Simulate ACK
        high_bw_ack_i = 1'b1;
        @(posedge clk);
        high_bw_ack_i = 1'b0;
        #20;

        // Test 7: High Bandwidth Read Request
        $display("Test 7: High Bandwidth Read Request");
        obi_write(HIGH_BW_READ_ADDR, 32'h00020000); // Length=2, Address=0x0000
        #20;

        // Check if high bandwidth request is generated
        if (high_bw_req_o !== 1'b1 || high_bw_we_o !== 1'b0) begin
            $display("ERROR: Test 7 - High bandwidth read request not generated correctly");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 7 - High bandwidth read request generated");
        end

        // Simulate ACK and data return
        high_bw_ack_i = 1'b1;
        high_bw_data_i = {10{32'hAABBCCDD}}; // Simulate read data
        @(posedge clk);
        high_bw_ack_i = 1'b0;
        #20;

        // Test 8: PE Result Write Back
        $display("Test 8: PE Result Write Back");
        set_pe_results(32'h00000100, PE_ARRAY_X * PE_ARRAY_Y);
        computation_done = 1'b1;
        #20;

        // Check if high bandwidth write is triggered for result write back
        if (high_bw_req_o !== 1'b1 || high_bw_we_o !== 1'b1) begin
            $display("ERROR: Test 8 - PE result write back not triggered");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 8 - PE result write back triggered");
        end

        high_bw_ack_i = 1'b1;
        @(posedge clk);
        high_bw_ack_i = 1'b0;
        computation_done = 1'b0;
        clear_pe_results();
        #20;

        // Test 9: Reset Test
        $display("Test 9: Reset Test");
        @(posedge clk);
        rst_n = 0;
        #20;
        rst_n = 1;
        #20;

        // Verify registers are reset
        obi_read(CONTROL_REG_ADDR, read_value);
        if (read_value !== 32'h00000000) begin
            $display("ERROR: Test 9 - Control register not reset to 0");
            error_count = error_count + 1;
        end

        obi_read(PE_ENABLE_ADDR, read_value);
        if (read_value[PE_ARRAY_X-1:0] !== {PE_ARRAY_X{1'b1}}) begin
            $display("ERROR: Test 9 - PE enable register not properly reset");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 9 - Registers properly reset");
        end
        #20;

        // Test 10: Multiple PE Enable/Disable
        $display("Test 10: Multiple PE Enable/Disable");
        obi_write(PE_ENABLE_ADDR, 32'h00000005); // Enable PE0 and PE2
        verify_register(PE_ENABLE_ADDR, 32'h00000005, 10);
        #20;

        // Final Test Results
        $display("===========================================");
        if (error_count == 0) begin
            $display("TEST PASSED: All %d tests completed successfully", 10);
        end else begin
            $display("TEST FAILED: %d errors detected", error_count);
        end
        $display("===========================================");

        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_pe_ctrl.vcd");
        $dumpvars(0, tb_pe_ctrl);
    end

endmodule