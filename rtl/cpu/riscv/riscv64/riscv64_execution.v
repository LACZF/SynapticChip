// riscv64_execution.v
`include "riscv64_instruction_defs.v"
`include "riscv64_i_extension.v"
`include "riscv64_m_extension.v"
`include "riscv64_a_extension.v"
`include "riscv64_f_extension.v"
`include "riscv64_d_extension.v"
`include "riscv64_q_extension.v"
`include "riscv64_zifencei_extension.v"
`include "riscv64_zicsr_extension.v"
`include "riscv64_zfh_extension.v"

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
    wire [2:0]  alu_op      = ctrl_in_i[14:12];
    wire        reg_op      = ctrl_in_i[15]; // 标识是否为寄存器算术指令
    wire [2:0]  funct3      = instr_in_i[14:12];
    wire        funct7_30   = instr_in_i[30]; // 用于区分 ADD/SUB, SRL/SRA 等指令
    wire [6:0]  opcode      = instr_in_i[6:0]; // 提取指令的opcode字段，便于统一使用

    // 扩展模块输出信号
    wire [63:0] i_result;
    wire        i_branch_taken;
    wire [63:0] i_branch_target;
    wire [63:0] m_result;
    wire [63:0] a_result;
    wire [63:0] a_mem_data;
    wire        a_load_reserved;
    wire        a_store_conditional;
    wire [63:0] f_result;
    wire [63:0] d_result;
    wire [127:0] q_result;
    wire [63:0] zicsr_result;
    wire [63:0] zfh_result;
    wire        is_i_extension;
    wire        is_m_extension;
    wire        is_a_extension;
    wire        is_f_extension;
    wire        is_d_extension;
    wire        is_q_extension;
    wire        is_zifencei_extension;
    wire        is_zicsr_extension;
    wire        is_zfh_extension;
    wire [63:0] alu_result_temp; // 中间结果

    // 实例化I扩展模块
    riscv64_i_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_i_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .imm_i(imm_i),
        .pc_in_i(pc_in_i),
        .alu_op(alu_op),
        .alu_result_o(i_result),
        .branch_taken_o(i_branch_taken),
        .branch_target_o(i_branch_target),
        .is_i_extension(is_i_extension)
    );

    // 实例化M扩展模块
    riscv64_m_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_m_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .alu_result_o(m_result),
        .is_m_extension(is_m_extension)
    );

    // 实例化A扩展模块（原子操作）
    riscv64_a_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_a_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .mem_data_i(64'b0), // 在实际系统中需要连接到内存读取数据
        .alu_result_o(a_result),
        .mem_data_o(a_mem_data),
        .is_a_extension(is_a_extension),
        .load_reserved(a_load_reserved),
        .store_conditional(a_store_conditional)
    );

    // 实例化F扩展模块（单精度浮点）
    riscv64_f_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_f_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .alu_result_o(f_result),
        .is_f_extension(is_f_extension)
    );

    // 实例化D扩展模块（双精度浮点）
    riscv64_d_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_d_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .alu_result_o(d_result),
        .is_d_extension(is_d_extension)
    );

    // 实例化Q扩展模块（四精度浮点）
    riscv64_q_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_q_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i({64'b0, rs1_data_i}), // 扩展为128位
        .rs2_data_i({64'b0, rs2_data_i}), // 扩展为128位
        .alu_result_o(q_result),
        .is_q_extension(is_q_extension)
    );

    // 实例化Zifencei扩展模块
    riscv64_zifencei_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_zifencei_extension (
        .funct3(funct3),
        .opcode(opcode),
        .is_zifencei_extension(is_zifencei_extension)
    );

    // 实例化Zicsr扩展模块
    riscv64_zicsr_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_zicsr_extension (
        .funct3(funct3),
        .opcode(opcode),
        .csr_addr_i(instr_in_i[31:20]), // CSR地址在指令的31:20位
        .rs1_data_i(rs1_data_i),
        .rs1_addr_i(instr_in_i[19:15]), // rs1地址
        .rs2_addr_i(instr_in_i[24:20]), // rs2地址
        .rd_addr_i(instr_in_i[11:7]),   // rd地址
        .alu_result_o(zicsr_result),
        .is_zicsr_extension(is_zicsr_extension)
    );

    // 实例化Zfh扩展模块（半精度浮点）
    riscv64_zfh_extension #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_zfh_extension (
        .funct7_30(funct7_30),
        .funct3(funct3),
        .opcode(opcode),
        .rs1_data_i(rs1_data_i),
        .rs2_data_i(rs2_data_i),
        .alu_result_o(zfh_result),
        .is_zfh_extension(is_zfh_extension)
    );

    // 扩展模块结果选择逻辑
    assign alu_result_temp = (
        is_m_extension ? m_result :
        is_a_extension ? a_result :
        is_f_extension ? f_result :
        is_d_extension ? d_result :
        is_q_extension ? q_result[63:0] : // 取Q扩展结果的低64位
        is_zicsr_extension ? zicsr_result :
        is_zfh_extension ? zfh_result :
        is_i_extension ? i_result :
        64'b0
    );

    // Zifencei指令不需要结果，所以不需要在结果选择逻辑中添加

    // 分支结果选择
    wire branch_taken = i_branch_taken;
    wire [63:0] branch_target = i_branch_target;

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