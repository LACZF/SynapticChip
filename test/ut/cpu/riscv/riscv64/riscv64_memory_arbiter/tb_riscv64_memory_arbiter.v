// tb_riscv64_memory_arbiter.v
// Memory arbiter testbench, removed references to pending_req signal
`timescale 1ns/1ps

module tb_riscv64_memory_arbiter;

    // Parameter definitions
    localparam ADDR_WIDTH = 64;
    localparam DATA_WIDTH = 64;
    localparam NUM_MASTERS = 2;

    // Test signals
    reg                              clk;
    reg                              rst_n;
    reg [NUM_MASTERS-1:0]            master_req;
    reg [NUM_MASTERS*ADDR_WIDTH-1:0] master_addr;
    reg [NUM_MASTERS*DATA_WIDTH-1:0] master_wdata;
    reg [NUM_MASTERS-1:0]            master_we;
    reg [NUM_MASTERS*8-1:0]          master_byte_en;
    wire [NUM_MASTERS-1:0]           master_grant;
    wire [ADDR_WIDTH-1:0]            mem_addr;
    wire [DATA_WIDTH-1:0]            mem_wdata;
    wire                             mem_we;
    wire [7:0]                       mem_byte_en;
    wire                             mem_req;
    wire [DATA_WIDTH-1:0]            mem_rdata;
    wire                             mem_ready;

    // Internal signals
    reg [DATA_WIDTH-1:0] mem_rdata_reg;
    reg                  mem_ready_reg;
    integer              test_num;
    integer              passed_tests;
    integer              failed_tests;

    // DUT instantiation
    riscv64_memory_arbiter #(
        .NUM_MASTERS(NUM_MASTERS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .master_req_i(master_req),
        .master_addr_i(master_addr),
        .master_wdata_i(master_wdata),
        .master_we_i(master_we),
        .master_byte_en_i(master_byte_en),
        .master_grant_o(master_grant),
        .mem_addr_o(mem_addr),
        .mem_wdata_o(mem_wdata),
        .mem_rdata_i(mem_rdata_reg),
        .mem_we_o(mem_we),
        .mem_byte_en_o(mem_byte_en),
        .mem_req_o(mem_req),
        .mem_ready_i(mem_ready_reg)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Memory response simulation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready_reg <= 0;
            mem_rdata_reg <= 0;
        end else begin
            // Simple memory response simulation: Acknowledge request in the next clock cycle
            if (mem_req) begin
                mem_ready_reg <= 1;
                if (!mem_we) begin
                    mem_rdata_reg <= 64'hDEADBEEFDEADBEEF; // Simulate read data
                end
            end else begin
                mem_ready_reg <= 0;
            end
        end
    end

    // Helper task: Print status information
    task print_state;
        input [31:0] cycle;
        begin
            $display("[%0d] Status: state=0x%x grant_reg=0x%x",
                     cycle, dut.state, dut.grant_reg);
            $display("  - Master requests: master0_req=%b master1_req=%b",
                     master_req[0], master_req[1]);
            $display("  - Grant signals: master0_grant=%b master1_grant=%b",
                     master_grant[0], master_grant[1]);
        end
    endtask

    // Helper task: Set master request
    task set_master_request;
        input integer master_id;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input we;
        input [7:0] byte_en;
        begin
            if (master_id == 0) begin
                master_req[0] <= 1;
                master_addr[0*ADDR_WIDTH +: ADDR_WIDTH] <= addr;
                master_wdata[0*DATA_WIDTH +: DATA_WIDTH] <= data;
                master_we[0] <= we;
                master_byte_en[0*8 +: 8] <= byte_en;
            end else if (master_id == 1) begin
                master_req[1] <= 1;
                master_addr[1*ADDR_WIDTH +: ADDR_WIDTH] <= addr;
                master_wdata[1*DATA_WIDTH +: DATA_WIDTH] <= data;
                master_we[1] <= we;
                master_byte_en[1*8 +: 8] <= byte_en;
            end
        end
    endtask

    // Helper task: Clear all master requests
    task clear_all_requests;
        begin
            master_req <= 0;
            master_addr <= 0;
            master_wdata <= 0;
            master_we <= 0;
            master_byte_en <= 0;
        end
    endtask

    // Helper task: Perform reset operation
    task reset_dut;
        begin
            $display("[%0d] Performing reset", $time);
            rst_n <= 0;
            clear_all_requests;
            #10;
            rst_n <= 1;
            #20;
        end
    endtask

    // Test 1: Single master request - Master 0
    task test_single_master_0;
        begin
            test_num = test_num + 1;
            $display("[%0d] Test %d: Single master request - Master 0", $time, test_num);

            // Set Master 0 request
            set_master_request(0, 64'h1000, 64'h1111111111111111, 1, 8'hff);
            #100;

            // Check test result
            if (mem_req && master_grant[0] && (dut.state == 3'b010)) begin
                $display("[%0d]  PASS: Memory request issued and signals are correct", $time);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[%0d]  FAIL: Memory request signals are incorrect or not issued", $time);
                failed_tests = failed_tests + 1;
            end

            // Clear requests
            clear_all_requests;
            #100;
        end
    endtask

    // Test 2: Single master request - Master 1
    task test_single_master_1;
        begin
            test_num = test_num + 1;
            $display("[%0d] Test %d: Single master request - Master 1", $time, test_num);

            // Set Master 1 request
            set_master_request(1, 64'h2000, 64'h2222222222222222, 1, 8'hff);
            #100;

            // Check test result
            if (mem_req && master_grant[1] && (dut.state == 3'b010)) begin
                $display("[%0d]  PASS: Memory request issued and signals are correct", $time);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[%0d]  FAIL: Memory request signals are incorrect or not issued", $time);
                failed_tests = failed_tests + 1;
            end

            // Clear requests
            clear_all_requests;
            #100;
        end
    endtask

    // Test 3: Priority test - Two masters requesting simultaneously
    task test_priority;
        begin
            test_num = test_num + 1;
            $display("[%0d] Test %d: Priority test - Two masters requesting simultaneously", $time, test_num);

            // Set requests for both masters simultaneously
            set_master_request(0, 64'h1000, 64'h1111111111111111, 1, 8'hff);
            set_master_request(1, 64'h2000, 64'h2222222222222222, 1, 8'hff);
            #100;

            // Check priority behavior
            if (master_grant[0]) begin
                $display("[%0d]  PASS: Master 0 got grant", $time);
                passed_tests = passed_tests + 1;
            end else if (master_grant[1]) begin
                $display("[%0d]  PASS: Master 1 got grant", $time);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[%0d]  FAIL: No master got grant", $time);
                failed_tests = failed_tests + 1;
            end

            // Clear requests
            clear_all_requests;
            #100;
        end
    endtask

    // Test 4: Reset function
    task test_reset;
        begin
            test_num = test_num + 1;
            $display("[%0d] Test %d: Reset function", $time, test_num);

            // Set some requests first
            set_master_request(0, 64'h1000, 64'h1111111111111111, 1, 8'hff);
            #50;

            // Perform reset
            reset_dut;

            // Check reset function
            if (!(|master_grant) && !mem_req) begin
                $display("[%0d]  PASS: Reset function is normal - All signals cleared", $time);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[%0d]  FAIL: Reset function is abnormal - Signals not cleared", $time);
                failed_tests = failed_tests + 1;
            end
        end
    endtask

    // Main test program
    initial begin
        // Initialize variables
        clk = 0;
        rst_n = 1;
        clear_all_requests;
        test_num = 0;
        passed_tests = 0;
        failed_tests = 0;

        // Create VCD file for waveform viewing
        $dumpfile("tb_riscv64_memory_arbiter.vcd");
        $dumpvars(0, tb_riscv64_memory_arbiter);

        $display("=== riscv64_memory_arbiter Testbench ===");
        $display("Testing basic functions and priority behavior");

        // Perform initial reset
        reset_dut;

        // Print status after reset
        $display("[%0d] Status after reset:", $time);
        print_state($time);

        // Run tests
        test_single_master_0;
        test_single_master_1;
        test_priority;
        test_reset;

        // Test summary
        $display("========================================");
        $display("Test Summary");
        $display("Total tests: %0d", test_num);
        $display("Passed tests: %0d", passed_tests);
        $display("Failed tests: %0d", failed_tests);
        $display("Test result: %s", (failed_tests == 0) ? "PASSED" : "FAILED");
        $display("========================================");

        // End simulation
        #100;
        $finish;
    end

endmodule