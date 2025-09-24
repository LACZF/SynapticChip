// riscv64_core.v
module riscv64_core #(
    parameter CORE_ID = 0
) (
    input wire clk,
    input wire rst_n,

    // 内存接口
    output reg mem_req,
    output reg [63:0] mem_addr,
    output reg [63:0] mem_wdata,
    input wire [63:0] mem_rdata,
    output reg mem_we,
    output reg [7:0] mem_byte_en,
    input wire mem_grant,
    input wire mem_ready,

    // 中断
    input wire ipi_interrupt,
    input wire timer_interrupt,
    input wire external_interrupt,

    // 调试
    output reg halted
);

    // 流水线寄存器
    reg [63:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    reg [31:0] instr_if, instr_id, instr_ex, instr_mem, instr_wb;

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

    wire [63:0] branch_target;

    wire [4:0] rd_wb;
    wire [4:0] rd_mem;
    wire [4:0] rd_ex;

    wire [63:0] reg_wdata;
    reg [63:0] rs1_data;
    reg [63:0] rs2_data;

    wire [63:0] mem_result;
    wire [15:0] ctrl_mem;

    wire [15:0] ctrl_ex;
    wire [63:0] alu_result;

    wire [63:0] imm_id;
    wire [15:0] ctrl_id;

    reg [63:0] if_mem_addr;

    // 冒险检测信号
    wire data_hazard, control_hazard;
    wire stall_if, stall_id, stall_ex, stall_mem, stall_wb;
    wire flush_if, flush_id, flush_ex, flush_mem;

    // 模块实例化
    instruction_fetch u_if (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_if),
        .flush(flush_if),
        .branch_target(branch_target),
        .branch_taken(branch_taken),
        .pc(pc_if),
        .instr(instr_if),
        .mem_req(if_mem_req),
        .mem_addr(if_mem_addr),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    instruction_decode u_id (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_id),
        .flush(flush_id),
        .pc_in(pc_if),
        .instr_in(instr_if),
        .pc_out(pc_id),
        .instr_out(instr_id),
        .funct3(funct3),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm_id),
        .ctrl_signals(ctrl_id)
    );

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

    /* TODO */
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
        // .mem_req(mem_req),
        // .mem_addr(mem_addr),
        // .mem_wdata(mem_wdata),
        // .mem_we(mem_we),
        // .mem_byte_en(mem_byte_en),
        // .mem_rdata(mem_rdata),
        // .mem_ready(mem_ready),
        .pc_out(pc_mem),
        .instr_out(instr_mem),
        .mem_result(mem_result),
        .ctrl_out(ctrl_mem)
    );

    write_back u_wb (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_wb),
        .pc_in(pc_mem),
        .instr_in(instr_mem),
        .alu_result(mem_result),
        .mem_result(mem_rdata),
        .ctrl_in(ctrl_mem),
        .rd(rd_wb),
        .reg_we(reg_we),
        .reg_wdata(reg_wdata)
    );

    register_file u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd_wb),
        .we(reg_we),
        .wdata(reg_wdata),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    hazard_detection u_hazard (
        .rs1_id(rs1),
        .rs2_id(rs2),
        .rd_ex(rd_ex),
        .rd_mem(rd_mem),
        .rd_wb(rd_wb),
        .reg_we_ex(reg_we_ex),
        .reg_we_mem(reg_we_mem),
        .reg_we_wb(reg_we_wb),
        .mem_read_ex(mem_read_ex),
        .branch_taken(branch_taken),
        .data_hazard(data_hazard),
        .control_hazard(control_hazard),
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

endmodule
