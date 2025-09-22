// riscv_system.v
// RISC-V系统顶层模块

`include "riscv_core_params.v"

module riscv_system (
    input clk,
    input rst_n,

    // 内存接口（用于测试）
    output [`ADDR_WIDTH-1:0] mem_addr,
    output [`DATA_WIDTH-1:0] mem_data_out,
    input [`DATA_WIDTH-1:0] mem_data_in,
    output mem_we,
    output [3:0] mem_be,
    input mem_ack
);

    // RISC-V核心信号
    wire core_inst_req;
    wire [`ADDR_WIDTH-1:0] core_inst_addr;
    wire [`INST_WIDTH-1:0] core_inst_data;
    wire core_inst_ack;

    wire core_data_req;
    wire [`ADDR_WIDTH-1:0] core_data_addr;
    wire [`DATA_WIDTH-1:0] core_data_out;
    wire [`DATA_WIDTH-1:0] core_data_in;
    wire core_data_ack;
    wire core_data_we;
    wire [3:0] core_data_be;

    // Ring总线信号
    wire ring_valid;
    wire [`NODE_ID_WIDTH-1:0] ring_src;
    wire [`NODE_ID_WIDTH-1:0] ring_dest;
    wire [`ADDR_WIDTH-1:0] ring_addr;
    wire [`DATA_WIDTH-1:0] ring_data;
    wire ring_we;
    wire [3:0] ring_be;
    wire ring_ack;

    // 实例化RISC-V核心
    riscv_core core (
        .clk(clk),
        .rst_n(rst_n),
        .inst_addr(core_inst_addr),
        .inst_data(core_inst_data),
        .inst_req(core_inst_req),
        .inst_ack(core_inst_ack),
        .data_req(core_data_req),
        .data_addr(core_data_addr),
        .data_out(core_data_out),
        .data_in(core_data_in),
        .data_ack(core_data_ack),
        .data_we(core_data_we),
        .data_be(core_data_be)
    );

    // 指令存储器（简单ROM）
    reg [`INST_WIDTH-1:0] inst_rom [0:255];
    /* TODO : 从flash读取指令 */
    // initial $readmemh("program.hex", inst_rom);

    assign core_inst_data = inst_rom[core_inst_addr[9:2]];
    assign core_inst_ack = core_inst_req;

    wire [`DATA_WIDTH-1:0] ring_data_out;
    wire [`DATA_WIDTH-1:0] ring_data_in;

    // 数据总线接口
    riscv_bus_interface data_if (
        .clk(clk),
        .rst_n(rst_n),
        .core_req(core_data_req),
        .core_addr(core_data_addr),
        .core_data_out(core_data_out),
        .core_data_in(core_data_in),
        .core_ack(core_data_ack),
        .core_we(core_data_we),
        .core_be(core_data_be),
        .ring_req(ring_req),
        .ring_dest(ring_dest),
        .ring_addr(ring_addr),
        .ring_data_out(ring_data_out),
        .ring_data_in(ring_data_in),
        .ring_ack(ring_ack),
        .ring_we_ack(ring_we_ack)
    );

    // Ring总线节点（节点0 - RISC-V核心）
    riscv_ring_node node0 (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(5'd0),
        .local_req(ring_req),
        .local_addr(ring_addr),
        .local_data_out(ring_data_out),
        .local_data_in(ring_data_in),
        .local_ack(ring_ack),
        .local_we(core_data_we),
        .local_be(core_data_be),
        .ring_in_valid(ring_valid),
        .ring_in_src(ring_src),
        .ring_in_dest(ring_dest),
        .ring_in_addr(ring_addr),
        .ring_in_data(ring_data),
        .ring_in_we(ring_we),
        .ring_in_be(ring_be),
        .ring_in_ack(ring_ack),
        .ring_out_valid(ring_valid),
        .ring_out_src(ring_src),
        .ring_out_dest(ring_dest),
        .ring_out_addr(ring_addr),
        .ring_out_data(ring_data),
        .ring_out_we(ring_we),
        .ring_out_be(ring_be),
        .ring_out_ack(ring_ack),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_we(mem_we),
        .mem_be(mem_be),
        .mem_ack(mem_ack)
    );

endmodule
