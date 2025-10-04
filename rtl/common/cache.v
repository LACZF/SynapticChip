`timescale 1ns / 1ps

module cache #(
    parameter CACHE_LINE_SIZE = 64,          // Cache line size in bytes
    parameter CACHE_SIZE = 4096,             // Cache size in bytes
    parameter ASSOCIATIVITY = 4,             // Cache associativity (1=direct mapped, 2=2-way, etc.)
    parameter ADDR_WIDTH = 32,               // Address width
    parameter DATA_WIDTH = 32,               // Data width
    parameter SUPPORT_COHERENCY = 1,         // 1=support cache coherency, 0=not support
    parameter CACHE_LEVEL = 2,               // Cache level (1=L1, 2=L2, 3=L3, etc.)
    parameter REPLACEMENT_POLICY = "LRU"     // Replacement policy ("LRU", "FIFO", "RANDOM")
)(
    input wire clk,
    input wire rst_n,

    // CPU interface
    input wire cpu_req_valid,
    input wire [ADDR_WIDTH-1:0] cpu_req_addr,
    input wire cpu_req_rw,                   // 0=read, 1=write
    input wire [DATA_WIDTH-1:0] cpu_req_data,
    input wire [DATA_WIDTH/8-1:0] cpu_req_strb,
    output wire cpu_rsp_valid,
    output wire [DATA_WIDTH-1:0] cpu_rsp_data,
    output wire cpu_rsp_error,

    // Memory interface
    output wire mem_req_valid,
    output wire [ADDR_WIDTH-1:0] mem_req_addr,
    output wire mem_req_rw,
    output wire [CACHE_LINE_SIZE-1:0] mem_req_data,
    input wire mem_rsp_valid,
    input wire [CACHE_LINE_SIZE-1:0] mem_rsp_data,
    input wire mem_rsp_error,

    // Coherency interface (only used if SUPPORT_COHERENCY=1)
    input wire [ADDR_WIDTH-1:0] coh_req_addr,
    input wire coh_req_valid,
    input wire [2:0] coh_req_type,           // 0=Read, 1=Write, 2=Invalidate
    output wire coh_rsp_valid,
    output wire [2:0] coh_rsp_state          // 0=Invalid, 1=Shared, 2=Exclusive, 3=Modified
);

    // Calculate cache parameters
    localparam LINE_WIDTH = $clog2(CACHE_LINE_SIZE);
    localparam NUM_SETS = (CACHE_SIZE / CACHE_LINE_SIZE) / ASSOCIATIVITY;
    localparam SET_WIDTH = $clog2(NUM_SETS);
    localparam TAG_WIDTH = ADDR_WIDTH - SET_WIDTH - LINE_WIDTH;
    localparam WAY_WIDTH = $clog2(ASSOCIATIVITY);

    // Cache line offset
    wire [LINE_WIDTH-1:0] line_offset = cpu_req_addr[LINE_WIDTH-1:0];
    // Cache set index
    wire [SET_WIDTH-1:0] set_index = cpu_req_addr[LINE_WIDTH+SET_WIDTH-1:LINE_WIDTH];
    // Cache tag
    wire [TAG_WIDTH-1:0] tag = cpu_req_addr[ADDR_WIDTH-1:LINE_WIDTH+SET_WIDTH];

    // Cache memory arrays
    // Valid, Dirty, Tag, Data, and LRU bits
    reg valid [ASSOCIATIVITY-1:0][NUM_SETS-1:0];
    reg dirty [ASSOCIATIVITY-1:0][NUM_SETS-1:0];
    reg [TAG_WIDTH-1:0] tag_array [ASSOCIATIVITY-1:0][NUM_SETS-1:0];
    reg [CACHE_LINE_SIZE-1:0] data_array [ASSOCIATIVITY-1:0][NUM_SETS-1:0];
    reg [WAY_WIDTH-1:0] lru_array [NUM_SETS-1:0];

    // MESI protocol states
    localparam INVALID   = 3'd0;
    localparam SHARED    = 3'd1;
    localparam EXCLUSIVE = 3'd2;
    localparam MODIFIED  = 3'd3;

    // Coherency state
    reg [2:0] coherency_state [ASSOCIATIVITY-1:0][NUM_SETS-1:0];

    // States for FSM
    localparam IDLE = 3'd0;
    localparam CHECK_HIT = 3'd1;
    localparam MEM_READ = 3'd2;
    localparam MEM_WRITE = 3'd3;
    localparam UPDATE_CACHE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal signals
    reg hit;
    reg [WAY_WIDTH-1:0] hit_way;
    reg [ASSOCIATIVITY-1:0] way_hit;
    reg [ASSOCIATIVITY-1:0] way_dirty;
    reg [CACHE_LINE_SIZE-1:0] write_data;
    reg evict;
    reg [WAY_WIDTH-1:0] evict_way;

    // FSM state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:
                if (cpu_req_valid) begin
                    next_state = CHECK_HIT;
                end
            CHECK_HIT:
                if (hit) begin
                    next_state = IDLE;
                end else begin
                    // Check if we need to evict a dirty line
                    if (way_dirty[evict_way]) begin
                        next_state = MEM_WRITE;
                    end else begin
                        next_state = MEM_READ;
                    end
                end
            MEM_WRITE:
                if (mem_rsp_valid) begin
                    next_state = MEM_READ;
                end
            MEM_READ:
                if (mem_rsp_valid) begin
                    next_state = UPDATE_CACHE;
                end
            UPDATE_CACHE:
                next_state = IDLE;
        endcase
    end

    // Hit detection
    always @(*) begin
        hit = 1'b0;
        hit_way = 0;
        way_hit = {ASSOCIATIVITY{1'b0}};
        for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
            if (valid[i][set_index] && (tag_array[i][set_index] == tag)) begin
                hit = 1'b1;
                hit_way = i;
                way_hit[i] = 1'b1;
            end
        end
    end

    // Get dirty ways
    always @(*) begin
        way_dirty = {ASSOCIATIVITY{1'b0}};
        for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
            way_dirty[i] = valid[i][set_index] && dirty[i][set_index];
        end
    end

    // Replacement policy implementation
    always @(*) begin
        evict_way = 0;
        case (REPLACEMENT_POLICY)
            "LRU": begin
                evict_way = lru_array[set_index];
            end
            "FIFO": begin
                // Simplified FIFO implementation
                // In a real design, you would track FIFO order with additional state
                evict_way = 0;
            end
            "RANDOM": begin
                // Simplified random implementation
                // In a real design, you would use a random number generator
                evict_way = 0;
            end
            default: begin
                evict_way = lru_array[set_index];
            end
        endcase
    end

    // Update LRU on hit
    always @(posedge clk) begin
        if (state == CHECK_HIT && hit) begin
            // In a real design, you would update the LRU state here
            // This is a simplified implementation
            lru_array[set_index] <= hit_way;
        end
    end

    // Cache write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize cache arrays
            for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
                for (integer j = 0; j < NUM_SETS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                    dirty[i][j] <= 1'b0;
                    tag_array[i][j] <= {TAG_WIDTH{1'b0}};
                    data_array[i][j] <= {CACHE_LINE_SIZE{1'b0}};
                end
            end
            // Initialize LRU array
            for (integer j = 0; j < NUM_SETS; j = j + 1) begin
                lru_array[j] <= {WAY_WIDTH{1'b0}};
            end
            // Initialize coherency state to Invalid
            for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
                for (integer j = 0; j < NUM_SETS; j = j + 1) begin
                    coherency_state[i][j] <= INVALID;
                end
            end
        end else begin
            // Handle cache write on CPU write hit
            if (state == CHECK_HIT && hit && cpu_req_rw) begin
                // Update data
                data_array[hit_way][set_index] <= write_data;
                // Mark as dirty
                dirty[hit_way][set_index] <= 1'b1;
                // Update coherency state according to MESI protocol
                if (SUPPORT_COHERENCY) begin
                    case (coherency_state[hit_way][set_index])
                        EXCLUSIVE, MODIFIED: coherency_state[hit_way][set_index] <= MODIFIED;
                        SHARED: coherency_state[hit_way][set_index] <= MODIFIED; // Write miss in shared state requires invalidating other caches
                        default: coherency_state[hit_way][set_index] <= MODIFIED;
                    endcase
                end
            end
            // Update cache on memory read completion
            if (state == UPDATE_CACHE) begin
                // Update valid, tag, and data
                valid[evict_way][set_index] <= 1'b1;
                tag_array[evict_way][set_index] <= tag;
                data_array[evict_way][set_index] <= mem_rsp_data;
                // Clear dirty bit
                dirty[evict_way][set_index] <= 1'b0;
                // Update coherency state according to MESI protocol
                if (SUPPORT_COHERENCY) begin
                    // For a read miss, we assume a clean line from memory, so set to Exclusive
                    coherency_state[evict_way][set_index] <= EXCLUSIVE;
                end
            end
        end
    end

    // Prepare write data (merge with existing data)
    always @(*) begin
        write_data = data_array[hit_way][set_index];
        // Update only the bytes specified by the strobe
        for (integer i = 0; i < DATA_WIDTH/8; i = i + 1) begin
            if (cpu_req_strb[i]) begin
                write_data[i*8 +: 8] = cpu_req_data[i*8 +: 8];
            end
        end
    end

    // Output assignments
    assign cpu_rsp_valid = (state == CHECK_HIT && hit) || (state == UPDATE_CACHE);
    assign cpu_rsp_data = hit ? data_array[hit_way][set_index][cpu_req_addr[LINE_WIDTH-1:0] +: DATA_WIDTH] :
                                mem_rsp_data[cpu_req_addr[LINE_WIDTH-1:0] +: DATA_WIDTH];
    assign cpu_rsp_error = 1'b0; // Simplified, no error handling

    assign mem_req_valid = (state == MEM_READ) || (state == MEM_WRITE);
    assign mem_req_addr = (state == MEM_WRITE) ? {tag_array[evict_way][set_index], set_index, {LINE_WIDTH{1'b0}}} :
                                                {tag, set_index, {LINE_WIDTH{1'b0}}};
    assign mem_req_rw = (state == MEM_WRITE) ? 1'b1 : 1'b0;
    assign mem_req_data = data_array[evict_way][set_index];

    // Coherency interface outputs (if supported)
    generate
        if (SUPPORT_COHERENCY) begin
            assign coh_rsp_valid = coh_req_valid;

            // MESI protocol coherency response logic
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    // No action
                end else if (coh_req_valid) begin
                    // Search for the address in all ways
                    for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
                        if (valid[i][set_index] && (tag_array[i][set_index] == tag)) begin
                            // Found a matching cache line
                            case (coh_req_type)
                                3'd0: begin // Read request
                                    case (coherency_state[i][set_index])
                                        MODIFIED: begin
                                            // Need to write back to memory
                                            // In a real design, you would trigger a write back here
                                            coherency_state[i][set_index] <= SHARED;
                                        end
                                        EXCLUSIVE: begin
                                            coherency_state[i][set_index] <= SHARED;
                                        end
                                        // Shared and Invalid states don't change
                                    endcase
                                end
                                3'd1: begin // Write request
                                    case (coherency_state[i][set_index])
                                        MODIFIED, EXCLUSIVE, SHARED: begin
                                            // Invalidate the line
                                            coherency_state[i][set_index] <= INVALID;
                                            valid[i][set_index] <= 1'b0;
                                            // If modified, need to write back
                                            if (coherency_state[i][set_index] == MODIFIED) begin
                                                // In a real design, you would trigger a write back here
                                            end
                                        end
                                    endcase
                                end
                                3'd2: begin // Invalidate request
                                    coherency_state[i][set_index] <= INVALID;
                                    valid[i][set_index] <= 1'b0;
                                    // If modified, need to write back
                                    if (coherency_state[i][set_index] == MODIFIED) begin
                                        // In a real design, you would trigger a write back here
                                    end
                                end
                            endcase
                        end
                    end
                end
            end

            // Simplified coherency state output (check way 0 only)
            assign coh_rsp_state = coherency_state[0][set_index];
        end else begin
            assign coh_rsp_valid = 1'b0;
            assign coh_rsp_state = INVALID;
        end
    endgenerate

endmodule