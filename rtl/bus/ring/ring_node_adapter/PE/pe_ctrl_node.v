// pe_ctrl_node.v
// 集成PE阵列和路由的Fabric模块

module pe_ctrl_node #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter NUM_PES           = 4,
    parameter INST_WIDTH        = 32,
    parameter PE_ID_WIDTH       = 4,
    parameter PE_ARRAY_ROWS     = 2,
    parameter PE_ARRAY_COLS     = 2
) (
    input clk,
    input rst_n,

    // 待删除
    input ring_in_valid,
    input [NODE_ID_WIDTH-1:0] ring_in_src,
    input [NODE_ID_WIDTH-1:0] ring_in_dest,
    input [ADDR_WIDTH-1:0] ring_in_addr,
    input [DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,
    output reg ring_out_valid,
    output reg [NODE_ID_WIDTH-1:0] ring_out_src,
    output reg [NODE_ID_WIDTH-1:0] ring_out_dest,
    output reg [ADDR_WIDTH-1:0] ring_out_addr,
    output reg [DATA_WIDTH-1:0] ring_out_data,
    output reg ring_out_we,
    output reg [3:0] ring_out_be,
    output reg ring_out_ack,

    // PE
    output reg [NUM_PES-1:0]                      pe_enable_o,
    output reg [NUM_PES-1:0]                      pe_reset_o,
    output reg [(NUM_PES*INST_WIDTH)-1:0]         pe_instructions_o,
    output reg                                    pe_inst_valid_o,
    input      [(NUM_PES*DATA_WIDTH)-1:0]         pe_status_i,
    input      [(NUM_PES*DATA_WIDTH)-1:0]         pe_outputs_i,
    input      [NUM_PES-1:0]                      pe_busy_i,
    output reg [(NUM_PES*4*PE_ID_WIDTH)-1:0]      pe_route_config_o,
    output reg                                    pe_route_cfg_valid_o,

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
    input  wire [DATA_WIDTH-1:0]        rsp_data_i
);
    pe_ctrl_ring_node #(
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PES(NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH)
    ) u_pe_ctrel_ring_node (
        .clk(clk),
        .rst_n(rst_n),
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
        .pe_enable(pe_enable_o),
        .pe_reset(pe_reset_o),
        .pe_instructions(pe_instructions_o),
        .pe_inst_valid(pe_inst_valid_o),
        .pe_status(pe_status_i),
        .pe_outputs(pe_outputs_i),
        .pe_busy(pe_busy_i),
        .route_config(pe_route_config_o),
        .route_cfg_valid(pe_route_cfg_valid_o)
    );
endmodule