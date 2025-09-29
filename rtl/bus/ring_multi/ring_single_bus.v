`include "ring_bus_params.v"

module ring_single_bus #(
    parameter NUM_NODES = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter OPCODE_WIDTH  = 8,        // 操作类型的宽带：read/write/reponse等
    parameter MATCH_TYPE_WIDTH = 2,
    parameter RING_ID_WIDTH = 4,
    parameter RING_ID = 0
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // 发送请求
    input  wire [NUM_NODES-1:0]                   tx_req_valid_i,
    input  wire [NUM_NODES-1:0]                   tx_req_is_order_i,
    input  wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire [NUM_NODES-1:0]                   rx_req_valid_o,
    output wire [NUM_NODES-1:0]                   rx_req_is_order_o,
    output wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire [NUM_NODES-1:0]                   rsp_valid_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data_o,

    output wire                                   ring_busy_o
);
    wire [NUM_NODES-1:0]                   node_req_valid;
    wire [NUM_NODES-1:0]                   node_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      node_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  node_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     node_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     node_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        node_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        node_req_data;

    // Instantiate ring nodes
    generate
        genvar i;
        for (i = 0; i < (NUM_NODES - 1); i = i + 1) begin
            ring_node #(
                .NODE_ID(i),
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .TX_FIFO_DEPTH(NODE_TX_FIFO_DEPTH),
                .RX_FIFO_DEPTH(NODE_RX_FIFO_DEPTH)
            ) node (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH]),
                .node_end_addr_i(node_end_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH]),

                .pre_req_valid_i(node_req_valid[i]),
                .pre_req_is_order_i(node_req_is_order[i]),
                .pre_req_opcode_i(node_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH]),
                .pre_req_match_type_i(node_req_match_type[i*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
                .pre_req_source_id_i(node_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .pre_req_target_id_i(node_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .pre_req_addr_i(node_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH]),
                .pre_req_data_i(node_req_data[i*DATA_WIDTH +: DATA_WIDTH]),

                .next_req_valid_i(node_req_valid[(i+1)]),
                .next_req_is_order_i(node_req_is_order[(i+1)]),
                .next_req_opcode_i(node_req_opcode[(i+1)*OPCODE_WIDTH +: OPCODE_WIDTH]),
                .next_req_match_type_i(node_req_match_type[(i+1)*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
                .next_req_source_id_i(node_req_source_id[(i+1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .next_req_target_id_i(node_req_target_id[(i+1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .next_req_addr_i(node_req_addr[(i+1)*ADDR_WIDTH +: ADDR_WIDTH]),
                .next_req_data_i(node_req_data[(i+1)*DATA_WIDTH +: DATA_WIDTH]),

                .tx_req_valid_i(tx_req_valid[i]),
                .tx_req_is_order_i(tx_req_is_order[i]),
                .tx_req_opcode_i(tx_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH]),
                .tx_req_match_type_i(tx_req_match_type[i*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
                .tx_req_source_id_i(tx_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .tx_req_target_id_i(tx_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .tx_req_addr_i(tx_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH]),
                .tx_req_data_i(tx_req_data[i*DATA_WIDTH +: DATA_WIDTH]),

                .rx_req_valid_o(rx_req_valid[i]),
                .rx_req_is_order_o(rx_req_is_order[i]),
                .rx_req_opcode_o(rx_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH]),
                .rx_req_match_type_o(rx_req_match_type[i*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
                .rx_req_source_id_o(rx_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .rx_req_target_id_o(rx_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .rx_req_addr_o(rx_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH]),
                .rx_req_data_o(rx_req_data[i*DATA_WIDTH +: DATA_WIDTH]),

                .rsp_valid_o(rsp_valid_o[i]),
                .rsp_source_id_o(rsp_source_id_o[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .rsp_target_id_o(rsp_target_id_o[i*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .rsp_addr_o(rsp_addr_o[i*ADDR_WIDTH +: ADDR_WIDTH]),
                .rsp_data_o(rsp_data_o[i*DATA_WIDTH +: DATA_WIDTH])
            );
        end
    endgenerate

    // 最后一个节点的next是节点0的pre
    ring_node #(
        .NODE_ID(NUM_NODES - 1),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .TX_FIFO_DEPTH(NODE_TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(NODE_RX_FIFO_DEPTH)
    ) last_node (
        .clk(clk),
        .rst_n(rst_n),

        .node_start_addr_i(node_start_addr_i[(NUM_NODES-1)*ADDR_WIDTH +: ADDR_WIDTH]),
        .node_end_addr_i(node_end_addr_i[(NUM_NODES-1)*ADDR_WIDTH +: ADDR_WIDTH]),

        .pre_req_valid_i(node_req_valid[(NUM_NODES-1)]),
        .pre_req_is_order_i(node_req_is_order[(NUM_NODES-1)]),
        .pre_req_opcode_i(node_req_opcode[(NUM_NODES-1)*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .pre_req_match_type_i(node_req_match_type[(NUM_NODES-1)*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
        .pre_req_source_id_i(node_req_source_id[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .pre_req_target_id_i(node_req_target_id[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .pre_req_addr_i(node_req_addr[(NUM_NODES-1)*ADDR_WIDTH +: ADDR_WIDTH]),
        .pre_req_data_i(node_req_data[(NUM_NODES-1)*DATA_WIDTH +: DATA_WIDTH]),

        .next_req_valid_i(node_req_valid[0]),
        .next_req_is_order_i(node_req_is_order[0]),
        .next_req_opcode_i(node_req_opcode[0*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .next_req_match_type_i(node_req_match_type[0*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
        .next_req_source_id_i(node_req_source_id[0*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .next_req_target_id_i(node_req_target_id[0*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .next_req_addr_i(node_req_addr[0*ADDR_WIDTH +: ADDR_WIDTH]),
        .next_req_data_i(node_req_data[0*DATA_WIDTH +: DATA_WIDTH]),

        .tx_req_valid_i(tx_req_valid[(NUM_NODES-1)]),
        .tx_req_is_order_i(tx_req_is_order[(NUM_NODES-1)]),
        .tx_req_opcode_i(tx_req_opcode[(NUM_NODES-1)*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_i(tx_req_match_type[(NUM_NODES-1)*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
        .tx_req_source_id_i(tx_req_source_id[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_i(tx_req_target_id[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_i(tx_req_addr[(NUM_NODES-1)*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_i(tx_req_data[(NUM_NODES-1)*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_o(rx_req_valid[(NUM_NODES-1)]),
        .rx_req_is_order_o(rx_req_is_order[(NUM_NODES-1)]),
        .rx_req_opcode_o(rx_req_opcode[(NUM_NODES-1)*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_o(rx_req_match_type[(NUM_NODES-1)*MATCH_TYPE_WIDTH := MATCH_TYPE_WIDTH]),
        .rx_req_source_id_o(rx_req_source_id[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_o(rx_req_target_id[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_o(rx_req_addr[(NUM_NODES-1)*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_o(rx_req_data[(NUM_NODES-1)*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_o(rsp_valid_o[(NUM_NODES-1)]),
        .rsp_source_id_o(rsp_source_id_o[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_o(rsp_target_id_o[(NUM_NODES-1)*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_o(rsp_addr_o[(NUM_NODES-1)*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_o(rsp_data_o[(NUM_NODES-1)*DATA_WIDTH +: DATA_WIDTH])
    );
endmodule
