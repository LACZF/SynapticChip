// riscv64_execution.v
// 顶层执行模块，集成非特权和特权指令执行
`include "riscv64_instruction_defs.v"
`include "riscv64_unprivileged_execution.v"
`include "riscv64_privileged_execution.v"

module riscv64_execution #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire                  stall_i,
    input wire                  flush_i,
    input wire [63:0]           pc_in_i,
    input wire [31:0]           instr_in_i,
    input wire [63:0]           rs1_data_i,
    input wire [63:0]           rs2_data_i,
    input wire [63:0]           imm_i,
    input wire [15:0]           ctrl_in_i,
    output reg [63:0]           pc_out_o,
    output reg [31:0]           instr_out_o,
    output reg [63:0]           alu_result_o,
    output reg                  branch_taken_o,
    output reg [63:0]           branch_target_o,
    output reg [15:0]           ctrl_out_o
);

    // 信号定义
    // 从指令和解码控制信号中提取的字段（用于DEBUG）
    wire [2:0]  alu_op      = ctrl_in_i[14:12];
    wire        reg_op      = ctrl_in_i[15]; // 标识是否为寄存器算术指令
    wire [2:0]  funct3      = instr_in_i[14:12];
    wire        funct7_30   = instr_in_i[30]; // 用于区分 ADD/SUB, SRL/SRA 等指令
    wire [6:0]  opcode      = instr_in_i[6:0]; // 提取指令的opcode字段，便于统一使用

    // 指令执行模块信号
    wire [63:0] unpriv_alu_result;
    wire unpriv_branch_taken;
    wire [63:0] unpriv_branch_target;
    wire is_unprivileged_instr;

    wire [63:0] priv_alu_result;
    wire priv_branch_taken;
    wire [63:0] priv_branch_target;
    wire is_privileged_instr;

    // 中间结果信号
    wire [63:0] alu_result_temp;
    wire branch_taken;
    wire [63:0] branch_target;

    // 实例化非特权指令执行模块
    riscv64_unprivileged_execution #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_unprivileged_execution (
        .clk(clk),
        .pc_in_i(pc_in_i),
        .instr_in_i(instr_in_i),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .imm_i(imm_i),
        .ctrl_in_i(ctrl_in_i),
        .alu_result_o(unpriv_alu_result),
        .branch_taken_o(unpriv_branch_taken),
        .branch_target_o(unpriv_branch_target),
        .is_unprivileged_instr(is_unprivileged_instr)
    );

    // 实例化特权指令执行模块
    riscv64_privileged_execution #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_privileged_execution (
        .clk(clk),
        .pc_in_i(pc_in_i),
        .instr_in_i(instr_in_i),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .imm_i(imm_i),
        .ctrl_in_i(ctrl_in_i),
        .alu_result_o(priv_alu_result),
        .branch_taken_o(priv_branch_taken),
        .branch_target_o(priv_branch_target),
        .is_privileged_instr(is_privileged_instr)
    );

    // 结果选择逻辑：优先处理特权指令
    assign alu_result_temp = (
        is_privileged_instr ? priv_alu_result :
        is_unprivileged_instr ? unpriv_alu_result :
        64'b0
    );

    // 分支结果选择
    assign branch_taken = (
        is_privileged_instr ? priv_branch_taken :
        is_unprivileged_instr ? unpriv_branch_taken :
        1'b0
    );

    assign branch_target = (
        is_privileged_instr ? priv_branch_target :
        is_unprivileged_instr ? unpriv_branch_target :
        64'b0
    );

    // 流水线寄存器更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h0000_0013;
            alu_result_o <= 64'b0;
            branch_taken_o <= 1'b0;
            branch_target_o <= 64'b0;
            ctrl_out_o <= 16'b0;
        end else if (flush_i) begin
            instr_out_o <= 32'h0000_0013;
            branch_taken_o <= 1'b0;
            ctrl_out_o <= 16'b0;
        end else if (!stall_i) begin
            pc_out_o <= pc_in_i;
            instr_out_o <= instr_in_i;
            ctrl_out_o <= ctrl_in_i;
            alu_result_o <= alu_result_temp; // 使用阻塞赋值确保在同一个时钟周期内更新
            branch_taken_o <= branch_taken;
            branch_target_o <= branch_target;

        `ifdef DEBUG
            // 添加更详细的调试信息
            $display("[%0t ps] EX: PC=%h, Instr=%h, Opcode=%h", $time, pc_in_i, instr_in_i, opcode);
            $display("[%0t ps] EX: rs1_data_i=%h, rs2_data_i=%h, imm_i=%h", $time, rs1_data_i, rs2_data_i, imm_i);
            $display("[%0t ps] EX: reg_op=%b, alu_op=%b, funct3=%b, funct7_30=%b", $time, reg_op, alu_op, funct3, funct7_30);
            $display("[%0t ps] EX: Final ALU result: %h", $time, alu_result_o);
            $display("[%0t ps] EX: Branch: taken=%b, target=%h", $time, branch_taken_o, branch_target_o);
            $display("[%0t ps] EX: Pipeline signals - stall_i=%b, flush_i=%b", $time, stall_i, flush_i);
        `endif
        end else begin
        `ifdef DEBUG
            $display("[%0t ps] EX: Pipeline stalled", $time);
        `endif
        end
    end

endmodule