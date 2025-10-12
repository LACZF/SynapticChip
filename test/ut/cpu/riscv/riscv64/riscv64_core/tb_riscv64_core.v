`timescale 1ns/1ps

module tb_riscv64_core;

    // Clock and Reset Signals
    reg          clk;
    reg          rst_n;

    // Instruction Cache Interface
    wire         icache_req;
    wire [63:0]  icache_addr;
    reg  [63:0]  icache_data;
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
    wire timer_interrupt;
    wire external_interrupt;
    wire software_interrupt;

    // Debug Interface
    wire [63:0] debug_pc;
    wire [31:0] debug_instr;
    wire [4:0]  debug_wb_rd;
    wire [63:0] debug_wb_value;
    wire        debug_wb_valid;

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
    parameter INSTR_FILE = "instructions.hex"; // Path to instruction hex file

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
        end
    end

    always @(*) begin
        if (dcache_req) begin
            if (!dcache_we && dcache_addr[31:3] < 4096) begin
                dcache_rdata = data_memory[dcache_addr[31:3]];
            end else begin
                dcache_rdata = 64'h0;
            end
            dcache_ready = 1'b1;
        end else begin
            dcache_rdata = 64'h0;
            dcache_ready = 1'b0;
        end
    end

    // Connect snoop interface (simplified test)
    assign snoop_valid = 1'b0; // Simplified test, no snoop requests
    assign snoop_addr = 64'h0;
    assign snoop_req_type = 2'b00;

    // Connect interrupt interface (simplified test)
    assign timer_interrupt = 1'b0;
    assign external_interrupt = 1'b0;
    assign software_interrupt = 1'b0;

    // Instantiate DUT
    riscv64_core #(
        .ADDR_WIDTH(64),
        .DATA_WIDTH(64),
        .L1_ICACHE_DATA_WIDTH(64),
        .L1_DCACHE_DATA_WIDTH(64),
        .CORE_ID(0)
    ) u_dut (
        // Clock and reset
        .clk(clk),
        .rst_n(rst_n),

        // Instruction cache interface
        .icache_req(icache_req),
        .icache_addr(icache_addr),
        .icache_data(icache_data),
        .icache_ready(icache_ready),

        // Data cache interface
        .dcache_req(dcache_req),
        .dcache_addr(dcache_addr),
        .dcache_we(dcache_we),
        .dcache_wdata(dcache_wdata),
        .dcache_byte_en(dcache_byte_en),
        .dcache_rdata(dcache_rdata),
        .dcache_ready(dcache_ready),

        // Snoop interface
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_req_type(snoop_req_type),
        .snoop_ready(snoop_ready),
        .snoop_hit(snoop_hit),
        .snoop_state(snoop_state),
        .snoop_data(snoop_data),

        // Interrupt interface
        .timer_interrupt(timer_interrupt),
        .external_interrupt(external_interrupt),
        .software_interrupt(software_interrupt),

        // Debug outputs
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_wb_valid(debug_wb_valid),
        .debug_wb_rd(debug_wb_rd),
        .debug_wb_value(debug_wb_value)
    );

    // Test Cases
    integer test_pass = 0;
    integer test_fail = 0;

    // Test Case 1: Basic Arithmetic Instructions Test
    task test_arithmetic;
        begin
            $display("Starting arithmetic instructions test...");

            // Set PC to the start of arithmetic test instructions (index 100)
            $display("Jumping to arithmetic test instructions at address 0x%0h", 64'h80000000 + (100 << 2));
            // Use JAL instruction to jump to the test address
            instr_memory[0] = 32'h0190006f; // JAL x0, 0x19 (jump to address 0x74 = 100*4)

            rst_n = 0;
            #20 rst_n = 1;
            // Wait for processor execution
            #2000;

            // Check results
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 15) begin
                $display("  Test arithmetic passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test arithmetic failed! Expected x5=15, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 2: Memory Access Instructions Test
    task test_memory;
        begin
            $display("Starting memory access instructions test...");

            // Set PC to the start of memory test instructions (index 5)
            $display("Jumping to memory test instructions at address 0x%0h", 64'h80000000 + (5 << 2));
            instr_memory[0] = 32'h0050006f; // JAL x0, 0x5 (jump to address 0x14 = 5*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results
            if (debug_wb_valid && debug_wb_rd == 3 && debug_wb_value == 100) begin
                $display("  Test memory passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test memory failed! Expected x3=100, Got x3=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 3: Branch Instructions Test
    task test_branch;
        begin
            $display("Starting branch instructions test...");

            // Set PC to the start of branch test instructions (index 9)
            $display("Jumping to branch test instructions at address 0x%0h", 64'h80000000 + (9 << 2));
            instr_memory[0] = 32'h0090006f; // JAL x0, 0x9 (jump to address 0x24 = 9*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results
            if (debug_wb_valid && debug_wb_rd == 6 && debug_wb_value == 4) begin
                $display("  Test branch passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test branch failed! Expected x6=4, Got x6=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 4: Logic Instructions Test
    task test_logic;
        begin
            $display("Starting logic instructions test...");

            // Set PC to the start of logic test instructions (index 16)
            $display("Jumping to logic test instructions at address 0x%0h", 64'h80000000 + (16 << 2));
            instr_memory[0] = 32'h0100006f; // JAL x0, 0x10 (jump to address 0x40 = 16*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 65535) begin
                $display("  Test logic passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test logic failed! Expected x5=0xFFFF, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 5: Shift Instructions Test
    task test_shift;
        begin
            $display("Starting shift instructions test...");

            // Set PC to the start of shift test instructions (index 21)
            $display("Jumping to shift test instructions at address 0x%0h", 64'h80000000 + (21 << 2));
            instr_memory[0] = 32'h0150006f; // JAL x0, 0x15 (jump to address 0x54 = 21*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 64'hFFFFFFFFFFFFFFFE) begin
                $display("  Test shift passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test shift failed! Expected x5=-2, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 6: Compare Instructions Test
    task test_compare;
        begin
            $display("Starting compare instructions test...");

            // Set PC to the start of compare test instructions (index 26)
            $display("Jumping to compare test instructions at address 0x%0h", 64'h80000000 + (26 << 2));
            instr_memory[0] = 32'h01a0006f; // JAL x0, 0x1a (jump to address 0x68 = 26*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 1) begin
                $display("  Test compare passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test compare failed! Expected x5=1, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 7: Jump Instructions Test
    task test_jump;
        begin
            $display("Starting jump instructions test...");

            // Set PC to the start of jump test instructions (index 31)
            $display("Jumping to jump test instructions at address 0x%0h", 64'h80000000 + (31 << 2));
            instr_memory[0] = 32'h01f0006f; // JAL x0, 0x1f (jump to address 0x7c = 31*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results
            if (debug_wb_valid && (debug_wb_rd == 1 || debug_wb_rd == 8)) begin
                if ((debug_wb_rd == 1 && debug_wb_value == 33) ||
                    (debug_wb_rd == 8 && debug_wb_value == 7)) begin
                    $display("  Test jump passed!");
                    test_pass = test_pass + 1;
                end else begin
                    $display("  Test jump failed! Expected x1=33 or x8=7, Got x%0d=%0h",
                             debug_wb_rd, debug_wb_value);
                    test_fail = test_fail + 1;
                end
            end else begin
                $display("  Test jump failed! Expected x1 or x8, Got x%0d", debug_wb_rd);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Test Case 8: Hazard Detection and Handling Test
    task test_hazard;
        begin
            $display("Starting hazard detection and handling test...");

            // Set PC to the start of hazard test instructions (index 39)
            $display("Jumping to hazard test instructions at address 0x%0h", 64'h80000000 + (39 << 2));
            instr_memory[0] = 32'h0270006f; // JAL x0, 0x27 (jump to address 0x9c = 39*4)

            rst_n = 0;
            #20 rst_n = 1;

            // Run for several cycles
            #200;

            // Check results (mainly verify pipeline works properly, not specific values)
            if (debug_wb_valid) begin
                $display("  Test hazard passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test hazard failed! No valid write back observed");
                test_fail = test_fail + 1;
            end
        end
    endtask

    // Run all test cases
    initial begin
        $display("Initial block started at time %0t", $time);

        // Initialize memory
        $display("Initializing memory from %s...", INSTR_FILE);
        // First fill with NOP instructions
        for (int i = 0; i < 4096; i = i + 1) begin
            instr_memory[i] = 32'h00000013; // NOP instruction
            data_memory[i] = 64'h0;
        end
        // Then load instructions from hex file
        $readmemh(INSTR_FILE, instr_memory);
        $display("Memory initialization from %s completed.", INSTR_FILE);
    `ifdef DEBUG
        $display("Initial instructions: ");
        for (int i = 0; i < 128; i = i + 1) begin
            $display("Instr[0x%0h] = 0x%0h", i, instr_memory[i]);
        end
    `endif

        // Wait for reset to complete
        $display("Waiting for reset...");
        @(posedge rst_n);
        $display("Reset deasserted at time %0t", $time);
        #10;

        $display("Reset completed. Starting test execution...");

        // Run test cases
        test_arithmetic;
        test_memory;
        test_branch;
        test_logic;
        test_shift;
        test_compare;
        test_jump;
        test_hazard;

        // Wait for all tests to complete
        #500;

        // Output test results summary
        $display("\nTest Results Summary:");
        $display("Total tests: %0d", test_pass + test_fail);
        $display("Passed tests: %0d", test_pass);
        $display("Failed tests: %0d", test_fail);

        if (test_fail == 0) begin
            $display("\nALL TESTS PASSED!");
        end else begin
            $display("\nSOME TESTS FAILED!");
        end

        // End simulation
        #100;
        $finish;
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

endmodule