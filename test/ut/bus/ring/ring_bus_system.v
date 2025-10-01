module ring_bus_system #(
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 8,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 内存请求接口（从CPU到内存）
    input  wire                         mem_req_enable_i,
    input  wire [ADDR_WIDTH-1:0]        mem_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        mem_req_data_i,
    input  wire                         mem_req_wr_i,
    output wire [DATA_WIDTH-1:0]        mem_req_data_o,
    output wire                         mem_req_ready_o,

    // 内存响应接口（从内存到CPU）
    output wire                         mem_resp_enable_o,
    output wire [ADDR_WIDTH-1:0]        mem_resp_addr_o,
    output wire [DATA_WIDTH-1:0]        mem_resp_data_o,
    output wire                         mem_resp_wr_o,
    input  wire [DATA_WIDTH-1:0]        mem_resp_data_i,
    input  wire                         mem_resp_ready_i,

    // UART请求接口（从CPU到UART）
    input  wire                         uart_req_enable_i,
    input  wire [ADDR_WIDTH-1:0]        uart_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        uart_req_data_i,
    input  wire                         uart_req_wr_i,
    output wire [DATA_WIDTH-1:0]        uart_req_data_o,
    output wire                         uart_req_ready_o,

    // UART响应接口（从UART到CPU）
    output wire                         uart_resp_enable_o,
    output wire [ADDR_WIDTH-1:0]        uart_resp_addr_o,
    output wire [DATA_WIDTH-1:0]        uart_resp_data_o,
    output wire                         uart_resp_wr_o,
    input  wire [DATA_WIDTH-1:0]        uart_resp_data_i,
    input  wire                         uart_resp_ready_i,

    // UART物理接口
    input  wire                         uart_rx_i,
    output wire                         uart_tx_o,
    output wire                         uart_irq_o,

    // 调试接口
    output wire [NUM_RINGS-1:0]         debug_ring_busy,
    output wire [NUM_RINGS*8-1:0]       debug_ring_load
);
    localparam MEM_REQ_NODE_ID = 0;
    localparam MEM_RSP_NODE_ID = 3;
    localparam UART_REQ_NODE_ID = 1;
    localparam UART_RSP_NODE_ID = 4;

    reg  [NUM_NODES-1:0]                   node_req_wr;
    reg  [NUM_NODES-1:0]                   node_resp_ready;
    reg  [NUM_NODES-1:0]                   node_resp_error;

    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr;
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr;

    assign node_start_addr[MEM_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}} | 32'h0000_1000;
    assign node_end_addr[MEM_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}} | 32'h0000_2000;
    assign node_start_addr[UART_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}};
    assign node_end_addr[UART_RSP_NODE_ID*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}} | 32'h0000_0FFF;

    // 发送请求
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

    // 接受请求
    wire [NUM_NODES-1:0]                   rx_req_valid;
    wire [NUM_NODES-1:0]                   rx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data;

    // 接收响应
    wire [NUM_NODES-1:0]                   rsp_valid;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data;

    // Ring总线状态
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

    // 内存请求节点（节点0 -> 发送请求到内存）
    memory_request_node #(
        .NODE_ID(MEM_REQ_NODE_ID),
        .TARGET_NODE_ID(MEM_RSP_NODE_ID),  // 发送到内存响应节点
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory_request_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
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
        // 外部请求接口
        .ext_req_enable_i(mem_req_enable_i),
        .ext_req_addr_i(mem_req_addr_i),
        .ext_req_data_i(mem_req_data_i),
        .ext_req_wr_i(mem_req_wr_i),
        .ext_req_data_o(mem_req_data_o),
        .ext_req_ready_o(mem_req_ready_o)
    );

    // 内存响应节点（节点3 -> 处理内存请求）
    memory_response_node #(
        .NODE_ID(MEM_RSP_NODE_ID),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory_response_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
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
        // 外部响应接口
        .ext_resp_enable_o(mem_resp_enable_o),
        .ext_resp_addr_o(mem_resp_addr_o),
        .ext_resp_data_o(mem_resp_data_o),
        .ext_resp_wr_o(mem_resp_wr_o),
        .ext_resp_data_i(mem_resp_data_i),
        .ext_resp_ready_i(mem_resp_ready_i)
    );

    // UART请求节点（节点1 -> 发送请求到UART）
    uart_request_node #(
        .NODE_ID(UART_REQ_NODE_ID),
        .TARGET_NODE_ID(UART_RSP_NODE_ID),  // 发送到UART响应节点
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_request_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
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
        // 外部请求接口
        .ext_req_enable_i(uart_req_enable_i),
        .ext_req_addr_i(uart_req_addr_i),
        .ext_req_data_i(uart_req_data_i),
        .ext_req_wr_i(uart_req_wr_i),
        .ext_req_data_o(uart_req_data_o),
        .ext_req_ready_o(uart_req_ready_o)
    );

    // UART响应节点（节点4 -> 处理UART请求）
    uart_response_node #(
        .NODE_ID(4),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_response_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
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
        // 外部响应接口
        .ext_resp_enable_o(uart_resp_enable_o),
        .ext_resp_addr_o(uart_resp_addr_o),
        .ext_resp_data_o(uart_resp_data_o),
        .ext_resp_wr_o(uart_resp_wr_o),
        .ext_resp_data_i(uart_resp_data_i),
        .ext_resp_ready_i(uart_resp_ready_i),
        // UART物理接口
        .uart_rx_i(uart_rx_i),
        .uart_tx_o(uart_tx_o),
        .uart_irq_o(uart_irq_o)
    );
endmodule