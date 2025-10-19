module ring_bus_system #(
    parameter NUM_RINGS                 = 2,        // Number of Ring buses
    parameter NUM_NODES                 = 8,        // Number of nodes per Ring
    parameter ADDR_WIDTH                = 64,       // Address width
    parameter DATA_WIDTH                = 64,       // Data width
    parameter OPCODE_WIDTH              = 8,        // Operation type width: read/write/response etc.
    parameter RING_ID_WIDTH             = 4,        // Ring ID width
    parameter NODE_ID_WIDTH             = 8,        // Node ID width
    parameter TX_FIFO_DEPTH             = 4,        // TX FIFO depth
    parameter RX_FIFO_DEPTH             = 4,        // RX FIFO depth
    parameter RSP_FIFO_DEPTH            = 4,        // Response FIFO depth
    parameter MATCH_TYPE_WIDTH          = 2         // Match type width
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Memory request interface (from CPU to memory)
    input  wire                         mem_req_enable_i,
    input  wire [ADDR_WIDTH-1:0]        mem_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        mem_req_data_i,
    input  wire                         mem_req_wr_i,
    output wire [DATA_WIDTH-1:0]        mem_req_data_o,
    output wire                         mem_req_ready_o,

    // Memory response interface (from memory to CPU)
    output wire                         mem_resp_enable_o,
    output wire [ADDR_WIDTH-1:0]        mem_resp_addr_o,
    output wire [DATA_WIDTH-1:0]        mem_resp_data_o,
    output wire                         mem_resp_wr_o,
    input  wire [DATA_WIDTH-1:0]        mem_resp_data_i,
    input  wire                         mem_resp_ready_i,

    // UART request interface (from CPU to UART)
    input  wire                         uart_req_enable_i,
    input  wire [ADDR_WIDTH-1:0]        uart_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        uart_req_data_i,
    input  wire                         uart_req_wr_i,
    output wire [DATA_WIDTH-1:0]        uart_req_data_o,
    output wire                         uart_req_ready_o,

    // UART response interface (from UART to CPU)
    output wire                         uart_resp_enable_o,
    output wire [ADDR_WIDTH-1:0]        uart_resp_addr_o,
    output wire [DATA_WIDTH-1:0]        uart_resp_data_o,
    output wire                         uart_resp_wr_o,
    input  wire [DATA_WIDTH-1:0]        uart_resp_data_i,
    input  wire                         uart_resp_ready_i,

    // UART physical interface
    input  wire                         uart_rx_i,
    output wire                         uart_tx_o,
    output wire                         uart_irq_o,

    // Debug interface
    output wire [NUM_RINGS-1:0]         debug_ring_busy,
    output wire [NUM_RINGS*8-1:0]       debug_ring_load
);
    localparam MEM_REQ_NODE_ID  = 0;
    localparam MEM_RSP_NODE_ID  = 3;
    localparam UART_REQ_NODE_ID = 1;
    localparam UART_RSP_NODE_ID = 4;

    reg  [NUM_NODES-1:0]                   node_req_wr;
    reg  [NUM_NODES-1:0]                   node_resp_ready;
    reg  [NUM_NODES-1:0]                   node_resp_error;

    reg  [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr;
    reg  [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr;

    assign node_start_addr[MEM_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}} | 32'h0000_1000;
    assign node_end_addr[MEM_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}} | 32'h0000_2000;
    assign node_start_addr[UART_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}};
    assign node_end_addr[UART_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}} | 32'h0000_0FFF;

    // Send requests
    wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask;
    wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable;
    wire [NUM_NODES-1:0]                   tx_req_valid;
    wire [NUM_NODES-1:0]                   tx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data;

    // Receive requests
    wire [NUM_NODES-1:0]                   rx_req_valid;
    wire [NUM_NODES-1:0]                   rx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data;

    // Receive responses
    wire [NUM_NODES-1:0]                   rsp_valid;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data;

    // Ring bus status
    wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id;
    wire [NUM_RINGS-1:0]                   ring_busy;

    ring_bus #(
        .NUM_RINGS(NUM_RINGS),
        .NUM_NODES(NUM_NODES),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .RING_ID_WIDTH(RING_ID_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .RSP_FIFO_DEPTH(RSP_FIFO_DEPTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_ring_bus (
        .clk(clk),
        .rst_n(rst_n),

        .node_start_addr_i(node_start_addr),
        .node_end_addr_i(node_end_addr),

        .tx_req_ring_mask_i(tx_req_ring_mask),
        .tx_req_ring_disable_i(tx_req_ring_disable),
        .tx_req_valid_i(tx_req_valid),
        .tx_req_is_order_i(tx_req_is_order),
        .tx_req_opcode_i(tx_req_opcode),
        .tx_req_match_type_i(tx_req_match_type),
        .tx_req_source_id_i(tx_req_source_id),
        .tx_req_target_id_i(tx_req_target_id),
        .tx_req_addr_i(tx_req_addr),
        .tx_req_data_i(tx_req_data),

        .rx_req_valid_o(rx_req_valid),
        .rx_req_is_order_o(rx_req_is_order),
        .rx_req_opcode_o(rx_req_opcode),
        .rx_req_match_type_o(rx_req_match_type),
        .rx_req_source_id_o(rx_req_source_id),
        .rx_req_target_id_o(rx_req_target_id),
        .rx_req_addr_o(rx_req_addr),
        .rx_req_data_o(rx_req_data),

        .rsp_valid_o(rsp_valid),
        .rsp_source_id_o(rsp_source_id),
        .rsp_target_id_o(rsp_target_id),
        .rsp_addr_o(rsp_addr),
        .rsp_data_o(rsp_data),

        .ring_id_o(ring_id),
        .ring_busy(ring_busy)
    );

    // Memory request node (node 0 -> send requests to memory)
    memory_request_node #(
        .NODE_ID(MEM_REQ_NODE_ID),
        .TARGET_NODE_ID(MEM_RSP_NODE_ID),  // Send to memory response node
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory_request_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring interface
        .ring_req_valid_o(tx_req_valid[MEM_REQ_NODE_ID]),
        .ring_req_ready_i(1'b1),
        .ring_req_addr_o(tx_req_addr[MEM_REQ_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(tx_req_data[MEM_REQ_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[MEM_REQ_NODE_ID]),
        .ring_req_dest_o(tx_req_target_id[MEM_REQ_NODE_ID*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(rsp_valid[MEM_REQ_NODE_ID]),
        .ring_resp_ready_o(node_resp_ready[MEM_REQ_NODE_ID]),
        .ring_resp_data_i(rsp_data[MEM_REQ_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[MEM_REQ_NODE_ID]),
        // External request interface
        .ext_req_enable_i(mem_req_enable_i),
        .ext_req_addr_i(mem_req_addr_i),
        .ext_req_data_i(mem_req_data_i),
        .ext_req_wr_i(mem_req_wr_i),
        .ext_req_data_o(mem_req_data_o),
        .ext_req_ready_o(mem_req_ready_o)
    );

    // Memory response node (node 3 -> process memory requests)
    memory_response_node #(
        .NODE_ID(MEM_RSP_NODE_ID),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory_response_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring interface
        .ring_req_valid_o(tx_req_valid[MEM_RSP_NODE_ID]),
        .ring_req_ready_i(1'b1),
        .ring_req_addr_o(tx_req_addr[MEM_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(tx_req_data[MEM_RSP_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[MEM_RSP_NODE_ID]),
        .ring_req_dest_o(tx_req_target_id[MEM_RSP_NODE_ID*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(rsp_valid[MEM_RSP_NODE_ID]),
        .ring_resp_ready_o(node_resp_ready[MEM_RSP_NODE_ID]),
        .ring_resp_data_i(rsp_data[MEM_RSP_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[MEM_RSP_NODE_ID]),
        // External response interface
        .ext_resp_enable_o(mem_resp_enable_o),
        .ext_resp_addr_o(mem_resp_addr_o),
        .ext_resp_data_o(mem_resp_data_o),
        .ext_resp_wr_o(mem_resp_wr_o),
        .ext_resp_data_i(mem_resp_data_i),
        .ext_resp_ready_i(mem_resp_ready_i)
    );

    // UART request node (node 1 -> send requests to UART)
    uart_request_node #(
        .NODE_ID(UART_REQ_NODE_ID),
        .TARGET_NODE_ID(UART_RSP_NODE_ID),  // Send to UART response node
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_request_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring interface
        .ring_req_valid_o(tx_req_valid[UART_REQ_NODE_ID]),
        .ring_req_ready_i(1'b1),
        .ring_req_addr_o(tx_req_addr[UART_REQ_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(tx_req_data[UART_REQ_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[UART_REQ_NODE_ID]),
        .ring_req_dest_o(tx_req_target_id[UART_REQ_NODE_ID*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(rsp_valid[UART_REQ_NODE_ID]),
        .ring_resp_ready_o(node_resp_ready[UART_REQ_NODE_ID]),
        .ring_resp_data_i(rsp_data[UART_REQ_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[UART_REQ_NODE_ID]),
        // External request interface
        .ext_req_enable_i(uart_req_enable_i),
        .ext_req_addr_i(uart_req_addr_i),
        .ext_req_data_i(uart_req_data_i),
        .ext_req_wr_i(uart_req_wr_i),
        .ext_req_data_o(uart_req_data_o),
        .ext_req_ready_o(uart_req_ready_o)
    );

    // UART response node (node 4 -> process UART requests)
    uart_response_node #(
        .NODE_ID(4),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_response_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring interface
        .ring_req_valid_o(tx_req_valid[UART_RSP_NODE_ID]),
        .ring_req_ready_i(1'b1),
        .ring_req_addr_o(tx_req_addr[UART_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(tx_req_data[UART_RSP_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[UART_RSP_NODE_ID]),
        .ring_req_dest_o(tx_req_target_id[UART_RSP_NODE_ID*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(rsp_valid[UART_RSP_NODE_ID]),
        .ring_resp_ready_o(node_resp_ready[UART_RSP_NODE_ID]),
        .ring_resp_data_i(rsp_data[UART_RSP_NODE_ID*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[UART_RSP_NODE_ID]),
        // External response interface
        .ext_resp_enable_o(uart_resp_enable_o),
        .ext_resp_addr_o(uart_resp_addr_o),
        .ext_resp_data_o(uart_resp_data_o),
        .ext_resp_wr_o(uart_resp_wr_o),
        .ext_resp_data_i(uart_resp_data_i),
        .ext_resp_ready_i(uart_resp_ready_i),
        // UART physical interface
        .uart_rx_i(uart_rx_i),
        .uart_tx_o(uart_tx_o),
        .uart_irq_o(uart_irq_o)
    );
endmodule