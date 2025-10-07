// 集成CPU和Ring总线接口的顶层模块示例
// 展示如何连接cpu_top和cpu_ring_interface

`include "cache_params.v"
`include "cache_system_params.v"

module cpu_with_ring #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter INST_WIDTH        = 32,
    parameter NUM_CORES         = 4,
    parameter CORE_ID_WIDTH     = 2,
    parameter ENABLE_L2_CACHE   = 1,
    parameter ENABLE_L3_CACHE   = 1,
    parameter CPU_TYPE          = 0
) (
    input clk,
    input rst_n,
    input ext_int,

    // Ring总线接口
    // 发送请求
    output wire [NUM_RINGS-1:0]       tx_req_ring_mask_o,
    output wire [NUM_RINGS-1:0]       tx_req_ring_disable_o,
    output wire                       tx_req_valid_o,
    output wire                       tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]    tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0] tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]   tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]   tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]      tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]      tx_req_data_o,

    // 接受请求
    input wire                        rx_req_valid_i,
    input wire                        rx_req_is_order_i,
    input wire [OPCODE_WIDTH-1:0]     rx_req_opcode_i,
    input wire [MATCH_TYPE_WIDTH-1:0] rx_req_match_type_i,
    input wire [NODE_ID_WIDTH-1:0]    rx_req_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]    rx_req_target_id_i,
    input wire [ADDR_WIDTH-1:0]       rx_req_addr_i,
    input wire [DATA_WIDTH-1:0]       rx_req_data_i,

    // 接收响应
    input wire                        rsp_valid_i,
    input wire [NODE_ID_WIDTH-1:0]    rsp_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]    rsp_target_id_i,
    input wire [ADDR_WIDTH-1:0]       rsp_addr_i,
    input wire [DATA_WIDTH-1:0]       rsp_data_i
);

    // CPU和Ring接口之间的连接信号
    wire                        cpu_mem_req;
    wire [ADDR_WIDTH-1:0]       cpu_mem_addr;
    wire [511:0]                cpu_mem_wdata;
    wire                        cpu_mem_we;
    wire                        cpu_mem_ready;
    wire [511:0]                cpu_mem_rdata;

    // CPU顶层模块实例
    cpu_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INST_WIDTH(INST_WIDTH),
        .NUM_CORES(NUM_CORES),
        .CORE_ID_WIDTH(CORE_ID_WIDTH),
        .ENABLE_L2_CACHE(ENABLE_L2_CACHE),
        .ENABLE_L3_CACHE(ENABLE_L3_CACHE),
        .CPU_TYPE(CPU_TYPE)
    ) u_cpu_top (
        .clk(clk),
        .rst_n(rst_n),
        .ext_int(ext_int),

        // 内存接口直接连接到Ring接口
        .mem_req(cpu_mem_req),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_we(cpu_mem_we),
        .mem_ready(cpu_mem_ready),
        .mem_rdata(cpu_mem_rdata)
    );

    // CPU-Ring总线接口模块实例
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

        // 连接到CPU顶层模块
        .cpu_mem_req(cpu_mem_req),
        .cpu_mem_addr(cpu_mem_addr),
        .cpu_mem_wdata(cpu_mem_wdata),
        .cpu_mem_we(cpu_mem_we),
        .cpu_mem_ready(cpu_mem_ready),
        .cpu_mem_rdata(cpu_mem_rdata),

        // 连接到Ring总线
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