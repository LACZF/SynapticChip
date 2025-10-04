// top_system.v
// 顶层系统模块，集成所有组件

`include "top_system_params.v"

module top_system #(
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 8,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
)(
    input clk,
    input rst_n,

    // UART接口
    output uart_txd,
    input uart_rxd,

    // GPIO接口
    inout [DATA_WIDTH-1:0] gpio_pins,

    // 外部中断
    input ext_int,

    // 状态输出
    output [DATA_WIDTH-1:0] system_status,

    // JTAG接口
    input jtag_tck,
    input jtag_tms,
    input jtag_tdi,
    output jtag_tdo,
    output jtag_tdo_en,

    // JTAG调试输出
    output [DATA_WIDTH-1:0] jtag_debug_data,
    output jtag_debug_valid
);
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr;
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr;

    // 发送请求
    wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask;
    wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable;
    wire [NUM_NODES-1:0]                   tx_req_valid;
    wire [NUM_NODES-1:0]                   tx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data;

    // 接受请求
    wire [NUM_NODES-1:0]                   rx_req_valid;
    wire [NUM_NODES-1:0]                   rx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data;

    // 接收响应
    wire [NUM_NODES-1:0]                   rsp_valid;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data;

    // Ring总线状态
    wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id;
    wire [NUM_RINGS-1:0]                   ring_busy;

    // 实例化Ring总线
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
    ) bus (
        .clk(clk),
        .rst_n(rst_n),

        .node_start_addr_i(node_start_addr),
        .node_end_addr_i(node_end_addr),

        .tx_req_ring_mask_i(tx_req_ring_mask),
        .tx_req_ring_disable_i(tx_req_ring_disable),
        .tx_req_valid_i(tx_req_valid),
        .tx_req_is_order_i(tx_req_is_order),
        .tx_req_opcode_i(tx_req_opcode),
        .tx_req_match_type_i(tx_req_match_type),
        .tx_req_source_id_i(tx_req_source_id),
        .tx_req_target_id_i(tx_req_target_id),
        .tx_req_addr_i(tx_req_addr),
        .tx_req_data_i(tx_req_data),

        .rx_req_valid_o(rx_req_valid),
        .rx_req_is_order_o(rx_req_is_order),
        .rx_req_opcode_o(rx_req_opcode),
        .rx_req_match_type_o(rx_req_match_type),
        .rx_req_source_id_o(rx_req_source_id),
        .rx_req_target_id_o(rx_req_target_id),
        .rx_req_addr_o(rx_req_addr),
        .rx_req_data_o(rx_req_data),

        .rsp_valid_o(rsp_valid),
        .rsp_source_id_o(rsp_source_id),
        .rsp_target_id_o(rsp_target_id),
        .rsp_addr_o(rsp_addr),
        .rsp_data_o(rsp_data),

        .ring_id_o(ring_id),
        .ring_busy(ring_busy)
    );

    riscv_system #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_RISCV),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .INST_WIDTH(32)
    ) riscv (
        .clk(clk),
        .rst_n(rst_n),

        .ext_int(ext_int),

        .tx_req_ring_mask_i(tx_req_ring_mask[`NODE_RISCV*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_i(tx_req_ring_disable[`NODE_RISCV*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_i(tx_req_valid[`NODE_RISCV]),
        .tx_req_is_order_i(tx_req_is_order[`NODE_RISCV]),
        .tx_req_opcode_i(tx_req_opcode[`NODE_RISCV*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_i(tx_req_match_type[`NODE_RISCV*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_i(tx_req_source_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_i(tx_req_target_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_i(tx_req_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_i(tx_req_data[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_o(rx_req_valid[`NODE_RISCV]),
        .rx_req_is_order_o(rx_req_is_order[`NODE_RISCV]),
        .rx_req_opcode_o(rx_req_opcode[`NODE_RISCV*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_o(rx_req_match_type[`NODE_RISCV*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_o(rx_req_source_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_o(rx_req_target_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_o(rx_req_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_o(rx_req_data[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_o(rsp_valid[`NODE_RISCV]),
        .rsp_source_id_o(rsp_source_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_o(rsp_target_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_o(rsp_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_o(rsp_data[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH])
    );

    // 实例化GPIO模块
    gpio_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_GPIO),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) gpio (
        .clk(clk),
        .rst_n(rst_n),

        .gpio_pins(gpio_pins),

        .tx_req_ring_mask_i(tx_req_ring_mask[`NODE_GPIO*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_i(tx_req_ring_disable[`NODE_GPIO*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_i(tx_req_valid[`NODE_GPIO]),
        .tx_req_is_order_i(tx_req_is_order[`NODE_GPIO]),
        .tx_req_opcode_i(tx_req_opcode[`NODE_GPIO*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_i(tx_req_match_type[`NODE_GPIO*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_i(tx_req_source_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_i(tx_req_target_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_i(tx_req_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_i(tx_req_data[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_o(rx_req_valid[`NODE_GPIO]),
        .rx_req_is_order_o(rx_req_is_order[`NODE_GPIO]),
        .rx_req_opcode_o(rx_req_opcode[`NODE_GPIO*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_o(rx_req_match_type[`NODE_GPIO*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_o(rx_req_source_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_o(rx_req_target_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_o(rx_req_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_o(rx_req_data[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_o(rsp_valid[`NODE_GPIO]),
        .rsp_source_id_o(rsp_source_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_o(rsp_target_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_o(rsp_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_o(rsp_data[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH])
    );

    // 实例化UART模块
    uart_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_UART),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) uart (
        .clk(clk),
        .rst_n(rst_n),

        .tx_req_ring_mask_i(tx_req_ring_mask[`NODE_UART*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_i(tx_req_ring_disable[`NODE_UART*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_i(tx_req_valid[`NODE_UART]),
        .tx_req_is_order_i(tx_req_is_order[`NODE_UART]),
        .tx_req_opcode_i(tx_req_opcode[`NODE_UART*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_i(tx_req_match_type[`NODE_UART*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_i(tx_req_source_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_i(tx_req_target_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_i(tx_req_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_i(tx_req_data[`NODE_UART*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_o(rx_req_valid[`NODE_UART]),
        .rx_req_is_order_o(rx_req_is_order[`NODE_UART]),
        .rx_req_opcode_o(rx_req_opcode[`NODE_UART*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_o(rx_req_match_type[`NODE_UART*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_o(rx_req_source_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_o(rx_req_target_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_o(rx_req_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_o(rx_req_data[`NODE_UART*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_o(rsp_valid[`NODE_UART]),
        .rsp_source_id_o(rsp_source_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_o(rsp_target_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_o(rsp_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_o(rsp_data[`NODE_UART*DATA_WIDTH +: DATA_WIDTH]),

        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd)
    );

    // 实例化DUT
    jtag_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_JTAG),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) jtag (
        .clk(clk),
        .rst_n(rst_n),

        .tx_req_ring_mask_i(tx_req_ring_mask[`NODE_JTAG*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_i(tx_req_ring_disable[`NODE_JTAG*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_i(tx_req_valid[`NODE_JTAG]),
        .tx_req_is_order_i(tx_req_is_order[`NODE_JTAG]),
        .tx_req_opcode_i(tx_req_opcode[`NODE_JTAG*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_i(tx_req_match_type[`NODE_JTAG*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_i(tx_req_source_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_i(tx_req_target_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_i(tx_req_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_i(tx_req_data[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_o(rx_req_valid[`NODE_JTAG]),
        .rx_req_is_order_o(rx_req_is_order[`NODE_JTAG]),
        .rx_req_opcode_o(rx_req_opcode[`NODE_JTAG*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_o(rx_req_match_type[`NODE_JTAG*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_o(rx_req_source_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_o(rx_req_target_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_o(rx_req_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_o(rx_req_data[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_o(rsp_valid[`NODE_JTAG]),
        .rsp_source_id_o(rsp_source_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_o(rsp_target_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_o(rsp_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_o(rsp_data[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH]),

        .tck(jtag_tck),
        .tms(jtag_tms),
        .tdi(jtag_tdi),
        .tdo(jtag_tdo),
        .tdo_en(jtag_tdo_en),
        .debug_data(jtag_debug_data),
        .debug_valid(jtag_debug_valid)
    );

    reg [DATA_WIDTH-1:0] fabric_status;
    // 实例化Fabric模块
    synaptic_core #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_FABRIC),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .NUM_PES(4),
        .INST_WIDTH(128),
        .PE_ID_WIDTH(3),
        .PE_ARRAY_ROWS(`PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(`PE_ARRAY_COLS)
    ) fabric (
        .clk(clk),
        .rst_n(rst_n),

        .tx_req_ring_mask_i(tx_req_ring_mask[`NODE_FABRIC*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_i(tx_req_ring_disable[`NODE_FABRIC*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_i(tx_req_valid[`NODE_FABRIC]),
        .tx_req_is_order_i(tx_req_is_order[`NODE_FABRIC]),
        .tx_req_opcode_i(tx_req_opcode[`NODE_FABRIC*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_i(tx_req_match_type[`NODE_FABRIC*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_i(tx_req_source_id[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_i(tx_req_target_id[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_i(tx_req_addr[`NODE_FABRIC*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_i(tx_req_data[`NODE_FABRIC*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_o(rx_req_valid[`NODE_FABRIC]),
        .rx_req_is_order_o(rx_req_is_order[`NODE_FABRIC]),
        .rx_req_opcode_o(rx_req_opcode[`NODE_FABRIC*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_o(rx_req_match_type[`NODE_FABRIC*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_o(rx_req_source_id[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_o(rx_req_target_id[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_o(rx_req_addr[`NODE_FABRIC*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_o(rx_req_data[`NODE_FABRIC*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_o(rsp_valid[`NODE_FABRIC]),
        .rsp_source_id_o(rsp_source_id[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_o(rsp_target_id[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_o(rsp_addr[`NODE_FABRIC*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_o(rsp_data[`NODE_FABRIC*DATA_WIDTH +: DATA_WIDTH]),

        .fabric_status(fabric_status)
    );

endmodule