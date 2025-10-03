// rom_node.v
// 完整的ROM节点，包含ROM、Flash控制器和总线接口

`include "rom_params.v"

module rom_node #(
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

    // Flash接口
    output flash_ce_n,
    output flash_oe_n,
    output flash_we_n,
    output [`FLASH_ADDR_WIDTH-1:0] flash_addr,
    inout [`FLASH_DATA_WIDTH-1:0] flash_data,

    // 发送请求
    input  wire [NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire                         rx_req_valid_o,
    output wire                         rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire                         rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [DATA_WIDTH-1:0]        rsp_data_o
);

    // ROM接口信号
    wire rom_req;
    wire [`ADDR_WIDTH-1:0] rom_addr;
    wire [`DATA_WIDTH-1:0] rom_data_out;
    wire rom_ack;

    // 初始化接口信号
    wire init_req;
    wire [`ADDR_WIDTH-1:0] init_addr;
    wire [`DATA_WIDTH-1:0] init_data;
    wire init_ack;
    wire initialized;

    // Flash控制器信号
    wire flash_init_req;

    // 实例化ROM模块
    rom_module rom_inst (
        .clk(clk),
        .rst_n(rst_n),
        .req(rom_req),
        .addr(rom_addr),
        .data_out(rom_data_out),
        .ack(rom_ack),
        .init_req(init_req),
        .init_addr(init_addr),
        .init_data(init_data),
        .init_ack(init_ack),
        .initialized(initialized)
    );

    // 实例化Flash控制器
    flash_controller flash_ctrl_inst (
        .clk(clk),
        .rst_n(rst_n),
        .init_req(flash_init_req),
        .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n),
        .flash_we_n(flash_we_n),
        .flash_addr(flash_addr),
        .flash_data(flash_data),
        .rom_init_req(init_req),
        .rom_init_addr(init_addr),
        .rom_init_data(init_data),
        .rom_init_ack(init_ack),
        .init_done(initialized)
    );

    // 实例化ROM Ring节点
    rom_ring_node ring_node_inst (
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
        .rom_req(rom_req),
        .rom_addr(rom_addr),
        .rom_data_out(rom_data_out),
        .rom_ack(rom_ack),
        .init_req(flash_init_req),
        .init_done(initialized)
    );

endmodule
