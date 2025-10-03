// riscv_system.v
// RISC-V系统顶层模块

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
    input  wire [NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
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
    output wire [DATA_WIDTH-1:0]        rsp_data_o
);

    // RISC-V核心信号
    wire core_inst_req;
    wire [ADDR_WIDTH-1:0] core_inst_addr;
    wire [INST_WIDTH-1:0] core_inst_data;
    wire core_inst_ack;

    wire core_data_req;
    wire [ADDR_WIDTH-1:0] core_data_addr;
    wire [DATA_WIDTH-1:0] core_data_out;
    wire [DATA_WIDTH-1:0] core_data_in;
    wire core_data_ack;
    wire core_data_we;
    wire [3:0] core_data_be;

    // Ring总线信号
    wire ring_valid;
    wire [NODE_ID_WIDTH-1:0] ring_src;
    wire [NODE_ID_WIDTH-1:0] ring_dest;
    wire [ADDR_WIDTH-1:0] ring_addr;
    wire [DATA_WIDTH-1:0] ring_data;
    wire ring_we;
    wire [3:0] ring_be;
    wire ring_ack;

    reg [4:0] debug_state;
    reg [31:0] debug_pc;
    reg [31:0] debug_instruction;
    // 实例化SoC
    riscv_soc soc (
        .clk(clk),
        .rst_n(rst_n),
        .ext_int(ext_int),
        .debug_pc(debug_pc),
        .debug_instruction(debug_instruction),
        .debug_state(debug_state),
        // .debug_registers(debug_registers),
        .ext_mem_addr(mem_addr),
        .ext_mem_data_out(mem_data_out),
        .ext_mem_data_in(mem_data_in),
        .ext_mem_we(mem_we),
        .ext_mem_re(mem_re),
        .ext_mem_ack(mem_ack)
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