// Arbiter module - supports load-based dynamic bus selection
module ring_arbiter #(
    parameter NUM_RINGS                            = 2,
    parameter ADDR_WIDTH                           = 32,
    parameter DATA_WIDTH                           = 64,
    parameter NODE_ID_WIDTH                        = 8,
    parameter MATCH_TYPE_WIDTH                     = 2
) (
    input  wire                                    clk,
    input  wire                                    rst_n,

    // Main request interface
    input  wire                                    req_valid,
    input  wire [ADDR_WIDTH-1:0]                   req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]             req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]                req_target_id,
    input  wire [DATA_WIDTH-1:0]                   req_data,
    input  wire [NUM_RINGS-1:0]                    req_ring_mask,      // Optional bus mask
    input  wire [NUM_RINGS-1:0]                    req_ring_disable,   // Disabled buses
    output wire                                    req_ready,

    // Ring bus interface
    output reg  [NUM_RINGS-1:0]                    ring_req_valid,
    input  wire [NUM_RINGS-1:0]                    ring_req_ready,
    output reg  [NUM_RINGS*ADDR_WIDTH-1:0]         ring_req_addr,
    output reg  [NUM_RINGS*MATCH_TYPE_WIDTH-1:0]   ring_req_match_type,
    output reg  [NUM_RINGS*NODE_ID_WIDTH-1:0]      ring_req_target_id,
    output reg  [NUM_RINGS*DATA_WIDTH-1:0]         ring_req_data,

    // Status outputs
    output wire [NUM_RINGS-1:0]                    ring_busy
);

    reg  [NUM_RINGS-1:0]                           ring_priority;   // Polling priority pointer
    reg  [NUM_RINGS-1:0]                           valid_rings;     // Valid buses
    wire [NUM_RINGS-1:0]                           available_rings; // Available buses
    reg  [NUM_RINGS*3-1:0]                         load_count;      // Load count for each bus, in 1D array format

    // Calculate available Ring buses
    assign available_rings = ring_req_ready & ~req_ring_disable;

    // Loop variable declaration
    integer i;

    // Load monitoring counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_count <= {NUM_RINGS*3{1'b0}};
        end else begin
            for (i = 0; i < NUM_RINGS; i = i + 1) begin
                // Increase load count
                if (ring_req_valid[i] && ring_req_ready[i]) begin
                    load_count[i*3 +: 3] <= load_count[i*3 +: 3] + 1;
                end
                // Periodically decrease load count (simulate load decay)
                if (load_count[i*3 +: 3] > 0 && (load_count[i*3 +: 3] % 4) == 0) begin
                    load_count[i*3 +: 3] <= load_count[i*3 +: 3] - 1;
                end
            end
        end
    end

    // Load-based dynamic bus selection logic
    function [NUM_RINGS-1:0] select_best_ring;
        input [NUM_RINGS-1:0] available; // Available buses
        input [NUM_RINGS-1:0] mask;      // Specified bus mask
        integer i;
        integer min_load;
        integer best_ring;
        begin
            // Initialize
            min_load = 8; // Maximum possible load value + 1
            best_ring = 0;
            select_best_ring = {NUM_RINGS{1'b0}};

            // Combine mask and availability
            valid_rings = available & mask;

            // If a specified bus mask exists, select the lightest loaded from the mask first
            if (|valid_rings) begin
                for (i = 0; i < NUM_RINGS; i = i + 1) begin
                    if (valid_rings[i] && (load_count[i*3 +: 3] < min_load)) begin
                        min_load = load_count[i*3 +: 3];
                        best_ring = i;
                    end
                end
                select_best_ring[best_ring] = 1'b1;
            end else if (|available) begin
                // If no mask is specified or all specified masked buses are unavailable, select from all available buses
                for (i = 0; i < NUM_RINGS; i = i + 1) begin
                    if (available[i] && (load_count[i*3 +: 3] < min_load)) begin
                        min_load = load_count[i*3 +: 3];
                        best_ring = i;
                    end
                end
                select_best_ring[best_ring] = 1'b1;
            end
        end
    endfunction

    // Priority arbitration logic
    always @(*) begin
        ring_req_valid = {NUM_RINGS{1'b0}};

        if (req_valid) begin
            // Use load-based dynamic selection function
            ring_req_valid = select_best_ring(available_rings, req_ring_mask);
        end
    end

    // Output data to selected Ring bus
    always @(*) begin
        for (i = 0; i < NUM_RINGS; i = i + 1) begin
            ring_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH] = req_addr;
            ring_req_match_type[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] = req_match_type;
            ring_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = req_target_id;
            ring_req_data[i*DATA_WIDTH +: DATA_WIDTH] = req_data;
        end
    end

    // Ready signal
    assign req_ready = |(ring_req_valid & ring_req_ready);

    // Bus busy status
    assign ring_busy = ~ring_req_ready;

endmodule