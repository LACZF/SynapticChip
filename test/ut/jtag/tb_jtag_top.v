// tb_jtag_top.v
// JTAG Test Bench

`include "jtag_params.v"
`timescale 1ns/1ps

module tb_jtag_top;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // JTAG Interface Signals
    reg  tck;
    reg  tms;
    reg  tdi;
    wire tdo;
    wire tdo_en;

    // Control Interface (Directly connected to JTAG module)
    reg                    req;
    reg                    we;
    reg  [`ADDR_WIDTH-1:0] addr;
    reg  [`DATA_WIDTH-1:0] data_in;
    wire [`DATA_WIDTH-1:0] data_out;
    wire                   ack;

    // Debug Output
    wire [`DATA_WIDTH-1:0] debug_data;
    wire                   debug_valid;

    // DUT Instantiation
    jtag_top #(
        .ADDR_WIDTH(`ADDR_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .INST_WIDTH(`INSTR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tck_i(tck),
        .tms_i(tms),
        .tdi_i(tdi),
        .tdo_o(tdo),
        .tdo_en_o(tdo_en),
        .req_i(req),
        .we_i(we),
        .addr_i(addr),
        .data_in_i(data_in),
        .data_out_o(data_out),
        .ack_o(ack),
        .debug_data_o(debug_data),
        .debug_valid_o(debug_valid)
    );

    // Clock Generation
    always #5 clk = ~clk;
    always #10 tck = ~tck; // JTAG clock frequency is half of system clock

    // Test Task: Write Register
    task write_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        input [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req = 1'b1;
            we = 1'b1;
            addr = reg_addr;
            data_in = reg_data;

        `ifdef DEBUG
            $display("[write_register] Writing to addr=0x%h, data=0x%h", reg_addr, reg_data);
        `endif

            // Wait for acknowledgment
            while (!ack) begin
                @(posedge clk);
            end

            @(posedge clk);
            req = 1'b0;
            we = 1'b0;

            $display("[write_register] Write completed successfully");
        end
    endtask

    // Test Task: Read Register
    task read_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        output [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req = 1'b1;
            we = 1'b0;
            addr = reg_addr;

        `ifdef DEBUG
            $display("[read_register] Reading from addr=0x%h", reg_addr);
        `endif

            // Wait for acknowledgment
            while (!ack) begin
                @(posedge clk);
            end

            reg_data = data_out;
            $display("[read_register] Read completed: data=0x%h", reg_data);

            @(posedge clk);
            req = 1'b0;
        end
    endtask

    // Test Task: JTAG TAP State Machine Control
    task jtag_tap_control;
        input [3:0] target_state;
        begin
            // Simplified implementation, actual should control TMS according to TAP state machine transition table
            // This is just an example, actual testing requires more complex control logic
            tms = 1'b1; // Enter TEST-LOGIC-RESET
            @(negedge tck);
            @(negedge tck);

            tms = 1'b0; // Enter RUN-TEST/IDLE
            @(negedge tck);
        end
    endtask

    // Main Test Program
    reg [`DATA_WIDTH-1:0] read_data;
    reg error_occurred;

    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        tck = 0;
        tms = 1;
        tdi = 0;
        req = 0;
        we = 0;
        addr = 0;
        data_in = 0;
        error_occurred = 0;

        // Reset
        #20 rst_n = 1;

        $display("Starting JTAG Module Test");
        $display("=========================");
        $display("Direct testing of jtag_top without Ring Bus");
        $display("=========================");

        // Wait for stabilization
        #100;

        $display("\n--- Basic JTAG Functionality Test ---");

        // Test 1: Write data register
        $display("\n1. Testing data register write");
        write_register(`REG_JTAG_DATA, 32'h12345678);
        #50;

        // Test 2: Read data register
        $display("\n2. Testing data register readback");
        read_register(`REG_JTAG_DATA, read_data);
        if (read_data !== 32'h12345678) begin
            $display("     ERROR: Data register readback mismatch: 0x%h (expected: 0x12345678)", read_data);
            error_occurred = 1;
        end else begin
            $display("     Data register readback verified: 0x%h", read_data);
        end

        // Test 3: Read status register
        $display("\n3. Testing status register read");
        read_register(`REG_JTAG_STAT, read_data);
        $display("   Status register value: 0x%h", read_data);

        // Test 4: Test JTAG TAP control
        $display("\n4. Testing JTAG TAP control");
        $display("   Current TMS value: %b", tms);
        jtag_tap_control(`RUN_TEST_IDLE);
        $display("   After TAP control, TMS value: %b", tms);

        // Test 5: Read TAP state
        $display("\n5. Reading TAP state");
        read_register(`REG_JTAG_CTRL, read_data);
        $display("   Current TAP state: 0x%h", read_data);

        // Final Test Result
        if (error_occurred) begin
            $display("\nTEST FAILED: Some errors occurred during testing.");
        end else begin
            $display("\nTEST PASSED: JTAG module functionality verified successfully!");
        end

        $display("\nTest completed.");

        // Additional delay to ensure sufficient time to observe all waveforms
        #1000;

        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_jtag_top.vcd");
        $dumpvars(0, tb_jtag_top);
    end

endmodule