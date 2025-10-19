// pe_ctrl_node.v
// Fabric module integrating PE array and routing

module pe_ctrl_node #(
    parameter NUM_RINGS                           = 2,
    parameter ADDR_WIDTH                          = 64,
    parameter DATA_WIDTH                          = 64,
    parameter NODE_ID_WIDTH                       = 8,
    parameter NODE_ID                             = 0,
    parameter OPCODE_WIDTH                        = 8,
    parameter MATCH_TYPE_WIDTH                    = 2,
    parameter NUM_PES                             = 4,
    parameter INST_WIDTH                          = 32,
    parameter PE_ID_WIDTH                         = 4,
    parameter PE_ARRAY_ROWS                       = 2,
    parameter PE_ARRAY_COLS                       = 2
) (
    input                                         clk,
    input                                         rst_n,

    // To be deleted
    input                                         ring_in_valid_i,
    input       [NODE_ID_WIDTH-1:0]               ring_in_src_i,
    input       [NODE_ID_WIDTH-1:0]               ring_in_dest_i,
    input       [ADDR_WIDTH-1:0]                  ring_in_addr_i,
    input       [DATA_WIDTH-1:0]                  ring_in_data_i,
    input                                         ring_in_we_i,
    input       [3:0]                             ring_in_be_i,
    input                                         ring_in_ack_i,
    output reg                                    ring_out_valid_o,
    output reg  [NODE_ID_WIDTH-1:0]               ring_out_src_o,
    output reg  [NODE_ID_WIDTH-1:0]               ring_out_dest_o,
    output reg  [ADDR_WIDTH-1:0]                  ring_out_addr_o,
    output reg  [DATA_WIDTH-1:0]                  ring_out_data_o,
    output reg                                    ring_out_we_o,
    output reg  [3:0]                             ring_out_be_o,
    output reg                                    ring_out_ack_o,

    // PE
    output wire [NUM_PES-1:0]                     pe_enable_o,
    output wire [NUM_PES-1:0]                     pe_reset_o,
    output wire [(NUM_PES*INST_WIDTH)-1:0]        pe_instructions_o,
    output wire                                   pe_inst_valid_o,
    input      [(NUM_PES*DATA_WIDTH)-1:0]         pe_status_i,
    input      [(NUM_PES*DATA_WIDTH)-1:0]         pe_outputs_i,
    input      [NUM_PES-1:0]                      pe_busy_i,
    output wire [(NUM_PES*4*PE_ID_WIDTH)-1:0]     pe_route_config_o,
    output wire                                   pe_route_cfg_valid_o,

    // Send request
    output wire [NUM_RINGS-1:0]                   tx_req_ring_mask_o,      // Specify Ring to use
    output wire [NUM_RINGS-1:0]                   tx_req_ring_disable_o,   // Disable Ring
    output wire                                   tx_req_valid_o,
    output wire                                   tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]                tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]            tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]               tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]               tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]                  tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]                  tx_req_data_o,

    // Receive request
    input  wire                                   rx_req_valid_i,
    input  wire                                   rx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]                rx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]            rx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]               rx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]               tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]               rx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]                  rx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]                  rx_req_data_i,

    // Receive response
    input  wire                                   rsp_valid_i,
    input  wire [NODE_ID_WIDTH-1:0]               rsp_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]               rsp_target_id_i,
    input  wire [ADDR_WIDTH-1:0]                  rsp_addr_i,
    input  wire [DATA_WIDTH-1:0]                  rsp_data_i
);
    pe_ctrl_ring_node #(
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PES(NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH)
    ) u_pe_ctrl_ring_node (
        .clk(clk),
        .rst_n(rst_n),
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
        .pe_enable_o(pe_enable_o),
        .pe_reset_o(pe_reset_o),
        .pe_instructions_o(pe_instructions_o),
        .pe_inst_valid_o(pe_inst_valid_o),
        .pe_status_i(pe_status_i),
        .pe_outputs_i(pe_outputs_i),
        .pe_busy_i(pe_busy_i),
        .route_config_o(pe_route_config_o),
        .route_cfg_valid_o(pe_route_cfg_valid_o)
    );
endmodule