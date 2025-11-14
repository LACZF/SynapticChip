// tb_router_new.v
// PE Router Test Bench for Refactored Module

`timescale 1ns/1ps

module tb_router;

    // Parameters
    parameter DATA_WIDTH     = 32;
    parameter TIMEOUT_CYCLES = 1000;

    // Error counter
    integer error_count = 0;

    // Clock and Reset
    reg                   clk;
    reg                   rst_n;

    // PE Interface
    reg  [DATA_WIDTH-1:0] pe_result;
    reg                   pe_result_valid;
    reg  [DATA_WIDTH-1:0] pe_config;

    // Memory Interface
    wire [DATA_WIDTH-1:0] pe_output;

    // Neighbor PE Outputs
    wire [DATA_WIDTH-1:0] north_out;
    wire [DATA_WIDTH-1:0] south_out;
    wire [DATA_WIDTH-1:0] east_out;
    wire [DATA_WIDTH-1:0] west_out;
    wire                  north_valid_out;
    wire                  south_valid_out;
    wire                  east_valid_out;
    wire                  west_valid_out;

    // Instantiate DUT
    pe_router #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pe_result(pe_result),
        .pe_result_valid(pe_result_valid),
        .pe_config(pe_config),
        .pe_output(pe_output),
        .north_out(north_out),
        .south_out(south_out),
        .east_out(east_out),
        .west_out(west_out),
        .north_valid_out(north_valid_out),
        .south_valid_out(south_valid_out),
        .east_valid_out(east_valid_out),
        .west_valid_out(west_valid_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: Configure Router
    task configure_router;
        input [1:0] output_dest;
        input store_to_mem;
        begin
            pe_config = {25'b0, store_to_mem, 1'b0, output_dest, 26'b0};
            @(posedge clk);
        end
    endtask

    // Test Task: Send PE Result
    task send_pe_result;
        input [DATA_WIDTH-1:0] result;
        begin
            pe_result = result;
            pe_result_valid = 1'b1;
            @(posedge clk);
            pe_result_valid = 1'b0;
            @(posedge clk);
        end
    endtask

    // Test Task: Verify Output
    task verify_output;
        input [DATA_WIDTH-1:0] expected_data;
        input expected_north;
        input expected_south;
        input expected_east;
        input expected_west;
        input expected_mem;
        input integer test_num;
        begin
            // Check memory output
            if (expected_mem && pe_output !== expected_data) begin
                $display("ERROR: Test %d - Memory output mismatch: Expected 0x%h, Got 0x%h",
                         test_num, expected_data, pe_output);
                error_count = error_count + 1;
            end else if (!expected_mem && pe_output !== 0) begin
                $display("ERROR: Test %d - Memory output should be 0, Got 0x%h",
                         test_num, pe_output);
                error_count = error_count + 1;
            end

            // Check north output
            if (expected_north && (north_out !== expected_data || !north_valid_out)) begin
                $display("ERROR: Test %d - North output mismatch or invalid", test_num);
                error_count = error_count + 1;
            end else if (!expected_north && (north_out !== 0 || north_valid_out)) begin
                $display("ERROR: Test %d - North output should be inactive", test_num);
                error_count = error_count + 1;
            end

            // Check south output
            if (expected_south && (south_out !== expected_data || !south_valid_out)) begin
                $display("ERROR: Test %d - South output mismatch or invalid", test_num);
                error_count = error_count + 1;
            end else if (!expected_south && (south_out !== 0 || south_valid_out)) begin
                $display("ERROR: Test %d - South output should be inactive", test_num);
                error_count = error_count + 1;
            end

            // Check east output
            if (expected_east && (east_out !== expected_data || !east_valid_out)) begin
                $display("ERROR: Test %d - East output mismatch or invalid", test_num);
                error_count = error_count + 1;
            end else if (!expected_east && (east_out !== 0 || east_valid_out)) begin
                $display("ERROR: Test %d - East output should be inactive", test_num);
                error_count = error_count + 1;
            end

            // Check west output
            if (expected_west && (west_out !== expected_data || !west_valid_out)) begin
                $display("ERROR: Test %d - West output mismatch or invalid", test_num);
                error_count = error_count + 1;
            end else if (!expected_west && (west_out !== 0 || west_valid_out)) begin
                $display("ERROR: Test %d - West output should be inactive", test_num);
                error_count = error_count + 1;
            end

            if (error_count == 0) begin
                $display("PASS: Test %d - Router outputs verified correctly", test_num);
            end
        end
    endtask

    // Main Test Program
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        pe_result = 0;
        pe_result_valid = 0;
        pe_config = 0;
        error_count = 0;

        // Reset
        #20 rst_n = 1;

        $display("Starting PE Router Test for Refactored Module");
        $display("==========================================");

        // Test 1: Route to North with Memory Store
        $display("Test 1: Route to North with Memory Store");
        configure_router(2'b00, 1'b1); // North + Store to memory
        send_pe_result(32'h12345678);
        verify_output(32'h12345678, 1, 0, 0, 0, 1, 1);
        #20;

        // Test 2: Route to South without Memory Store
        $display("Test 2: Route to South without Memory Store");
        configure_router(2'b01, 1'b0); // South, no memory store
        send_pe_result(32'hAABBCCDD);
        verify_output(32'h00000000, 0, 1, 0, 0, 0, 2);
        #20;

        // Test 3: Route to East with Memory Store
        $display("Test 3: Route to East with Memory Store");
        configure_router(2'b10, 1'b1); // East + Store to memory
        send_pe_result(32'h11223344);
        verify_output(32'h11223344, 0, 0, 1, 0, 1, 3);
        #20;

        // Test 4: Route to West without Memory Store
        $display("Test 4: Route to West without Memory Store");
        configure_router(2'b11, 1'b0); // West, no memory store
        send_pe_result(32'h55667788);
        verify_output(32'h00000000, 0, 0, 0, 1, 0, 4);
        #20;

        // Test 5: No Routing (Invalid Configuration)
        $display("Test 5: No Routing (Invalid Configuration)");
        configure_router(2'b00, 1'b0); // North, no memory store
        send_pe_result(32'h99AABBCC);
        verify_output(32'h00000000, 1, 0, 0, 0, 0, 5);
        #20;

        // Test 6: Multiple Consecutive Transmissions
        $display("Test 6: Multiple Consecutive Transmissions");
        configure_router(2'b10, 1'b1); // East + Store to memory

        // First transmission
        send_pe_result(32'h11111111);
        verify_output(32'h11111111, 0, 0, 1, 0, 1, 6);

        // Second transmission
        send_pe_result(32'h22222222);
        verify_output(32'h22222222, 0, 0, 1, 0, 1, 6);

        // Third transmission
        send_pe_result(32'h33333333);
        verify_output(32'h33333333, 0, 0, 1, 0, 1, 6);
        #20;

        // Test 7: Configuration Change During Operation
        $display("Test 7: Configuration Change During Operation");

        // Start with North routing
        configure_router(2'b00, 1'b1);
        send_pe_result(32'h44444444);
        verify_output(32'h44444444, 1, 0, 0, 0, 1, 7);

        // Change to South routing
        configure_router(2'b01, 1'b0);
        send_pe_result(32'h55555555);
        verify_output(32'h00000000, 0, 1, 0, 0, 0, 7);
        #20;

        // Test 8: Invalid PE Result (No Valid Signal)
        $display("Test 8: Invalid PE Result (No Valid Signal)");
        configure_router(2'b00, 1'b1);

        // Send data without valid signal
        pe_result = 32'h66666666;
        pe_result_valid = 1'b0;
        @(posedge clk);

        // Verify no outputs are active
        verify_output(32'h00000000, 0, 0, 0, 0, 0, 8);
        #20;

        // Test 9: Reset Test
        $display("Test 9: Reset Test");

        // Configure and send data
        configure_router(2'b00, 1'b1);
        send_pe_result(32'h77777777);

        // Apply reset
        @(posedge clk);
        rst_n = 0;
        #20;
        rst_n = 1;
        #20;

        // Verify outputs are reset
        if (north_out !== 0 || south_out !== 0 || east_out !== 0 || west_out !== 0 ||
            north_valid_out !== 0 || south_valid_out !== 0 || east_valid_out !== 0 || west_valid_out !== 0 ||
            pe_output !== 0) begin
            $display("ERROR: Test 9 - Outputs not properly reset");
            error_count = error_count + 1;
        end else begin
            $display("PASS: Test 9 - Router properly reset");
        end
        #20;

        // Test 10: Edge Case - Maximum Data Value
        $display("Test 10: Edge Case - Maximum Data Value");
        configure_router(2'b11, 1'b1); // West + Store to memory
        send_pe_result(32'hFFFFFFFF);
        verify_output(32'hFFFFFFFF, 0, 0, 0, 1, 1, 10);
        #20;

        // Final Test Results
        $display("==========================================");
        if (error_count == 0) begin
            $display("TEST PASSED: All %d tests completed successfully", 10);
        end else begin
            $display("TEST FAILED: %d errors detected", error_count);
        end
        $display("==========================================");

        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_router.vcd");
        $dumpvars(0, tb_router);
    end

endmodule