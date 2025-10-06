// gpio_node.v
// 完整的GPIO节点，包含GPIO模块和总线接口

`include "gpio_params.v"

module gpio_node #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2
) (
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

    // 发送请求
    output wire [NUM_RINGS-1:0]         tx_req_ring_mask_o,      // 指定使用的Ring
    output wire [NUM_RINGS-1:0]         tx_req_ring_disable_o,   // 禁用的Ring
    output wire                         tx_req_valid_o,
    output wire                         tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        tx_req_data_o,

    // 接受请求
    input  wire                         rx_req_valid_i,
    input  wire                         rx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      rx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        rx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        rx_req_data_i,

    // 接收响应
    input  wire                         rsp_valid_i,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        rsp_addr_i,
    input  wire [DATA_WIDTH-1:0]        rsp_data_i,

    // GPIO引脚
    inout [`GPIO_WIDTH-1:0] gpio_pins,

    // 中断输出
    output int_out
);

    // GPIO接口信号
    wire gpio_req;
    wire gpio_we;
    wire [`ADDR_WIDTH-1:0] gpio_addr;
    wire [`DATA_WIDTH-1:0] gpio_data_out;
    wire [`DATA_WIDTH-1:0] gpio_data_in;
    wire gpio_ack;
    wire gpio_int;

    // 实例化GPIO模块
    gpio_module gpio_inst (
        .clk(clk),
        .rst_n(rst_n),
        .req(gpio_req),
        .we(gpio_we),
        .addr(gpio_addr),
        .data_in(gpio_data_out),
        .data_out(gpio_data_in),
        .ack(gpio_ack),
        .gpio_pins(gpio_pins),
        .int_out(gpio_int)
    );

    // 实例化GPIO Ring节点
    gpio_ring_node ring_node_inst (
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
        .gpio_req(gpio_req),
        .gpio_we(gpio_we),
        .gpio_addr(gpio_addr),
        .gpio_data_out(gpio_data_out),
        .gpio_data_in(gpio_data_in),
        .gpio_ack(gpio_ack),
        .gpio_int(gpio_int),
        .int_ack() // 暂时不使用中断确认
    );

    // 中断输出
    assign int_out = gpio_int;

endmodule
