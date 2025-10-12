// cpu_top.v
// CPU top-level module, containing CPU cores and cache hierarchy
// Communicates directly with external world, no longer through ring bus

`include "cache_params.v"
`include "cache_system_params.v"

module cpu_top #(
    parameter ADDR_WIDTH                    = 64,  // Consistent with 64-bit RISC-V architecture
    parameter DATA_WIDTH                    = 64,
    parameter MEM_WIDTH                     = 512,
    parameter INST_WIDTH                    = 32,
    parameter NUM_CORES                     = 4,
    parameter CORE_ID_WIDTH                 = 2,
    parameter L1_ICACHE_DATA_WIDTH          = 32,
    parameter L1_DCACHE_DATA_WIDTH          = 64,
    parameter L2_CACHE_DATA_WIDTH           = 512,
    parameter L3_CACHE_DATA_WIDTH           = 512,
    parameter ENABLE_L2_CACHE               = 1,   // Enable L2 cache, default is 1
    parameter ENABLE_L3_CACHE               = 1,   // Enable L3 cache, default is 1
    parameter CPU_TYPE                      = 0    // 0: RISC-V, 1: Reserved for other CPU types
) (
    input                                   clk,
    input                                   rst_n,

    // External interrupt
    input                                   ext_int,

    // Memory interface signals - Directly exposed for external communication
    output wire                             mem_req,
    output wire [ADDR_WIDTH-1:0]            mem_addr,
    output wire [MEM_WIDTH-1:0]             mem_wdata,
    output wire                             mem_we,
    input  wire                             mem_ready,
    input  wire  [MEM_WIDTH-1:0]            mem_rdata
);
    localparam L2_OUT_WIDTH = ENABLE_L3_CACHE ? L3_CACHE_DATA_WIDTH : MEM_WIDTH;
    localparam L1_OUT_WIDTH = ENABLE_L2_CACHE ? L2_CACHE_DATA_WIDTH : ENABLE_L3_CACHE ? L3_CACHE_DATA_WIDTH : MEM_WIDTH;
    // Calculate maximum L1 cache data width for L2 cache input bit width
    localparam MAX_L1_DATA_WIDTH = L1_ICACHE_DATA_WIDTH > L1_DCACHE_DATA_WIDTH ? L1_ICACHE_DATA_WIDTH : L1_DCACHE_DATA_WIDTH;

    // Changed to per-core independent signals to avoid index access issues
    wire [NUM_CORES-1:0]                                l1_icache_req;
    wire [NUM_CORES*ADDR_WIDTH-1:0]                     l1_icache_addr;
    wire [NUM_CORES*L1_OUT_WIDTH-1:0]                   l1_icache_wdata;
    wire [NUM_CORES*L1_OUT_WIDTH-1:0]                   l1_icache_data;
    wire [NUM_CORES-1:0]                                l1_icache_ready;

    wire [NUM_CORES-1:0]                                l1_dcache_req;
    wire [NUM_CORES*ADDR_WIDTH-1:0]                     l1_dcache_addr;
    wire [NUM_CORES*L1_OUT_WIDTH-1:0]                   l1_dcache_wdata;
    wire [NUM_CORES*L1_OUT_WIDTH-1:0]                   l1_dcache_data;
    wire [NUM_CORES-1:0]                                l1_dcache_we;
    wire [NUM_CORES*2-1:0]                              l1_dcache_req_type;
    wire [NUM_CORES-1:0]                                l1_dcache_ready;

    // Snoop interface signals
    wire [NUM_CORES-1:0]                                snoop_valid;
    wire [NUM_CORES*ADDR_WIDTH-1:0]                     snoop_addr;
    wire [NUM_CORES*2-1:0]                              snoop_req_type;
    wire [NUM_CORES-1:0]                                snoop_ready;
    wire [NUM_CORES-1:0]                                snoop_hit;
    wire [NUM_CORES*2-1:0]                              snoop_state;
    wire [NUM_CORES*512-1:0]                            snoop_data;

    // L2-L3 interface signals
    wire                                                l2_l3_req;
    wire [ADDR_WIDTH-1:0]                               l2_l3_addr;
    wire [L2_OUT_WIDTH-1:0]                             l2_l3_wdata;
    wire [L2_OUT_WIDTH-1:0]                             l2_l3_rdata;
    wire                                                l2_l3_we;
    wire                                                l2_l3_ready;

    // Interface signals between cores and L2 cache
    wire [NUM_CORES-1:0]                                core_l2_ready;
    wire [NUM_CORES*512-1:0]                            core_l2_data;

    // Memory interface signals - Already declared in module ports

    // Cache hierarchy connection logic
    generate
        // When L2 cache is enabled
        if (ENABLE_L2_CACHE) begin : l2_cache_gen
            // Intermediate signals for L2 cache coherency state
            wire [2:0] l2_coh_rsp_state;

            // Intermediate signals for L2 cache width adaptation
            wire [MAX_L1_DATA_WIDTH-1:0] l2_cpu_req_data;
            wire [MAX_L1_DATA_WIDTH/8-1:0] l2_cpu_req_strb;
            wire [MAX_L1_DATA_WIDTH-1:0] l2_cpu_rsp_data;

            // Assign L2 cache request data and byte enables
            assign l2_cpu_req_data = |l1_dcache_req ?
                {{(MAX_L1_DATA_WIDTH-L1_DCACHE_DATA_WIDTH){1'b0}}, l1_dcache_wdata[0*L1_DCACHE_DATA_WIDTH +: L1_DCACHE_DATA_WIDTH]} :
                {{(MAX_L1_DATA_WIDTH-L1_ICACHE_DATA_WIDTH){1'b0}}, l1_icache_wdata[0*L1_ICACHE_DATA_WIDTH +: L1_ICACHE_DATA_WIDTH]};

            assign l2_cpu_req_strb = |l1_dcache_req ?
                {{(MAX_L1_DATA_WIDTH/8-L1_DCACHE_DATA_WIDTH/8){1'b0}}, {L1_DCACHE_DATA_WIDTH/8{1'b1}}} :
                {{(MAX_L1_DATA_WIDTH/8-L1_ICACHE_DATA_WIDTH/8){1'b0}}, {L1_ICACHE_DATA_WIDTH/8{1'b1}}};

            // Shared L2 cache instance (using generic cache module)
            cache #(
                .CACHE_LINE_SIZE(`L2_CACHE_LINE_SIZE),
                .CACHE_SIZE(`L2_CACHE_SIZE),
                .ASSOCIATIVITY(`L2_CACHE_ASSOCIATIVITY),
                .ADDR_WIDTH(ADDR_WIDTH),
                // L2 cache uses maximum L1 cache data width as input bit width
                .INPUT_DATA_WIDTH(MAX_L1_DATA_WIDTH),
                .OUTPUT_DATA_WIDTH(L2_OUT_WIDTH),
                .SUPPORT_COHERENCY(0),  // L2 cache is shared, doesn't need coherency
                .CACHE_LEVEL(`CACHE_LEVEL_L2),
                .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
            ) u_l2_cache (
                .clk(clk),
                .rst_n(rst_n),

                // CPU interface
                .cpu_req_valid(|l1_dcache_req || |l1_icache_req),
                .cpu_req_addr(|l1_dcache_req ? l1_dcache_addr[0*ADDR_WIDTH +: ADDR_WIDTH] : l1_icache_addr[0*ADDR_WIDTH +: ADDR_WIDTH]),
                .cpu_req_rw(|l1_dcache_req && l1_dcache_we[0]),
                // Use intermediate signals for connection
                .cpu_req_data(l2_cpu_req_data),
                .cpu_req_strb(l2_cpu_req_strb),
                .cpu_rsp_valid(core_l2_ready[0]),
                .cpu_rsp_data(l2_cpu_rsp_data),
                .cpu_rsp_error(),

                // Memory interface
                .mem_req_valid(l2_l3_req),
                .mem_req_addr(l2_l3_addr),
                .mem_req_rw(l2_l3_we),
                .mem_req_data(l2_l3_wdata),
                .mem_rsp_valid(l2_l3_ready),
                .mem_rsp_data(l2_l3_rdata),
                .mem_rsp_error(),

                // Coherency interface (not used, connected to 0)
                .coh_req_addr({ADDR_WIDTH{1'b0}}),
                .coh_req_valid(1'b0),
                .coh_req_type(3'd0),
                .coh_rsp_valid(),
                .coh_rsp_state()
            );

            // L2 cache doesn't need coherency, directly set snoop_state to default value
            assign snoop_state[0*2 +: 2] = 2'b00;

            // Connect response data according to different L1 cache bit widths
            // Connection for instruction cache
            assign l1_icache_data[0*L1_ICACHE_DATA_WIDTH +: L1_ICACHE_DATA_WIDTH] = l2_cpu_rsp_data[0*L1_ICACHE_DATA_WIDTH +: L1_ICACHE_DATA_WIDTH];

            // Connection for data cache
            assign l1_dcache_data[0*L1_DCACHE_DATA_WIDTH +: L1_DCACHE_DATA_WIDTH] = l2_cpu_rsp_data[0*L1_DCACHE_DATA_WIDTH +: L1_DCACHE_DATA_WIDTH];

            assign l1_dcache_ready[0] = core_l2_ready[0];
            assign l1_icache_ready[0] = core_l2_ready[0];

            if (NUM_CORES > 1) begin
                // Connection for multi-core, also considering different bit widths
                for (genvar j = 1; j < NUM_CORES; j = j + 1) begin
                    assign l1_icache_data[j*L1_ICACHE_DATA_WIDTH +: L1_ICACHE_DATA_WIDTH] = l2_cpu_rsp_data[0*L1_ICACHE_DATA_WIDTH +: L1_ICACHE_DATA_WIDTH];
                    assign l1_dcache_data[j*L1_DCACHE_DATA_WIDTH +: L1_DCACHE_DATA_WIDTH] = l2_cpu_rsp_data[0*L1_DCACHE_DATA_WIDTH +: L1_DCACHE_DATA_WIDTH];
                    assign l1_dcache_ready[j] = core_l2_ready[0];
                    assign l1_icache_ready[j] = core_l2_ready[0];
                end
            end

            // L3 cache instance (using generic cache module, optional)
            if (ENABLE_L3_CACHE) begin : l3_cache_gen
                cache #(
                    .CACHE_LINE_SIZE(`L3_CACHE_LINE_SIZE),
                    .CACHE_SIZE(`L3_CACHE_SIZE),
                    .ASSOCIATIVITY(`L3_CACHE_ASSOCIATIVITY),
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .INPUT_DATA_WIDTH(L2_CACHE_DATA_WIDTH),
                    .OUTPUT_DATA_WIDTH(MEM_WIDTH),
                    .SUPPORT_COHERENCY(0),  // L3 cache is shared, doesn't need coherency
                    .CACHE_LEVEL(`CACHE_LEVEL_L3),
                    .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
                ) u_l3_cache (
                    .clk(clk),
                    .rst_n(rst_n),

                    // CPU interface (connect to L2)
                    .cpu_req_valid(l2_l3_req),
                    .cpu_req_addr(l2_l3_addr),
                    .cpu_req_rw(l2_l3_we),
                    .cpu_req_data(l2_l3_wdata),
                    .cpu_req_strb({L2_CACHE_DATA_WIDTH/8{1'b1}}),
                    .cpu_rsp_valid(l2_l3_ready),
                    .cpu_rsp_data(l2_l3_rdata),
                    .cpu_rsp_error(),

                    // Memory interface
                    .mem_req_valid(mem_req),
                    .mem_req_addr(mem_addr),
                    .mem_req_rw(mem_we),
                    .mem_req_data(mem_wdata),
                    .mem_rsp_valid(mem_ready),
                    .mem_rsp_data(mem_rdata),
                    .mem_rsp_error(),

                    // Coherency interface
                    .coh_req_addr({ADDR_WIDTH{1'b0}}),
                    .coh_req_valid(1'b0),
                    .coh_req_type(3'd0),
                    .coh_rsp_valid(),
                    .coh_rsp_state()
                );
            end else begin : direct_l2_to_mem
                // Directly connect L2 to memory
                assign mem_req = l2_l3_req;
                assign mem_addr = l2_l3_addr;
                assign mem_wdata = l2_l3_wdata;
                assign mem_we = l2_l3_we;
                assign l2_l3_rdata = mem_rdata;
                assign l2_l3_ready = mem_ready;
            end
        end else begin : direct_l1_to_mem
            // Without L2 cache, L1 directly connects to memory
            // Create request arbitration logic for each core
            wire [NUM_CORES-1:0] core_mem_req;
            wire [NUM_CORES*ADDR_WIDTH-1:0] core_mem_addr;
            wire [NUM_CORES*512-1:0] core_mem_wdata;
            wire [NUM_CORES-1:0] core_mem_we;
            wire [NUM_CORES-1:0] core_mem_ready;
            wire [NUM_CORES*512-1:0] core_mem_rdata;

            // Simplified arbitration logic, only connect first core to memory
            // More complex arbiter should be implemented in practical applications
            assign mem_req = core_mem_req[0];
            assign mem_addr = core_mem_addr[0*ADDR_WIDTH +: ADDR_WIDTH];
            assign mem_wdata = core_mem_wdata[0*512 +: 512];
            assign mem_we = core_mem_we[0];
            assign core_mem_rdata[0*512 +: 512] = mem_rdata;
            assign core_mem_ready[0] = mem_ready;

            // Directly connect L1 cache to memory interface
            genvar i;
            for (i = 0; i < NUM_CORES; i = i + 1) begin : l1_to_mem_conn
                assign core_mem_req[i] = l1_dcache_req[i] || l1_icache_req[i];
                assign core_mem_addr[i*ADDR_WIDTH +: ADDR_WIDTH] =
                    l1_dcache_req[i] ? l1_dcache_addr[i*ADDR_WIDTH +: ADDR_WIDTH] : l1_icache_addr[i*ADDR_WIDTH +: ADDR_WIDTH];
                assign core_mem_we[i] = l1_dcache_req[i] && l1_dcache_we[i];
                assign core_mem_wdata[i*512 +: 512] = l1_dcache_wdata[i*512 +: 512];

                // Connect response signals
                assign l1_dcache_data[i*512 +: 512] = core_mem_rdata[i*512 +: 512];
                assign l1_icache_data[i*512 +: 512] = core_mem_rdata[i*512 +: 512];
                assign l1_dcache_ready[i] = core_mem_ready[i];
                assign l1_icache_ready[i] = core_mem_ready[i];

                // Not using snoop interface, set default values
                assign snoop_ready[i] = 1'b1;
                assign snoop_state[i*2 +: 2] = 2'b00;
            end

            if (NUM_CORES > 1) begin
                for (i = 1; i < NUM_CORES; i = i + 1) begin : multi_core_conn
                    assign core_mem_rdata[i*512 +: 512] = mem_rdata;
                    assign core_mem_ready[i] = mem_ready;
                end
            end
        end
    endgenerate

    // Generate multiple CPU cores with L1 cache
    generate
        genvar i;
        for (i = 0; i < NUM_CORES; i = i + 1) begin : core_gen
            if (CPU_TYPE == 0) begin : riscv_implementation
                // Create intermediate signals for 32-bit to 64-bit zero extension
                wire [ADDR_WIDTH-1:0] l1_icache_addr_64;
                wire [ADDR_WIDTH-1:0] l1_dcache_addr_64;
                wire icache_mem_req_rw;

                // Intermediate signals between CPU core and L1 cache
                wire icache_req;
                wire [ADDR_WIDTH-1:0] icache_addr;
                wire [L1_ICACHE_DATA_WIDTH-1:0] icache_data;  // Using instruction cache dedicated data width
                wire icache_ready;
                wire dcache_req;
                wire [ADDR_WIDTH-1:0] dcache_addr;
                wire dcache_we;
                wire dcache_ready;

                // Cache side uses dedicated data width
                wire [L1_DCACHE_DATA_WIDTH-1:0] dcache_wdata;
                wire [L1_DCACHE_DATA_WIDTH-1:0] dcache_rdata;
                wire [L1_DCACHE_DATA_WIDTH/8-1:0] dcache_byte_en;

                assign l1_icache_addr_64 = {{32{1'b0}}, l1_icache_addr[i*32 +: 32]};
                assign l1_dcache_addr_64 = {{32{1'b0}}, l1_dcache_addr[i*32 +: 32]};
                assign icache_mem_req_rw = 1'b0;  // Instruction cache is always read operation

                // Create intermediate signals for coherency interface (3-bit width)
                wire [2:0] icache_coh_rsp_state;
                wire [2:0] dcache_coh_rsp_state;

                // Connect 3-bit coherency state to 2-bit snoop_state
                assign snoop_state[i*2 +: 2] = icache_coh_rsp_state[1:0] | dcache_coh_rsp_state[1:0];

                // RISC-V CPU core instance
                riscv64_core #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(L1_DCACHE_DATA_WIDTH),
                    .L1_ICACHE_DATA_WIDTH(L1_ICACHE_DATA_WIDTH),
                    .L1_DCACHE_DATA_WIDTH(L1_DCACHE_DATA_WIDTH),
                    .CORE_ID(i)
                ) u_riscv64_core (
                    .clk(clk),
                    .rst_n(rst_n),

                    // Instruction cache interface
                    .icache_req_o(icache_req),
                    .icache_addr_o(icache_addr),
                    .icache_data_i(icache_data),
                    .icache_ready_i(icache_ready),

                    // Data cache interface
                    .dcache_req_o(dcache_req),
                    .dcache_addr_o(dcache_addr),
                    .dcache_wdata_o(dcache_wdata),
                    .dcache_rdata_i(dcache_rdata),
                    .dcache_we_o(dcache_we),
                    .dcache_byte_en_o(dcache_byte_en),
                    .dcache_ready_i(dcache_ready),

                    // Snoop interface
                    .snoop_valid_i(snoop_valid[i]),
                    .snoop_addr_i(snoop_addr[i*ADDR_WIDTH +: ADDR_WIDTH]),
                    .snoop_req_type_i(snoop_req_type[i*2 +: 2]),
                    .snoop_ready_o(snoop_ready[i]),
                    .snoop_hit_o(snoop_hit[i]),
                    .snoop_state_o(snoop_state[i*2 +: 2]),
                    .snoop_data_o(snoop_data[i*512 +: 512]),

                    // Interrupt and debugging
                    .timer_interrupt_i(1'b0),
                    .external_interrupt_i(ext_int),
                    .software_interrupt_i(1'b0),

                    // Debug interface - Can be connected to debug module
                    .debug_pc_o(),
                    .debug_instr_o(),
                    .debug_wb_valid_o(),
                    .debug_wb_rd_o(),
                    .debug_wb_value_o()
                );

            `ifdef DEBUG
                // Add debug information to track instruction request signal flow
                always @(posedge clk) begin
                    if (icache_req) begin
                        $display("[%0t ps] CPU CORE %d: icache_req=%b, icache_addr=0x%h",
                                 $time, i, icache_req, icache_addr);
                    end
                    if (l1_icache_req[i]) begin
                        $display("[%0t ps] CPU TOP CORE %d: l1_icache_req=%b, l1_icache_addr=0x%h",
                                 $time, i, l1_icache_req[i], l1_icache_addr_64);
                    end
                end
            `endif

                // L1 instruction cache instance (using generic cache module)
                cache #(
                    .CACHE_LINE_SIZE(`L1_ICACHE_LINE_SIZE),
                    .CACHE_SIZE(`L1_ICACHE_SIZE),
                    .ASSOCIATIVITY(`L1_ICACHE_ASSOCIATIVITY),
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .INPUT_DATA_WIDTH(L1_ICACHE_DATA_WIDTH),
                    .OUTPUT_DATA_WIDTH(L1_OUT_WIDTH),
                    .SUPPORT_COHERENCY(1),  // L1 cache is core-private, requires coherency between multiple cores
                    .CACHE_LEVEL(`CACHE_LEVEL_L1),
                    .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
                ) u_l1_icache (
                    .clk(clk),
                    .rst_n(rst_n),

                    // CPU interface
                    .cpu_req_valid(icache_req),
                    .cpu_req_addr(icache_addr),
                    .cpu_req_rw(1'b0),
                    .cpu_req_data({L1_ICACHE_DATA_WIDTH{1'd0}}),
                    .cpu_req_strb({L1_ICACHE_DATA_WIDTH/8{1'b1}}),
                    .cpu_rsp_valid(icache_ready),
                    .cpu_rsp_data(icache_data),
                    .cpu_rsp_error(),

                    // Memory interface (connected to width adapter)
                    .mem_req_valid(l1_icache_req[i]),
                    .mem_req_addr(l1_icache_addr_64),
                    .mem_req_rw(icache_mem_req_rw),
                    // Simplified indexed access method
                    .mem_req_data(l1_icache_wdata[L1_OUT_WIDTH*i +: L1_OUT_WIDTH]),
                    .mem_rsp_valid(l1_icache_ready[i]),
                    // Simplified indexed access method
                    .mem_rsp_data(l1_icache_data[L1_OUT_WIDTH*i +: L1_OUT_WIDTH]),
                    .mem_rsp_error(),

                    // Coherency interface (connected to snoop signals)
                    .coh_req_addr(l1_icache_addr_64),
                    .coh_req_valid(snoop_valid[i]),
                    .coh_req_type({1'b0, snoop_req_type[i*2 +: 2]}),
                    .coh_rsp_valid(snoop_ready[i]),
                    .coh_rsp_state(icache_coh_rsp_state)
                );

                // L1 data cache instance (using generic cache module)
                cache #(
                    .CACHE_LINE_SIZE(`L1_DCACHE_LINE_SIZE),
                    .CACHE_SIZE(`L1_DCACHE_SIZE),
                    .ASSOCIATIVITY(`L1_DCACHE_ASSOCIATIVITY),
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .INPUT_DATA_WIDTH(L1_DCACHE_DATA_WIDTH),
                    .OUTPUT_DATA_WIDTH(L1_OUT_WIDTH),
                    .SUPPORT_COHERENCY(1),  // L1 cache is core-private, requires coherency between multiple cores
                    .CACHE_LEVEL(`CACHE_LEVEL_L1),
                    .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
                ) u_l1_dcache (
                    .clk(clk),
                    .rst_n(rst_n),

                    // CPU interface
                    .cpu_req_valid(dcache_req),
                    .cpu_req_addr(dcache_addr),
                    .cpu_req_rw(dcache_we),
                    .cpu_req_data(dcache_wdata),
                    .cpu_req_strb(dcache_byte_en),
                    .cpu_rsp_valid(dcache_ready),
                    .cpu_rsp_data(dcache_rdata),
                    .cpu_rsp_error(),

                    // Memory interface (connected to width adapter)
                    .mem_req_valid(l1_dcache_req[i]),
                    .mem_req_addr(l1_dcache_addr_64),
                    .mem_req_rw(l1_dcache_we[i]),
                    // Simplified indexed access method
                    .mem_req_data(l1_dcache_wdata[L1_OUT_WIDTH*i +: L1_OUT_WIDTH]),
                    .mem_rsp_valid(l1_dcache_ready[i]),
                    // Simplified indexed access method
                    .mem_rsp_data(l1_dcache_data[L1_OUT_WIDTH*i +: L1_OUT_WIDTH]),
                    .mem_rsp_error(),

                    // Coherency interface (connected to snoop signals)
                    .coh_req_addr(l1_dcache_addr_64),
                    .coh_req_valid(snoop_valid[i]),
                    .coh_req_type({1'b0, snoop_req_type[i*2 +: 2]}),
                    .coh_rsp_valid(snoop_ready[i]),
                    .coh_rsp_state(dcache_coh_rsp_state)
                );
            end
            // Reserved for other CPU type implementations
            else if (CPU_TYPE == 1) begin : other_cpu_implementation
                // Other CPU type implementations can be added here
                // This is just a placeholder, actual implementation needs to be written according to specific CPU architecture
                assign mem_req = 1'b0;
                assign mem_addr = {ADDR_WIDTH{1'b0}};
                assign mem_wdata = {512{1'b0}};
                assign mem_we = 1'b0;
            end
        end
    endgenerate

endmodule