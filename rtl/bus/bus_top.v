
// This is the bus top module

// 系统参数
`define NUM_CORES 4

// Ring bus operation definitions
`define RING_OP_READ  0
`define RING_OP_WRITE 1
`define RING_OP_RESP  2

// Ring bus match type definitions
`define RING_MATCH_TYPE_ID   0
`define RING_MATCH_TYPE_ADDR 1

module bus_top #(
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 4,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
) (
    input  wire                                   clk,
    input  wire                                   rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // 发送请求
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
    input  wire [NUM_NODES-1:0]                   tx_req_valid_i,
    input  wire [NUM_NODES-1:0]                   tx_req_is_order_i,
    input  wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data_i,
    output wire [NUM_NODES-1:0]                   tx_req_ready_o,

    // 接受请求
    output wire [NUM_NODES-1:0]                   rx_req_valid_o,
    output wire [NUM_NODES-1:0]                   rx_req_is_order_o,
    output wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire [NUM_NODES-1:0]                   rsp_valid_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data_o,

    // Ring总线状态
    output wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id_o,
    output wire [NUM_RINGS-1:0]                   ring_busy,

    // 外设接口
    output wire                                   uart_txd,
    input  wire                                   uart_rxd,
    input  wire [15:0]                            gpio_in,
    output wire [15:0]                            gpio_out,
    input  wire [3:0]                             dip_switch,
    output wire [3:0]                             led,

    // 中断接口
    output wire [(`NUM_CORES*16)-1:0]             core_irq,
    output wire [`NUM_CORES-1:0]                  timer_irq,
    output wire [`NUM_CORES-1:0]                  external_irq,
    output wire [`NUM_CORES-1:0]                  software_irq
);
    // 内部信号定义
    wire                                          req_valid;
    wire [ADDR_WIDTH-1:0]                         req_addr;
    wire [MATCH_TYPE_WIDTH-1:0]                   req_match_type;
    wire [NODE_ID_WIDTH-1:0]                      req_target_id;
    wire [DATA_WIDTH-1:0]                         req_data;
    wire [NUM_RINGS-1:0]                          req_ring_mask;
    wire [NUM_RINGS-1:0]                          req_ring_disable;
    wire                                          req_ready;

    wire [NUM_RINGS-1:0]                          ring_req_valid;
    wire [NUM_RINGS-1:0]                          ring_req_ready;
    wire [NUM_RINGS*ADDR_WIDTH-1:0]               ring_req_addr;
    wire [NUM_RINGS*MATCH_TYPE_WIDTH-1:0]         ring_req_match_type;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]            ring_req_target_id;
    wire [NUM_RINGS*DATA_WIDTH-1:0]               ring_req_data;

    wire                                          cpu_req;
    wire [ADDR_WIDTH-1:0]                         cpu_addr;
    wire [DATA_WIDTH-1:0]                         cpu_wdata;
    wire [DATA_WIDTH-1:0]                         cpu_rdata;
    wire                                          cpu_we;
    wire [7:0]                                    cpu_byte_en;
    wire                                          cpu_ready;

    wire [ADDR_WIDTH-1:0]                         sys_addr;
    wire [DATA_WIDTH-1:0]                         sys_wdata;
    wire [DATA_WIDTH-1:0]                         sys_rdata;
    wire                                          sys_we;
    wire [7:0]                                    sys_byte_en;
    wire                                          sys_req;
    wire                                          sys_ready;
    wire [1:0]                                    sys_master_id;

    wire                                          flash_req;
    wire [ADDR_WIDTH-1:0]                         flash_addr;
    wire [DATA_WIDTH-1:0]                         flash_wdata;
    wire [DATA_WIDTH-1:0]                         flash_rdata;
    wire                                          flash_we;
    wire                                          flash_ready;

    wire                                          sram_req;
    wire [ADDR_WIDTH-1:0]                         sram_addr;
    wire [DATA_WIDTH-1:0]                         sram_wdata;
    wire [DATA_WIDTH-1:0]                         sram_rdata;
    wire                                          sram_we;
    wire                                          sram_ready;

    wire                                          mmio_req;
    wire [ADDR_WIDTH-1:0]                         mmio_addr;
    wire [DATA_WIDTH-1:0]                         mmio_wdata;
    wire [DATA_WIDTH-1:0]                         mmio_rdata;
    wire                                          mmio_we;
    wire [7:0]                                    mmio_byte_en;
    wire                                          mmio_ready;
    ring_bus #(
        .NUM_RINGS(NUM_RINGS),
        .NUM_NODES(NUM_NODES),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .RING_ID_WIDTH(RING_ID_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .RSP_FIFO_DEPTH(RSP_FIFO_DEPTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_ring_bus (
        .clk(clk),
        .rst_n(rst_n),

        .node_start_addr_i(node_start_addr_i),
        .node_end_addr_i(node_end_addr_i),

        .tx_req_ring_mask_i(tx_req_ring_mask_i),
        .tx_req_ring_disable_i(tx_req_ring_disable_i),
        .tx_req_valid_i(tx_req_valid_i),
        .tx_req_is_order_i(tx_req_is_order_i),
        .tx_req_opcode_i(tx_req_opcode_i),
        .tx_req_match_type_i(tx_req_match_type_i),
        .tx_req_source_id_i(tx_req_source_id_i),
        .tx_req_target_id_i(tx_req_target_id_i),
        .tx_req_addr_i(tx_req_addr_i),
        .tx_req_data_i(tx_req_data_i),
        .tx_req_ready_o(tx_req_ready_o),

        .rx_req_valid_o(rx_req_valid_o),
        .rx_req_is_order_o(rx_req_is_order_o),
        .rx_req_opcode_o(rx_req_opcode_o),
        .rx_req_match_type_o(rx_req_match_type_o),
        .rx_req_source_id_o(rx_req_source_id_o),
        .rx_req_target_id_o(rx_req_target_id_o),
        .rx_req_addr_o(rx_req_addr_o),
        .rx_req_data_o(rx_req_data_o),

        .rsp_valid_o(rsp_valid_o),
        .rsp_source_id_o(rsp_source_id_o),
        .rsp_target_id_o(rsp_target_id_o),
        .rsp_addr_o(rsp_addr_o),
        .rsp_data_o(rsp_data_o),

        .ring_id_o(ring_id_o),
        .ring_busy(ring_busy)
    );

    // Ring仲裁器实例化
    ring_arbiter #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_ring_arbiter (
        .clk(clk),
        .rst_n(rst_n),

        // 主请求接口
        .req_valid(req_valid),
        .req_addr(req_addr),
        .req_match_type(req_match_type),
        .req_target_id(req_target_id),
        .req_data(req_data),
        .req_ring_mask(req_ring_mask),
        .req_ring_disable(req_ring_disable),
        .req_ready(req_ready),

        // Ring总线接口
        .ring_req_valid(ring_req_valid),
        .ring_req_ready(ring_req_ready),
        .ring_req_addr(ring_req_addr),
        .ring_req_match_type(ring_req_match_type),
        .ring_req_target_id(ring_req_target_id),
        .ring_req_data(ring_req_data),

        // 状态输出
        .ring_busy(ring_busy)
    );
endmodule