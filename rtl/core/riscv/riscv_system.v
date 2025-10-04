// riscv_system.v
// RISC-V系统顶层模块，连接测试平台和riscv64_soc的中间层模块

`include "riscv_core_params.v"

module riscv_system #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter INST_WIDTH        = 32  // 指令宽度
) (
    input clk,
    input rst_n,

    input ext_int,

    // 内存接口（用于测试）
    output [ADDR_WIDTH-1:0] mem_addr,
    output [DATA_WIDTH-1:0] mem_data_out,
    input [DATA_WIDTH-1:0] mem_data_in,
    output mem_we,
    output [3:0] mem_be,
    input mem_ack,

    input [NODE_ID_WIDTH-1:0] node_id,

    // Ring接口 - 输入
    input ring_in_valid,
    input [NODE_ID_WIDTH-1:0] ring_in_src,
    input [NODE_ID_WIDTH-1:0] ring_in_dest,
    input [ADDR_WIDTH-1:0] ring_in_addr,
    input [DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,

    // Ring接口 - 输出
    output ring_out_valid,
    output [NODE_ID_WIDTH-1:0] ring_out_src,
    output [NODE_ID_WIDTH-1:0] ring_out_dest,
    output [ADDR_WIDTH-1:0] ring_out_addr,
    output [DATA_WIDTH-1:0] ring_out_data,
    output ring_out_we,
    output [3:0] ring_out_be,
    output ring_out_ack,

    // 发送请求
    output wire [NUM_RINGS-1:0]         tx_req_ring_mask_i,
    output wire [NUM_RINGS-1:0]         tx_req_ring_disable_i,
    output wire                         tx_req_valid_i,
    output wire                         tx_req_is_order_i,
    output wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    output wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    output wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    output wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    output wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    input  wire                         rx_req_valid_o,
    input  wire                         rx_req_is_order_o,
    input  wire [OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    input  wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    input  wire [ADDR_WIDTH-1:0]        rx_req_addr_o,
    input  wire [DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    input  wire                         rsp_valid_o,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    input  wire [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    input  wire [ADDR_WIDTH-1:0]        rsp_addr_o,
    input  wire [DATA_WIDTH-1:0]        rsp_data_o
);

    // 适配信号：连接riscv64_soc和测试平台
    wire [23:0] flash_addr;
    wire [31:0] flash_data_in;
    wire [31:0] flash_data_out;
    wire flash_ce_n;
    wire flash_oe_n;
    wire flash_we_n;
    wire flash_wp_n;
    wire flash_ready = 1'b1; // 简化测试，假设Flash始终准备好

    wire uart_txd;
    wire uart_rxd;
    wire [15:0] gpio_in;
    wire [15:0] gpio_out;
    wire [3:0] dip_switch = 4'h0; // 默认值
    wire [3:0] led;
    wire soc_ready;

    // 实例化riscv64_soc
    riscv64_soc soc (
        .clk(clk),
        .rst_n(rst_n),

        // Flash接口
        .flash_addr(flash_addr),
        .flash_data_in(flash_data_in),
        .flash_data_out(flash_data_out),
        .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n),
        .flash_we_n(flash_we_n),
        .flash_wp_n(flash_wp_n),
        .flash_ready(flash_ready),

        // UART接口
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),

        // GPIO接口
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),

        // 系统控制
        .dip_switch(dip_switch),
        .led(led),
        .soc_ready(soc_ready)
    );

    // 连接测试平台接口和SoC内部信号
    // 简化实现：将输入直接连接到输出，并为未使用的端口提供默认值
    assign mem_addr = 0;
    assign mem_data_out = 0;
    assign mem_we = 0;
    assign mem_be = 0;

    assign ring_out_valid = ring_in_valid;
    assign ring_out_src = ring_in_src;
    assign ring_out_dest = ring_in_dest;
    assign ring_out_addr = ring_in_addr;
    assign ring_out_data = ring_in_data;
    assign ring_out_we = ring_in_we;
    assign ring_out_be = ring_in_be;
    assign ring_out_ack = ring_in_ack;

    assign tx_req_ring_mask_i = 0;
    assign tx_req_ring_disable_i = 0;
    assign tx_req_valid_i = 0;
    assign tx_req_is_order_i = 0;
    assign tx_req_opcode_i = 0;
    assign tx_req_match_type_i = 0;
    assign tx_req_target_id_i = 0;
    assign tx_req_addr_i = 0;
    assign tx_req_data_i = 0;

    // 将外部中断信号连接到SoC的适当位置
    // 这里需要根据实际的中断处理逻辑进行连接
    always @(posedge clk) begin
        if (!rst_n) begin
            // 复位状态
        end else begin
            // 可以在这里添加中断处理逻辑
            // 例如：当检测到ext_int时，通过适当的方式通知SoC
        end
    end

    // 简单的Flash模拟，用于测试
    reg [31:0] flash_memory [0:1023]; // 简单的4KB Flash模拟
    initial begin
        // 可以在这里初始化Flash内容，用于测试程序
        // 例如：添加一些简单的测试指令
    end

    // 模拟Flash访问
    assign flash_data_in = flash_ce_n ? 32'hzzzzzzzz : flash_memory[flash_addr[11:2]];

    // 监控UART输出，用于调试
    always @(negedge clk) begin
        if (uart_txd !== 1'bz && soc_ready) begin
            // 可以在这里添加UART输出监控逻辑
            // 例如：捕获UART数据并输出到控制台
        end
    end

endmodule