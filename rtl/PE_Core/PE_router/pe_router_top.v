// pe_router_top.v
// Complete router module implementation

`include "pe_router_params.v"

module pe_router_top #(
    parameter ADDR_WIDTH                    = 32,
    parameter DATA_WIDTH                    = 32,
    parameter NUM_PORTS                     = 4
) (
    input                                   clk,
    input                                   rst_n,

    // Configuration interface
    input                                   cfg_valid_i,
    input  [ADDR_WIDTH-1:0]                 cfg_addr_i,
    input  [DATA_WIDTH-1:0]                 cfg_data_i,
    output                                  cfg_ack_o,

    // Data input interface
    input  [NUM_PORTS-1:0]                  data_in_valid_i,
    input  [(NUM_PORTS*DATA_WIDTH)-1:0]     data_in_i,
    output [NUM_PORTS-1:0]                  data_in_ready_o,

    // Data output interface
    output [NUM_PORTS-1:0]                  data_out_valid_o,
    output [(NUM_PORTS*DATA_WIDTH)-1:0]     data_out_o,
    input  [NUM_PORTS-1:0]                  data_out_ready_i,

    // Status output
    output [DATA_WIDTH-1:0]                 status_o
);

    // Internal signals
    wire                  route_cfg_valid;
    wire [ADDR_WIDTH-1:0] route_cfg_addr;
    wire [DATA_WIDTH-1:0] route_cfg_data;
    wire                  route_cfg_ack;
    wire [DATA_WIDTH-1:0] route_status;

    // Instantiate router configuration interface
    router_config #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PORTS(NUM_PORTS)
    ) config_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid_i(cfg_valid_i),
        .cfg_addr_i(cfg_addr_i),
        .cfg_data_i(cfg_data_i),
        .cfg_ack_o(cfg_ack_o),
        .route_cfg_valid_o(route_cfg_valid),
        .route_cfg_addr_o(route_cfg_addr),
        .route_cfg_data_o(route_cfg_data),
        .route_cfg_ack_i(route_cfg_ack),
        .route_status_i(route_status),
        .status_out_o(status_o)
    );

    // Instantiate router core
    pe_router_core #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PORTS(NUM_PORTS)
    ) core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid_i(route_cfg_valid),
        .cfg_addr_i(route_cfg_addr),
        .cfg_data_i(route_cfg_data),
        .cfg_ack_o(route_cfg_ack),
        .data_in_valid_i(data_in_valid_i),
        .data_in_i(data_in_i),
        .data_in_ready_o(data_in_ready_o),
        .data_out_valid_o(data_out_valid_o),
        .data_out_o(data_out_o),
        .data_out_ready_i(data_out_ready_i),
        .status_o(route_status)
    );

endmodule