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
    input                                   cfg_valid,
    input  [ADDR_WIDTH-1:0]                 cfg_addr,
    input  [DATA_WIDTH-1:0]                 cfg_data,
    output                                  cfg_ack,

    // Data input interface
    input  [NUM_PORTS-1:0]                  data_in_valid,
    input  [(NUM_PORTS*DATA_WIDTH)-1:0]     data_in,
    output [NUM_PORTS-1:0]                  data_in_ready,

    // Data output interface
    output [NUM_PORTS-1:0]                  data_out_valid,
    output [(NUM_PORTS*DATA_WIDTH)-1:0]     data_out,
    input  [NUM_PORTS-1:0]                  data_out_ready,

    // Status output
    output [DATA_WIDTH-1:0]                 status
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
        .cfg_valid(cfg_valid),
        .cfg_addr(cfg_addr),
        .cfg_data(cfg_data),
        .cfg_ack(cfg_ack),
        .route_cfg_valid(route_cfg_valid),
        .route_cfg_addr(route_cfg_addr),
        .route_cfg_data(route_cfg_data),
        .route_cfg_ack(route_cfg_ack),
        .route_status(route_status),
        .status_out(status)
    );

    // Instantiate router core
    pe_router_core #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PORTS(NUM_PORTS)
    ) core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid(route_cfg_valid),
        .cfg_addr(route_cfg_addr),
        .cfg_data(route_cfg_data),
        .cfg_ack(route_cfg_ack),
        .data_in_valid(data_in_valid),
        .data_in(data_in),
        .data_in_ready(data_in_ready),
        .data_out_valid(data_out_valid),
        .data_out(data_out),
        .data_out_ready(data_out_ready),
        .status(route_status)
    );

endmodule