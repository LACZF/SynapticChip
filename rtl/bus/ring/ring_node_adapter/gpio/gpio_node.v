// gpio_node.v
// Complete GPIO node, including GPIO module and bus interface

`include "gpio_params.v"

module gpio_node #(
    parameter NUM_RINGS                 = 2,
    parameter ADDR_WIDTH                = 32,
    parameter DATA_WIDTH                = 64,
    parameter NODE_ID_WIDTH             = 8,
    parameter NODE_ID                   = 0,
    parameter OPCODE_WIDTH              = 8,
    parameter GPIO_WIDTH                = 32,
    parameter MATCH_TYPE_WIDTH          = 2
) (
    input                               clk,
    input                               rst_n,
    input  [NODE_ID_WIDTH-1:0]          node_id,

    // Ring interface - Input
    input                               ring_in_valid,
    input  [NODE_ID_WIDTH-1:0]          ring_in_src,
    input  [NODE_ID_WIDTH-1:0]          ring_in_dest,
    input  [ADDR_WIDTH-1:0]             ring_in_addr,
    input  [DATA_WIDTH-1:0]             ring_in_data,
    input                               ring_in_we,
    input  [3:0]                        ring_in_be,
    input                               ring_in_ack,

    // Ring interface - Output
    output                              ring_out_valid,
    output [NODE_ID_WIDTH-1:0]          ring_out_src,
    output [NODE_ID_WIDTH-1:0]          ring_out_dest,
    output [ADDR_WIDTH-1:0]             ring_out_addr,
    output [DATA_WIDTH-1:0]             ring_out_data,
    output                              ring_out_we,
    output [3:0]                        ring_out_be,
    output                              ring_out_ack,

    output                              gpio_req_o,
    output                              gpio_we_o,
    output     [ADDR_WIDTH-1:0]         gpio_addr_o,
    output     [DATA_WIDTH-1:0]         gpio_data_in_o,
    input  reg [DATA_WIDTH-1:0]         gpio_data_out_i,
    input  reg                          gpio_ack_i,
    inout      [GPIO_WIDTH-1:0]         gpio_pins,
    input  reg                          gpio_int_i,

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
        .gpio_req(gpio_req_o),
        .gpio_we(gpio_we_o),
        .gpio_addr(gpio_addr_o),
        .gpio_data_out(gpio_data_out_i),
        .gpio_data_in(gpio_data_in_o),
        .gpio_ack(gpio_ack_i),
        .gpio_int(gpio_int_i),
        .int_ack() // Interrupt acknowledgment not used for now
    );
endmodule