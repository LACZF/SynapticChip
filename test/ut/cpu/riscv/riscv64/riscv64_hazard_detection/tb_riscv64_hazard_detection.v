`timescale 1ns/1ps

// RISC-V 64-bit Hazard Detection Unit Test Bench
module tb_riscv64_hazard_detection;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;

    // Input Signals
    reg [4:0]   rs1_id_i;
    reg [4:0]   rs2_id_i;
    reg [4:0]   rd_ex_i;
    reg [4:0]   rd_mem_i;
    reg [4:0]   rd_wb_i;
    reg         reg_we_ex_i;
    reg         reg_we_mem_i;
    reg         reg_we_wb_i;
    reg         mem_read_ex_i;
    reg         branch_taken_i;

    // Output Signals
    wire        data_hazard_o;
    wire        control_hazard_o;
    wire        stall_if_o;
    wire        stall_id_o;
    wire        stall_ex_o;
    wire        stall_mem_o;
    wire        stall_wb_o;
    wire        flush_if_o;
    wire        flush_id_o;
    wire        flush_ex_o;
    wire        flush_mem_o;

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate Device Under Test (DUT)
    riscv64_hazard_detection u_riscv64_hazard_detection (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_id_i(rs1_id_i),
        .rs2_id_i(rs2_id_i),
        .rd_ex_i(rd_ex_i),
        .rd_mem_i(rd_mem_i),
        .rd_wb_i(rd_wb_i),
        .reg_we_ex_i(reg_we_ex_i),
        .reg_we_mem_i(reg_we_mem_i),
        .reg_we_wb_i(reg_we_wb_i),
        .mem_read_ex_i(mem_read_ex_i),
        .branch_taken_i(branch_taken_i),
        .data_hazard_o(data_hazard_o),
        .control_hazard_o(control_hazard_o),
        .stall_if_o(stall_if_o),
        .stall_id_o(stall_id_o),
        .stall_ex_o(stall_ex_o),
        .stall_mem_o(stall_mem_o),
        .stall_wb_o(stall_wb_o),
        .flush_if_o(flush_if_o),
        .flush_id_o(flush_id_o),
        .flush_ex_o(flush_ex_o),
        .flush_mem_o(flush_mem_o)
    );

    // Test Variables
    integer test_passed;
    integer total_tests;
    integer error_count;

    // Reset Task
    task reset_dut;
        begin
            rst_n = 0;
            #20;
            rst_n = 1;
            #10;
        end
    endtask

    // Initialize Task
    task initialize_signals;
        begin
            rs1_id_i     = 0;
            rs2_id_i     = 0;
            rd_ex_i      = 0;
            rd_mem_i     = 0;
            rd_wb_i      = 0;
            reg_we_ex_i  = 0;
            reg_we_mem_i = 0;
            reg_we_wb_i  = 0;
            mem_read_ex_i = 0;
            branch_taken_i = 0;
        end
    endtask

    // Verify Task
    task verify_output;
        input integer test_num;
        input [255:0] test_desc;
        input expected_data_hazard;
        input expected_control_hazard;
        input expected_stall_if;
        input expected_stall_id;
        input expected_flush_if;
        input expected_flush_id;
        input expected_flush_ex;
        begin
            total_tests = total_tests + 1;

            if (data_hazard_o === expected_data_hazard &&
                control_hazard_o === expected_control_hazard &&
                stall_if_o === expected_stall_if &&
                stall_id_o === expected_stall_id &&
                flush_if_o === expected_flush_if &&
                flush_id_o === expected_flush_id &&
                flush_ex_o === expected_flush_ex) begin
                $display("[%0d] Test %d: %s - PASS", $time, test_num, test_desc);
                test_passed = test_passed + 1;
            end else begin
                $display("[%0d] Test %d: %s - FAIL", $time, test_num, test_desc);
                $display("  Expected: data_hazard=%b, control_hazard=%b, stall_if=%b, stall_id=%b, flush_if=%b, flush_id=%b, flush_ex=%b",
                         expected_data_hazard, expected_control_hazard, expected_stall_if, expected_stall_id, expected_flush_if, expected_flush_id, expected_flush_ex);
                $display("  Actual:   data_hazard=%b, control_hazard=%b, stall_if=%b, stall_id=%b, flush_if=%b, flush_id=%b, flush_ex=%b",
                         data_hazard_o, control_hazard_o, stall_if_o, stall_id_o, flush_if_o, flush_id_o, flush_ex_o);
                error_count = error_count + 1;
            end
        end
    endtask

    // Test Task: Data Hazard - EX stage write, ID stage read (rs1)
    task test_data_hazard_ex_rs1;
        begin
            @(posedge clk);
            rs1_id_i    = 5'b00001; // Read from x1
            rd_ex_i     = 5'b00001; // Write to x1 in EX stage
            reg_we_ex_i = 1'b1;     // Enable write
            #1;
            verify_output(1, "Data Hazard - EX stage write, ID stage read (rs1)", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            @(posedge clk);
        end
    endtask

    // Test Task: Data Hazard - EX stage write, ID stage read (rs2)
    task test_data_hazard_ex_rs2;
        begin
            @(posedge clk);
            rs2_id_i    = 5'b00010; // Read from x2
            rd_ex_i     = 5'b00010; // Write to x2 in EX stage
            reg_we_ex_i = 1'b1;     // Enable write
            #1;
            verify_output(2, "Data Hazard - EX stage write, ID stage read (rs2)", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            @(posedge clk);
        end
    endtask

    // Test Task: Data Hazard - MEM stage write, ID stage read (rs1)
    task test_data_hazard_mem_rs1;
        begin
            @(posedge clk);
            initialize_signals;
            rs1_id_i     = 5'b00011; // Read from x3
            rd_mem_i     = 5'b00011; // Write to x3 in MEM stage
            reg_we_mem_i = 1'b1;     // Enable write
            #1;
            verify_output(3, "Data Hazard - MEM stage write, ID stage read (rs1)", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            @(posedge clk);
        end
    endtask

    // Test Task: Data Hazard - MEM stage write, ID stage read (rs2)
    task test_data_hazard_mem_rs2;
        begin
            @(posedge clk);
            rs2_id_i     = 5'b00100; // Read from x4
            rd_mem_i     = 5'b00100; // Write to x4 in MEM stage
            reg_we_mem_i = 1'b1;     // Enable write
            #1;
            verify_output(4, "Data Hazard - MEM stage write, ID stage read (rs2)", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            @(posedge clk);
        end
    endtask

    // Test Task: Load-use Hazard
    task test_load_use_hazard;
        begin
            @(posedge clk);
            initialize_signals;
            rs1_id_i     = 5'b00101; // Read from x5
            rd_ex_i      = 5'b00101; // Write to x5 in EX stage
            reg_we_ex_i  = 1'b1;     // Enable write
            mem_read_ex_i = 1'b1;    // Load instruction in EX stage
            #1;
            verify_output(5, "Load-use Hazard", 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);
            @(posedge clk);
        end
    endtask

    // Test Task: Control Hazard (Branch Taken)
    task test_control_hazard;
        begin
            @(posedge clk);
            initialize_signals;
            branch_taken_i = 1'b1;   // Branch taken
            #1;
            verify_output(6, "Control Hazard (Branch Taken)", 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
            @(posedge clk);
        end
    endtask

    // Test Task: Multiple Hazards
    task test_multiple_hazards;
        begin
            @(posedge clk);
            initialize_signals;
            rs1_id_i     = 5'b00110; // Read from x6
            rd_ex_i      = 5'b00110; // Write to x6 in EX stage
            reg_we_ex_i  = 1'b1;     // Enable write
            mem_read_ex_i = 1'b1;    // Load instruction in EX stage
            branch_taken_i = 1'b1;   // Branch taken
            #1;
            verify_output(7, "Multiple Hazards (Data and Control)", 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1);
            @(posedge clk);
        end
    endtask

    // Test Task: No Hazard
    task test_no_hazard;
        begin
            @(posedge clk);
            initialize_signals;
            rs1_id_i = 5'b00111;     // Read from x7
            rs2_id_i = 5'b01000;     // Read from x8
            rd_ex_i  = 5'b01001;     // Write to x9 in EX stage
            rd_mem_i = 5'b01010;     // Write to x10 in MEM stage
            #1;
            verify_output(8, "No Hazard Condition", 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
            @(posedge clk);
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        initialize_signals;
        test_passed = 0;
        total_tests = 0;
        error_count = 0;

        $display("=== riscv64_hazard_detection Testbench ===");
        $display("Testing hazard detection and handling functionality");

        // Perform reset
        $display("[%0d] Performing reset", $time);
        reset_dut;

        // Run tests
        $display("[%0d] Starting tests", $time);
        test_data_hazard_ex_rs1;
        test_data_hazard_ex_rs2;
        test_data_hazard_mem_rs1;
        test_data_hazard_mem_rs2;
        test_load_use_hazard;
        test_control_hazard;
        test_multiple_hazards;
        test_no_hazard;

        // Test summary
        #100;
        $display("========================================");
        $display("Test Summary");
        $display("Total tests: %0d", total_tests);
        $display("Passed tests: %0d", test_passed);
        $display("Failed tests: %0d", error_count);
        $display("Test result: %s", (error_count == 0) ? "PASSED" : "FAILED");
        $display("========================================");

        // End simulation
        #100;
        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_riscv64_hazard_detection.vcd");
        $dumpvars(0, tb_riscv64_hazard_detection);
    end

endmodule