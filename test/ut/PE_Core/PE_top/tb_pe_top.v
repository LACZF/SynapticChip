// tb_pe_top_new.v
// PE Top Test Bench for Refactored Module

`timescale 1ns/1ps

module tb_pe_top;

    // Parameters
    parameter PE_ARRAY_X     = 4;
    parameter PE_ARRAY_Y     = 4;
    parameter DATA_WIDTH     = 32;
    parameter ADDR_WIDTH     = 16;
    parameter HIGH_BW_DW     = 320;
    parameter TIMEOUT_CYCLES = 1000;

    // Error counter
    integer error_count = 0;

    // Clock and Reset
    reg                     clk;
    reg                     rst_n;

    // OBI Bus Interface
    reg                     req_i;
    reg                     we_i;
    reg  [31:0]             addr_i;
    reg  [DATA_WIDTH-1:0]   wdata_i;
    wire                    gnt_o;
    wire                    rvalid_o;
    wire [DATA_WIDTH-1:0]   rdata_o;

    // High Bandwidth Memory Interface
    wire                    mem_req_o;
    wire                    mem_we_o;
    wire [31:0]             mem_addr_o;
    wire [HIGH_BW_DW-1:0]   mem_data_o;
    reg                     mem_ack_i;
    reg  [HIGH_BW_DW-1:0]   mem_data_i;

    // Instantiate DUT
    pe_top #(
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
        .rdata_o(rdata_o)
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
            req_i = 1'b1;
            we_i = 1'b1;
            addr_i = addr;
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
            we_i = 1'b0;
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
                data = {DATA_WIDTH{1'b0}};
            end

            timeout = 0;
            while (!rvalid_o && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: OBI read response timeout for address 0x%h", addr);
                error_count = error_count + 1;
                data = {DATA_WIDTH{1'b0}};
            end else begin
                data = rdata_o;
            end

            @(posedge clk);
            req_i = 1'b0;
        end
    endtask

    // Test Task: Simulate High Bandwidth Memory Response
    task simulate_high_bw_response;
        input [HIGH_BW_DW-1:0] data;
        begin
            mem_ack_i = 1'b1;
            mem_data_i = data;
            @(posedge clk);
            mem_ack_i = 1'b0;
        end
    endtask

    // Test Task: Wait for Computation Completion
    task wait_for_computation;
        integer timeout;
        begin
            timeout = 0;
            // Monitor high bandwidth interface for write back activity
            while (!mem_req_o && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Timeout waiting for computation completion");
                error_count = error_count + 1;
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
        clk         = 0;
        rst_n       = 0;
        req_i       = 0;
        we_i        = 0;
        addr_i      = 0;
        wdata_i     = 0;
        mem_ack_i   = 0;
        mem_data_i  = 0;
        error_count = 0;

        // Reset
        #20 rst_n = 1;

        $display("Starting PE Top Test for Refactored Module");
        $display("=========================================");

        // Test 1: Basic Register Access
        $display("Test 1: Basic Register Access");
        obi_read(STATUS_REG_ADDR, read_value);
        $display("Initial status register: 0x%h", read_value);

        obi_write(CONTROL_REG_ADDR, 32'h00000001);
        obi_read(CONTROL_REG_ADDR, read_value);
        if (read_value !== 32'h00000001) begin
            $display("ERROR: Test 1 - Control register write/read mismatch");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 1 - Register access working");
        end
        #20;

        // Test 2: PE Enable Configuration
        $display("Test 2: PE Enable Configuration");
        obi_write(PE_ENABLE_ADDR, 32'h0000000F); // Enable first 4 PEs
        obi_read(PE_ENABLE_ADDR, read_value);
        if (read_value[PE_ARRAY_X-1:0] !== 4'b1111) begin
            $display("ERROR: Test 2 - PE enable configuration mismatch");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 2 - PE enable configuration successful");
        end
        #20;

        // Test 3: Memory Write/Read Operations
        $display("Test 3: Memory Write/Read Operations");

        // Write operand data for PE0
        obi_write(32'h00000000, 32'h0000000A); // PE0 operand1 = 10
        obi_write(32'h00000010, 32'h00000005); // PE0 operand2 = 5
        obi_write(32'h00000020, 32'h00000001); // PE0 config: ADD operation

        // Read back to verify
        obi_read(32'h00000000, read_value);
        if (read_value !== 32'h0000000A) begin
            $display("ERROR: Test 3 - Memory write/read mismatch for operand1");
            error_count = error_count + 1;
        end

        obi_read(32'h00000010, read_value);
        if (read_value !== 32'h00000005) begin
            $display("ERROR: Test 3 - Memory write/read mismatch for operand2");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 3 - Memory operations successful");
        end
        #20;

        // Test 4: High Bandwidth Write Operation
        $display("Test 4: High Bandwidth Write Operation");
        obi_write(HIGH_BW_WRITE_ADDR, 32'h00010000); // Length=1, Address=0x0000

        // Wait for high bandwidth request
        wait_for_computation();

        if (mem_req_o !== 1'b1 || mem_we_o !== 1'b1) begin
            $display("ERROR: Test 4 - High bandwidth write request not generated");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 4 - High bandwidth write operation successful");
        end

        simulate_high_bw_response({HIGH_BW_DW{1'b0}});
        #20;

        // Test 5: High Bandwidth Read Operation
        $display("Test 5: High Bandwidth Read Operation");
        obi_write(HIGH_BW_READ_ADDR, 32'h00020000); // Length=2, Address=0x0000

        // Wait for high bandwidth request
        wait_for_computation();

        if (mem_req_o !== 1'b1 || mem_we_o !== 1'b0) begin
            $display("ERROR: Test 5 - High bandwidth read request not generated");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 5 - High bandwidth read operation successful");
        end

        simulate_high_bw_response({10{32'h12345678}}); // Simulate read data
        #20;

        // Test 6: PE Computation with Result Write Back
        $display("Test 6: PE Computation with Result Write Back");

        // Configure PE0 for ADD operation
        obi_write(32'h00000020, 32'h00000001); // ADD operation

        // Start computation
        obi_write(CONTROL_REG_ADDR, 32'h00000001);

        // Wait for computation to complete (monitor high bandwidth interface)
        wait_for_computation();

        if (mem_req_o !== 1'b1 || mem_we_o !== 1'b1) begin
            $display("ERROR: Test 6 - PE computation result write back not triggered");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 6 - PE computation and result write back successful");
        end

        simulate_high_bw_response({HIGH_BW_DW{1'b0}});
        #20;

        // Test 7: Multiple PE Operations
        $display("Test 7: Multiple PE Operations");

        // Configure multiple PEs
        obi_write(PE_ENABLE_ADDR, 32'h0000000F); // Enable all 4 PEs

        // Configure PE1
        obi_write(32'h00000001, 32'h00000014); // PE1 operand1 = 20
        obi_write(32'h00000011, 32'h0000000A); // PE1 operand2 = 10
        obi_write(32'h00000021, 32'h00000001); // PE1 config: ADD operation

        // Start computation
        obi_write(CONTROL_REG_ADDR, 32'h00000001);

        // Wait for computation to complete
        wait_for_computation();

        if (mem_req_o !== 1'b1) begin
            $display("ERROR: Test 7 - Multiple PE computation not completed");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 7 - Multiple PE operations successful");
        end

        simulate_high_bw_response({HIGH_BW_DW{1'b0}});
        #20;

        // Test 8: Reset Test
        $display("Test 8: Reset Test");

        // Perform some operations
        obi_write(CONTROL_REG_ADDR, 32'h00000001);
        obi_write(PE_ENABLE_ADDR, 32'h0000000F);

        // Apply reset
        @(posedge clk);
        rst_n = 0;
        #20;
        rst_n = 1;
        #20;

        // Verify registers are reset
        obi_read(CONTROL_REG_ADDR, read_value);
        if (read_value !== 32'h00000000) begin
            $display("ERROR: Test 8 - Control register not reset");
            error_count = error_count + 1;
        end

        obi_read(PE_ENABLE_ADDR, read_value);
        if (read_value[PE_ARRAY_X-1:0] !== {PE_ARRAY_X{1'b1}}) begin
            $display("ERROR: Test 8 - PE enable register not properly reset");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 8 - Reset functionality verified");
        end
        #20;

        // Test 9: Error Handling - Invalid Address
        $display("Test 9: Error Handling - Invalid Address");
        obi_write(32'hFFFFFFFF, 32'hDEADBEEF); // Write to invalid address

        // This should not generate any high bandwidth request
        #100;

        if (mem_req_o === 1'b1) begin
            $display("ERROR: Test 9 - Invalid address generated unexpected request");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 9 - Invalid address handled correctly");
        end
        #20;

        // Test 10: Comprehensive System Test
        $display("Test 10: Comprehensive System Test");

        // Configure system for full operation
        obi_write(PE_ENABLE_ADDR, 32'h0000000F); // Enable all PEs

        // Configure memory for each PE
        for (i = 0; i < PE_ARRAY_X * PE_ARRAY_Y; i = i + 1) begin
            obi_write(i * 4, 32'h0000000A + i); // operand1
            obi_write(16 + i * 4, 32'h00000005 + i); // operand2
            obi_write(32 + i * 4, 32'h00000001); // ADD operation
        end

        // Start computation
        obi_write(CONTROL_REG_ADDR, 32'h00000001);

        // Wait for computation completion
        wait_for_computation();

        if (mem_req_o !== 1'b1 || mem_we_o !== 1'b1) begin
            $display("ERROR: Test 10 - Comprehensive system test failed");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 10 - Comprehensive system test successful");
        end

        simulate_high_bw_response({HIGH_BW_DW{1'b0}});
        #20;

        // Final Test Results
        $display("=========================================");
        if (error_count == 0) begin
            $display("TEST PASSED: All %d tests completed successfully", 10);
        end else begin
            $display("TEST FAILED: %d errors detected", error_count);
        end
        $display("=========================================");

        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_pe_top.vcd");
        $dumpvars(0, tb_pe_top);
    end

endmodule