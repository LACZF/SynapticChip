`include "ring_bus_params.v"

module ring_bus_node #(
    parameter NUM_RINGS                 = 2,        // Number of Ring buses
    parameter ADDR_WIDTH                = 32,       // Address width
    parameter DATA_WIDTH                = 64,       // Data width
    parameter NODE_ID_WIDTH             = 8,        // Node ID width
    parameter NODE_ID                   = 0,        // Node ID
    parameter OPCODE_WIDTH              = 8,        // Width of operation type: read/write/response, etc.
    parameter MATCH_TYPE_WIDTH          = 2,        // Match type width
    parameter TX_FIFO_DEPTH             = 4,        // Transmit FIFO depth
    parameter RX_FIFO_DEPTH             = 4,        // Receive FIFO depth
    parameter RSP_FIFO_DEPTH            = 4         // Response FIFO depth
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [ADDR_WIDTH-1:0]        node_end_addr_i,

    input  wire                         pre_req_valid_i,
    input  wire                         pre_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      pre_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  pre_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     pre_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     pre_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        pre_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        pre_req_data_i,

    output wire                         next_req_valid_o,
    output wire                         next_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      next_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  next_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     next_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     next_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        next_req_addr_o,
    output wire [DATA_WIDTH-1:0]        next_req_data_o,

    // Transmit request
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // Receive request
    output wire                         rx_req_valid_o,
    output wire                         rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        rx_req_data_o,

    // Receive response
    output wire                         rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [DATA_WIDTH-1:0]        rsp_data_o
);
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam RESPOND = 2'b10;

    localparam tx_fifo_data_width = OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH + 1 + 1;
    localparam rx_fifo_data_width = OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH + 1 + 1;
    localparam rsp_fifo_data_width = NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH;
    reg [NODE_ID_WIDTH-1:0] node_id = NODE_ID;

    // Transmit FIFO signals
    reg                         tx_req_rd_en;
    reg                         tx_req_rd_done;
    reg                         tx_fifo_full;
    reg                         tx_fifo_empty;
    reg                         tx_req_valid;
    reg                         tx_req_is_order;
    reg [OPCODE_WIDTH-1:0]      tx_req_opcode;
    reg [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type;
    reg [NODE_ID_WIDTH-1:0]     tx_req_source_id;
    reg [NODE_ID_WIDTH-1:0]     tx_req_target_id;
    reg [ADDR_WIDTH-1:0]        tx_req_addr;
    reg [DATA_WIDTH-1:0]        tx_req_data;

    // Receive FIFO signals
    reg                         rx_req_rd_en;
    wire                        rx_req_rd_done;
    reg                         rx_fifo_full;
    reg                         rx_fifo_empty;
    reg                         rx_req_valid;
    reg                         rx_req_is_order;
    reg [OPCODE_WIDTH-1:0]      rx_req_opcode;
    reg [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type;
    reg [NODE_ID_WIDTH-1:0]     rx_req_source_id;
    reg [NODE_ID_WIDTH-1:0]     rx_req_target_id;
    reg [ADDR_WIDTH-1:0]        rx_req_addr;
    reg [DATA_WIDTH-1:0]        rx_req_data;

    // Response FIFO signals
    reg                         rsp_rd_en;
    wire                        rsp_rd_done;
    wire                        rsp_fifo_full;
    wire                        rsp_fifo_empty;
    reg                         rsp_valid;
    reg [NODE_ID_WIDTH-1:0]     rsp_source_id;
    reg [NODE_ID_WIDTH-1:0]     rsp_target_id;
    reg [ADDR_WIDTH-1:0]        rsp_addr;
    reg [DATA_WIDTH-1:0]        rsp_data;
    wire [NODE_ID_WIDTH-1:0]    rsp_source_id_fifo;
    wire [NODE_ID_WIDTH-1:0]    rsp_target_id_fifo;
    wire [ADDR_WIDTH-1:0]       rsp_addr_fifo;
    wire [DATA_WIDTH-1:0]       rsp_data_fifo; // Intermediate wire variable, connecting FIFO output

    // Target matching logic
    wire is_for_me;
    assign is_for_me = ((pre_req_match_type_i == `RING_MATCH_TYPE_ID) || (pre_req_opcode_i == `RING_OP_RESP)) ?
        (pre_req_target_id_i == node_id) :
        (node_start_addr_i <= pre_req_addr_i && pre_req_addr_i <= node_end_addr_i);

    // New: Internal registers for forwarding requests
    reg                         next_req_valid;
    reg                         next_req_is_order;
    reg [OPCODE_WIDTH-1:0]      next_req_opcode;
    reg [MATCH_TYPE_WIDTH-1:0]  next_req_match_type;
    reg [NODE_ID_WIDTH-1:0]     next_req_source_id;
    reg [NODE_ID_WIDTH-1:0]     next_req_target_id;
    reg [ADDR_WIDTH-1:0]        next_req_addr;
    reg [DATA_WIDTH-1:0]        next_req_data;

    /* Not for this node, forward to next node */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_req_valid <= 1'b0;
            next_req_is_order <= 1'b0;
            next_req_opcode <= 0;
            next_req_match_type <= 0;
            next_req_source_id <= 0;
            next_req_target_id <= 0;
            next_req_addr <= 0;
            next_req_data <= 0;
        end else if (pre_req_valid_i && pre_req_source_id_i == node_id) begin
            // Exception handling: Request returned to source node, indicating no matching node
            next_req_valid <= 1'b0;
        end else if (!is_for_me && pre_req_valid_i) begin
            // Forward request
            next_req_valid <= pre_req_valid_i;
            next_req_is_order <= pre_req_is_order_i;
            next_req_opcode <= pre_req_opcode_i;
            next_req_match_type <= pre_req_match_type_i;
            next_req_source_id <= pre_req_source_id_i;
            next_req_target_id <= pre_req_target_id_i;
            next_req_addr <= pre_req_addr_i;
            next_req_data <= pre_req_data_i;
        end else begin
            next_req_valid <= 1'b0;
        end
    end

    // Transmit FIFO instantiation
    fifo #(
        .DATA_WIDTH(tx_fifo_data_width),
        .FIFO_DEPTH(TX_FIFO_DEPTH)
    ) tx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_i(tx_req_valid_i),
        /* This node is the source during TX */
        .data_in_i({tx_req_valid_i, tx_req_is_order_i, tx_req_opcode_i, tx_req_match_type_i, node_id, tx_req_target_id_i, tx_req_addr_i, tx_req_data_i}),
        .rd_en_i(tx_req_rd_en),
        .rd_done_o(tx_req_rd_done),
        .data_out_o({tx_req_valid, tx_req_is_order, tx_req_opcode, tx_req_match_type, tx_req_source_id, tx_req_target_id, tx_req_addr, tx_req_data}),
        .full_o(tx_fifo_full),
        .empty_o(tx_fifo_empty)
    );

    // Receive FIFO instantiation - for rx direction receive buffer
    fifo #(
        .DATA_WIDTH(rx_fifo_data_width),
        .FIFO_DEPTH(RX_FIFO_DEPTH)
    ) rx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_i(is_for_me && pre_req_valid_i),
        .data_in_i({pre_req_valid_i, pre_req_is_order_i, pre_req_opcode_i, pre_req_match_type_i, pre_req_source_id_i, pre_req_target_id_i, pre_req_addr_i, pre_req_data_i}),
        .rd_en_i(rx_req_rd_en),
        .rd_done_o(rx_req_rd_done),
        .data_out_o({rx_req_valid, rx_req_is_order, rx_req_opcode, rx_req_match_type, rx_req_source_id, rx_req_target_id, rx_req_addr, rx_req_data}),
        .full_o(rx_fifo_full),
        .empty_o(rx_fifo_empty)
    );

    // Response FIFO instantiation - for rsp receive buffer
    fifo #(
        .DATA_WIDTH(rsp_fifo_data_width),
        .FIFO_DEPTH(RSP_FIFO_DEPTH)
    ) rsp_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_i((rx_req_opcode == `RING_OP_READ || rx_req_opcode == `RING_OP_WRITE) && rx_req_valid),
        .data_in_i({node_id, rx_req_source_id, rx_req_addr, rx_req_data}),
        .rd_en_i(rsp_rd_en),
        .rd_done_o(rsp_rd_done),
        .data_out_o({rsp_source_id_fifo, rsp_target_id_fifo, rsp_addr_fifo, rsp_data_fifo}),
        .full_o(rsp_fifo_full),
        .empty_o(rsp_fifo_empty)
    );

    // Transmit state machine
    reg [1:0] tx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            tx_req_rd_en <= 0;
        end else begin
            case (tx_state)
                IDLE: begin
                    if (!tx_fifo_empty) begin
                        tx_req_rd_en <= 1;
                        tx_state <= PROCESS;
                    end
                end
                PROCESS: begin
                    if (tx_req_rd_done) begin
                        tx_req_rd_en <= 0;
                        tx_state <= RESPOND;
                    end
                end
                RESPOND: begin
                    // Clear request signal
                    tx_state <= IDLE;
                end
            endcase
        end
    end

    // Receive state machine
    reg [1:0] rx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE;
            rx_req_rd_en <= 0;
            rsp_valid <= 1'b0;
        end else begin
            case (rx_state)
                IDLE: begin
                    rsp_valid <= 1'b0;
                    if (!rx_fifo_empty) begin
                        rx_req_rd_en <= 1;
                        rx_state <= PROCESS;
                    end
                end
                PROCESS: begin
                    if (rx_req_rd_done) begin
                        rx_req_rd_en <= 0;
                        // Process request
                        if (rx_req_opcode == `RING_OP_RESP) begin
                            // Directly output response
                            rsp_valid <= 1'b1;
                            rsp_source_id <= rx_req_source_id;
                            rsp_target_id <= rx_req_target_id;
                            rsp_addr <= rx_req_addr;
                            rsp_data <= rx_req_data;
                            rx_state <= RESPOND;
                        end else begin
                            // Write to response FIFO waiting for processing
                            rx_state <= IDLE;
                        end
                    end
                end
                RESPOND: begin
                    rsp_valid <= 1'b0;
                    rx_state <= IDLE;
                end
            endcase
        end
    end

    // Response processing state machine
    reg [1:0] rsp_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_state <= IDLE;
            rsp_rd_en <= 0;
        end else begin
            case (rsp_state)
                IDLE: begin
                    if (!rsp_fifo_empty) begin
                        rsp_rd_en <= 1;
                        rsp_state <= PROCESS;
                    end
                end
                PROCESS: begin
                    if (rsp_rd_done) begin
                        rsp_rd_en <= 0;
                        // Process response
                        rsp_valid <= 1'b1;
                        rsp_source_id <= rsp_source_id_fifo;
                        rsp_target_id <= rsp_target_id_fifo;
                        rsp_addr <= rsp_addr_fifo;
                        rsp_data <= rsp_data_fifo;
                        rsp_state <= RESPOND;
                    end
                end
                RESPOND: begin
                    rsp_valid <= 1'b0;
                    rsp_state <= IDLE;
                end
            endcase
        end
    end

    // Output signal assignment
    assign rsp_valid_o = rsp_valid;
    assign rsp_source_id_o = rsp_source_id;
    assign rsp_target_id_o = rsp_target_id;
    assign rsp_addr_o = rsp_addr;
    assign rsp_data_o = rsp_data;

    assign rx_req_valid_o = rx_req_valid;
    assign rx_req_is_order_o = rx_req_is_order;
    assign rx_req_opcode_o = rx_req_opcode;
    assign rx_req_match_type_o = rx_req_match_type;
    assign rx_req_source_id_o = rx_req_source_id;
    assign rx_req_target_id_o = rx_req_target_id;
    assign rx_req_addr_o = rx_req_addr;
    assign rx_req_data_o = rx_req_data;

    // Forward request output assignment
    assign next_req_valid_o = next_req_valid;
    assign next_req_is_order_o = next_req_is_order;
    assign next_req_opcode_o = next_req_opcode;
    assign next_req_match_type_o = next_req_match_type;
    assign next_req_source_id_o = next_req_source_id;
    assign next_req_target_id_o = next_req_target_id;
    assign next_req_addr_o = next_req_addr;
    assign next_req_data_o = next_req_data;

endmodule