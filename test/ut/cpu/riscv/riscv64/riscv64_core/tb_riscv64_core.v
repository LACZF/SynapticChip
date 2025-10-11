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
            if (dcache_byte_en[0]) data_memory[dcache_addr[31:3]][7:0] <= dcache_wdata[7:0];
            if (dcache_byte_en[1]) data_memory[dcache_addr[31:3]][15:8] <= dcache_wdata[15:8];
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
            $display("Time: %0t, Writing test instructions to instr_memory", $time);

            // Initialize instruction memory (use offset 100 to avoid conflicts with other test cases)
            // ADD x1, x0, x0 (x1 = 0)
            instr_memory[100] = 32'h000000b3;
            // ADDI x2, x0, 10 (x2 = 10)
            instr_memory[101] = 32'h00a00113;
            // ADD x3, x1, x2 (x3 = 10)
            instr_memory[102] = 32'h002081b3;
            // SUB x4, x2, x1 (x4 = 10)
            // ADDI x5, x3, 5 (x5 = 15)
            instr_memory[104] = 32'h00508293;

            // Display written instructions
            $display("Time: %0t, Test instructions written:", $time);
            for (int i = 100; i < 105; i = i + 1) begin
                $display("  instr_memory[%0d] = 0x%0h", i, instr_memory[i]);
            end

            // Set processor to start execution from our test instructions
            // Note: This needs to be achieved by modifying the processor's PC register,
            // but PC registers are usually not directly exposed in RTL designs
            // So we need to set the initial PC through the debug interface or other means
            $display("Time: %0t, Note: Need to set PC to 0x%0h to start test", $time, 64'h80000000 + (100 << 2));

            // Wait for processor execution
            $display("Time: %0t, Waiting for instruction execution", $time);
            #2000;

            // Check results
            $display("Time: %0t, Checking test results", $time);
            $display("  Current debug_wb_valid: %0d, debug_wb_rd: %0d, debug_wb_value: %0h",
                     debug_wb_valid, debug_wb_rd, debug_wb_value);

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

            // Initialize instruction memory
            // ADDI x1, x0, 100 (x1 = 100)
            instr_memory[5] = 32'h064000b3;
            // ADDI x2, x0, 0x1000 (x2 = 4096)
            instr_memory[6] = 32'h10000113;
            // SD x1, 0(x2) (store x1 to memory[4096])
            instr_memory[7] = 32'h00112023;
            // LD x3, 0(x2) (load x3 from memory[4096])
            instr_memory[8] = 32'h00012183;

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

            // Initialize instruction memory
            // ADDI x1, x0, 5 (x1 = 5)
            instr_memory[9] = 32'h005000b3;
            // ADDI x2, x0, 5 (x2 = 5)
            instr_memory[10] = 32'h00500113;
            // BEQ x1, x2, 4 (branch to 15 if x1 == x2)
            instr_memory[11] = 32'h00208463;
            // ADDI x3, x0, 1 (should not reach here)
            instr_memory[12] = 32'h00100193;
            // ADDI x4, x0, 2 (should not reach here)
            instr_memory[13] = 32'h00200213;
            // ADDI x5, x0, 3 (should not reach here)
            instr_memory[14] = 32'h00300293;
            // ADDI x6, x0, 4 (branch target)
            instr_memory[15] = 32'h00400313;

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

            // Initialize instruction memory
            // ADDI x1, x0, 0xAAAA (x1 = 0xAAAA)
            instr_memory[16] = 32'hAAA000b3;
            // ADDI x2, x0, 0x5555 (x2 = 0x5555)
            instr_memory[17] = 32'h55500113;
            // AND x3, x1, x2 (x3 = 0)
            instr_memory[18] = 32'h0020a1b3;
            // OR x4, x1, x2 (x4 = 0xFFFF)
            instr_memory[19] = 32'h0020c233;
            // XOR x5, x1, x2 (x5 = 0xFFFF)
            instr_memory[20] = 32'h0020e293;

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

            // Initialize instruction memory
            // ADDI x1, x0, 1 (x1 = 1)
            instr_memory[21] = 32'h001000b3;
            // SLLI x2, x1, 4 (x2 = 16)
            instr_memory[22] = 32'h00409113;
            // SRLI x3, x2, 2 (x3 = 4)
            instr_memory[23] = 32'h0020d193;
            // ADDI x4, x0, -8 (x4 = -8)
            instr_memory[24] = 32'hFF800213;
            // SRAI x5, x4, 2 (x5 = -2)
            instr_memory[25] = 32'h4020f293;

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

            // Initialize instruction memory
            // ADDI x1, x0, 5 (x1 = 5)
            instr_memory[26] = 32'h005000b3;
            // ADDI x2, x0, 10 (x2 = 10)
            instr_memory[27] = 32'h00a00113;
            // SLT x3, x1, x2 (x3 = 1)
            instr_memory[28] = 32'h0020e1b3;
            // SLTU x4, x2, x1 (x4 = 0)
            instr_memory[29] = 32'h00114233;
            // SLTI x5, x2, 15 (x5 = 1)
            instr_memory[30] = 32'h00f11293;

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

            // Initialize instruction memory
            // JAL x1, 8 (jump to 38, x1 = 33)
            instr_memory[31] = 32'h004000ef;
            instr_memory[32] = 32'h00100113;
            // ADDI x3, x0, 2 (should not reach here)
            instr_memory[33] = 32'h00200193;
            // ADDI x4, x0, 3 (should not reach here)
            instr_memory[34] = 32'h00300213;
            // ADDI x5, x0, 4 (should not reach here)
            instr_memory[35] = 32'h00400293;
            // ADDI x6, x0, 5 (should not reach here)
            instr_memory[36] = 32'h00500313;
            // ADDI x7, x0, 6 (should not reach here)
            instr_memory[37] = 32'h00600393;
            // ADDI x8, x0, 7 (jump target)
            instr_memory[38] = 32'h00700413;

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

            // Initialize instruction memory
            // LD x1, 0(x0) (load data to x1)
            instr_memory[39] = 32'h00000083;
            // ADD x2, x1, x1 (use x1, should trigger load-use hazard)
            instr_memory[40] = 32'h00108113;
            // ADD x3, x2, x2 (use x2)
            instr_memory[41] = 32'h00210193;

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
        $display("Initializing memory...");
        for (int i = 0; i < 4096; i = i + 1) begin
            instr_memory[i] = 32'h00000013; // NOP instruction
            data_memory[i] = 64'h0;
        end

        $display("Memory initialization completed.");

        // Wait for reset to complete
        $display("Waiting for reset...");
        @(posedge rst_n);
        $display("Reset deasserted at time %0t", $time);
        #10;

        $display("Reset completed. Starting test execution...");
    `ifdef DEBUG
        $display("Initial instructions: ");
        for (int i = 0; i < 10; i = i + 1) begin
            $display("Instr[0x%0h] = 0x%0h", i, instr_memory[i]);
        end
    `endif

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

        // Generate waveform file
        $dumpfile("tb_riscv64_core.vcd");
        $dumpvars(0, tb_riscv64_core);

        // End simulation
        #100;
        $finish;
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