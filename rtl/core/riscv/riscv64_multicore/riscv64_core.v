// riscv64_core.v
`include "cache_params.v"
`include "cache_system_params.v"

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

    // L1-L2缓存接口
    output wire l1_icache_req,
    output wire [63:0] l1_icache_addr,
    input wire [511:0] l1_icache_data,
    input wire l1_icache_ready,

    output wire l1_dcache_req,
    output wire [63:0] l1_dcache_addr,
    output wire [511:0] l1_dcache_wdata,
    input wire [511:0] l1_dcache_data,
    output wire l1_dcache_we,
    output wire [1:0] l1_dcache_req_type,
    input wire l1_dcache_ready,

    // 监听接口
    input wire snoop_valid,
    input wire [63:0] snoop_addr,
    input wire [1:0] snoop_req_type,
    output wire snoop_ready,
    output wire snoop_hit,
    output wire [1:0] snoop_state,
    output wire [511:0] snoop_data,

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

    // 中间信号用于缓存一致性状态
    wire [2:0] icache_coh_rsp_state;
    wire [2:0] dcache_coh_rsp_state;
    wire icache_mem_req_rw;  // 指令缓存内存请求读写信号
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
    wire snoop_we;
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

    // L1-L2接口信号
    wire l1_l2_req;
    wire [63:0] l1_l2_addr;
    wire [511:0] l1_l2_wdata;
    wire [511:0] l1_l2_rdata;
    wire l1_l2_we;
    wire l1_l2_ready;

    // 指令缓存实例（使用通用cache模块）
    cache #(
        .CACHE_LINE_SIZE(`L1_ICACHE_LINE_SIZE),
        .CACHE_SIZE(`L1_ICACHE_SIZE),
        .ASSOCIATIVITY(`L1_ICACHE_ASSOCIATIVITY),
        .ADDR_WIDTH(`L1_ICACHE_ADDR_WIDTH),
        .DATA_WIDTH(`L1_ICACHE_DATA_WIDTH),
        .SUPPORT_COHERENCY(1),
        .CACHE_LEVEL(`CACHE_LEVEL_L1),
        .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
    ) u_l1_icache (
        .clk(clk),
        .rst_n(rst_n),

        // CPU接口
        .cpu_req_valid(icache_req),
        .cpu_req_addr(icache_addr),
        .cpu_req_rw(1'b0),
        .cpu_req_data(32'd0),
        .cpu_req_strb(4'hF),
        .cpu_rsp_valid(icache_ready),
        .cpu_rsp_data(icache_data),
        .cpu_rsp_error(),

        // 内存接口（连接L2）
        .mem_req_valid(l1_icache_req),
        .mem_req_addr(l1_icache_addr),
        .mem_req_rw(icache_mem_req_rw),
        .mem_req_data(l1_dcache_wdata[0*64 +: 64]),
        .mem_rsp_valid(l1_icache_ready),
        .mem_rsp_data(l1_icache_data[0*64 +: 64]),
        .mem_rsp_error(),

        // 一致性接口
        .coh_req_addr(snoop_addr),
        .coh_req_valid(snoop_valid),
        .coh_req_type(3'd0),
        .coh_rsp_valid(),
        .coh_rsp_state(icache_coh_rsp_state)
    );

    // 数据缓存实例（使用通用cache模块）
    cache #(
        .CACHE_LINE_SIZE(`L1_DCACHE_LINE_SIZE),
        .CACHE_SIZE(`L1_DCACHE_SIZE),
        .ASSOCIATIVITY(`L1_DCACHE_ASSOCIATIVITY),
        .ADDR_WIDTH(`L1_DCACHE_ADDR_WIDTH),
        .DATA_WIDTH(`L1_DCACHE_DATA_WIDTH),
        .SUPPORT_COHERENCY(1),
        .CACHE_LEVEL(`CACHE_LEVEL_L1),
        .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
    ) u_l1_dcache (
        .clk(clk),
        .rst_n(rst_n),

        // CPU接口
        .cpu_req_valid(dcache_req),
        .cpu_req_addr(dcache_addr),
        .cpu_req_rw(dcache_we),
        .cpu_req_data(dcache_wdata),
        .cpu_req_strb(dcache_byte_en),
        .cpu_rsp_valid(dcache_ready),
        .cpu_rsp_data(dcache_rdata),
        .cpu_rsp_error(),

        // 内存接口（连接L2）
        .mem_req_valid(l1_dcache_req),
        .mem_req_addr(l1_dcache_addr),
        .mem_req_rw(l1_dcache_we),
        .mem_req_data(l1_dcache_wdata[0*64 +: 64]),
        .mem_rsp_valid(l1_dcache_ready),
        .mem_rsp_data(l1_dcache_data[0*64 +: 64]),
        .mem_rsp_error(),

        // 一致性接口
        .coh_req_addr(snoop_addr),
        .coh_req_valid(snoop_valid),
        .coh_req_type({1'b0, snoop_req_type}),
        .coh_rsp_valid(snoop_ready),
        .coh_rsp_state(dcache_coh_rsp_state)
    );

    // 将缓存一致性状态转换为2位宽
    assign snoop_state = dcache_coh_rsp_state[1:0];

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
        .cache_addr(icache_addr),
        .cache_data(icache_data),
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