// riscv64_core.v
`include "cache_params.v"
`include "cache_system_params.v"

module riscv64_core #(
    parameter ADDR_WIDTH                    = 64,
    parameter DATA_WIDTH                    = 64,
    parameter L1_ICACHE_DATA_WIDTH          = 32,
    parameter L1_DCACHE_DATA_WIDTH          = 64,
    parameter CORE_ID                       = 0
)(
    input wire clk,
    input wire rst_n,

    // 指令缓存接口 - 现在连接到cpu_top中的L1缓存
    output wire                                      icache_req,
    output wire [ADDR_WIDTH-1:0]                     icache_addr,
    input  wire [L1_ICACHE_DATA_WIDTH-1:0]           icache_data,
    input  wire                                      icache_ready,

    // 数据缓存接口 - 现在连接到cpu_top中的L1缓存
    output wire                                      dcache_req,
    output wire [ADDR_WIDTH-1:0]                     dcache_addr,
    output wire [L1_DCACHE_DATA_WIDTH-1:0]           dcache_wdata,
    input  wire [L1_DCACHE_DATA_WIDTH-1:0]           dcache_rdata,
    output wire                                      dcache_we,
    output wire [L1_DCACHE_DATA_WIDTH/8-1:0]         dcache_byte_en,
    input  wire                                      dcache_ready,

    // 监听接口
    input  wire                                      snoop_valid,
    input  wire [ADDR_WIDTH-1:0]                     snoop_addr,
    input  wire [1:0]                                snoop_req_type,
    output wire                                      snoop_ready,
    output wire                                      snoop_hit,
    output wire [1:0]                                snoop_state,
    output wire [511:0]                              snoop_data,

    // 中断和调试
    input  wire                                      timer_interrupt,
    input  wire                                      external_interrupt,
    input  wire                                      software_interrupt,

    // Debug interface
    output wire [63:0]                               debug_pc,
    output wire [31:0]                               debug_instr,
    output wire                                      debug_wb_valid,
    output wire [4:0]                                debug_wb_rd,
    output wire [63:0]                               debug_wb_value
);

    // 内部信号定义
    wire [2:0] icache_coh_rsp_state;
    wire [2:0] dcache_coh_rsp_state;
    wire [2:0] snoop_state_internal;
    wire icache_mem_req_rw;
    assign icache_mem_req_rw = 1'b0;  // 指令缓存始终是读操作

    // 流水线寄存器
    wire [63:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    wire [31:0] instr_if, instr_id, instr_ex, instr_mem, instr_wb;
    wire [15:0] ctrl_id, ctrl_ex, ctrl_mem, ctrl_wb;

    // 控制信号
    wire [6:0] opcode = instr_id[6:0];
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign rd = instr_id[11:7];
    assign rs1 = instr_id[19:15];
    assign rs2 = instr_id[24:20];
    assign funct3 = instr_id[14:12];
    assign funct7 = instr_id[31:25];

    wire [4:0] rd_wb;
    wire [4:0] rd_mem;
    wire [4:0] rd_ex;

    wire [63:0] reg_wdata;
    wire [63:0] rs1_data;
    wire [63:0] rs2_data;

    wire [63:0] imm_id;

    // 冒险检测信号
    wire stall_if, stall_id, stall_ex, stall_mem, stall_wb;
    wire flush_if, flush_id, flush_ex, flush_mem;

    // 执行阶段信号
    wire [63:0] alu_result;
    wire branch_taken;
    wire [63:0] branch_target;

    // 内存访问信号
    wire [63:0] mem_result;

    // 写回信号
    wire [4:0] wb_rd;
    wire wb_reg_we;
    wire [63:0] wb_reg_wdata;

    // L1-L2接口信号
    wire l1_l2_ready;

    // 当L1缓存在cpu_top中实例化时，这些L1-L2信号直接连接到cpu_top中的L1缓存
    assign l1_icache_req = icache_req;
    assign l1_icache_addr = icache_addr;
    assign l1_dcache_req = dcache_req;
    assign l1_dcache_addr = dcache_addr;
    assign l1_dcache_wdata = {{448{1'b0}}, dcache_wdata};
    assign l1_dcache_we = dcache_we;
    assign l1_dcache_req_type = 2'b00;

    // 一致性状态处理
    assign snoop_state = dcache_coh_rsp_state[1:0];
    assign snoop_hit = 1'b0;
    assign snoop_ready = 1'b1;
    assign snoop_data = 512'd0;

    // 取指阶段
    riscv64_instruction_fetch #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .L1_ICACHE_DATA_WIDTH(L1_ICACHE_DATA_WIDTH)
    ) u_if (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_if),
        .flush(flush_if),
        .branch_target(branch_target),
        .branch_taken(branch_taken),
        .pc(pc_if),
        .instr(instr_if),
        .cache_req(icache_req),
        .cache_addr(icache_addr),
        .cache_data(icache_data),
        .cache_ready(icache_ready)
    );

    // 译码阶段
    riscv64_instruction_decode #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_id (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_id),
        .flush(flush_id),
        .pc_in(pc_if),
        .instr_in(instr_if),
        .pc_out(pc_id),
        .instr_out(instr_id),
        .rs1(rs1),
        .rs2(rs2),
        .imm(imm_id),
        .ctrl_signals(ctrl_id)
    );

    // 执行阶段
    riscv64_execution #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ex (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_ex),
        .flush(flush_ex),
        .pc_in(pc_id),
        .instr_in(instr_id),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .imm(imm_id),
        .ctrl_in(ctrl_id),
        .pc_out(pc_ex),
        .instr_out(instr_ex),
        .alu_result(alu_result),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .ctrl_out(ctrl_ex)
    );

    // 内存访问阶段
    riscv64_memory_access #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .L1_DCACHE_DATA_WIDTH(L1_DCACHE_DATA_WIDTH)
    ) u_mem (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_mem),
        .flush(flush_mem),
        .pc_in(pc_ex),
        .instr_in(instr_ex),
        .alu_result(alu_result),
        .rs2_data(rs2_data),
        .ctrl_in(ctrl_ex),
        .cache_addr(dcache_addr),
        .cache_wdata(dcache_wdata),
        .cache_rdata(dcache_rdata),
        .cache_req(dcache_req),
        .cache_we(dcache_we),
        .cache_byte_en(dcache_byte_en),
        .cache_ready(dcache_ready),
        .pc_out(pc_mem),
        .instr_out(instr_mem),
        .mem_result(mem_result),
        .ctrl_out(ctrl_mem)
    );

    // 写回阶段
    riscv64_write_back #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_wb (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_wb),
        .pc_in(pc_mem),
        .instr_in(instr_mem),
        .alu_result(alu_result),
        .mem_result(mem_result),
        .ctrl_in(ctrl_mem),
        .rd(wb_rd),
        .reg_we(wb_reg_we),
        .reg_wdata(wb_reg_wdata),
        .pc_out(pc_wb),
        .instr_out(instr_wb),
        .wb_valid(debug_wb_valid)
    );

    // 寄存器文件
    riscv64_register_file #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1(instr_id[19:15]),
        .rs2(instr_id[24:20]),
        .rd(wb_rd),
        .we(wb_reg_we),
        .wdata(wb_reg_wdata),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // 冒险检测单元
    riscv64_hazard_detection #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_hazard (
        .rs1_id(instr_id[19:15]),
        .rs2_id(instr_id[24:20]),
        .rd_ex(instr_ex[11:7]),
        .rd_mem(instr_mem[11:7]),
        .rd_wb(wb_rd),
        .reg_we_ex(ctrl_ex[10]),
        .reg_we_mem(ctrl_mem[10]),
        .reg_we_wb(wb_reg_we),
        .mem_read_ex(ctrl_ex[9]),
        .branch_taken(branch_taken),
        .data_hazard(),
        .control_hazard(),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .stall_ex(stall_ex),
        .stall_mem(stall_mem),
        .stall_wb(stall_wb),
        .flush_if(flush_if),
        .flush_id(flush_id),
        .flush_ex(flush_ex),
        .flush_mem(flush_mem)
    );

    // 调试输出
    assign debug_pc = pc_wb;
    assign debug_instr = instr_wb;
    assign debug_wb_rd = wb_rd;
    assign debug_wb_value = wb_reg_wdata;

endmodule