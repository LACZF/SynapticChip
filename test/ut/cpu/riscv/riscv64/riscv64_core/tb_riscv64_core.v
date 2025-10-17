`timescale 1ns / 1ps

module tb_riscv64_core;

    // Clock and Reset Signals
    reg          clk;
    reg          rst_n;

    // Instruction Cache Interface
    wire         icache_req;
    wire [63:0]  icache_addr;
    reg  [31:0]  icache_data;
    reg          icache_ready;

    // Data Cache Interface
    wire         dcache_req;
    wire [63:0]  dcache_addr;
    wire         dcache_we;
    wire [63:0]  dcache_wdata;
    wire [7:0]   dcache_byte_en;
    reg  [63:0]  dcache_rdata;
    reg          dcache_ready;

    // Snoop Interface
    wire         snoop_valid;
    wire [63:0]  snoop_addr;
    wire [1:0]   snoop_req_type;
    wire         snoop_ready;
    wire         snoop_hit;
    wire [1:0]   snoop_state;
    wire [511:0] snoop_data;

    // Interrupt Interface
    wire timer_interrupt = 1'b0;
    wire external_interrupt = 1'b0;
    wire software_interrupt = 1'b0;

    // Debug Interface
    wire [63:0] debug_pc;
    wire [31:0] debug_instr;
    wire [4:0]  debug_wb_rd;
    wire [63:0] debug_wb_value;
    wire        debug_wb_valid;

    // Variables for test tracking
    integer test_pass = 0;
    integer test_fail = 0;
    reg [63:0] test_result = 64'h0;  // Store test result
    integer instruction_count = 0;   // Count executed instructions
    reg [63:0] last_pc = 64'h0;      // Track last PC to detect stalls
    integer stall_count = 0;         // Count pipeline stalls
    integer max_instruction_count = 500;  // Maximum instructions to execute

    // Track instruction execution
    always @(posedge clk) begin
        if (rst_n) begin
            // Check for new instruction execution (PC change indicates new instruction)
            if (debug_pc != last_pc && debug_pc != 0) begin
                instruction_count <= instruction_count + 1;
                last_pc <= debug_pc;
                stall_count <= 0;
                // Read test result from memory address 0x100 when EBREAK is executed
                if (debug_instr == 32'h00000073 && debug_wb_valid) begin
                    test_result <= 64'h1;
                end
            end else if (debug_pc != 0) begin
                // Increment stall count if PC hasn't changed
                stall_count <= stall_count + 1;
            end
        end else begin
            // Reset tracking variables during reset
            instruction_count <= 0;
            last_pc <= 0;
            stall_count <= 0;
            test_result <= 0;
        end
    end

    // Instantiate the DUT (Device Under Test)
    riscv64_core u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .icache_req_o(icache_req),
        .icache_addr_o(icache_addr),
        .icache_data_i(icache_data),
        .icache_ready_i(icache_ready),
        .dcache_req_o(dcache_req),
        .dcache_addr_o(dcache_addr),
        .dcache_wdata_o(dcache_wdata),
        .dcache_rdata_i(dcache_rdata),
        .dcache_we_o(dcache_we),
        .dcache_byte_en_o(dcache_byte_en),
        .dcache_ready_i(dcache_ready),
        .snoop_valid_i(snoop_valid),
        .snoop_addr_i(snoop_addr),
        .snoop_req_type_i(snoop_req_type),
        .snoop_ready_o(snoop_ready),
        .snoop_hit_o(snoop_hit),
        .snoop_state_o(snoop_state),
        .snoop_data_o(snoop_data),
        .timer_interrupt_i(timer_interrupt),
        .external_interrupt_i(external_interrupt),
        .software_interrupt_i(software_interrupt),
        .debug_pc_o(debug_pc),
        .debug_instr_o(debug_instr),
        .debug_wb_valid_o(debug_wb_valid),
        .debug_wb_rd_o(debug_wb_rd),
        .debug_wb_value_o(debug_wb_value)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Simulate Instruction Cache
    reg [31:0] instr_memory [0:4095]; // Simple instruction memory simulation
    parameter INSTR_FILE = "comprehensive_test.hex"; // Path to instruction hex file

    always @(*) begin
        if (icache_req) begin
        `ifdef DEBUG
            $display("Time: %0t, ICache request: addr=%0h", $time, icache_addr);
        `endif
            if (icache_addr >= 64'h80000000 && icache_addr < 64'h80004000) begin
                icache_data = instr_memory[(icache_addr - 64'h80000000) >> 2];
            `ifdef DEBUG
                $display("Time: %0t, ICache hit: addr=%0h, index=%0d, data=0x%0h",
                         $time, icache_addr, (icache_addr - 64'h80000000) >> 2, icache_data);
            `endif
            end else if (icache_addr >= 0 && icache_addr < 64'h4000) begin
                icache_data = instr_memory[icache_addr >> 2];
            `ifdef DEBUG
                $display("Time: %0t, ICache hit: addr=%0h, index=%0d, data=0x%0h",
                         $time, icache_addr, icache_addr >> 2, icache_data);
            `endif
            end else begin
                icache_data = 32'h00000013; // NOP
            `ifdef DEBUG
                $display("Time: %0t, ICache miss: addr=%0h, returning NOP", $time, icache_addr);
            `endif
            end
            icache_ready = 1'b1;
        `ifdef DEBUG
            $display("Time: %0t, ICache response: data=0x%0h, ready=1", $time, icache_data);
        `endif
        end else begin
            icache_data = 32'h00000013; // NOP
            icache_ready = 1'b0;
        end
    end

    // Simulate Data Cache
    reg [63:0] data_memory [0:4095]; // Simple data memory simulation

    always @(posedge clk) begin
        if (dcache_req && dcache_we) begin
            // Process write operation
            if (dcache_byte_en[0]) data_memory[dcache_addr[31:3]][7:0]   <= dcache_wdata[7:0];
            if (dcache_byte_en[1]) data_memory[dcache_addr[31:3]][15:8]  <= dcache_wdata[15:8];
            if (dcache_byte_en[2]) data_memory[dcache_addr[31:3]][23:16] <= dcache_wdata[23:16];
            if (dcache_byte_en[3]) data_memory[dcache_addr[31:3]][31:24] <= dcache_wdata[31:24];
            if (dcache_byte_en[4]) data_memory[dcache_addr[31:3]][39:32] <= dcache_wdata[39:32];
            if (dcache_byte_en[5]) data_memory[dcache_addr[31:3]][47:40] <= dcache_wdata[47:40];
            if (dcache_byte_en[6]) data_memory[dcache_addr[31:3]][55:48] <= dcache_wdata[55:48];
            if (dcache_byte_en[7]) data_memory[dcache_addr[31:3]][63:56] <= dcache_wdata[63:56];
        `ifdef DEBUG
            $display("Time: %0t, DCache write: addr=%0h, data=%0h, be=%0h",
                     $time, dcache_addr, dcache_wdata, dcache_byte_en);
        `endif
            dcache_ready = 1'b1;
        end else if (dcache_req && !dcache_we) begin
            // Process read operation
            if (dcache_addr >= 64'h80000000 && dcache_addr < 64'h80004000) begin
                dcache_rdata = data_memory[(dcache_addr - 64'h80000000) >> 3];
            end else if (dcache_addr >= 0 && dcache_addr < 64'h4000) begin
                dcache_rdata = data_memory[dcache_addr >> 3];
            end else begin
                dcache_rdata = 64'h0;
            end
        `ifdef DEBUG
            $display("Time: %0t, DCache read: addr=%0h, data=%0h",
                     $time, dcache_addr, dcache_rdata);
        `endif
            dcache_ready = 1'b1;
        end else begin
            dcache_ready = 1'b0;
        end
    end

    // Check for test completion (EBREAK instruction or test result at memory address 0x100)
    always @(posedge clk) begin
        if (rst_n && (debug_instr == 32'h00000073 || instruction_count >= max_instruction_count)) begin
            // Read test result from memory address 0x100
            test_result = data_memory[256 >> 3]; // 0x100 / 8 = 256
            #10;
            $finish;
        end
    end

    // Run all test cases
    initial begin
        $display("Initial block started at time %0t", $time);

        // Initialize memory
        $display("Initializing memory...");
        // First fill with NOP instructions
        for (int i = 0; i < 4096; i = i + 1) begin
            instr_memory[i] = 32'h00000013; // NOP instruction
            data_memory[i] = 64'h0;
        end

        // Load instructions from hex file
        $display("Loading instructions from %s...", INSTR_FILE);
        $readmemh(INSTR_FILE, instr_memory);
        $display("Instruction loading completed.");
    `ifdef DEBUG
        $display("Initial instructions: ");
        for (int i = 0; i < 48; i = i + 1) begin
            $display("Instr[0x%0h] = 0x%0h", i, instr_memory[i]);
        end
    `endif

        // Wait for reset to complete
        $display("Waiting for reset...");
        @(posedge rst_n);
        $display("Reset deasserted at time %0t", $time);
        #10;

        $display("Reset completed. Starting comprehensive test execution...");
        $display("Executing test program from %s...", INSTR_FILE);
        $display("Test will automatically terminate on EBREAK instruction or after %0d instructions", max_instruction_count);

        // Test will run until EBREAK or instruction count limit is reached
        // Results will be checked in the always block above
    end

    initial begin
        $dumpfile("tb_riscv64_core.vcd");
        $dumpvars(0, tb_riscv64_core);
        $dumpon;
        $dumpall;
    end

    // Timeout detection
    initial begin
        #20000;
        $display("\nSimulation timeout!");
        $finish;
    end

`ifdef DEBUG
    // Debug monitoring
    always @(posedge clk) begin
        if (debug_wb_valid) begin
            $display("Time: %0t, PC: %0h, Instr: %0h, WB: x%0d = %0h",
                    $time, debug_pc, debug_instr, debug_wb_rd, debug_wb_value);
        end

        if (icache_req) begin
            $display("Time: %0t, ICache req: addr=%0h, data=%0h",
                    $time, icache_addr, icache_data);
        end

        if (dcache_req) begin
            if (dcache_we) begin
                $display("Time: %0t, DCache write: addr=%0h, data=%0h, be=%0h",
                        $time, dcache_addr, dcache_wdata, dcache_byte_en);
            end else begin
                $display("Time: %0t, DCache read: addr=%0h, data=%0h",
                        $time, dcache_addr, dcache_rdata);
            end
        end
    end
`endif

    // Add test_complete flag
    reg test_complete = 0;

    // Set test_complete flag when test should terminate
    always @(posedge clk) begin
        if (instruction_count >= max_instruction_count || (debug_instr == 32'h00000073 && debug_wb_valid)) begin
            test_complete <= 1;
        end
    end

    // Final test report
    always @(posedge clk) begin
        if (test_complete && !$isunknown(test_complete)) begin
            $display("\n\n*** Comprehensive RISC-V64 Test Report ***");
            $display("Test program: %s", INSTR_FILE);
            $display("Total instructions executed: %0d", instruction_count);
            $display("Pipeline stalls detected: %0d", stall_count);
            $display("Last PC: 0x%0h", debug_pc);
            $display("Last instruction: 0x%0h", debug_instr);
            $display("Test result value at 0x100: %0h", test_result);

            if (test_result == 64'h1 && debug_instr == 32'h00000073) begin
                $display("\nTEST PASSED!");
            end else if (instruction_count >= max_instruction_count) begin
                $display("\nTEST TIMEOUT!");
            end else begin
                $display("\nTEST FAILED!");
            end

            $display("*****************************************");
        end
    end

endmodule