// spi_ring_node.v
// SPI Ring节点实现，连接SPI节点和Ring总线

`include "spi_params.v"

// 定义必要的Ring总线操作类型宏
`ifndef RING_OP_READ
`define RING_OP_READ  0
`endif
`ifndef RING_OP_WRITE
`define RING_OP_WRITE 1
`endif
`ifndef RING_OP_RESP
`define RING_OP_RESP  2
`endif

module spi_ring_node #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter TX_FIFO_DEPTH     = 4,
    parameter RX_FIFO_DEPTH     = 4,
    parameter RSP_FIFO_DEPTH    = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [ADDR_WIDTH-1:0]        node_end_addr_i,

    input  wire                         pre_req_valid_i,
    input  wire                         pre_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      pre_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  pre_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     pre_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     pre_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        pre_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        pre_req_data_i,

    output wire                         next_req_valid_o,
    output wire                         next_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      next_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  next_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     next_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     next_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        next_req_addr_o,
    output wire [DATA_WIDTH-1:0]        next_req_data_o,

    // 发送请求
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire                         rx_req_valid_o,
    output wire                         rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire                         rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [DATA_WIDTH-1:0]        rsp_data_o,

    // SPI物理接口
    output reg                          spi_cs_n,
    output reg                          spi_clk,
    output reg                          spi_mosi,
    input wire                          spi_miso
);
    // SPI节点
    wire spi_node_rsp_valid;
    wire [NODE_ID_WIDTH-1:0] spi_node_rsp_source_id;
    wire [NODE_ID_WIDTH-1:0] spi_node_rsp_target_id;
    wire [ADDR_WIDTH-1:0] spi_node_rsp_addr;
    wire [DATA_WIDTH-1:0] spi_node_rsp_data;

    // 实例化SPI节点
    spi_node #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH)
    ) u_spi_node (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(NODE_ID[NODE_ID_WIDTH-1:0]),
        .node_start_addr(node_start_addr_i),
        .node_end_addr(node_end_addr_i),
        .req_valid(rx_req_valid_o && rx_req_opcode_o != `RING_OP_RESP),
        .req_source_id(rx_req_source_id_o),
        .req_target_id(rx_req_target_id_o),
        .req_addr(rx_req_addr_o),
        .req_data(rx_req_data_o),
        .req_we(rx_req_opcode_o == `RING_OP_WRITE),
        .rsp_valid(spi_node_rsp_valid),
        .rsp_source_id(spi_node_rsp_source_id),
        .rsp_target_id(spi_node_rsp_target_id),
        .rsp_addr(spi_node_rsp_addr),
        .rsp_data(spi_node_rsp_data),
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // 处理SPI节点的响应，将其转发到Ring总线
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 初始化
        end else begin
            // SPI节点的响应会通过ring_bus_node的响应接口发送
            // 这里不需要额外的处理逻辑
        end
    end

endmodule