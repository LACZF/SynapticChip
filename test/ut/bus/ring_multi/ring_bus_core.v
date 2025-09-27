module ring_bus_core #(
    parameter NUM_NODES      = 6,
    parameter NUM_RINGS      = 2,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 64,
    parameter NODE_ID_WIDTH  = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 节点接口 - 完全展开的一维数组
    input  wire [NUM_NODES-1:0]         node_req_valid_i,
    output wire [NUM_NODES-1:0]         node_req_ready_o,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0] node_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0] node_req_data_i,
    input  wire [NUM_NODES-1:0]         node_req_wr_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0] node_req_dest_i,

    output wire [NUM_NODES-1:0]         node_resp_valid_o,
    input  wire [NUM_NODES-1:0]         node_resp_ready_i,
    output wire [NUM_NODES*DATA_WIDTH-1:0] node_resp_data_o,
    output wire [NUM_NODES-1:0]         node_resp_error_o,

    // 调试接口
    output wire [NUM_RINGS-1:0]         debug_ring_busy,
    output wire [NUM_RINGS*8-1:0]       debug_ring_load
);

    // 内部Ring总线接口 - 完全展开的一维数组
    wire [NUM_RINGS*NUM_NODES-1:0]      ring_req_valid;
    wire [NUM_RINGS*NUM_NODES-1:0]      ring_req_ready;
    wire [NUM_RINGS*NUM_NODES*ADDR_WIDTH-1:0] ring_req_addr;
    wire [NUM_RINGS*NUM_NODES*DATA_WIDTH-1:0] ring_req_data;
    wire [NUM_RINGS*NUM_NODES-1:0]      ring_req_wr;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0] ring_req_dest;

    wire [NUM_RINGS*NUM_NODES-1:0]      ring_resp_valid;
    wire [NUM_RINGS*NUM_NODES-1:0]      ring_resp_ready;
    wire [NUM_RINGS*NUM_NODES*DATA_WIDTH-1:0] ring_resp_data;
    wire [NUM_RINGS*NUM_NODES-1:0]      ring_resp_error;

    wire [NUM_RINGS-1:0]                ring_busy;
    wire [NUM_RINGS*8-1:0]              ring_load;

    // 节点接口控制器
    genvar i;
    generate
        for (i = 0; i < NUM_NODES; i = i + 1) begin : node_if
            node_interface #(
                .NODE_ID(i),
                .NUM_RINGS(NUM_RINGS),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH)
            ) u_node_if (
                .clk(clk),
                .rst_n(rst_n),
                // 外部节点接口
                .ext_req_valid_i(node_req_valid_i[i]),
                .ext_req_ready_o(node_req_ready_o[i]),
                .ext_req_addr_i(node_req_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH]),
                .ext_req_data_i(node_req_data_i[i*DATA_WIDTH +: DATA_WIDTH]),
                .ext_req_wr_i(node_req_wr_i[i]),
                .ext_req_dest_i(node_req_dest_i[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .ext_resp_valid_o(node_resp_valid_o[i]),
                .ext_resp_ready_i(node_resp_ready_i[i]),
                .ext_resp_data_o(node_resp_data_o[i*DATA_WIDTH +: DATA_WIDTH]),
                .ext_resp_error_o(node_resp_error_o[i]),
                // Ring总线接口 - 完全展开
                .ring_req_valid_o(ring_req_valid[i*NUM_RINGS +: NUM_RINGS]),
                .ring_req_ready_i(ring_req_ready[i*NUM_RINGS +: NUM_RINGS]),
                .ring_req_addr_o(ring_req_addr[i*NUM_RINGS*ADDR_WIDTH +: NUM_RINGS*ADDR_WIDTH]),
                .ring_req_data_o(ring_req_data[i*NUM_RINGS*DATA_WIDTH +: NUM_RINGS*DATA_WIDTH]),
                .ring_req_wr_o(ring_req_wr[i*NUM_RINGS +: NUM_RINGS]),
                .ring_req_dest_o(ring_req_dest[i*NUM_RINGS*NODE_ID_WIDTH +: NUM_RINGS*NODE_ID_WIDTH]),
                .ring_resp_valid_i(ring_resp_valid[i*NUM_RINGS +: NUM_RINGS]),
                .ring_resp_ready_o(ring_resp_ready[i*NUM_RINGS +: NUM_RINGS]),
                .ring_resp_data_i(ring_resp_data[i*NUM_RINGS*DATA_WIDTH +: NUM_RINGS*DATA_WIDTH]),
                .ring_resp_error_i(ring_resp_error[i*NUM_RINGS +: NUM_RINGS]),
                // 负载信息
                .ring_busy_i(ring_busy),
                .ring_load_i(ring_load)
            );
        end
    endgenerate

    // Ring总线实例
    genvar j;
    generate
        for (j = 0; j < NUM_RINGS; j = j + 1) begin : ring_gen
            ring_bus #(
                .RING_ID(j),
                .NUM_NODES(NUM_NODES),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH)
            ) u_ring (
                .clk(clk),
                .rst_n(rst_n),
                // 节点请求接口 - 完全展开
                .node_req_valid_i(ring_req_valid[j*NUM_NODES +: NUM_NODES]),
                .node_req_ready_o(ring_req_ready[j*NUM_NODES +: NUM_NODES]),
                .node_req_addr_i(ring_req_addr[j*NUM_NODES*ADDR_WIDTH +: NUM_NODES*ADDR_WIDTH]),
                .node_req_data_i(ring_req_data[j*NUM_NODES*DATA_WIDTH +: NUM_NODES*DATA_WIDTH]),
                .node_req_wr_i(ring_req_wr[j*NUM_NODES +: NUM_NODES]),
                .node_req_dest_i(ring_req_dest[j*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                // 节点响应接口 - 完全展开
                .node_resp_valid_o(ring_resp_valid[j*NUM_NODES +: NUM_NODES]),
                .node_resp_ready_i(ring_resp_ready[j*NUM_NODES +: NUM_NODES]),
                .node_resp_data_o(ring_resp_data[j*NUM_NODES*DATA_WIDTH +: NUM_NODES*DATA_WIDTH]),
                .node_resp_error_o(ring_resp_error[j*NUM_NODES +: NUM_NODES]),
                // 状态输出
                .ring_busy_o(ring_busy[j]),
                .ring_load_o(ring_load[j*8 +: 8])
            );
        end
    endgenerate

    // 调试信号
    assign debug_ring_busy = ring_busy;
    assign debug_ring_load = ring_load;

endmodule
