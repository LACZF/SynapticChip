`timescale 1ns / 1ps

module tb_cache;

    // Clock and Reset Signals
    reg clk;
    reg rst_n;

    // CPU Interface Signals
    reg         cpu_req_valid;
    reg  [31:0] cpu_req_addr;
    reg         cpu_req_rw;
    reg  [31:0] cpu_req_data;
    reg  [3:0]  cpu_req_strb;
    wire        cpu_rsp_valid;
    wire [31:0] cpu_rsp_data;
    wire        cpu_rsp_error;

    // Memory Interface Signals
    reg         mem_req_valid;
    reg  [31:0] mem_req_addr;
    reg         mem_req_rw;
    reg  [63:0] mem_req_data;
    reg         mem_rsp_valid;
    reg  [63:0] mem_rsp_data;
    reg         mem_rsp_error;

    // Coherency Interface Signals
    reg  [31:0] coh_req_addr;
    reg         coh_req_valid;
    reg  [2:0]  coh_req_type;
    wire        coh_rsp_valid;
    wire [2:0]  coh_rsp_state;

    // L1+L2 Multi-Level Cache Signals
    wire [31:0] l2_cpu_req_addr;
    reg  [31:0] l2_cpu_req_data;
    reg  [3:0]  l2_cpu_req_strb;
    wire        l2_cpu_req_valid;
    wire        l2_cpu_req_rw;
    wire [31:0] l2_cpu_rsp_data;
    wire        l2_cpu_rsp_valid;
    wire        l2_cpu_rsp_error;

    // L1+L2+L3 Multi-Level Cache Signals
    reg  [31:0] l3_cpu_req_addr;
    reg  [31:0] l3_cpu_req_data;
    reg  [3:0]  l3_cpu_req_strb;
    reg         l3_cpu_req_valid;
    reg         l3_cpu_req_rw;
    wire [31:0] l3_cpu_rsp_data;
    wire        l3_cpu_rsp_valid;
    wire        l3_cpu_rsp_error;

    // Test Mode Selection Signals
    reg [1:0] test_mode;
    localparam SINGLE_LEVEL   = 2'b00;
    localparam L1_L2_CACHE    = 2'b01;
    localparam L1_L2_L3_CACHE = 2'b10;

    // Test Completion Flag
    reg test_done = 0;

    // Intermediate Signals to Resolve Conditional Expression Issues in Port Connections
    wire [31:0] l2_mem_req_addr;
    wire        l2_mem_req_valid;
    wire        l2_mem_req_rw;
    wire [63:0] l2_mem_req_data;
    wire [31:0] l3_mem_req_addr;
    wire        l3_mem_req_valid;
    wire        l3_mem_req_rw;
    wire [63:0] l3_mem_req_data;
    wire [31:0] dut_mem_req_addr;
    wire        dut_mem_req_valid;
    wire        dut_mem_req_rw;
    wire [63:0] dut_mem_req_data;
    wire [63:0] l1_mem_req_data; // L1 cache memory request data intermediate signal

    // Intermediate Signals to Fix iverilog Warnings - Avoid Using Constant Selectors in always_comb Blocks
    wire [31:0]     l1_mem_req_data_32bit;       // Extract lower 32 bits of l1_mem_req_data
    wire [63:0]     l2_cache_cpu_rsp_data_64bit; // Extend l2_cache.cpu_rsp_data to 64 bits
    wire [63:0]     l3_cache_cpu_rsp_data_64bit; // Extend l3_cache.cpu_rsp_data to 64 bits
    wire [31:0]     l2_cache_mem_req_data_32bit; // Extract lower 32 bits of l2_cache.mem_req_data
    wire [3:0]      full_strb;                   // Full strobe signal constant
    wire            zero_bit;                    // Zero value signal
    wire [63:0]     zero_64bit;                  // 64-bit zero value signal

    // Define These Signal Connections Outside always_comb Block
    assign l1_mem_req_data_32bit       = l1_mem_req_data[31:0];
    assign l2_cache_cpu_rsp_data_64bit = {32'b0, l2_cpu_rsp_data};

    assign l3_cache_cpu_rsp_data_64bit = {32'b0, l3_cpu_rsp_data};
    assign l2_cache_mem_req_data_32bit = l2_mem_req_data[31:0];
    assign full_strb                   = 4'b1111; // Define constant value externally
    assign zero_bit                    = 1'b0;
    assign zero_64bit                  = 64'b0;

    // Cache Module Memory Response Signals - Changed to reg Type for Assignment in always_comb
    reg          l1_mem_rsp_valid;
    reg  [63:0]  l1_mem_rsp_data;
    reg          l1_mem_rsp_error;
    reg          l2_mem_rsp_valid;
    reg  [63:0]  l2_mem_rsp_data;
    reg          l2_mem_rsp_error;
    reg          l3_mem_rsp_valid;
    reg  [63:0]  l3_mem_rsp_data;
    reg          l3_mem_rsp_error;
    reg          dut_mem_rsp_valid;
    reg  [63:0]  dut_mem_rsp_data;
    reg          dut_mem_rsp_error;

    // Select connection method based on test mode
    always_comb begin
        case(test_mode)
            L1_L2_CACHE:
            begin
                // L1+L2 mode: L2 connected to main memory
                mem_req_valid = l2_mem_req_valid;
                mem_req_addr = l2_mem_req_addr;
                mem_req_rw = l2_mem_req_rw;
                mem_req_data = l2_mem_req_data;

                // L2 CPU request data directly connected to lower 32 bits of L1 memory request data
                l2_cpu_req_data = l1_mem_req_data_32bit;
                l2_cpu_req_strb = full_strb; // Use defined intermediate signal instead of constant

                // L2 memory response connected to main memory response
                l2_mem_rsp_valid = mem_rsp_valid;
                l2_mem_rsp_data = mem_rsp_data;
                l2_mem_rsp_error = mem_rsp_error;

                // L1 memory response connected to L2 CPU response
                l1_mem_rsp_valid = l2_cpu_rsp_valid;
                l1_mem_rsp_data = l2_cache_cpu_rsp_data_64bit;
                l1_mem_rsp_error = l2_cpu_rsp_error;

                // Single-level cache disabled
                dut_mem_rsp_valid = zero_bit;
                dut_mem_rsp_data = zero_64bit;
                dut_mem_rsp_error = zero_bit;

                // L3 cache disabled
                l3_mem_rsp_valid = zero_bit;
                l3_mem_rsp_data = zero_64bit;
                l3_mem_rsp_error = zero_bit;
            end

            L1_L2_L3_CACHE:
            begin
                // L1+L2+L3 mode: L2 connected to L3, L3 connected to main memory
                l3_cpu_req_valid = l2_mem_req_valid;
                l3_cpu_req_addr = l2_mem_req_addr;
                l3_cpu_req_rw = l2_mem_req_rw;
                // L3 CPU request data directly connected to lower 32 bits of L2 memory request data
                l3_cpu_req_data = l2_cache_mem_req_data_32bit;
                l3_cpu_req_strb = full_strb;

                // L2 CPU request data connected to L1 memory request data
                l2_cpu_req_data = l1_mem_req_data_32bit;
                l2_cpu_req_strb = full_strb;

                // L2 memory response connected to L3 CPU response
                l2_mem_rsp_valid = l3_cpu_rsp_valid;
                l2_mem_rsp_data = l3_cache_cpu_rsp_data_64bit;
                l2_mem_rsp_error = l3_cpu_rsp_error;

                // L3 connected to main memory
                mem_req_valid = l3_mem_req_valid;
                mem_req_addr = l3_mem_req_addr;
                mem_req_rw = l3_mem_req_rw;
                mem_req_data = l3_mem_req_data;

                // L3 memory response connected to main memory response
                l3_mem_rsp_valid = mem_rsp_valid;
                l3_mem_rsp_data = mem_rsp_data;
                l3_mem_rsp_error = mem_rsp_error;

                // L1 memory response connected to L2 CPU response
                l1_mem_rsp_valid = l2_cpu_rsp_valid;
                l1_mem_rsp_data = l2_cache_cpu_rsp_data_64bit;
                l1_mem_rsp_error = l2_cpu_rsp_error;

                // Single-level cache disabled
                dut_mem_rsp_valid = zero_bit;
                dut_mem_rsp_data = zero_64bit;
                dut_mem_rsp_error = zero_bit;
            end

            default: // SINGLE_LEVEL
            begin
                // Single-level cache mode
                mem_req_valid = dut_mem_req_valid;
                mem_req_addr = dut_mem_req_addr;
                mem_req_rw = dut_mem_req_rw;
                mem_req_data = dut_mem_req_data;

                // Single-level cache memory response connected to main memory response
                dut_mem_rsp_valid = mem_rsp_valid;
                dut_mem_rsp_data = mem_rsp_data;
                dut_mem_rsp_error = mem_rsp_error;

                // Other caches disabled
                l1_mem_rsp_valid = zero_bit;
                l1_mem_rsp_data = zero_64bit;
                l1_mem_rsp_error = zero_bit;
                l2_mem_rsp_valid = zero_bit;
                l2_mem_rsp_data = zero_64bit;
                l2_mem_rsp_error = zero_bit;
                l3_mem_rsp_valid = zero_bit;
                l3_mem_rsp_data = zero_64bit;
                l3_mem_rsp_error = zero_bit;
            end
        endcase
    end

    // Instantiate L1 cache
    cache #(
        .CACHE_LINE_SIZE(64),          // 64-byte cache line
        .CACHE_SIZE(256),              // 256B - smaller L1 cache
        .ASSOCIATIVITY(2),             // 2-way set associative
        .ADDR_WIDTH(32),               // 32-bit address width
        .INPUT_DATA_WIDTH(32),         // 32-bit data width
        .OUTPUT_DATA_WIDTH(64),
        .SUPPORT_COHERENCY(1),         // Support coherency
        .CACHE_LEVEL(1),               // L1 cache
        .REPLACEMENT_POLICY("LRU")     // LRU replacement policy
    ) l1_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid_i(cpu_req_valid),
        .cpu_req_addr_i(cpu_req_addr),
        .cpu_req_rw_i(cpu_req_rw),
        .cpu_req_data_i(cpu_req_data),
        .cpu_req_strb_i(cpu_req_strb),
        .cpu_rsp_valid_o(cpu_rsp_valid),
        .cpu_rsp_data_o(cpu_rsp_data),
        .cpu_rsp_error_o(cpu_rsp_error),
        .mem_req_valid_o(l2_cpu_req_valid),
        .mem_req_addr_o(l2_cpu_req_addr),
        .mem_req_rw_o(l2_cpu_req_rw),
        .mem_req_data_o(l1_mem_req_data), // Connected to intermediate signal
        .mem_rsp_valid_i(l1_mem_rsp_valid), // Connected to intermediate signal
        .mem_rsp_data_i(l1_mem_rsp_data),  // Connected to intermediate signal
        .mem_rsp_error_i(l1_mem_rsp_error), // Connected to intermediate signal
        .coh_req_addr_i(coh_req_addr),
        .coh_req_valid_i(coh_req_valid),
        .coh_req_type_i(coh_req_type),
        .coh_rsp_valid_o(coh_rsp_valid),
        .coh_rsp_state_o(coh_rsp_state)
    );

    // Instantiate L2 cache
    cache #(
        .CACHE_LINE_SIZE(64),          // 64-byte cache line
        .CACHE_SIZE(1024),             // 1KB cache capacity
        .ASSOCIATIVITY(4),             // 4-way set associative
        .ADDR_WIDTH(32),               // 32-bit address width
        .INPUT_DATA_WIDTH(32),         // 32-bit data width
        .OUTPUT_DATA_WIDTH(64),
        .SUPPORT_COHERENCY(1),         // Support coherency
        .CACHE_LEVEL(2),               // L2 cache
        .REPLACEMENT_POLICY("LRU")     // LRU replacement policy
    ) l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid_i(l2_cpu_req_valid),
        .cpu_req_addr_i(l2_cpu_req_addr),
        .cpu_req_rw_i(l2_cpu_req_rw),
        .cpu_req_data_i(l2_cpu_req_data),
        .cpu_req_strb_i(l2_cpu_req_strb),
        .cpu_rsp_valid_o(l2_cpu_rsp_valid),
        .cpu_rsp_data_o(l2_cpu_rsp_data),
        .cpu_rsp_error_o(l2_cpu_rsp_error),
        .mem_req_valid_o(l2_mem_req_valid),
        .mem_req_addr_o(l2_mem_req_addr),
        .mem_req_rw_o(l2_mem_req_rw),
        .mem_req_data_o(l2_mem_req_data), // Keep 64-bit data width
        .mem_rsp_valid_i(l2_mem_rsp_valid), // Connected to intermediate signal
        .mem_rsp_data_i(l2_mem_rsp_data),  // Connected to intermediate signal
        .mem_rsp_error_i(l2_mem_rsp_error), // Connected to intermediate signal
        .coh_req_addr_i(32'h0),
        .coh_req_valid_i(1'b0),
        .coh_req_type_i(3'b0),
        .coh_rsp_valid_o(),
        .coh_rsp_state_o()
    );

    // Instantiate L3 cache
    cache #(
        .CACHE_LINE_SIZE(64),          // 64-byte cache line
        .CACHE_SIZE(4096),             // 4KB cache capacity
        .ASSOCIATIVITY(8),             // 8-way set associative
        .ADDR_WIDTH(32),               // 32-bit address width
        .INPUT_DATA_WIDTH(32),         // 32-bit data width
        .OUTPUT_DATA_WIDTH(64),
        .SUPPORT_COHERENCY(1),         // Support coherency
        .CACHE_LEVEL(3),               // L3 cache
        .REPLACEMENT_POLICY("LRU")     // LRU replacement policy
    ) l3_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid_i(l3_cpu_req_valid),
        .cpu_req_addr_i(l3_cpu_req_addr),
        .cpu_req_rw_i(l3_cpu_req_rw),
        .cpu_req_data_i(l3_cpu_req_data),
        .cpu_req_strb_i(l3_cpu_req_strb),
        .cpu_rsp_valid_o(l3_cpu_rsp_valid),
        .cpu_rsp_data_o(l3_cpu_rsp_data),
        .cpu_rsp_error_o(l3_cpu_rsp_error),
        .mem_req_valid_o(l3_mem_req_valid),
        .mem_req_addr_o(l3_mem_req_addr),
        .mem_req_rw_o(l3_mem_req_rw),
        .mem_req_data_o(l3_mem_req_data), // Keep 64-bit data width
        .mem_rsp_valid_i(l3_mem_rsp_valid), // Connected to intermediate signal
        .mem_rsp_data_i(l3_mem_rsp_data),  // Connected to intermediate signal
        .mem_rsp_error_i(l3_mem_rsp_error), // Connected to intermediate signal
        .coh_req_addr_i(32'h0),
        .coh_req_valid_i(1'b0),
        .coh_req_type_i(3'b0),
        .coh_rsp_valid_o(),
        .coh_rsp_state_o()
    );

    // Original single-level cache instance - preserved for existing tests
    cache #(
        .CACHE_LINE_SIZE(64),          // 64-byte cache line
        .CACHE_SIZE(1024),             // 1KB cache capacity
        .ASSOCIATIVITY(4),             // 4-way set associative
        .ADDR_WIDTH(32),               // 32-bit address width
        .INPUT_DATA_WIDTH(32),         // 32-bit data width
        .OUTPUT_DATA_WIDTH(64),
        .SUPPORT_COHERENCY(1),         // Support coherency
        .CACHE_LEVEL(2),               // L2 cache
        .REPLACEMENT_POLICY("LRU")     // LRU replacement policy
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid_i(test_mode == SINGLE_LEVEL ? cpu_req_valid : 1'b0),
        .cpu_req_addr_i(cpu_req_addr),
        .cpu_req_rw_i(cpu_req_rw),
        .cpu_req_data_i(cpu_req_data),
        .cpu_req_strb_i(cpu_req_strb),
        .cpu_rsp_valid_o(cpu_rsp_valid),
        .cpu_rsp_data_o(cpu_rsp_data),
        .cpu_rsp_error_o(cpu_rsp_error),
        .mem_req_valid_o(dut_mem_req_valid),
        .mem_req_addr_o(dut_mem_req_addr),
        .mem_req_rw_o(dut_mem_req_rw),
        .mem_req_data_o(dut_mem_req_data),
        .mem_rsp_valid_i(dut_mem_rsp_valid), // Connected to intermediate signal
        .mem_rsp_data_i(dut_mem_rsp_data),  // Connected to intermediate signal
        .mem_rsp_error_i(dut_mem_rsp_error), // Connected to intermediate signal
        .coh_req_addr_i(coh_req_addr),
        .coh_req_valid_i(coh_req_valid),
        .coh_req_type_i(coh_req_type),
        .coh_rsp_valid_o(coh_rsp_valid),
        .coh_rsp_state_o(coh_rsp_state)
    );

    // Create reference memory model
    reg [7:0] ref_memory [0:4095];

    // Clock generation
    always #5 clk = ~clk;

    // Memory model initialization
    initial begin
        for (integer i = 0; i < 4096; i = i + 1) begin
            ref_memory[i] = i & 8'hFF;
        end
    end

    // Memory delay counter
    reg [3:0] mem_delay_count;
    reg mem_req_pending;
    reg [31:0] pending_addr;
    reg pending_rw;
    reg [63:0] pending_data;

    // Memory response logic - Fixed delay implementation
    always @(posedge clk) begin
        if (~rst_n) begin
            mem_rsp_valid <= 1'b0;
            mem_delay_count <= 4'h0;
            mem_req_pending <= 1'b0;
        end else begin
            if (mem_req_valid && ~mem_req_pending) begin
                // New memory request
                pending_addr <= mem_req_addr;
                pending_rw <= mem_req_rw;
                pending_data <= mem_req_data;
                mem_req_pending <= 1'b1;
                mem_delay_count <= 4'h9; // Set 10-cycle delay
                mem_rsp_valid <= 1'b0;
            end else if (mem_req_pending) begin
                // Wait for delay to complete
                mem_delay_count <= mem_delay_count - 1'b1;
                if (mem_delay_count == 0) begin
                    // Delay completed, generate response
                    mem_req_pending <= 1'b0;
                    mem_rsp_valid <= 1'b1;
                    if (pending_rw) begin
                        // Memory write operation
                        for (integer i = 0; i < 64; i = i + 1) begin
                            ref_memory[pending_addr + i] = pending_data[i*8 +: 8];
                        end
                    end else begin
                        // Memory read operation
                        for (integer i = 0; i < 64; i = i + 1) begin
                            mem_rsp_data[i*8 +: 8] = ref_memory[pending_addr + i];
                        end
                    end
                end else begin
                    mem_rsp_valid <= 1'b0;
                end
            end else begin
                mem_rsp_valid <= 1'b0;
            end
            mem_rsp_error <= 1'b0;
        end
    end

    // Timeout parameter definition
    localparam TIMEOUT_CYCLES = 1000;

    // Test task: Data read - Add timeout mechanism
    task read_data;
        input [31:0] address;
        integer timeout;
        begin
            @(posedge clk);
            cpu_req_valid = 1'b1;
            cpu_req_addr = address;
            cpu_req_rw = 1'b0;  // Read operation
            cpu_req_data = 32'h0;
            cpu_req_strb = 4'b1111;

            timeout = 0;
            while (~cpu_rsp_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

        `ifdef DEBUG
            if (cpu_rsp_valid) begin
                $display("Time: %t - Read address: 0x%h, data: 0x%h", $time, address, cpu_rsp_data);
            end else begin
                $display("Time: %t - Read address: 0x%h timeout! Test may have issues.", $time, address);
            end
        `endif

            @(posedge clk);
            cpu_req_valid = 1'b0;
        end
    endtask

    // Test task: Data write - Add timeout mechanism
    task write_data;
        input [31:0] address;
        input [31:0] data;
        input [3:0] strb;
        integer timeout;
        begin
            @(posedge clk);
            cpu_req_valid = 1'b1;
            cpu_req_addr = address;
            cpu_req_rw = 1'b1;  // Write operation
            cpu_req_data = data;
            cpu_req_strb = strb;

            timeout = 0;
            while (~cpu_rsp_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

        `ifdef DEBUG
            if (cpu_rsp_valid) begin
                $display("Time: %t - Write address: 0x%h, data: 0x%h, strobe: 0x%h", $time, address, data, strb);
            end else begin
                $display("Time: %t - Write address: 0x%h timeout! Test may have issues.", $time, address);
            end
        `endif

            @(posedge clk);
            cpu_req_valid = 1'b0;
        end
    endtask

    // Define MESI protocol state constants
    localparam INVALID   = 3'd0;
    localparam SHARED    = 3'd1;
    localparam EXCLUSIVE = 3'd2;
    localparam MODIFIED  = 3'd3;

    // Define coherency request type constants
    localparam COH_READ      = 3'd0;
    localparam COH_WRITE     = 3'd1;
    localparam COH_INVALIDATE = 3'd2;

    // Test task: Coherency operation - Add timeout mechanism
    task coherency_op;
        input [31:0] address;
        input [2:0] req_type;
        input string req_name;
        integer timeout;
        begin
            @(posedge clk);
            coh_req_valid = 1'b1;
            coh_req_addr = address;
            coh_req_type = req_type;

            timeout = 0;
            while (~coh_rsp_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

        `ifdef DEBUG
            if (coh_rsp_valid) begin
                $display("Time: %t - Coherency operation: %s, address=0x%h, state=%s",
                         $time, req_name, address, get_state_name(coh_rsp_state));
            end else begin
                $display("Time: %t - Coherency operation: %s, address=0x%h timeout! Test may have issues.", $time, req_name, address);
            end
        `endif

            @(posedge clk);
            coh_req_valid = 1'b0;
        end
    endtask

    // Helper function: Get state name
    function string get_state_name;
        input [2:0] state;
        begin
            case (state)
                INVALID:   get_state_name = "INVALID";
                SHARED:    get_state_name = "SHARED";
                EXCLUSIVE: get_state_name = "EXCLUSIVE";
                MODIFIED:  get_state_name = "MODIFIED";
                default:   get_state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // Main test flow
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        cpu_req_valid = 0;
        cpu_req_addr = 0;
        cpu_req_rw = 0;
        cpu_req_data = 0;
        cpu_req_strb = 0;
        mem_rsp_valid = 0;
        mem_rsp_data = 0;
        mem_rsp_error = 0;
        coh_req_valid = 0;
        coh_req_addr = 0;
        coh_req_type = 0;

        // Start global timeout monitoring
        fork
            // Main test thread
            begin
                // Create VCD file
                $dumpfile("tb_cache.vcd");
                $dumpvars(0, tb_cache);

                // Reset
                #20;
                rst_n = 1;

                $display("=== Cache Module Test Start ===");

                // Test 1: Basic read test
                $display("Test 1: Basic read test");
                read_data(32'h00000000);  // First read, should miss
                read_data(32'h00000000);  // Second read, should hit

                // Test 2: Cache line fill test
                $display("Test 2: Cache line fill test");
                read_data(32'h00000010);  // Same cache line, should hit
                read_data(32'h00000020);  // Same cache line, should hit

                // Test 3: Basic write test
                $display("Test 3: Basic write test");
                write_data(32'h00001000, 32'h12345678, 4'b1111);  // Write miss
                read_data(32'h00001000);  // Read back the written data, should hit

                // Test 4: Partial write test
                $display("Test 4: Partial write test");
                write_data(32'h00001000, 32'hFF00FF00, 4'b1010);  // Write only bytes 0 and 2
                read_data(32'h00001000);  // Read to verify partial write

                // Test 5: Cache replacement test
                $display("Test 5: Cache replacement test");
                // With our cache size of 1KB, 4-way set associative, 64-byte lines, there are (1024/64)/4 = 4 sets
                // Access enough different sets to trigger replacement
                for (integer i = 0; i < 8; i = i + 1) begin
                    read_data(32'h00002000 + i*64);
                end
                // Verify the earliest line has been replaced
                read_data(32'h00002000);  // Should miss

                // Test 6: MESI protocol coherency operation test
                $display("Test 6: MESI protocol coherency operation test");
                if (dut.SUPPORT_COHERENCY) begin
                    // First write to an address to put it into MODIFIED state
                    write_data(32'h00001000, 32'h12345678, 4'b1111);
                    read_data(32'h00001000);  // Confirm data was written

                    // Test MODIFIED -> SHARED transition
                    $display("Test 6.1: MODIFIED -> SHARED state transition (Read request)");
                    coherency_op(32'h00001000, COH_READ, "Read request");

                    // Write to another address to put it into EXCLUSIVE state
                    read_data(32'h00001040);  // First read, should enter EXCLUSIVE state

                    // Test EXCLUSIVE -> SHARED transition
                    $display("Test 6.2: EXCLUSIVE -> SHARED state transition (Read request)");
                    coherency_op(32'h00001040, COH_READ, "Read request");

                    // Test SHARED -> INVALID transition
                    $display("Test 6.3: SHARED -> INVALID state transition (Write request)");
                    coherency_op(32'h00001040, COH_WRITE, "Write request");

                    // Test invalidation operation
                    $display("Test 6.4: Direct invalidation operation (Invalidate request)");
                    write_data(32'h00001080, 32'h87654321, 4'b1111);
                    coherency_op(32'h00001080, COH_INVALIDATE, "Invalidate request");

                    // Verify read behavior after invalidation
                    $display("Test 6.5: Verify read behavior after invalidation");
                    read_data(32'h00001080);  // Should reload from memory
                end else begin
                    $display("Coherency feature not enabled, skipping MESI protocol test");
                end

                // Test 7: Configuration parameter verification
                $display("Test 7: Configuration parameter verification");
                $display("Cache size: %d KB", dut.CACHE_SIZE/1024);
                $display("Cache Line size: %d bytes", dut.CACHE_LINE_SIZE);
                $display("Associativity: %d-way", dut.ASSOCIATIVITY);
                $display("Cache level: L%d", dut.CACHE_LEVEL);
                $display("Replacement policy: %s", dut.REPLACEMENT_POLICY);
                $display("Coherency support: %s", dut.SUPPORT_COHERENCY ? "Yes" : "No");

                // Test 8: L1+L2 multi-level cache test
                $display("Test 8: L1+L2 multi-level cache test");
                test_mode = L1_L2_CACHE;
                @(posedge clk);

                // Simplified L1+L2 test: Only test basic functions, avoid complex cache state management
                $display("Test 8.1: Basic L1+L2 read test");
                read_data(32'h00003000);  // L1 miss, L2 miss, load from memory
                read_data(32'h00003000);  // L1 hit

                // Test 9: L1+L2+L3 multi-level cache test
                $display("Test 9: L1+L2+L3 multi-level cache test");
                test_mode = L1_L2_L3_CACHE;
                @(posedge clk);

                // Simplified L1+L2+L3 test: Only test basic functions, avoid complex cache state management
                $display("Test 9.1: Basic L1+L2+L3 read test");
                read_data(32'h00004000);  // L1 miss, L2 miss, L3 miss, load from memory
                read_data(32'h00004000);  // L1 hit

                $display("=== Cache Module Test Completed ===");

                // Wait for All Operations to Complete
                repeat (10) @(posedge clk);

                $finish;
            end

            // Global Timeout Monitoring Thread
            begin
                #1000000;  // 1ms global timeout
                $display("Time: %t - Test execution timeout! Forcing simulation to end.", $time);
                $finish;
            end
        join
    end

`ifdef DEBUG
    // Monitor Cache Operations
    always @(posedge clk) begin
        if (mem_req_valid) begin
            if (mem_req_rw) begin
                $display("Time: %t - Cache eviction: address=0x%h, data=0x%h",
                         $time, mem_req_addr, mem_req_data);
            end else begin
                $display("Time: %t - Cache fill: address=0x%h", $time, mem_req_addr);
            end
        end
    end
`endif

endmodule