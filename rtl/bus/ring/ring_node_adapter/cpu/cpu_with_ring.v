// Top-level module example integrating CPU and Ring bus interface
// Demonstrates how to connect cpu_top and cpu_ring_interface

module cpu_with_ring #(
    parameter NUM_RINGS                      = 2,
    parameter ADDR_WIDTH                     = 64,
    parameter DATA_WIDTH                     = 64,
    parameter NODE_ID_WIDTH                  = 8,
    parameter NODE_ID                        = 0,
    parameter OPCODE_WIDTH                   = 8,
    parameter MATCH_TYPE_WIDTH               = 2,
    parameter INST_WIDTH                     = 32,
    parameter NUM_CORES                      = 4,
    parameter CORE_ID_WIDTH                  = 2,
    parameter ENABLE_L2_CACHE                = 1,
    parameter ENABLE_L3_CACHE                = 1,
    parameter CPU_TYPE                       = 0
) (
    input                                    clk,
    input                                    rst_n,

    output                                   cpu_ext_int_o,
    input  wire                              cpu_mem_req_i,
    input  wire [ADDR_WIDTH-1:0]             cpu_mem_addr_i,
    input  wire [511:0]                      cpu_mem_wdata_i,
    input  wire                              cpu_mem_we_i,
    output wire                              cpu_mem_ready_o,
    output wire [511:0]                      cpu_mem_rdata_o,

    // Ring bus interface
    // Send requests
    output wire [NUM_RINGS-1:0]              tx_req_ring_mask_o,
    output wire [NUM_RINGS-1:0]              tx_req_ring_disable_o,
    output wire                              tx_req_valid_o,
    output wire                              tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]           tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]       tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]          tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]          tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]             tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]             tx_req_data_o,

    // Receive requests
    input wire                               rx_req_valid_i,
    input wire                               rx_req_is_order_i,
    input wire [OPCODE_WIDTH-1:0]            rx_req_opcode_i,
    input wire [MATCH_TYPE_WIDTH-1:0]        rx_req_match_type_i,
    input wire [NODE_ID_WIDTH-1:0]           rx_req_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]           rx_req_target_id_i,
    input wire [ADDR_WIDTH-1:0]              rx_req_addr_i,
    input wire [DATA_WIDTH-1:0]              rx_req_data_i,

    // Receive responses
    input wire                               rsp_valid_i,
    input wire [NODE_ID_WIDTH-1:0]           rsp_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]           rsp_target_id_i,
    input wire [ADDR_WIDTH-1:0]              rsp_addr_i,
    input wire [DATA_WIDTH-1:0]              rsp_data_i
);
    // CPU-Ring bus interface module instance
    cpu_ring_interface #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(NODE_ID),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_cpu_ring_interface (
        .clk(clk),
        .rst_n(rst_n),

        // Connect to CPU top module
        .cpu_mem_req(cpu_mem_req_i),
        .cpu_mem_addr(cpu_mem_addr_i),
        .cpu_mem_wdata(cpu_mem_wdata_i),
        .cpu_mem_we(cpu_mem_we_i),
        .cpu_mem_ready(cpu_mem_ready_o),
        .cpu_mem_rdata(cpu_mem_rdata_o),

        // Connect to Ring bus
        .tx_req_ring_mask_o(tx_req_ring_mask_o),
        .tx_req_ring_disable_o(tx_req_ring_disable_o),
        .tx_req_valid_o(tx_req_valid_o),
        .tx_req_is_order_o(tx_req_is_order_o),
        .tx_req_opcode_o(tx_req_opcode_o),
        .tx_req_match_type_o(tx_req_match_type_o),
        .tx_req_source_id_o(tx_req_source_id_o),
        .tx_req_target_id_o(tx_req_target_id_o),
        .tx_req_addr_o(tx_req_addr_o),
        .tx_req_data_o(tx_req_data_o),
        .rx_req_valid_i(rx_req_valid_i),
        .rx_req_is_order_i(rx_req_is_order_i),
        .rx_req_opcode_i(rx_req_opcode_i),
        .rx_req_match_type_i(rx_req_match_type_i),
        .rx_req_source_id_i(rx_req_source_id_i),
        .rx_req_target_id_i(rx_req_target_id_i),
        .rx_req_addr_i(rx_req_addr_i),
        .rx_req_data_i(rx_req_data_i),
        .rsp_valid_i(rsp_valid_i),
        .rsp_source_id_i(rsp_source_id_i),
        .rsp_target_id_i(rsp_target_id_i),
        .rsp_addr_i(rsp_addr_i),
        .rsp_data_i(rsp_data_i)
    );

endmodule