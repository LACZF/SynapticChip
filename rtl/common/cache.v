module ip4_cache #(
    parameter CACHE_LINE_SIZE               = 64,       // Cache line size in bytes
    parameter CACHE_SIZE                    = 4096,     // Cache size in bytes
    parameter ASSOCIATIVITY                 = 4,        // Cache associativity (1=direct mapped, 2=2-way, etc.)
    parameter ADDR_WIDTH                    = 64,       // Address width
    parameter INPUT_DATA_WIDTH              = 64,       // Data width (CPU interface)
    parameter OUTPUT_DATA_WIDTH             = 64,       // Memory data width (new parameter)
    parameter SUPPORT_COHERENCY             = 1,        // 1=support cache coherency, 0=not support
    parameter CACHE_LEVEL                   = 2,        // Cache level (1=L1, 2=L2, 3=L3, etc.)
    parameter BYPASS_START_ADDR             = 32'h9000_0000,
    parameter BYPASS_START_END              = 32'hFFFF_FFFF,
    parameter REPLACEMENT_POLICY            = "LRU"     // Replacement policy ("LRU", "FIFO", "RANDOM")
)(
    input wire                              clk,
    input wire                              rst_n,

    // CPU interface
    input  wire                             cpu_req_valid_i,
    input  wire [ADDR_WIDTH-1:0]            cpu_req_addr_i,
    input  wire                             cpu_req_rw_i,                   // 0=read, 1=write
    input  wire [INPUT_DATA_WIDTH-1:0]      cpu_req_data_i,
    input  wire [INPUT_DATA_WIDTH/8-1:0]    cpu_req_strb_i,
    output wire                             cpu_rsp_valid_o,
    output wire [INPUT_DATA_WIDTH-1:0]      cpu_rsp_data_o,
    output wire                             cpu_rsp_error_o,

    // Memory interface
    output wire                             mem_req_valid_o,
    output wire [ADDR_WIDTH-1:0]            mem_req_addr_o,
    output wire                             mem_req_rw_o,
    output wire [OUTPUT_DATA_WIDTH-1:0]     mem_req_data_o,
    input  wire                             mem_rsp_valid_i,
    input  wire [OUTPUT_DATA_WIDTH-1:0]     mem_rsp_data_i,
    input  wire                             mem_rsp_error_i,

    // Coherency interface (only used if SUPPORT_COHERENCY=1)
    input  wire [ADDR_WIDTH-1:0]            coh_req_addr_i,
    input  wire                             coh_req_valid_i,
    input  wire [2:0]                       coh_req_type_i,          // 0=Read, 1=Write, 2=Invalidate
    output wire                             coh_rsp_valid_o,
    output wire [2:0]                       coh_rsp_state_o          // 0=Invalid, 1=Shared, 2=Exclusive, 3=Modified
);

    // Calculate cache parameters
    localparam LINE_WIDTH = $clog2(CACHE_LINE_SIZE);
    localparam NUM_SETS   = (CACHE_SIZE / CACHE_LINE_SIZE) / ASSOCIATIVITY;
    localparam SET_WIDTH  = $clog2(NUM_SETS);
    localparam TAG_WIDTH  = ADDR_WIDTH - SET_WIDTH - LINE_WIDTH;
    localparam WAY_WIDTH  = $clog2(ASSOCIATIVITY);

    // Calculate transfer parameters for handling different data widths
    // Calculate number of transfers needed from CPU data width to memory data width
    localparam TRANSFER_COUNT = (INPUT_DATA_WIDTH > OUTPUT_DATA_WIDTH) ?
                              ((INPUT_DATA_WIDTH + OUTPUT_DATA_WIDTH - 1) / OUTPUT_DATA_WIDTH) : 1;
    localparam TRANSFER_COUNT_WIDTH = $clog2(TRANSFER_COUNT + 1);

    // Safely calculate truncation offset from memory data width to CPU data width
    localparam MEM_TO_CPU_TRUNC_OFFSET = (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH) ?
                                        (OUTPUT_DATA_WIDTH - INPUT_DATA_WIDTH) : 0;

    // Cache line offset
    wire [LINE_WIDTH-1:0] line_offset = cpu_req_addr_i[LINE_WIDTH-1:0];
    // Cache set index
    wire [SET_WIDTH-1:0] set_index = cpu_req_addr_i[LINE_WIDTH+SET_WIDTH-1:LINE_WIDTH];
    // Cache tag
    wire [TAG_WIDTH-1:0] tag = cpu_req_addr_i[ADDR_WIDTH-1:LINE_WIDTH+SET_WIDTH];

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

    // New states for multi-transfer support
    localparam MEM_READ_MULTI = 3'd5;
    localparam MEM_WRITE_MULTI = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal signal to control bypass mode
    reg bypass_mode;
    always @(*) begin
        bypass_mode = (state == IDLE) && cpu_req_valid_i &&
                     (BYPASS_START_ADDR <= cpu_req_addr_i && cpu_req_addr_i <= BYPASS_START_END);
    end

    // Internal signals
    reg hit;
    reg [WAY_WIDTH-1:0] hit_way;
    reg [ASSOCIATIVITY-1:0] way_hit;
    reg [ASSOCIATIVITY-1:0] way_dirty;
    reg [CACHE_LINE_SIZE-1:0] write_data;
    reg evict;
    reg [WAY_WIDTH-1:0] evict_way;

    // Multi-transfer signals
    reg [TRANSFER_COUNT_WIDTH-1:0] transfer_count;
    reg [CACHE_LINE_SIZE-1:0] multi_transfer_buffer;
    reg [CACHE_LINE_SIZE-1:0] cpu_data_buffer; // Used to store complete CPU data

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
                if (cpu_req_valid_i) begin
                    if (BYPASS_START_ADDR <= cpu_req_addr_i && cpu_req_addr_i <= BYPASS_START_END) begin
                        /* BYPASS Cache - handled by assign statements outside the always block */
                        next_state = (cpu_req_rw_i == 0) ? MEM_READ : MEM_WRITE;
                    end else begin
                        next_state = CHECK_HIT;
                    end
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
                if (mem_rsp_valid_i) begin
                    if (TRANSFER_COUNT > 1) begin
                        next_state = MEM_WRITE_MULTI;
                    end else begin
                        next_state = MEM_READ;
                    end
                end
            MEM_WRITE_MULTI:
                if (mem_rsp_valid_i) begin
                    if (transfer_count == TRANSFER_COUNT - 1) begin
                        next_state = MEM_READ;
                    end
                end
            MEM_READ:
                if (mem_rsp_valid_i) begin
                    if (TRANSFER_COUNT > 1) begin
                        next_state = MEM_READ_MULTI;
                    end else begin
                        next_state = UPDATE_CACHE;
                    end
                end
            MEM_READ_MULTI:
                if (mem_rsp_valid_i) begin
                    if (transfer_count == TRANSFER_COUNT - 1) begin
                        next_state = UPDATE_CACHE;
                    end
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
            if (state == CHECK_HIT && hit && cpu_req_rw_i) begin
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
            // Update cache on memory read completion - Ensure cache is updated only after receiving memory response
            if (state == UPDATE_CACHE) begin
                // Update valid, tag, and data
                valid[evict_way][set_index] <= 1'b1;
                tag_array[evict_way][set_index] <= tag;
                if (TRANSFER_COUNT > 1) begin
                    data_array[evict_way][set_index] <= multi_transfer_buffer;
                end else begin
                    // For cases where memory data width is greater than CPU data width, we only use lower bits
                    if (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH) begin
                        data_array[evict_way][set_index] <= {{(CACHE_LINE_SIZE-INPUT_DATA_WIDTH){1'b0}}, mem_rsp_data_i[0 +: INPUT_DATA_WIDTH]};
                    end else begin
                        data_array[evict_way][set_index] <= mem_rsp_data_i[0 +: CACHE_LINE_SIZE];
                    end
                end
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
        for (integer i = 0; i < INPUT_DATA_WIDTH/8; i = i + 1) begin
            if (cpu_req_strb_i[i]) begin
                write_data[i*8 +: 8] = cpu_req_data_i[i*8 +: 8];
            end
        end
    end

    // CPU data buffer - Used to store complete CPU data during multi-transfer operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_data_buffer <= {CACHE_LINE_SIZE{1'b0}};
        end else if (state == IDLE && cpu_req_valid_i) begin
            // Store complete CPU request data
            if (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH) begin
                // When memory data width is greater than CPU data width, only use lower bits
                cpu_data_buffer <= {{(CACHE_LINE_SIZE-INPUT_DATA_WIDTH){1'b0}}, cpu_req_data_i};
            end else begin
                cpu_data_buffer <= cpu_req_data_i;
            end
        end
    end

    // Transfer count logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            transfer_count <= 0;
        end else begin
            case (state)
                MEM_WRITE:
                    if (mem_rsp_valid_i && TRANSFER_COUNT > 1) begin
                        transfer_count <= 1;
                    end
                MEM_READ:
                    if (mem_rsp_valid_i && TRANSFER_COUNT > 1) begin
                        transfer_count <= 1;
                    end
                MEM_WRITE_MULTI:
                    if (mem_rsp_valid_i) begin
                        transfer_count <= transfer_count + 1;
                    end
                MEM_READ_MULTI:
                    if (mem_rsp_valid_i) begin
                        transfer_count <= transfer_count + 1;
                    end
                default:
                    transfer_count <= 0;
            endcase
        end
    end

    // Multi-transfer buffer logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            multi_transfer_buffer <= {CACHE_LINE_SIZE{1'b0}};
        end else begin
            case (state)
                MEM_READ:
                    if (mem_rsp_valid_i) begin
                        multi_transfer_buffer[0 +: OUTPUT_DATA_WIDTH] <= mem_rsp_data_i;
                    end
                MEM_READ_MULTI:
                    if (mem_rsp_valid_i) begin
                        multi_transfer_buffer[transfer_count*OUTPUT_DATA_WIDTH +: OUTPUT_DATA_WIDTH] <= mem_rsp_data_i;
                    end
                MEM_WRITE:
                    if (mem_rsp_valid_i && TRANSFER_COUNT > 1) begin
                        // Initialize multi-transfer buffer
                        multi_transfer_buffer <= data_array[evict_way][set_index];
                    end
            endcase
        end
    end

    // Output assignments - Redesigned CPU response logic to ensure reliable timing
    reg cpu_rsp_valid_reg;
    reg [INPUT_DATA_WIDTH-1:0] cpu_rsp_data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_rsp_valid_reg <= 1'b0;
        end else begin
            // Immediate response for CPU read hit
            if (state == CHECK_HIT && hit && !cpu_req_rw_i) begin
                cpu_rsp_valid_reg <= 1'b1;
                cpu_rsp_data_reg <= data_array[hit_way][set_index][0 +: INPUT_DATA_WIDTH];
            end
            // Immediate response for CPU write operation (write-back cache)
            else if (state == CHECK_HIT && hit && cpu_req_rw_i) begin
                cpu_rsp_valid_reg <= 1'b1;
                cpu_rsp_data_reg <= cpu_req_data_i; // Write operation returns the written data
            end
            // Response after cache update completion (read miss)
            else if (state == UPDATE_CACHE) begin
                cpu_rsp_valid_reg <= 1'b1;
                if (TRANSFER_COUNT > 1) begin
                    cpu_rsp_data_reg <= multi_transfer_buffer[0 +: INPUT_DATA_WIDTH];
                end else begin
                    // For cases where memory data width is greater than CPU data width, we only use lower bits
                    cpu_rsp_data_reg <= mem_rsp_data_i[0 +: INPUT_DATA_WIDTH];
                end
            end
            // Clear response in other cases
            else begin
                cpu_rsp_valid_reg <= 1'b0;
            end
        end
    end

    // Output assignments
    assign cpu_rsp_valid_o = cpu_rsp_valid_reg;
    assign cpu_rsp_data_o = cpu_rsp_data_reg;
    assign cpu_rsp_error_o = 1'b0; // Simplified, no error handling

    assign mem_req_valid_o = (state == MEM_READ) || (state == MEM_WRITE) || (state == MEM_READ_MULTI) || (state == MEM_WRITE_MULTI);
    assign mem_req_addr_o = (state == MEM_WRITE || state == MEM_WRITE_MULTI) ?
                          {tag_array[evict_way][set_index], set_index, {LINE_WIDTH{1'b0}}} + (transfer_count * OUTPUT_DATA_WIDTH/8) :
                          {tag, set_index, {LINE_WIDTH{1'b0}}} + (transfer_count * OUTPUT_DATA_WIDTH/8);
    assign mem_req_rw_o = (state == MEM_WRITE || state == MEM_WRITE_MULTI) ? 1'b1 : 1'b0;
    assign mem_req_data_o = (state == MEM_WRITE) ?
                         (OUTPUT_DATA_WIDTH > INPUT_DATA_WIDTH) ?
                           {{MEM_TO_CPU_TRUNC_OFFSET{1'b0}}, cpu_req_data_i} :
                           data_array[evict_way][set_index][0 +: OUTPUT_DATA_WIDTH] :
                          (state == MEM_WRITE_MULTI) ? data_array[evict_way][set_index][transfer_count*OUTPUT_DATA_WIDTH +: OUTPUT_DATA_WIDTH] :
                          {OUTPUT_DATA_WIDTH{1'b0}};

    // Coherency interface outputs (if supported)
    generate
        if (SUPPORT_COHERENCY) begin
            reg coh_rsp_valid_reg;
            reg [2:0] coh_rsp_state_reg;

            // Ensure coh_rsp_valid has proper timing instead of directly connecting to coh_req_valid
            assign coh_rsp_valid_o = coh_rsp_valid_reg;
            assign coh_rsp_state_o = coh_rsp_state_reg;

            // MESI protocol coherency response logic
            integer way_found;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    coh_rsp_valid_reg <= 1'b0;
                    coh_rsp_state_reg <= INVALID;
                end else begin
                    // Clear response by default
                    coh_rsp_valid_reg <= 1'b0;

                    if (coh_req_valid_i) begin
                        // First check if address is in cache
                        way_found = -1;
                        for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
                            if (way_found == -1 && valid[i][set_index] && (tag_array[i][set_index] == tag)) begin
                                way_found = i;
                                // Use condition instead of break to terminate search early
                            end
                        end

                        // Handle coherency operations based on found way and request type
                        if (way_found != -1) begin
                            case (coh_req_type_i)
                                3'd0: begin // Read request
                                    case (coherency_state[way_found][set_index])
                                        MODIFIED: begin
                                            // Need to write back to memory
                                            // In a real design, you would trigger a write back here
                                            coherency_state[way_found][set_index] <= SHARED;
                                        end
                                        EXCLUSIVE: begin
                                            coherency_state[way_found][set_index] <= SHARED;
                                        end
                                        // Shared and Invalid states don't change
                                    endcase
                                end
                                3'd1: begin // Write request
                                    case (coherency_state[way_found][set_index])
                                        MODIFIED, EXCLUSIVE, SHARED: begin
                                            // Invalidate the line
                                            coherency_state[way_found][set_index] <= INVALID;
                                            valid[way_found][set_index] <= 1'b0;
                                            // If modified, need to write back
                                            if (coherency_state[way_found][set_index] == MODIFIED) begin
                                                // In a real design, you would trigger a write back here
                                            end
                                        end
                                    endcase
                                end
                                3'd2: begin // Invalidate request
                                    coherency_state[way_found][set_index] <= INVALID;
                                    valid[way_found][set_index] <= 1'b0;
                                    // If modified, need to write back
                                    if (coherency_state[way_found][set_index] == MODIFIED) begin
                                        // In a real design, you would trigger a write back here
                                    end
                                end
                            endcase
                            // Output coherency response
                            coh_rsp_valid_reg <= 1'b1;
                            coh_rsp_state_reg <= coherency_state[way_found][set_index];
                        end else begin
                            // Address not in cache, return invalid state
                            coh_rsp_valid_reg <= 1'b1;
                            coh_rsp_state_reg <= INVALID;
                        end
                    end
                end
            end
        end else begin
            assign coh_rsp_valid_o = 1'b0;
            assign coh_rsp_state_o = INVALID;
        end
    endgenerate

endmodule