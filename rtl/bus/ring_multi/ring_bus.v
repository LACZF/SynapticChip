`include "ring_bus_params.v"

module ring_bus #(
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 4,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
) (
    input  wire                                   clk,
    input  wire                                   rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // 发送请求
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
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

    // Ring总线状态
    output wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id_o,
    output wire [NUM_RINGS-1:0]                   ring_busy
);
    reg [NUM_RINGS-1:0] ring_busy;
    localparam tx_fifo_data_width = NUM_RINGS + NUM_RINGS + OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH + 1 + 1;
    localparam rx_fifo_data_width = NUM_RINGS + NUM_RINGS + OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH + 1 + 1;

    reg [NUM_NODES-1:0]                   tx_fifo_full;
    reg [NUM_NODES-1:0]                   tx_fifo_empty;

    reg [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask;
    reg [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable;
    reg [NUM_NODES-1:0]                   tx_req_valid;
    reg [NUM_NODES-1:0]                   tx_req_is_order;
    reg [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode;
    reg [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type;
    reg [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id;
    reg [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id;
    reg [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr;
    reg [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data;

    genvar i;
    generate
        for (i = 0; i < NUM_NODES; i = i + 1) begin : ring_tx_fifo
            simple_fifo #(
                .DATA_WIDTH(tx_fifo_data_width),
                .FIFO_DEPTH(TX_FIFO_DEPTH)
            ) tx_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .wr_en(tx_req_valid_i[i]),
                .data_in({
                    tx_req_ring_mask_i[i*NUM_RINGS +: NUM_RINGS],
                    tx_req_ring_disable_i[i*NUM_RINGS +: NUM_RINGS],
                    tx_req_valid_i[i],
                    tx_req_is_order_i[i],
                    tx_req_opcode_i[i*OPCODE_WIDTH +: OPCODE_WIDTH],
                    tx_req_match_type_i[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH],
                    tx_req_source_id_i[i*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    tx_req_target_id_i[i*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    tx_req_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH],
                    tx_req_data_i[i*DATA_WIDTH +: DATA_WIDTH]
                }),
                .rd_en(tx_req_rd_en),
                .rd_done(tx_req_rd_done);
                .data_out({
                    tx_req_ring_mask[i*NUM_RINGS +: NUM_RINGS],
                    tx_req_ring_disable[i*NUM_RINGS +: NUM_RINGS],
                    tx_req_valid[i],
                    tx_req_is_order[i],
                    tx_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH],
                    tx_req_match_type[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH],
                    tx_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    tx_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    tx_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH],
                    tx_req_data[i*DATA_WIDTH +: DATA_WIDTH]
                }),
                .full(tx_fifo_full),
                .empty(tx_fifo_empty)
            );
        end
    endgenerate

    // 仲裁器
    ring_arbiter #(
        .NUM_RINGS(NUM_RINGS)
    ) u_arbiter (
        .clk(clk),
        .rst_n(rst_n),

        .req_valid(req_valid),
        .req_addr(req_addr),
        .req_match_type(req_match_type),
        .req_target_id(req_target_id),
        .req_data(req_data),
        .req_ring_mask(req_ring_mask),
        .req_ring_disable(req_ring_disable),
        .req_ready(req_ready),

        .ring_req_valid(ring_req_valid),
        .ring_req_ready(ring_req_ready),
        .ring_req_addr(ring_req_addr),
        .ring_req_match_type(ring_req_match_type),
        .ring_req_target_id(ring_req_target_id),
        .ring_req_data(ring_req_data),

        .ring_busy(ring_busy)
    );

    // 生成多条Ring总线
    genvar i;
    generate
        for (i = 0; i < NUM_RINGS; i = i + 1) begin : ring_gen
            ring_single_bus #(
                .NUM_NODES(NUM_NODES),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .OPCODE_WIDTH(OPCODE_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
                .RING_ID_WIDTH(RING_ID_WIDTH),
                .RING_ID(i)
            ) u_single_ring (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i),
                .node_end_addr_i(node_end_addr_i),

                .tx_req_valid_i(tx_req_valid_i),
                .tx_req_is_order_i(tx_req_is_order_i),
                .tx_req_opcode_i(tx_req_opcode_i),
                .tx_req_match_type_i(tx_req_match_type_i),
                .tx_req_source_id_i(tx_req_source_id_i),
                .tx_req_target_id_i(tx_req_target_id_i),
                .tx_req_addr_i(tx_req_addr_i),
                .tx_req_data_i(tx_req_data_i),

                .rx_req_valid_o(rx_req_valid_o),
                .rx_req_is_order_o(rx_req_is_order_o),
                .rx_req_opcode_o(rx_req_opcode_o),
                .rx_req_match_type_o(rx_req_match_type_o),
                .rx_req_source_id_o(rx_req_source_id_o),
                .rx_req_target_id_o(rx_req_target_id_o),
                .rx_req_addr_o(rx_req_addr_o),
                .rx_req_data_o(rx_req_data_o),

                .rsp_valid_o(rsp_valid_o),
                .rsp_source_id_o(rsp_source_id_o),
                .rsp_target_id_o(rsp_target_id_o),
                .rsp_addr_o(rsp_addr_o),
                .rsp_data_o(rsp_data_o),

                .ring_busy_o(ring_busy[i])
            );
        end
    endgenerate

endmodule
