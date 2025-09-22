// top_system.v
// 顶层系统模块，集成所有组件

`include "top_system_params.v"

module top_system (
    input clk,
    input rst_n,

    // UART接口
    output uart_txd,
    input uart_rxd,

    // GPIO接口
    inout [`DATA_WIDTH-1:0] gpio_pins,

    // 外部中断
    input ext_int,

    // 状态输出
    output [`DATA_WIDTH-1:0] system_status,

    // JTAG接口
    input jtag_tck,
    input jtag_tms,
    input jtag_tdi,
    output jtag_tdo,
    output jtag_tdo_en,

    // JTAG调试输出
    output [`DATA_WIDTH-1:0] jtag_debug_data,
    output jtag_debug_valid
);

    // Ring总线信号
    wire [`NODES-1:0] ring_valid;
    wire [(`NODES*`NODE_ID_WIDTH)-1:0] ring_src;
    wire [(`NODES*`NODE_ID_WIDTH)-1:0] ring_dest;
    wire [(`NODES*`ADDR_WIDTH)-1:0] ring_addr;
    wire [(`NODES*`DATA_WIDTH)-1:0] ring_data_in;
    wire [(`NODES*`DATA_WIDTH)-1:0] ring_data_out;
    wire [`NODES-1:0] ring_we;
    wire [(`NODES*4)-1:0] ring_be;
    wire [`NODES-1:0] ring_ack;

    // RISC-V核心信号
    wire riscv_mem_req;
    wire riscv_mem_we;
    wire [`ADDR_WIDTH-1:0] riscv_mem_addr;
    wire [`DATA_WIDTH-1:0] riscv_mem_data_out;
    wire [`DATA_WIDTH-1:0] riscv_mem_data_in;
    wire riscv_mem_ack;
    wire [3:0] riscv_mem_be;

    // 存储器信号
    wire ram_req;
    wire ram_we;
    wire [`ADDR_WIDTH-1:0] ram_addr;
    wire [`DATA_WIDTH-1:0] ram_data_out;
    wire [`DATA_WIDTH-1:0] ram_data_in;
    wire ram_ack;

    wire rom_req;
    wire [`ADDR_WIDTH-1:0] rom_addr;
    wire [`DATA_WIDTH-1:0] rom_data_out;
    wire rom_ack;

    // UART信号
    wire uart_req;
    wire uart_we;
    wire [`ADDR_WIDTH-1:0] uart_addr;
    wire [`DATA_WIDTH-1:0] uart_data_out;
    wire [`DATA_WIDTH-1:0] uart_data_in;
    wire uart_ack;

    // GPIO信号
    wire gpio_req;
    wire gpio_we;
    wire [`ADDR_WIDTH-1:0] gpio_addr;
    wire [`DATA_WIDTH-1:0] gpio_data_out;
    wire [`DATA_WIDTH-1:0] gpio_data_in;
    wire gpio_ack;

    // Fabric信号
    wire fabric_req;
    wire fabric_we;
    wire [`ADDR_WIDTH-1:0] fabric_addr;
    wire [`DATA_WIDTH-1:0] fabric_data_out;
    wire [`DATA_WIDTH-1:0] fabric_data_in;
    wire fabric_ack;
    wire [`DATA_WIDTH-1:0] fabric_status;

    // 实例化Ring总线
    ring_bus bus (
        .clk(clk),
        .rst_n(rst_n),
        .local_req(ring_valid),
        .ring_src(ring_src),
        .ring_dest(ring_dest),
        .local_addr(ring_addr),
        .local_data_in(ring_data_in),
        .local_data_out(ring_data_out),
        .ring_we(ring_we),
        .ring_be(ring_be),
        .local_ack(ring_ack)
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
        .ext_int(ext_int)
    );

    // 实例化RAM模块
    ram_node ram (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_RAM),
        .ring_in_valid(ring_valid[`NODE_RAM]),
        .ring_in_src(ring_src[`NODE_RAM*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_RAM*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_RAM*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_RAM*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_RAM]),
        .ring_in_be(ring_be[`NODE_RAM*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_RAM]),
        .ring_out_valid(ring_valid[(`NODE_RAM+1)%`NODES]),
        .ring_out_src(ring_src[(`NODE_RAM+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_RAM+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_RAM+1)%`NODES*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_RAM+1)%`NODES*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_RAM+1)%`NODES]),
        .ring_out_be(ring_be[(`NODE_RAM+1)%`NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_RAM+1)%`NODES])
    );

    // 实例化ROM模块
    rom_node rom (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_ROM),
        .ring_in_valid(ring_valid[`NODE_ROM]),
        .ring_in_src(ring_src[`NODE_ROM*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_ROM*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_ROM*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_ROM*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_ROM]),
        .ring_in_be(ring_be[`NODE_ROM*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_ROM]),
        .ring_out_valid(ring_valid[(`NODE_ROM+1)%`NODES]),
        .ring_out_src(ring_src[(`NODE_ROM+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_ROM+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_ROM+1)%`NODES*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_ROM+1)%`NODES*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_ROM+1)%`NODES]),
        .ring_out_be(ring_be[(`NODE_ROM+1)%`NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_ROM+1)%`NODES])
    );

    // 实例化GPIO模块
    gpio_node gpio (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_GPIO),
        .ring_in_valid(ring_valid[`NODE_GPIO]),
        .ring_in_src(ring_src[`NODE_GPIO*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_GPIO*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_GPIO*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_GPIO*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_GPIO]),
        .ring_in_be(ring_be[`NODE_GPIO*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_GPIO]),
        .ring_out_valid(ring_valid[(`NODE_GPIO+1)%`NODES]),
        .ring_out_src(ring_src[(`NODE_GPIO+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_GPIO+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_GPIO+1)%`NODES*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_GPIO+1)%`NODES*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_GPIO+1)%`NODES]),
        .ring_out_be(ring_be[(`NODE_GPIO+1)%`NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_GPIO+1)%`NODES]),
        .gpio_pins(gpio_pins)
    );

    // 实例化UART模块
    uart_node uart (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_UART),
        .ring_in_valid(ring_valid[`NODE_UART]),
        .ring_in_src(ring_src[`NODE_UART*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_UART*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_UART*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_UART*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_UART]),
        .ring_in_be(ring_be[`NODE_UART*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_UART]),
        .ring_out_valid(ring_valid[(`NODE_UART+1)%`NODES]),
        .ring_out_src(ring_src[(`NODE_UART+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_UART+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_UART+1)%`NODES*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_UART+1)%`NODES*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_UART+1)%`NODES]),
        .ring_out_be(ring_be[(`NODE_UART+1)%`NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_UART+1)%`NODES]),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd)
    );

    // 实例化DUT
    jtag_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(`NODE_JTAG),
        .ring_in_valid(ring_valid[`NODE_JTAG]),
        .ring_in_src(ring_src[`NODE_JTAG*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_JTAG*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_JTAG*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_JTAG*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_JTAG]),
        .ring_in_be(ring_be[`NODE_JTAG*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_JTAG]),
        .ring_out_valid(ring_valid[(`NODE_JTAG+1)%`NODES]),
        .ring_out_src(ring_src[(`NODE_JTAG+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_JTAG+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_JTAG+1)%`NODES*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_JTAG+1)%`NODES*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_JTAG+1)%`NODES]),
        .ring_out_be(ring_be[(`NODE_JTAG+1)%`NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_JTAG+1)%`NODES]),
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
        .ring_in_src(ring_src[`NODE_FABRIC*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_dest(ring_dest[`NODE_FABRIC*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_in_addr(ring_addr[`NODE_FABRIC*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_in_data(ring_data_in[`NODE_FABRIC*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_in_we(ring_we[`NODE_FABRIC]),
        .ring_in_be(ring_be[`NODE_FABRIC*4 +: 4]),
        .ring_in_ack(ring_ack[`NODE_FABRIC]),
        .ring_out_valid(ring_valid[(`NODE_FABRIC+1)%`NODES]),
        .ring_out_src(ring_src[(`NODE_FABRIC+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_dest(ring_dest[(`NODE_FABRIC+1)%`NODES*`NODE_ID_WIDTH +: `NODE_ID_WIDTH]),
        .ring_out_addr(ring_addr[(`NODE_FABRIC+1)%`NODES*`ADDR_WIDTH +: `ADDR_WIDTH]),
        .ring_out_data(ring_data_out[(`NODE_FABRIC+1)%`NODES*`DATA_WIDTH +: `DATA_WIDTH]),
        .ring_out_we(ring_we[(`NODE_FABRIC+1)%`NODES]),
        .ring_out_be(ring_be[(`NODE_FABRIC+1)%`NODES*4 +: 4]),
        .ring_out_ack(ring_ack[(`NODE_FABRIC+1)%`NODES]),
        .fabric_status(fabric_status)
    );

    // 系统状态
    assign system_status = {
        fabric_status,  // Fabric状态
        ring_ack,       // Ring总线确认状态
        ring_valid      // Ring总线有效状态
    };

endmodule
