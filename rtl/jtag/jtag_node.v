// jtag_node.v
// 完整的JTAG节点，包含JTAG TAP控制器和总线接口

`include "jtag_params.v"

module jtag_node (
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
    output ring_out_ack,

    // JTAG接口
    input tck,
    input tms,
    input tdi,
    output tdo,
    output tdo_en,

    // 调试输出
    output [`DATA_WIDTH-1:0] debug_data,
    output debug_valid
);

    // JTAG接口信号
    wire jtag_req;
    wire jtag_we;
    wire [`ADDR_WIDTH-1:0] jtag_addr;
    wire [`DATA_WIDTH-1:0] jtag_data_out;
    wire [`DATA_WIDTH-1:0] jtag_data_in;
    wire jtag_ack;
    wire [`DATA_WIDTH-1:0] jtag_debug_data;
    wire jtag_debug_valid;

    // 实例化JTAG TAP控制器
    jtag_tap tap_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .tdo_en(tdo_en),
        .req(jtag_req),
        .we(jtag_we),
        .addr(jtag_addr),
        .data_in(jtag_data_out),
        .data_out(jtag_data_in),
        .ack(jtag_ack),
        .debug_data(jtag_debug_data),
        .debug_valid(jtag_debug_valid)
    );

    // 实例化JTAG Ring节点
    jtag_ring_node ring_node_inst (
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
        .jtag_req(jtag_req),
        .jtag_we(jtag_we),
        .jtag_addr(jtag_addr),
        .jtag_data_out(jtag_data_out),
        .jtag_data_in(jtag_data_in),
        .jtag_ack(jtag_ack),
        .jtag_debug_data(jtag_debug_data),
        .jtag_debug_valid(jtag_debug_valid)
    );

    // 调试输出
    assign debug_data = jtag_debug_data;
    assign debug_valid = jtag_debug_valid;

endmodule
