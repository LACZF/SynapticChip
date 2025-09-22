// uart_node.v
// 完整的UART节点，包含UART模块和总线接口

`include "uart_params.v"

module uart_node (
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

    // 串行接口
    output uart_txd,            // 发送数据线
    input uart_rxd,             // 接收数据线
    output rts,            // 请求发送 (可选)
    input cts,             // 清除发送 (可选)

    // 中断输出
    output int_out
);

    // UART接口信号
    wire uart_req;
    wire uart_we;
    wire [`ADDR_WIDTH-1:0] uart_addr;
    wire [`DATA_WIDTH-1:0] uart_data_out;
    wire [`DATA_WIDTH-1:0] uart_data_in;
    wire uart_ack;
    wire uart_int;

    // 实例化UART模块
    uart_core uart_inst (
        .clk(clk),
        .rst_n(rst_n),
        .req(uart_req),
        .we(uart_we),
        .addr(uart_addr),
        .data_in(uart_data_out),
        .data_out(uart_data_in),
        .ack(uart_ack),
        .txd(uart_txd),
        .rxd(uart_rxd),
        .rts(rts),
        .cts(cts),
        .int_out(uart_int)
    );

    // 实例化UART Ring节点
    uart_ring_node ring_node_inst (
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
        .uart_req(uart_req),
        .uart_we(uart_we),
        .uart_addr(uart_addr),
        .uart_data_out(uart_data_out),
        .uart_data_in(uart_data_in),
        .uart_ack(uart_ack),
        .uart_int(uart_int),
        .int_ack() // 暂时不使用中断确认
    );

    // 中断输出
    assign int_out = uart_int;

endmodule
