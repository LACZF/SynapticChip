`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "spm.v"

module cpu_top (
    input  wire                      clk,
    input  wire                      reset,

    input  wire [`WordDataBus]       if_bus_rd_data_i,
    input  wire                      if_bus_rdy_n_i,
    input  wire                      if_bus_grnt_n_i,
    output wire                      if_bus_req_n_o,
    output wire [`WordAddrBus]       if_bus_addr_o,
    output wire                      if_bus_as_n_o,
    output wire                      if_bus_rw_o,
    output wire [`WordDataBus]       if_bus_wr_data_o,

    input  wire [`WordDataBus]       mem_bus_rd_data_i,
    input  wire                      mem_bus_rdy_n_i,
    input  wire                      mem_bus_grnt_n_i,
    output wire                      mem_bus_req_n_o,
    output wire [`WordAddrBus]       mem_bus_addr_o,
    output wire                      mem_bus_as_n_o,
    output wire                      mem_bus_rw_o,
    output wire [`WordDataBus]       mem_bus_wr_data_o,

    input  wire [`CPU_IRQ_CH-1:0]    cpu_irq_i
);

    /********** 流水线寄存器 **********/
    wire [`WordAddrBus]             if_pc;
    wire [`WordDataBus]             if_insn;
    wire                            if_en;

    wire [`WordAddrBus]             id_pc;
    wire [`WordDataBus]             id_insn;
    wire                            id_en;
    wire [`AluOpBus]                id_alu_op;
    wire [`WordDataBus]             id_alu_in0;
    wire [`WordDataBus]             id_alu_in1;
    wire                            id_br_flag;
    wire [`MemOpBus]                id_mem_op;
    wire [`WordDataBus]             id_mem_wr_data;
    wire [`CtrlOpBus]               id_ctrl_op;
    wire [`RegAddrBus]              id_dst_addr;
    wire                            id_gpr_we_n;
    wire [`IsaExpBus]               id_exp_code;

    wire [`WordAddrBus]             ex_pc;
    wire [`WordDataBus]             ex_insn;
    wire                            ex_en;
    wire                            ex_br_flag;
    wire [`MemOpBus]                ex_mem_op;
    wire [`WordDataBus]             ex_mem_wr_data;
    wire [`CtrlOpBus]               ex_ctrl_op;
    wire [`RegAddrBus]              ex_dst_addr;
    wire                            ex_gpr_we_n;
    wire [`IsaExpBus]               ex_exp_code;
    wire [`WordDataBus]             ex_out;

    wire [`WordAddrBus]             mem_pc;
    wire [`WordDataBus]             mem_insn;
    wire                            mem_en;
    wire                            mem_br_flag;
    wire [`CtrlOpBus]               mem_ctrl_op;
    wire [`RegAddrBus]              mem_dst_addr;
    wire                            mem_gpr_we_n;
    wire [`IsaExpBus]               mem_exp_code;
    wire [`WordDataBus]             mem_out;

    /********** 流水线控制信号 **********/
    wire                         if_stall;
    wire                         id_stall;
    wire                         ex_stall;
    wire                         mem_stall;

    wire                         if_flush;
    wire                         id_flush;
    wire                         ex_flush;
    wire                         mem_flush;

    wire                         if_busy;
    wire                         mem_busy;

    wire [`WordAddrBus]          new_pc;
    wire [`WordAddrBus]          br_addr;
    wire                         br_taken;
    wire                         ld_hazard;

    wire [`WordDataBus]          gpr_rd_data0;
    wire [`WordDataBus]          gpr_rd_data1;
    wire [`RegAddrBus]           gpr_rd_addr0;
    wire [`RegAddrBus]           gpr_rd_addr1;

    wire [`CpuExeModeBus]        exe_mode;
    wire [`WordDataBus]          creg_rd_data;
    wire [`RegAddrBus]           creg_rd_addr;

    wire                         int_detect;

    wire [`WordDataBus]          if_spm_rd_data;
    wire [`WordAddrBus]          if_spm_addr;
    wire                         if_spm_as_n;
    wire                         if_spm_rw;
    wire [`WordDataBus]          if_spm_wr_data;

    wire [`WordDataBus]          mem_spm_rd_data;
    wire [`WordAddrBus]          mem_spm_addr;
    wire                         mem_spm_as_n;
    wire                         mem_spm_rw;
    wire [`WordDataBus]          mem_spm_wr_data;

    wire [`WordDataBus]          ex_fwd_data;
    wire [`WordDataBus]          mem_fwd_data;

    /********** IF阶段 **********/
    if_stage u_if_stage (
        .clk               (clk),
        .reset             (reset),

        .spm_rd_data_i     (if_spm_rd_data),
        .spm_addr_o        (if_spm_addr),
        .spm_as_n_o        (if_spm_as_n),
        .spm_rw_o          (if_spm_rw),
        .spm_wr_data_o     (if_spm_wr_data),

        .bus_rd_data_i     (if_bus_rd_data_i),
        .bus_rdy_n_i       (if_bus_rdy_n_i),
        .bus_grnt_n_i      (if_bus_grnt_n_i),
        .bus_req_n_o       (if_bus_req_n_o),
        .bus_addr_o        (if_bus_addr_o),
        .bus_as_n_o        (if_bus_as_n_o),
        .bus_rw_o          (if_bus_rw_o),
        .bus_wr_data_o     (if_bus_wr_data_o),

        .stall_i           (if_stall),
        .flush_i           (if_flush),
        .new_pc_i          (new_pc),
        .br_taken_i        (br_taken),
        .br_addr_i         (br_addr),
        .busy_o            (if_busy),

        .if_pc_o           (if_pc),
        .if_insn_o         (if_insn),
        .if_en_o           (if_en)
    );

    /********** ID阶段 **********/
    id_stage u_id_stage (
        .clk                   (clk),
        .reset                 (reset),

        .gpr_rd_data0_i        (gpr_rd_data0),
        .gpr_rd_data1_i        (gpr_rd_data1),
        .gpr_rd_addr0_o        (gpr_rd_addr0),
        .gpr_rd_addr1_o        (gpr_rd_addr1),

        .ex_en_i               (ex_en),
        .ex_fwd_data_i         (ex_fwd_data),
        .ex_dst_addr_i         (ex_dst_addr),
        .ex_gpr_we_n_i         (ex_gpr_we_n),

        .mem_fwd_data_i        (mem_fwd_data),

        .exe_mode_i            (exe_mode),
        .creg_rd_data_i        (creg_rd_data),
        .creg_rd_addr_o        (creg_rd_addr),

        .stall_i               (id_stall),
        .flush_i               (id_flush),
        .br_addr_o             (br_addr),
        .br_taken_o            (br_taken),
        .ld_hazard_o           (ld_hazard),

        .if_pc_i               (if_pc),
        .if_insn_i             (if_insn),
        .if_en_i               (if_en),

        .id_pc_o               (id_pc),
        .id_insn_o             (id_insn),
        .id_en_o               (id_en),
        .id_alu_op_o           (id_alu_op),
        .id_alu_in0_o          (id_alu_in0),
        .id_alu_in1_o          (id_alu_in1),
        .id_br_flag_o          (id_br_flag),
        .id_mem_op_o           (id_mem_op),
        .id_mem_wr_data_o      (id_mem_wr_data),
        .id_ctrl_op_o          (id_ctrl_op),
        .id_dst_addr_o         (id_dst_addr),
        .id_gpr_we_n_o         (id_gpr_we_n),
        .id_exp_code_o         (id_exp_code)
    );

    /********** EX阶段 **********/
    ex_stage u_ex_stage (
        .clk                   (clk),
        .reset                 (reset),

        .stall_i               (ex_stall),
        .flush_i               (ex_flush),
        .int_detect_i          (int_detect),

        .fwd_data_o            (ex_fwd_data),

        .id_pc_i               (id_pc),
        .id_insn_i             (id_insn),
        .id_en_i               (id_en),
        .id_alu_op_i           (id_alu_op),
        .id_alu_in0_i          (id_alu_in0),
        .id_alu_in1_i          (id_alu_in1),
        .id_br_flag_i          (id_br_flag),
        .id_mem_op_i           (id_mem_op),
        .id_mem_wr_data_i      (id_mem_wr_data),
        .id_ctrl_op_i          (id_ctrl_op),
        .id_dst_addr_i         (id_dst_addr),
        .id_gpr_we_n_i         (id_gpr_we_n),
        .id_exp_code_i         (id_exp_code),

        .ex_pc_o               (ex_pc),
        .ex_insn_o             (ex_insn),
        .ex_en_o               (ex_en),
        .ex_br_flag_o          (ex_br_flag),
        .ex_mem_op_o           (ex_mem_op),
        .ex_mem_wr_data_o      (ex_mem_wr_data),
        .ex_ctrl_op_o          (ex_ctrl_op),
        .ex_dst_addr_o         (ex_dst_addr),
        .ex_gpr_we_n_o         (ex_gpr_we_n),
        .ex_exp_code_o         (ex_exp_code),
        .ex_out_o              (ex_out)
    );

    /********** MEM阶段 **********/
    mem_stage u_mem_stage (
        .clk                 (clk),
        .reset               (reset),

        .stall_i             (mem_stall),
        .flush_i             (mem_flush),
        .busy_o              (mem_busy),

        .fwd_data_o          (mem_fwd_data),

        .spm_rd_data_i       (mem_spm_rd_data),
        .spm_addr_o          (mem_spm_addr),
        .spm_as_n_o          (mem_spm_as_n),
        .spm_rw_o            (mem_spm_rw),
        .spm_wr_data_o       (mem_spm_wr_data),

        .bus_rd_data_i       (mem_bus_rd_data_i),
        .bus_rdy_n_i         (mem_bus_rdy_n_i),
        .bus_grnt_n_i        (mem_bus_grnt_n_i),
        .bus_req_n_o         (mem_bus_req_n_o),
        .bus_addr_o          (mem_bus_addr_o),
        .bus_as_n_o          (mem_bus_as_n_o),
        .bus_rw_o            (mem_bus_rw_o),
        .bus_wr_data_o       (mem_bus_wr_data_o),

        .ex_pc_i             (ex_pc),
        .ex_insn_i           (ex_insn),
        .ex_en_i             (ex_en),
        .ex_br_flag_i        (ex_br_flag),
        .ex_mem_op_i         (ex_mem_op),
        .ex_mem_wr_data_i    (ex_mem_wr_data),
        .ex_ctrl_op_i        (ex_ctrl_op),
        .ex_dst_addr_i       (ex_dst_addr),
        .ex_gpr_we_n_i       (ex_gpr_we_n),
        .ex_exp_code_i       (ex_exp_code),
        .ex_out_i            (ex_out),

        .mem_pc_o            (mem_pc),
        .mem_insn_o          (mem_insn),
        .mem_en_o            (mem_en),
        .mem_br_flag_o       (mem_br_flag),
        .mem_ctrl_op_o       (mem_ctrl_op),
        .mem_dst_addr_o      (mem_dst_addr),
        .mem_gpr_we_n_o      (mem_gpr_we_n),
        .mem_exp_code_o      (mem_exp_code),
        .mem_out_o           (mem_out)
    );

    /********** 控制单元 **********/
    ctrl u_ctrl (
        .clk               (clk),
        .reset             (reset),

        .creg_rd_addr_i    (creg_rd_addr),
        .creg_rd_data_o    (creg_rd_data),
        .exe_mode_o        (exe_mode),

        .irq_i             (cpu_irq_i),
        .int_detect_o      (int_detect),

        .id_pc_i           (id_pc),

        .mem_pc_i          (mem_pc),
        .mem_en_i          (mem_en),
        .mem_br_flag_i     (mem_br_flag),
        .mem_ctrl_op_i     (mem_ctrl_op),
        .mem_dst_addr_i    (mem_dst_addr),
        .mem_exp_code_i    (mem_exp_code),
        .mem_out_i         (mem_out),

        .if_busy_i         (if_busy),
        .ld_hazard_i       (ld_hazard),
        .mem_busy_i        (mem_busy),

        .if_stall_o        (if_stall),
        .id_stall_o        (id_stall),
        .ex_stall_o        (ex_stall),
        .mem_stall_o       (mem_stall),

        .if_flush_o        (if_flush),
        .id_flush_o        (id_flush),
        .ex_flush_o        (ex_flush),
        .mem_flush_o       (mem_flush),

        .new_pc_o          (new_pc)
    );

    /********** 通用寄存器 **********/
    gpr u_gpr (
        .clk               (clk),
        .reset             (reset),

        .mem_pc_i          (mem_pc),
        .mem_insn_i        (mem_insn),
        .mem_en_i          (mem_en),

        .rd_addr0_i        (gpr_rd_addr0),
        .rd_data0_o        (gpr_rd_data0),
        .rd_addr1_i        (gpr_rd_addr1),
        .rd_data1_o        (gpr_rd_data1),

        .we_n_i            (mem_gpr_we_n),
        .wr_addr_i         (mem_dst_addr),
        .wr_data_i         (mem_out)
    );

    /********** SPM **********/
    spm_top u_spm (
        .clk                   (clk),
        .reset                 (reset),

        .if_pc_i               (if_pc),
        .if_insn_i             (if_insn),
        .if_en_i               (if_en),
        .if_spm_addr_i         (if_spm_addr[`SpmAddrLoc]),
        .if_spm_as_n_i         (if_spm_as_n),
        .if_spm_rw_i           (if_spm_rw),
        .if_spm_wr_data_i      (if_spm_wr_data),
        .if_spm_rd_data_o      (if_spm_rd_data),

        .mem_pc_i              (mem_pc),
        .mem_insn_i            (mem_insn),
        .mem_en_i              (mem_en),
        .mem_spm_addr_i        (mem_spm_addr[`SpmAddrLoc]),
        .mem_spm_as_n_i        (mem_spm_as_n),
        .mem_spm_rw_i          (mem_spm_rw),
        .mem_spm_wr_data_i     (mem_spm_wr_data),
        .mem_spm_rd_data_o     (mem_spm_rd_data)
    );

endmodule