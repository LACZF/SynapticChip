// ring_bus.v
// Ring总线顶层模块

`include "ring_params.v"

module ring_bus (
    input clk,
    input rst_n,

    // 节点接口
    input [`NODES-1:0] local_req,
    input [`NODES*`ADDR_WIDTH-1:0] local_addr,
    input [`NODES*`DATA_WIDTH-1:0] local_data_in,
    output [`NODES-1:0] local_ack,
    output [`NODES*`DATA_WIDTH-1:0] local_data_out
);

    // 节点间连接信号
    wire [`NODES-1:0] ring_valid;
    wire [`NODES*`NODE_ID_WIDTH-1:0] ring_src;
    wire [`NODES*`NODE_ID_WIDTH-1:0] ring_dest;
    wire [`NODES*`ADDR_WIDTH-1:0] ring_addr;
    wire [`NODES*`DATA_WIDTH-1:0] ring_data;
    wire [`NODES-1:0] ring_ack;

    // 生成节点实例
    genvar i;
    generate
        for (i = 0; i < `NODES; i = i + 1) begin : node_gen
            ring_node node_inst (
                .clk(clk),
                .rst_n(rst_n),
                .node_id(i),

                // 本地接口
                .local_req(local_req[i]),
                .local_addr(local_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .local_data_in(local_data_in[i*`DATA_WIDTH +: `DATA_WIDTH]),
                .local_ack(local_ack[i]),
                .local_data_out(local_data_out[i*`DATA_WIDTH +: `DATA_WIDTH]),

                // Ring输入接口（来自上一个节点）
                .ring_in_valid(ring_valid[i]),
                .ring_in_src(ring_src[i*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
                .ring_in_dest(ring_dest[i*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
                .ring_in_addr(ring_addr[i*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .ring_in_data(ring_data[i*`DATA_WIDTH +: `DATA_WIDTH]),
                .ring_in_ack(ring_ack[i]),

                // Ring输出接口（到下一个节点）
                .ring_out_valid(ring_valid[(i+1) % `NODES]),
                .ring_out_src(ring_src[((i+1) % `NODES)*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
                .ring_out_dest(ring_dest[((i+1) % `NODES)*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
                .ring_out_addr(ring_addr[((i+1) % `NODES)*`ADDR_WIDTH +: `ADDR_WIDTH]),
                .ring_out_data(ring_data[((i+1) % `NODES)*`DATA_WIDTH +: `DATA_WIDTH]),
                .ring_out_ack(ring_ack[(i+1) % `NODES])
            );
        end
    endgenerate

endmodule
