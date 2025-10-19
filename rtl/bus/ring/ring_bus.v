`include "ring_bus_params.v"

module ring_bus #(
    parameter NUM_RINGS                           = 2,        // Number of Ring buses
    parameter NUM_NODES                           = 4,        // Number of nodes per Ring
    parameter ADDR_WIDTH                          = 64,       // Address width
    parameter DATA_WIDTH                          = 64,       // Data width
    parameter OPCODE_WIDTH                        = 8,        // Opcode width: read/write/response etc.
    parameter RING_ID_WIDTH                       = 4,        // Ring ID width
    parameter NODE_ID_WIDTH                       = 8,        // Node ID width
    parameter TX_FIFO_DEPTH                       = 4,        // Transmit FIFO depth
    parameter RX_FIFO_DEPTH                       = 4,        // Receive FIFO depth
    parameter RSP_FIFO_DEPTH                      = 4,        // Response FIFO depth
    parameter MATCH_TYPE_WIDTH                    = 2         // Match type width
) (
    input  wire                                   clk,
    input  wire                                   rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // Transmit request
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask_i,      // Specify the ring to use
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable_i,   // Disabled ring
    input  wire [NUM_NODES-1:0]                   tx_req_valid_i,
    input  wire [NUM_NODES-1:0]                   tx_req_is_order_i,
    input  wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data_i,
    output wire [NUM_NODES-1:0]                   tx_req_ready_o,

    // Receive request
    output wire [NUM_NODES-1:0]                   rx_req_valid_o,
    output wire [NUM_NODES-1:0]                   rx_req_is_order_o,
    output wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data_o,

    // Receive response
    output wire [NUM_NODES-1:0]                   rsp_valid_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data_o,

    // Ring bus status
    output wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id_o,
    output wire [NUM_RINGS-1:0]                   ring_busy
);
    // Internal signal definition
    wire [NUM_RINGS-1:0]                             ring_req_valid;
    wire [NUM_RINGS-1:0]                             ring_req_ready;
    // By default, drive ring_req_ready signal to always 1'b1 to ensure basic functionality
    // In practical applications, this signal can be dynamically adjusted based on bus status and load
    assign ring_req_ready = {NUM_RINGS{1'b1}};
    wire [NUM_RINGS*ADDR_WIDTH-1:0]                  ring_req_addr;
    wire [NUM_RINGS*MATCH_TYPE_WIDTH-1:0]            ring_req_match_type;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]               ring_req_source_id;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]               ring_req_target_id;
    wire [NUM_RINGS*DATA_WIDTH-1:0]                  ring_req_data;
    wire [NUM_RINGS*RING_ID_WIDTH-1:0]               ring_id;
    wire [NUM_RINGS-1:0]                             ring_busy_int;

    // Add internal signals for requests and responses of each bus
    wire [NUM_RINGS*NUM_NODES-1:0]                   ring_rx_req_valid;
    wire [NUM_RINGS*NUM_NODES-1:0]                   ring_rx_req_is_order;
    wire [NUM_RINGS*NUM_NODES*OPCODE_WIDTH-1:0]      ring_rx_req_opcode;
    wire [NUM_RINGS*NUM_NODES*MATCH_TYPE_WIDTH-1:0]  ring_rx_req_match_type;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rx_req_source_id;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rx_req_target_id;
    wire [NUM_RINGS*NUM_NODES*ADDR_WIDTH-1:0]        ring_rx_req_addr;
    wire [NUM_RINGS*NUM_NODES*DATA_WIDTH-1:0]        ring_rx_req_data;

    wire [NUM_RINGS*NUM_NODES-1:0]                   ring_rsp_valid;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rsp_source_id;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rsp_target_id;
    wire [NUM_RINGS*NUM_NODES*ADDR_WIDTH-1:0]        ring_rsp_addr;
    wire [NUM_RINGS*NUM_NODES*DATA_WIDTH-1:0]        ring_rsp_data;

    // Instantiate arbiter for each node
    generate
        genvar j, r, p;
        for (j = 0; j < NUM_NODES; j = j + 1) begin : node_arbiter_gen
            // Create temporary signals for each node to connect to the arbiter's 2D array ports
            wire [NUM_RINGS-1:0]          node_ring_req_valid;
            wire [NUM_RINGS-1:0]          node_ring_req_ready;
            wire [NUM_RINGS-1:0]          node_ring_busy;
            wire [ADDR_WIDTH-1:0]         node_ring_req_addr [NUM_RINGS-1:0];
            wire [MATCH_TYPE_WIDTH-1:0]   node_ring_req_match_type [NUM_RINGS-1:0];
            wire [NODE_ID_WIDTH-1:0]      node_ring_req_target_id [NUM_RINGS-1:0];
            wire [DATA_WIDTH-1:0]         node_ring_req_data [NUM_RINGS-1:0];
            wire [RING_ID_WIDTH-1:0]      node_ring_id [NUM_RINGS-1:0];

            ring_arbiter #(
                .NUM_RINGS(NUM_RINGS),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
            ) node_arbiter (
                .clk(clk),
                .rst_n(rst_n),

                // Main request interface
                .req_valid_i(tx_req_valid_i[j]),
                .req_addr_i(tx_req_addr_i[j*ADDR_WIDTH +: ADDR_WIDTH]),
                .req_match_type_i(tx_req_match_type_i[j*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
                .req_target_id_i(tx_req_target_id_i[j*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .req_data_i(tx_req_data_i[j*DATA_WIDTH +: DATA_WIDTH]),
                .req_ring_mask_i(tx_req_ring_mask_i[j*NUM_RINGS +: NUM_RINGS]),
                .req_ring_disable_i(tx_req_ring_disable_i[j*NUM_RINGS +: NUM_RINGS]),
                .req_ready_o(tx_req_ready_o[j]),

                // Ring bus interface
                .ring_req_valid_o(node_ring_req_valid),
                .ring_req_ready_i(node_ring_req_ready),
                .ring_req_addr_o(ring_req_addr),
                .ring_req_match_type_o(ring_req_match_type),
                .ring_req_target_id_o(ring_req_target_id),
                .ring_req_data_o(ring_req_data),

                // Status output
                .ring_busy_o(node_ring_busy)
            );

            // Convert 2D array ports of node arbiter to 1D vector signals
            for (r = 0; r < NUM_RINGS; r = r + 1) begin : ring_signal_gen
                // Connect ring_req_ready signal to node arbiter
                assign node_ring_req_ready[r] = ring_req_ready[r];
                // Map 2D array port data to 1D vector
                assign ring_req_addr[r*ADDR_WIDTH +: ADDR_WIDTH] = node_ring_req_addr[r];
                assign ring_req_match_type[r*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] = node_ring_req_match_type[r];
                assign ring_req_target_id[r*NODE_ID_WIDTH +: NODE_ID_WIDTH] = node_ring_req_target_id[r];
                assign ring_req_data[r*DATA_WIDTH +: DATA_WIDTH] = node_ring_req_data[r];
                // Fix: Connect ring_req_valid signal
                assign ring_req_valid[r] = node_ring_req_valid[r];

                // Collect ring_busy status
                assign ring_busy_int[r] = node_ring_busy[r];
                assign ring_id[r*RING_ID_WIDTH +: RING_ID_WIDTH] = node_ring_id[r];
            end
        end
    endgenerate

    // Instantiate multiple ring_single_bus buses
    generate
        genvar i;
        for (i = 0; i < NUM_RINGS; i = i + 1) begin : ring_single_bus_gen
            ring_single_bus #(
                .NUM_NODES(NUM_NODES),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .OPCODE_WIDTH(OPCODE_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
                .RING_ID_WIDTH(RING_ID_WIDTH),
                .RING_ID(i)
            ) ring_single_bus_inst (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i),
                .node_end_addr_i(node_end_addr_i),

                // Transmit request - obtained from arbiter
                .tx_req_valid_i({{(NUM_NODES-1){1'b0}}, ring_req_valid[i]}),  // Only set the first node as valid
                .tx_req_is_order_i({{(NUM_NODES-1){1'b0}}, 1'b0}),  // All set to non-ordered
                .tx_req_opcode_i({{(NUM_NODES-1)*OPCODE_WIDTH{1'b0}}, {OPCODE_WIDTH{1'b0}}}),  // All set to 0
                .tx_req_match_type_i({{(NUM_NODES-1)*MATCH_TYPE_WIDTH{1'b0}}, {MATCH_TYPE_WIDTH{1'b0}}}),  // All set to 0
                .tx_req_source_id_i({{(NUM_NODES-1)*NODE_ID_WIDTH{1'b0}}, {NODE_ID_WIDTH{1'b0}}}),  // All set to 0
                .tx_req_target_id_i({{(NUM_NODES-1)*NODE_ID_WIDTH{1'b0}}, ring_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]}),  // Fix: Correctly set target node ID
                .tx_req_addr_i({{(NUM_NODES-1)*ADDR_WIDTH{1'b0}}, ring_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH]}),  // Only first node has address
                .tx_req_data_i({{(NUM_NODES-1)*DATA_WIDTH{1'b0}}, ring_req_data[i*DATA_WIDTH +: DATA_WIDTH]}),  // Only first node has data

                // Receive request - connect to internal signals instead of directly to outputs
                .rx_req_valid_o(ring_rx_req_valid[i*NUM_NODES +: NUM_NODES]),
                .rx_req_is_order_o(ring_rx_req_is_order[i*NUM_NODES +: NUM_NODES]),
                .rx_req_opcode_o(ring_rx_req_opcode[i*NUM_NODES*OPCODE_WIDTH +: NUM_NODES*OPCODE_WIDTH]),
                .rx_req_match_type_o(ring_rx_req_match_type[i*NUM_NODES*MATCH_TYPE_WIDTH +: NUM_NODES*MATCH_TYPE_WIDTH]),
                .rx_req_source_id_o(ring_rx_req_source_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rx_req_target_id_o(ring_rx_req_target_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rx_req_addr_o(ring_rx_req_addr[i*NUM_NODES*ADDR_WIDTH +: NUM_NODES*ADDR_WIDTH]),
                .rx_req_data_o(ring_rx_req_data[i*NUM_NODES*DATA_WIDTH +: NUM_NODES*DATA_WIDTH]),

                // Receive response - connect to internal signals instead of directly to outputs
                .rsp_valid_o(ring_rsp_valid[i*NUM_NODES +: NUM_NODES]),
                .rsp_source_id_o(ring_rsp_source_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rsp_target_id_o(ring_rsp_target_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rsp_addr_o(ring_rsp_addr[i*NUM_NODES*ADDR_WIDTH +: NUM_NODES*ADDR_WIDTH]),
                .rsp_data_o(ring_rsp_data[i*NUM_NODES*DATA_WIDTH +: NUM_NODES*DATA_WIDTH]),

                .ring_busy_o(ring_busy_int[i])
            );
        end
    endgenerate

    // Fix genvar definition position
    genvar k;
    genvar m;
    genvar n; // Use different variable name to avoid conflict

    // Define rsp_fifo_rd_en signal outside node_cache_gen generate block
    generate
        // First define shared signals
        wire [NUM_NODES-1:0][NUM_RINGS-1:0] rsp_fifo_rd_en;
        // Define global found signal arrays to avoid Yosys width detection issues
        reg [NUM_NODES-1:0] rx_fifo_found;
        reg [NUM_NODES-1:0] rsp_fifo_found;

        for (k = 0; k < NUM_NODES; k = k + 1) begin : node_cache_gen
            // Define FIFO input/output signals
            wire [NUM_RINGS-1:0] node_ring_rx_valid;
            wire [NUM_RINGS-1:0] node_ring_rsp_valid;
            wire [NUM_RINGS-1:0] rx_fifo_wr_en;
            wire [NUM_RINGS-1:0] rsp_fifo_wr_en;
            wire [NUM_RINGS-1:0] rx_fifo_full;
            wire [NUM_RINGS-1:0] rsp_fifo_full;

            // Create response FIFO for each bus of each node
            wire [NUM_RINGS-1:0] rsp_fifo_empty;
            wire [NUM_RINGS*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH)-1:0] rsp_fifo_data;

            // Create request FIFO for each bus of each node
            wire [NUM_RINGS-1:0] rx_fifo_empty;
            wire [NUM_RINGS*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH)-1:0] rx_fifo_data;

            // Read control logic for request FIFO
            wire [NUM_RINGS-1:0] rx_fifo_rd_en;
            reg [RING_ID_WIDTH-1:0] selected_rx_fifo;

            // Read control logic for response FIFO
            reg [RING_ID_WIDTH-1:0] selected_rsp_fifo;

            // Declare loop variables outside always blocks to avoid SystemVerilog pattern errors
            integer loop_m;
            integer loop_n;

            // Create intermediate signal arrays to store extracted field values
            wire [OPCODE_WIDTH-1:0] extracted_opcode [NUM_RINGS-1:0];
            wire [MATCH_TYPE_WIDTH-1:0] extracted_match_type [NUM_RINGS-1:0];
            wire [NODE_ID_WIDTH-1:0] extracted_source_id [NUM_RINGS-1:0];
            wire [NODE_ID_WIDTH-1:0] extracted_target_id [NUM_RINGS-1:0];
            wire [ADDR_WIDTH-1:0] extracted_addr [NUM_RINGS-1:0];
            wire [DATA_WIDTH-1:0] extracted_data [NUM_RINGS-1:0];

            // Extract valid signals and field values from each bus for the current node
            for (m = 0; m < NUM_RINGS; m = m + 1) begin : node_valid_and_extract_gen
                assign node_ring_rx_valid[m] = ring_rx_req_valid[m*NUM_NODES + k];
                assign node_ring_rsp_valid[m] = ring_rsp_valid[m*NUM_NODES + k];
                // Write to FIFO when it's not full and there's valid data
                assign rx_fifo_wr_en[m] = node_ring_rx_valid[m] && !rx_fifo_full[m];
                assign rsp_fifo_wr_en[m] = node_ring_rsp_valid[m] && !rsp_fifo_full[m];

                // Copy field values bit by bit to avoid complex bit-slice expressions
                for (p = 0; p < OPCODE_WIDTH; p = p + 1) begin : extract_opcode_bits
                    assign extracted_opcode[m][p] = ring_rx_req_opcode[(m*NUM_NODES + k)*OPCODE_WIDTH + p];
                end
                for (p = 0; p < MATCH_TYPE_WIDTH; p = p + 1) begin : extract_match_type_bits
                    assign extracted_match_type[m][p] = ring_rx_req_match_type[(m*NUM_NODES + k)*MATCH_TYPE_WIDTH + p];
                end
                for (p = 0; p < NODE_ID_WIDTH; p = p + 1) begin : extract_source_id_bits
                    assign extracted_source_id[m][p] = ring_rx_req_source_id[(m*NUM_NODES + k)*NODE_ID_WIDTH + p];
                end
                for (p = 0; p < NODE_ID_WIDTH; p = p + 1) begin : extract_target_id_bits
                    assign extracted_target_id[m][p] = ring_rx_req_target_id[(m*NUM_NODES + k)*NODE_ID_WIDTH + p];
                end
                for (p = 0; p < ADDR_WIDTH; p = p + 1) begin : extract_addr_bits
                    assign extracted_addr[m][p] = ring_rx_req_addr[(m*NUM_NODES + k)*ADDR_WIDTH + p];
                end
                for (p = 0; p < DATA_WIDTH; p = p + 1) begin : extract_data_bits
                    assign extracted_data[m][p] = ring_rx_req_data[(m*NUM_NODES + k)*DATA_WIDTH + p];
                end
            end

            for (m = 0; m < NUM_RINGS; m = m + 1) begin : rx_fifo_gen
                // Combine request data signals
                wire [OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH-1:0] rx_req_combined;

                assign rx_req_combined = {
                    extracted_opcode[m],
                    extracted_match_type[m],
                    extracted_source_id[m],
                    extracted_target_id[m],
                    extracted_addr[m],
                    extracted_data[m]
                };

                // Instantiate request FIFO
                fifo #(
                    .DATA_WIDTH(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH),
                    .FIFO_DEPTH(RX_FIFO_DEPTH)
                ) rx_fifo (
                    .clk(clk),
                    .rst_n(rst_n),
                    .wr_en_i(rx_fifo_wr_en[m]),
                    .data_in_i(rx_req_combined),
                    .full_o(rx_fifo_full[m]),
                    .rd_en_i(rx_fifo_rd_en[m]),
                    .data_out_o(rx_fifo_data[m*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +
                             (OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) - 1 :
                             m*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH)]),
                    .empty_o(rx_fifo_empty[m])
                );
            end

            // Create intermediate signal arrays to store response field values
            wire [NODE_ID_WIDTH-1:0] extracted_rsp_source_id [NUM_RINGS-1:0];
            wire [NODE_ID_WIDTH-1:0] extracted_rsp_target_id [NUM_RINGS-1:0];
            wire [ADDR_WIDTH-1:0] extracted_rsp_addr [NUM_RINGS-1:0];
            wire [DATA_WIDTH-1:0] extracted_rsp_data [NUM_RINGS-1:0];

            // Extract response field values
            for (m = 0; m < NUM_RINGS; m = m + 1) begin : extract_rsp_fields_gen
                // Copy response field values bit by bit to avoid complex bit-slice expressions
                for (p = 0; p < NODE_ID_WIDTH; p = p + 1) begin : extract_rsp_source_id_bits
                    assign extracted_rsp_source_id[m][p] = ring_rsp_source_id[(m*NUM_NODES + k)*NODE_ID_WIDTH + p];
                end
                for (p = 0; p < NODE_ID_WIDTH; p = p + 1) begin : extract_rsp_target_id_bits
                    assign extracted_rsp_target_id[m][p] = ring_rsp_target_id[(m*NUM_NODES + k)*NODE_ID_WIDTH + p];
                end
                for (p = 0; p < ADDR_WIDTH; p = p + 1) begin : extract_rsp_addr_bits
                    assign extracted_rsp_addr[m][p] = ring_rsp_addr[(m*NUM_NODES + k)*ADDR_WIDTH + p];
                end
                for (p = 0; p < DATA_WIDTH; p = p + 1) begin : extract_rsp_data_bits
                    assign extracted_rsp_data[m][p] = ring_rsp_data[(m*NUM_NODES + k)*DATA_WIDTH + p];
                end
            end

            for (m = 0; m < NUM_RINGS; m = m + 1) begin : rsp_fifo_gen
                // Combine response data signals
                wire [2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH-1:0] rsp_combined;

                assign rsp_combined = {
                    extracted_rsp_source_id[m],
                    extracted_rsp_target_id[m],
                    extracted_rsp_addr[m],
                    extracted_rsp_data[m]
                };

                // Instantiate response FIFO
                fifo #(
                    .DATA_WIDTH(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH),
                    .FIFO_DEPTH(RSP_FIFO_DEPTH)
                ) rsp_fifo (
                    .clk(clk),
                    .rst_n(rst_n),
                    .wr_en_i(rsp_fifo_wr_en[m]),
                    .data_in_i(rsp_combined),
                    .full_o(rsp_fifo_full[m]),
                    // Use correct scope path
                    .rd_en_i(rsp_fifo_rd_en[k][m]),
                    .data_out_o(rsp_fifo_data[m*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + (2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) - 1 : m*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH)]),
                    .empty_o(rsp_fifo_empty[m])
                );

            end

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    selected_rx_fifo <= 0;
                end else begin
                    // Poll to find non-empty FIFO
                    rx_fifo_found[k] = 0;
                    for (loop_m = 0; loop_m < NUM_RINGS; loop_m = loop_m + 1) begin
                        if (!rx_fifo_found[k] && !rx_fifo_empty[(selected_rx_fifo + loop_m) % NUM_RINGS]) begin
                            selected_rx_fifo <= (selected_rx_fifo + loop_m) % NUM_RINGS;
                            rx_fifo_found[k] = 1;
                        end
                    end
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    selected_rsp_fifo <= 0;
                end else begin
                    // Poll to find non-empty FIFO
                    rsp_fifo_found[k] = 0;
                    for (loop_n = 0; loop_n < NUM_RINGS; loop_n = loop_n + 1) begin
                        if (!rsp_fifo_found[k] && !rsp_fifo_empty[(selected_rsp_fifo + loop_n) % NUM_RINGS]) begin
                            selected_rsp_fifo <= (selected_rsp_fifo + loop_n) % NUM_RINGS;
                            rsp_fifo_found[k] = 1;
                        end
                    end
                end
            end

            // Define selected_node signal to ensure it's defined before use
            reg [$clog2(NUM_NODES)-1:0] selected_node;

            // Generate read enable signals
            assign rx_fifo_rd_en = (1 << selected_rx_fifo) & {NUM_RINGS{!rx_fifo_empty[selected_rx_fifo]}};
            // Fix: rsp_fifo_rd_en should be a single-bit signal, consistent with rx_fifo_rd_en
            assign rsp_fifo_rd_en = (1 << selected_rsp_fifo) & {NUM_RINGS{!rsp_fifo_empty[selected_rsp_fifo]}};

            // Output request data - use generate block to generate outputs for each node
            for (n = 0; n < NUM_NODES; n = n + 1) begin : node_output_gen
                assign rx_req_valid_o[n] = (n == selected_node) ? !rx_fifo_empty[selected_rx_fifo] : 1'b0;
                assign rx_req_is_order_o[n] = (n == selected_node) ? ring_rx_req_is_order[selected_rx_fifo*NUM_NODES + n] : 1'b0;
                assign rx_req_opcode_o[n*OPCODE_WIDTH +: OPCODE_WIDTH] =
                    (n == selected_node) ? rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +: OPCODE_WIDTH] : {OPCODE_WIDTH{1'b0}};
                assign rx_req_match_type_o[n*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] =
                    (n == selected_node) ? rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH +: MATCH_TYPE_WIDTH] : {MATCH_TYPE_WIDTH{1'b0}};
                assign rx_req_source_id_o[n*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                    (n == selected_node) ? rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH +: NODE_ID_WIDTH] : {NODE_ID_WIDTH{1'b0}};
                assign rx_req_target_id_o[n*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                    (n == selected_node) ? rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH +: NODE_ID_WIDTH] : {NODE_ID_WIDTH{1'b0}};
                assign rx_req_addr_o[n*ADDR_WIDTH +: ADDR_WIDTH] =
                    (n == selected_node) ? rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH + 2*NODE_ID_WIDTH +: ADDR_WIDTH] : {ADDR_WIDTH{1'b0}};
                assign rx_req_data_o[n*DATA_WIDTH +: DATA_WIDTH] =
                    (n == selected_node) ? rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH + 2*NODE_ID_WIDTH + ADDR_WIDTH +: DATA_WIDTH] : {DATA_WIDTH{1'b0}};
            end

            // Polling logic for selected_node signal
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    selected_node <= 0;
                end else begin
                    // Simple polling to select nodes, more complex logic may be needed in practical applications
                    selected_node <= (selected_node + 1) % NUM_NODES;
                end
            end

            // Output response data
            assign rsp_valid_o[k] = !rsp_fifo_empty[selected_rsp_fifo];
            assign rsp_source_id_o[k*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +: NODE_ID_WIDTH];
            assign rsp_target_id_o[k*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + NODE_ID_WIDTH +: NODE_ID_WIDTH];
            assign rsp_addr_o[k*ADDR_WIDTH +: ADDR_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + 2*NODE_ID_WIDTH +: ADDR_WIDTH];
            assign rsp_data_o[k*DATA_WIDTH +: DATA_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + 2*NODE_ID_WIDTH + ADDR_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // Output signal assignments
    assign ring_id_o = ring_id;
    assign ring_busy = ring_busy_int;

endmodule