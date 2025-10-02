// top_system.v
// 顶层系统模块，集成所有组件

`include "top_system_params.v"

module top_system #(
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 4,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter DATA_WIDTH       = 64
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

    // Ring总线信号
    wire [NUM_NODES-1:0] ring_valid;
    wire [(NUM_NODES*NODE_ID_WIDTH)-1:0] ring_src;
    wire [(NUM_NODES*NODE_ID_WIDTH)-1:0] ring_dest;
    wire [(NUM_NODES*ADDR_WIDTH)-1:0] ring_addr;
    wire [(NUM_NODES*DATA_WIDTH)-1:0] ring_data_in;
    wire [(NUM_NODES*DATA_WIDTH)-1:0] ring_data_out;
    wire [NUM_NODES-1:0] ring_we;
    wire [(NUM_NODES*4)-1:0] ring_be;
    wire [NUM_NODES-1:0] ring_ack;

    // RISC-V核心信号
    wire riscv_mem_req;
    wire riscv_mem_we;
    wire [ADDR_WIDTH-1:0] riscv_mem_addr;
    wire [DATA_WIDTH-1:0] riscv_mem_data_out;
    wire [DATA_WIDTH-1:0] riscv_mem_data_in;
    wire riscv_mem_ack;
    wire [3:0] riscv_mem_be;

    // 存储器信号
    wire ram_req;
    wire ram_we;
    wire [ADDR_WIDTH-1:0] ram_addr;
    wire [DATA_WIDTH-1:0] ram_data_out;
    wire [DATA_WIDTH-1:0] ram_data_in;
    wire ram_ack;

    wire rom_req;
    wire [ADDR_WIDTH-1:0] rom_addr;
    wire [DATA_WIDTH-1:0] rom_data_out;
    wire rom_ack;

    // UART信号
    wire uart_req;
    wire uart_we;
    wire [ADDR_WIDTH-1:0] uart_addr;
    wire [DATA_WIDTH-1:0] uart_data_out;
    wire [DATA_WIDTH-1:0] uart_data_in;
    wire uart_ack;

    // GPIO信号
    wire gpio_req;
    wire gpio_we;
    wire [ADDR_WIDTH-1:0] gpio_addr;
    wire [DATA_WIDTH-1:0] gpio_data_out;
    wire [DATA_WIDTH-1:0] gpio_data_in;
    wire gpio_ack;

    // Fabric信号
    wire fabric_req;
    wire fabric_we;
    wire [ADDR_WIDTH-1:0] fabric_addr;
    wire [DATA_WIDTH-1:0] fabric_data_out;
    wire [DATA_WIDTH-1:0] fabric_data_in;
    wire fabric_ack;
    wire [DATA_WIDTH-1:0] fabric_status;

    // 实例化Ring总线
    ring_bus #(
        .NUM_RINGS(NUM_RINGS),
        .NUM_NODES(NUM_NODES),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH)
    ) bus (
        .clk(clk),
        .rst_n(rst_n),
        .node_start_addr_i({NUM_NODES{32'h0}}),
        .node_end_addr_i({NUM_NODES{32'hFFFFFFFF}}),
        .tx_req_ring_mask_i({NUM_NODES{1'b1}}),
        .tx_req_ring_disable_i({NUM_NODES{1'b0}}),
        .tx_req_valid_i(ring_valid),
        .tx_req_is_order_i({NUM_NODES{1'b0}}),
        .tx_req_opcode_i({NUM_NODES{8'd0}}),
        .tx_req_match_type_i({NUM_NODES{2'd0}}),
        .tx_req_source_id_i(ring_src),
        .tx_req_target_id_i(ring_dest),
        .tx_req_addr_i(ring_addr),
        .tx_req_data_i(ring_data_in),
        .tx_req_ready_o(),
        .rx_req_valid_o(ring_valid),
        .rx_req_is_order_o(),
        .rx_req_opcode_o(),
        .rx_req_match_type_o(),
        .rx_req_source_id_o(ring_src),
        .rx_req_target_id_o(ring_dest),
        .rx_req_addr_o(ring_addr),
        .rx_req_data_o(ring_data_out),
        .rsp_valid_o(ring_valid),
        .rsp_source_id_o(ring_src),
        .rsp_target_id_o(ring_dest),
        .rsp_addr_o(ring_addr),
        .rsp_data_o(ring_data_out),
        .ring_id_o(),
        .ring_busy()
    );

    riscv_system riscv (
        .clk(clk),
        .rst_n(rst_n),
        .mem_we(riscv_mem_we),
        .mem_addr(riscv_mem_addr),
        .mem_data_out(riscv_mem_data_out),
        .mem_data_in(riscv_mem_data_in),
        .mem_ack(riscv_mem_ack),
        .mem_be(riscv_mem_be),
        .ext_int(ext_int),

        .node_id(`NODE_RISCV),
        .ring_in_valid(ring_valid[`NODE_RISCV]),
        .ring_in_src(ring_src[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_RISCV]),
        .ring_in_be(ring_be[`NODE_RISCV*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_RISCV]),
        .ring_out_valid(ring_valid[(`NODE_RISCV+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_RISCV+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_RISCV+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_RISCV+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_RISCV+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_RISCV+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_RISCV+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_RISCV+1)%NUM_NODES])
    );

    // 实例化RAM模块
    ram_node ram (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_RAM),
        .ring_in_valid(ring_valid[`NODE_RAM]),
        .ring_in_src(ring_src[`NODE_RAM*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_RAM*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_RAM*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_RAM*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_RAM]),
        .ring_in_be(ring_be[`NODE_RAM*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_RAM]),
        .ring_out_valid(ring_valid[(`NODE_RAM+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_RAM+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_RAM+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_RAM+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_RAM+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_RAM+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_RAM+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_RAM+1)%NUM_NODES])
    );

    // 实例化ROM模块
    rom_node rom (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_ROM),
        .ring_in_valid(ring_valid[`NODE_ROM]),
        .ring_in_src(ring_src[`NODE_ROM*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_ROM*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_ROM*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_ROM*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_ROM]),
        .ring_in_be(ring_be[`NODE_ROM*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_ROM]),
        .ring_out_valid(ring_valid[(`NODE_ROM+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_ROM+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_ROM+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_ROM+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_ROM+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_ROM+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_ROM+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_ROM+1)%NUM_NODES])
    );

    // 实例化GPIO模块
    gpio_node gpio (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_GPIO),
        .ring_in_valid(ring_valid[`NODE_GPIO]),
        .ring_in_src(ring_src[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_GPIO]),
        .ring_in_be(ring_be[`NODE_GPIO*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_GPIO]),
        .ring_out_valid(ring_valid[(`NODE_GPIO+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_GPIO+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_GPIO+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_GPIO+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_GPIO+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_GPIO+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_GPIO+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_GPIO+1)%NUM_NODES]),
        .gpio_pins(gpio_pins)
    );

    // 实例化UART模块
    uart_node uart (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_UART),
        .ring_in_valid(ring_valid[`NODE_UART]),
        .ring_in_src(ring_src[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_UART*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_UART]),
        .ring_in_be(ring_be[`NODE_UART*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_UART]),
        .ring_out_valid(ring_valid[(`NODE_UART+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_UART+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_UART+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_UART+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_UART+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_UART+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_UART+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_UART+1)%NUM_NODES]),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd)
    );

    // 实例化DUT
    jtag_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_JTAG),
        .ring_in_valid(ring_valid[`NODE_JTAG]),
        .ring_in_src(ring_src[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_JTAG]),
        .ring_in_be(ring_be[`NODE_JTAG*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_JTAG]),
        .ring_out_valid(ring_valid[(`NODE_JTAG+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_JTAG+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_JTAG+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_JTAG+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_JTAG+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_JTAG+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_JTAG+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_JTAG+1)%NUM_NODES]),
        .tck(jtag_tck),
        .tms(jtag_tms),
        .tdi(jtag_tdi),
        .tdo(jtag_tdo),
        .tdo_en(jtag_tdo_en),
        .debug_data(jtag_debug_data),
        .debug_valid(jtag_debug_valid)
    );

    // 实例化Fabric模块
    synaptic_core fabric (
        .clk(clk),
        .rst_n(rst_n),
        .ring_in_valid(ring_valid[`NODE_FABRIC]),
        .ring_in_src(ring_src[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_FABRIC*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_FABRIC*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_FABRIC*DATA_WIDTH +: DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_FABRIC]),
        .ring_in_be(ring_be[`NODE_FABRIC*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_FABRIC]),
        .ring_out_valid(ring_valid[(`NODE_FABRIC+1)%NUM_NODES]),
        .ring_out_src(ring_src[(`NODE_FABRIC+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_FABRIC+1)%NUM_NODES*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_FABRIC+1)%NUM_NODES*ADDR_WIDTH +: ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_FABRIC+1)%NUM_NODES*DATA_WIDTH +: DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_FABRIC+1)%NUM_NODES]),
        .ring_out_be(ring_be[(`NODE_FABRIC+1)%NUM_NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_FABRIC+1)%NUM_NODES]),
        .fabric_status(fabric_status)
    );

    // 系统状态
    assign system_status = {
        fabric_status,  // Fabric状态
        ring_ack,       // Ring总线确认状态
        ring_valid      // Ring总线有效状态
    };

endmodule