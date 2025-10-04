// riscv64_core.v
`include "cache_params.v"

module riscv64_core #(
    parameter CORE_ID = 0
) (
    input wire clk,
    input wire rst_n,

    // 指令缓存接口
    output wire icache_req,
    output wire [63:0] icache_addr,
    input wire [31:0] icache_data,
    input wire icache_ready,

    // 数据缓存接口
    output wire dcache_req,
    output wire [63:0] dcache_addr,
    output wire [63:0] dcache_wdata,
    input wire [63:0] dcache_rdata,
    output wire dcache_we,
    output wire [7:0] dcache_byte_en,
    input wire dcache_ready,

    // 中断接口
    input wire timer_interrupt,
    input wire external_interrupt,
    input wire software_interrupt,

    // 调试接口
    output wire [63:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire debug_wb_valid,
    output wire [4:0] debug_wb_rd,
    output wire [63:0] debug_wb_value
);

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

    // wire [63:0] branch_target;

    wire [4:0] rd_wb;
    wire [4:0] rd_mem;
    wire [4:0] rd_ex;

    wire [63:0] reg_wdata;
    wire [63:0] rs1_data;
    wire [63:0] rs2_data;

    // wire [63:0] mem_result;
    // wire [15:0] ctrl_mem;

    // wire [15:0] ctrl_ex;
    // wire [63:0] alu_result;

    wire [63:0] imm_id;
    // wire [15:0] ctrl_id;

    reg [63:0] if_mem_addr;

    wire l2_req;
    wire [63:0] l2_icache_addr;
    wire [63:0] l2_dcache_addr;
    wire [511:0] l2_dcache_wdata;
    wire [511:0] l2_icache_data;
    wire [511:0] l2_dcache_data;
    wire l2_we;
    wire l2_ready;
    wire snoop_valid;
    wire [63:0] snoop_addr;
    wire snoop_we;
    wire snoop_hit;
    wire [511:0] snoop_data;
    wire [31:0] if_instr;
    wire [63:0] if_pc;

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

    wire [63:0] mem_addr;
    wire [63:0] mem_wdata;
    wire [7:0] mem_byte_en;
    wire [63:0] mem_rdata;

    // 指令缓存实例
    l1_icache u_icache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(if_pc),
        .cpu_req(if_req),
        .cpu_data(if_instr),
        .cpu_ready(if_ready),
        .cache_hit(),
        .l2_req(l2_icache_req),
        .l2_addr(l2_icache_addr),
        .l2_data(l2_icache_data),
        .l2_ready(l2_icache_ready),
        .l2_read(),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_hit()
    );

    // 数据缓存实例
    l1_dcache u_dcache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(mem_addr),
        .cpu_wdata(mem_wdata),
        .cpu_req(mem_req),
        .cpu_we(mem_we),
        .cpu_byte_en(mem_byte_en),
        .cpu_rdata(mem_rdata),
        .cpu_ready(mem_ready),
        .cache_hit(),
        .l2_req(l2_dcache_req),
        .l2_addr(l2_dcache_addr),
        .l2_wdata(l2_dcache_wdata),
        .l2_rdata(l2_dcache_data),
        .l2_we(l2_dcache_we),
        .l2_ready(l2_dcache_ready),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        // .snoop_we(snoop_we),
        .snoop_hit(snoop_hit),
        .snoop_data(snoop_data)
    );

    // 取指阶段
    instruction_fetch u_if (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_if),
        .flush(flush_if),
        .branch_target(branch_target),
        .branch_taken(branch_taken),
        .pc(pc_if),
        .instr(instr_if),
        .cache_req(icache_req),
        /* TODO */
        // .cache_addr(icache_addr),
        // .cache_data(icache_data),
        .cache_ready(icache_ready)
    );

    // 译码阶段
    instruction_decode u_id (
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
    execution u_ex (
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
    memory_access u_mem (
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
    write_back u_wb (
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
    register_file u_regfile (
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
    hazard_detection u_hazard (
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