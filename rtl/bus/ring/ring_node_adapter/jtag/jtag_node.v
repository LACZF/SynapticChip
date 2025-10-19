// jtag_node.v
// Complete JTAG node, including JTAG TAP controller and bus interface

`include "jtag_params.v"

module jtag_node #(
    parameter NUM_RINGS                 = 2,
    parameter ADDR_WIDTH                = 64,
    parameter DATA_WIDTH                = 64,
    parameter NODE_ID_WIDTH             = 5,
    parameter NODE_ID                   = 0,
    parameter OPCODE_WIDTH              = 8,
    parameter MATCH_TYPE_WIDTH          = 2
) (
    input                               clk,
    input                               rst_n,
    input [NODE_ID_WIDTH-1:0]           node_id_i,

    // Ring interface - Input
    input                               ring_in_valid_i,
    input [NODE_ID_WIDTH-1:0]           ring_in_src_i,
    input [NODE_ID_WIDTH-1:0]           ring_in_dest_i,
    input [ADDR_WIDTH-1:0]              ring_in_addr_i,
    input [DATA_WIDTH-1:0]              ring_in_data_i,
    input                               ring_in_we_i,
    input [3:0]                         ring_in_be_i,
    input                               ring_in_ack_i,

    // Ring interface - Output
    output                              ring_out_valid_o,
    output [NODE_ID_WIDTH-1:0]          ring_out_src_o,
    output [NODE_ID_WIDTH-1:0]          ring_out_dest_o,
    output [ADDR_WIDTH-1:0]             ring_out_addr_o,
    output [DATA_WIDTH-1:0]             ring_out_data_o,
    output                              ring_out_we_o,
    output [3:0]                        ring_out_be_o,
    output                              ring_out_ack_o,

    // JTAG interface
    output                              jtag_tck_o,
    output                              jtag_tms_o,
    output                              jtag_tdi_o,
    input  reg                          jtag_tdo_i,
    input  reg                          jtag_tdo_en_i,
    output                              jtag_req_o,
    output                              jtag_we_o,
    output [ADDR_WIDTH-1:0]             jtag_addr_o,
    output [DATA_WIDTH-1:0]             jtag_data_in_o,
    input  reg [DATA_WIDTH-1:0]         jtag_data_out_i,
    input  reg                          jtag_ack_i,
    input  reg [DATA_WIDTH-1:0]         jtag_debug_data_i,
    input  reg                          jtag_debug_valid_i,

    // Send requests
    output wire [NUM_RINGS-1:0]         tx_req_ring_mask_o,      // Specify Ring to use
    output wire [NUM_RINGS-1:0]         tx_req_ring_disable_o,   // Disable Ring
    output wire                         tx_req_valid_o,
    output wire                         tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        tx_req_data_o,

    // Receive requests
    input  wire                         rx_req_valid_i,
    input  wire                         rx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      rx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        rx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        rx_req_data_i,

    // Receive responses
    input  wire                         rsp_valid_i,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        rsp_addr_i,
    input  wire [DATA_WIDTH-1:0]        rsp_data_i
);
    jtag_ring_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(NODE_ID),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) ring_node_inst (
        .clk(clk),
        .rst_n(rst_n),
        .node_id_i(node_id_i),
        .ring_in_valid_i(ring_in_valid_i),
        .ring_in_src_i(ring_in_src_i),
        .ring_in_dest_i(ring_in_dest_i),
        .ring_in_addr_i(ring_in_addr_i),
        .ring_in_data_i(ring_in_data_i),
        .ring_in_we_i(ring_in_we_i),
        .ring_in_be_i(ring_in_be_i),
        .ring_in_ack_i(ring_in_ack_i),

        .ring_out_valid_o(ring_out_valid_o),
        .ring_out_src_o(ring_out_src_o),
        .ring_out_dest_o(ring_out_dest_o),
        .ring_out_addr_o(ring_out_addr_o),
        .ring_out_data_o(ring_out_data_o),
        .ring_out_we_o(ring_out_we_o),
        .ring_out_be_o(ring_out_be_o),
        .ring_out_ack_o(ring_out_ack_o),
        .jtag_req_o(jtag_req_o),
        .jtag_we_o(jtag_we_o),
        .jtag_addr_o(jtag_addr_o),
        .jtag_data_out_o(jtag_data_in_o),
        .jtag_data_in_i(jtag_data_out_i),
        .jtag_ack_i(jtag_ack_i),
        .jtag_debug_data_i(jtag_debug_data_i),
        .jtag_debug_valid_i(jtag_debug_valid_i)
    );
endmodule