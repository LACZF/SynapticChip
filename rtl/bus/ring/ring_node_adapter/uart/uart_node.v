// uart_node.v
// Complete UART node, including UART module and bus interface

`include "uart_params.v"

module uart_node #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2
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
    input       [3:0]                   ring_in_be_i,
    input                               ring_in_ack_i,

    // Ring interface - Output
    output                              ring_out_valid_o,
    output      [NODE_ID_WIDTH-1:0]     ring_out_src_o,
    output      [NODE_ID_WIDTH-1:0]     ring_out_dest_o,
    output      [ADDR_WIDTH-1:0]        ring_out_addr_o,
    output      [DATA_WIDTH-1:0]        ring_out_data_o,
    output                              ring_out_we_o,
    output      [3:0]                   ring_out_be_o,
    output                              ring_out_ack_o,

    output                              req_o,
    output                              we_o,
    output      [ADDR_WIDTH-1:0]        addr_o,
    output      [DATA_WIDTH-1:0]        data_in_o,
    input  reg  [DATA_WIDTH-1:0]        data_out_i,
    input  reg                          ack_i,
    input  reg                          txd_i,
    output                              rxd_o,
    input  reg                          rts_i,
    output                              cts_o,
    input  reg                          int_i,

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
    // Instantiate UART Ring node
    uart_ring_node ring_node_inst (
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
        .uart_req_o(req_o),
        .uart_we_o(we_o),
        .uart_addr_o(addr_o),
        .uart_data_out_i(data_out_i),
        .uart_data_in_o(data_in_o),
        .uart_ack_i(ack_i),
        .uart_int_i(int_i),
        .int_ack_o()
    );
endmodule