// pe_router_top.v
// 完整的路由模块实现

`include "pe_router_params.v"

module pe_router_top (
    input clk,
    input rst_n,

    // 配置接口
    input cfg_valid,
    input [`ADDR_WIDTH-1:0] cfg_addr,
    input [`DATA_WIDTH-1:0] cfg_data,
    output cfg_ack,

    // 数据输入接口
    input [`NUM_PORTS-1:0] data_in_valid,
    input [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_in,
    output [`NUM_PORTS-1:0] data_in_ready,

    // 数据输出接口
    output [`NUM_PORTS-1:0] data_out_valid,
    output [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_out,
    input [`NUM_PORTS-1:0] data_out_ready,

    // 状态输出
    output [`DATA_WIDTH-1:0] status
);

    // 内部信号
    wire route_cfg_valid;
    wire [`ADDR_WIDTH-1:0] route_cfg_addr;
    wire [`DATA_WIDTH-1:0] route_cfg_data;
    wire route_cfg_ack;
    wire [`DATA_WIDTH-1:0] route_status;

    // 实例化路由配置接口
    router_config config_inst (
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

    // 实例化路由核心
    router_core core_inst (
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
