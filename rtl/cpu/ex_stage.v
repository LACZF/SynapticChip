
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module ex_stage (
    input  wire                   clk,
    input  wire                   reset,
    /********** 流水线控制信号 **********/
    input  wire                   stall_i,
    input  wire                   flush_i,
    input  wire                   int_detect_i,
    /********** 数据直通 **********/
    output wire [`WordDataBus]    fwd_data_o,
    /********** ID/EX流水线寄存器 **********/
    input  wire [`WordAddrBus]    id_pc_i,
    input  wire [`WordDataBus]    id_insn_i,
    input  wire                   id_en_i,
    input  wire [`AluOpBus]       id_alu_op_i,
    input  wire [`WordDataBus]    id_alu_in_0_i,
    input  wire [`WordDataBus]    id_alu_in_1_i,
    input  wire                   id_br_flag_i,
    input  wire [`MemOpBus]       id_mem_op_i,
    input  wire [`WordDataBus]    id_mem_wr_data_i,
    input  wire [`CtrlOpBus]      id_ctrl_op_i,
    input  wire [`RegAddrBus]     id_dst_addr_i,
    input  wire                   id_gpr_we_n_i,
    input  wire [`IsaExpBus]      id_exp_code_i,
    /********** EX/MEM流水线寄存器 **********/
    output wire [`WordAddrBus]    ex_pc_o,
    output wire                   ex_en_o,
    output wire                   ex_br_flag_o,
    output wire [`MemOpBus]       ex_mem_op_o,
    output wire [`WordDataBus]    ex_mem_wr_data_o,
    output wire [`CtrlOpBus]      ex_ctrl_op_o,
    output wire [`RegAddrBus]     ex_dst_addr_o,
    output wire                   ex_gpr_we_n_o,
    output wire [`IsaExpBus]      ex_exp_code_o,
    output wire [`WordDataBus]    ex_out_o
);

    /********** ALU的输出 **********/
    wire [`WordDataBus]           alu_out;
    wire                          alu_of;

    /********** 数据直通运算结果 **********/
    assign fwd_data_o = alu_out;

    /********** ALU **********/
    alu u_alu (
        .clk          (clk),
        .reset        (reset),
        .id_insn_i    (id_insn_i),

        .in0_i        (id_alu_in_0_i),
        .in1_i        (id_alu_in_1_i),
        .op_i         (id_alu_op_i),
        .result_o     (alu_out),
        .overflow_o   (alu_of)
    );

    /********** 流水线寄存器 **********/
    ex_reg u_ex_reg (
        /********** 时钟 & 复位 **********/
        .clk                (clk),
        .reset              (reset),
        /********** ALU的输出 **********/
        .alu_out_i          (alu_out),
        .alu_of_i           (alu_of),
        /********** 流水线控制信号 **********/
        .stall_i            (stall_i),
        .flush_i            (flush_i),
        .int_detect_i       (int_detect_i),
        /********** ID/EX流水线寄存器 **********/
        .id_pc_i            (id_pc_i),
        .id_insn_i          (id_insn_i),
        .id_en_i            (id_en_i),
        .id_br_flag_i       (id_br_flag_i),
        .id_mem_op_i        (id_mem_op_i),
        .id_mem_wr_data_i   (id_mem_wr_data_i),
        .id_ctrl_op_i       (id_ctrl_op_i),
        .id_dst_addr_i      (id_dst_addr_i),
        .id_gpr_we_n_i      (id_gpr_we_n_i),
        .id_exp_code_i      (id_exp_code_i),
        /********** EX/MEM流水线寄存器 **********/
        .ex_pc_o            (ex_pc_o),
        .ex_en_o            (ex_en_o),
        .ex_br_flag_o       (ex_br_flag_o),
        .ex_mem_op_o        (ex_mem_op_o),
        .ex_mem_wr_data_o   (ex_mem_wr_data_o),
        .ex_ctrl_op_o       (ex_ctrl_op_o),
        .ex_dst_addr_o      (ex_dst_addr_o),
        .ex_gpr_we_n_o      (ex_gpr_we_n_o),
        .ex_exp_code_o      (ex_exp_code_o),
        .ex_out_o           (ex_out_o)
    );

endmodule