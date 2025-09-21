// ram_node.v
// 完整的RAM节点，包含RAM和总线接口

`include "ram_params.v"

module ram_node (
    input clk,
    input rst_n,
    input [`NODE_ID_WIDTH-1:0] node_id,

    // Ring接口 - 输入
    input ring_in_valid,
    input [`NODE_ID_WIDTH-1:0] ring_in_src,
    input [`NODE_ID_WIDTH-1:0] ring_in_dest,
    input [`ADDR_WIDTH-1:0] ring_in_addr,
    input [`DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,

    // Ring接口 - 输出
    output ring_out_valid,
    output [`NODE_ID_WIDTH-1:0] ring_out_src,
    output [`NODE_ID_WIDTH-1:0] ring_out_dest,
    output [`ADDR_WIDTH-1:0] ring_out_addr,
    output [`DATA_WIDTH-1:0] ring_out_data,
    output ring_out_we,
    output [3:0] ring_out_be,
    output ring_out_ack
);

    // RAM接口信号
    wire ram_req;
    wire ram_we;
    wire [`ADDR_WIDTH-1:0] ram_addr;
    wire [`DATA_WIDTH-1:0] ram_data_in;
    wire [3:0] ram_be;
    wire [`DATA_WIDTH-1:0] ram_data_out;
    wire ram_ack;

    // 实例化RAM模块
    ram_module ram_inst (
        .clk(clk),
        .rst_n(rst_n),
        .req(ram_req),
        .we(ram_we),
        .addr(ram_addr),
        .data_in(ram_data_in),
        .be(ram_be),
        .data_out(ram_data_out),
        .ack(ram_ack)
    );

    // 实例化RAM Ring节点
    ram_ring_node ring_node_inst (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(node_id),
        .ring_in_valid(ring_in_valid),
        .ring_in_src(ring_in_src),
        .ring_in_dest(ring_in_dest),
        .ring_in_addr(ring_in_addr),
        .ring_in_data(ring_in_data),
        .ring_in_we(ring_in_we),
        .ring_in_be(ring_in_be),
        .ring_in_ack(ring_in_ack),
        .ring_out_valid(ring_out_valid),
        .ring_out_src(ring_out_src),
        .ring_out_dest(ring_out_dest),
        .ring_out_addr(ring_out_addr),
        .ring_out_data(ring_out_data),
        .ring_out_we(ring_out_we),
        .ring_out_be(ring_out_be),
        .ring_out_ack(ring_out_ack),
        .ram_req(ram_req),
        .ram_we(ram_we),
        .ram_addr(ram_addr),
        .ram_data_in(ram_data_in),
        .ram_be(ram_be),
        .ram_data_out(ram_data_out),
        .ram_ack(ram_ack)
    );

endmodule
