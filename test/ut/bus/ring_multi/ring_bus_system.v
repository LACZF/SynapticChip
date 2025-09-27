module ring_bus_system #(
    parameter NUM_NODES      = 6,        // 总节点数：2个内存节点 + 2个UART节点 + 2个空闲
    parameter NUM_RINGS      = 2,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 64,
    parameter NODE_ID_WIDTH  = 8
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

    // 节点接口信号 - 完全展开的一维数组
    wire [NUM_NODES-1:0]                node_req_valid;
    wire [NUM_NODES-1:0]                node_req_ready;
    wire [NUM_NODES*ADDR_WIDTH-1:0]     node_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]     node_req_data;
    wire [NUM_NODES-1:0]                node_req_wr;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]  node_req_dest;

    wire [NUM_NODES-1:0]                node_resp_valid;
    wire [NUM_NODES-1:0]                node_resp_ready;
    wire [NUM_NODES*DATA_WIDTH-1:0]     node_resp_data;
    wire [NUM_NODES-1:0]                node_resp_error;

    // Ring总线系统实例
    ring_bus_core #(
        .NUM_NODES(NUM_NODES),
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH)
    ) u_ring_core (
        .clk(clk),
        .rst_n(rst_n),
        .node_req_valid_i(node_req_valid),
        .node_req_ready_o(node_req_ready),
        .node_req_addr_i(node_req_addr),
        .node_req_data_i(node_req_data),
        .node_req_wr_i(node_req_wr),
        .node_req_dest_i(node_req_dest),
        .node_resp_valid_o(node_resp_valid),
        .node_resp_ready_i(node_resp_ready),
        .node_resp_data_o(node_resp_data),
        .node_resp_error_o(node_resp_error),
        .debug_ring_busy(debug_ring_busy),
        .debug_ring_load(debug_ring_load)
    );

    // 内存请求节点（节点0 -> 发送请求到内存）
    memory_request_node #(
        .NODE_ID(0),
        .TARGET_NODE_ID(3),  // 发送到内存响应节点
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory_request_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
        .ring_req_valid_o(node_req_valid[0]),
        .ring_req_ready_i(node_req_ready[0]),
        .ring_req_addr_o(node_req_addr[0*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(node_req_data[0*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[0]),
        .ring_req_dest_o(node_req_dest[0*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(node_resp_valid[0]),
        .ring_resp_ready_o(node_resp_ready[0]),
        .ring_resp_data_i(node_resp_data[0*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[0]),
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
        .NODE_ID(3),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_memory_response_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
        .ring_req_valid_o(node_req_valid[3]),
        .ring_req_ready_i(node_req_ready[3]),
        .ring_req_addr_o(node_req_addr[3*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(node_req_data[3*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[3]),
        .ring_req_dest_o(node_req_dest[3*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(node_resp_valid[3]),
        .ring_resp_ready_o(node_resp_ready[3]),
        .ring_resp_data_i(node_resp_data[3*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[3]),
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
        .NODE_ID(1),
        .TARGET_NODE_ID(4),  // 发送到UART响应节点
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_uart_request_node (
        .clk(clk),
        .rst_n(rst_n),
        // Ring接口
        .ring_req_valid_o(node_req_valid[1]),
        .ring_req_ready_i(node_req_ready[1]),
        .ring_req_addr_o(node_req_addr[1*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(node_req_data[1*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[1]),
        .ring_req_dest_o(node_req_dest[1*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(node_resp_valid[1]),
        .ring_resp_ready_o(node_resp_ready[1]),
        .ring_resp_data_i(node_resp_data[1*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[1]),
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
        .ring_req_valid_o(node_req_valid[4]),
        .ring_req_ready_i(node_req_ready[4]),
        .ring_req_addr_o(node_req_addr[4*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_req_data_o(node_req_data[4*DATA_WIDTH +: DATA_WIDTH]),
        .ring_req_wr_o(node_req_wr[4]),
        .ring_req_dest_o(node_req_dest[4*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_resp_valid_i(node_resp_valid[4]),
        .ring_resp_ready_o(node_resp_ready[4]),
        .ring_resp_data_i(node_resp_data[4*DATA_WIDTH +: DATA_WIDTH]),
        .ring_resp_error_i(node_resp_error[4]),
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

    // 未使用的节点接地
    assign node_req_valid[5:2] = 4'b0000;
    assign node_req_addr[2*ADDR_WIDTH +: 4*ADDR_WIDTH] = {4*ADDR_WIDTH{1'b0}};
    assign node_req_data[2*DATA_WIDTH +: 4*DATA_WIDTH] = {4*DATA_WIDTH{1'b0}};
    assign node_req_wr[5:2] = 4'b0000;
    assign node_req_dest[2*NODE_ID_WIDTH +: 4*NODE_ID_WIDTH] = {4*NODE_ID_WIDTH{1'b0}};
    assign node_resp_ready[5:2] = 4'b1111;

endmodule
