
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module mem_stage (
    input  wire                clk,
    input  wire                reset,
    /********** 流水线控制信号 **********/
    input  wire                stall_i,
    input  wire                flush_i,
    output wire                busy_o,
    /********** 数据直通 **********/
    output wire [`WordDataBus] fwd_data_o,
    /********** SPM接口 **********/
    input  wire [`WordDataBus] spm_rd_data_i,
    output wire [`WordAddrBus] spm_addr_o,
    output wire                spm_as_n_o,
    output wire                spm_rw_o,
    output wire [`WordDataBus] spm_wr_data_o,
    /********** 总线接口 **********/
    input  wire [`WordDataBus] bus_rd_data_i,
    input  wire                bus_rdy_n_i,
    input  wire                bus_grnt_n_i,
    output wire                bus_req_n_o,
    output wire [`WordAddrBus] bus_addr_o,
    output wire                bus_as_n_o,
    output wire                bus_rw_o,
    output wire [`WordDataBus] bus_wr_data_o,
    /********** EX/MEM流水线寄存器 **********/
    input  wire [`WordAddrBus] ex_pc_i,
    input  wire                ex_en_i,
    input  wire                ex_br_flag_i,
    input  wire [`MemOpBus]    ex_mem_op_i,
    input  wire [`WordDataBus] ex_mem_wr_data_i,
    input  wire [`CtrlOpBus]   ex_ctrl_op_i,
    input  wire [`RegAddrBus]  ex_dst_addr_i,
    input  wire                ex_gpr_we_n_i,
    input  wire [`IsaExpBus]   ex_exp_code_i,
    input  wire [`WordDataBus] ex_out_i,
    /********** MEM/WB流水线寄存器 **********/
    output wire [`WordAddrBus] mem_pc_o,
    output wire                mem_en_o,
    output wire                mem_br_flag_o,
    output wire [`CtrlOpBus]   mem_ctrl_op_o,
    output wire [`RegAddrBus]  mem_dst_addr_o,
    output wire                mem_gpr_we_n_o,
    output wire [`IsaExpBus]   mem_exp_code_o,
    output wire [`WordDataBus] mem_out_o
);

    /********** 内部信号 **********/
    wire [`WordDataBus]      rd_data;
    wire [`WordAddrBus]      addr;
    wire                     as_;
    wire                     rw;
    wire [`WordDataBus]      wr_data;
    wire [`WordDataBus]      result;
    wire                     miss_align;

    /********** 结果数据直通 **********/
    assign fwd_data_o        = result;

    /********** 内存访问控制模块 **********/
    mem_ctrl u_mem_ctrl (
        .clk             (clk),
        .reset           (reset),

        /********** EX/MEM流水线寄存器 **********/
        .ex_en_i             (ex_en_i),
        .ex_mem_op_i         (ex_mem_op_i),
        .ex_mem_wr_data_i    (ex_mem_wr_data_i),
        .ex_out_i            (ex_out_i),
        /********** 内存访问接口 **********/
        .rd_data_i           (rd_data),
        .addr_o              (addr),
        .as_n_o              (as_),
        .rw_o                (rw),
        .wr_data_o           (wr_data),
        /********** 内存访问结果 **********/
        .result_o            (result),
        .miss_align_o        (miss_align)
    );

    /********** 总线接口 **********/
    bus_if u_bus_if (
        .clk             (clk),
        .reset           (reset),

        /********** 流水线控制信号 **********/
        .stall_i         (stall_i),
        .flush_i         (flush_i),
        .busy_o          (busy_o),
        /********** CPU接口 **********/
        .addr_i          (addr),
        .as_n_i          (as_),
        .rw_i            (rw),
        .wr_data_i       (wr_data),
        .rd_data_o       (rd_data),
        /********** 便笺式存储器接口 **********/
        .spm_rd_data_i   (spm_rd_data_i),
        .spm_addr_o      (spm_addr_o),
        .spm_as_n_o      (spm_as_n_o),
        .spm_rw_o        (spm_rw_o),
        .spm_wr_data_o   (spm_wr_data_o),
        /********** 总线接口 **********/
        .bus_rd_data_i   (bus_rd_data_i),
        .bus_rdy_n_i     (bus_rdy_n_i),
        .bus_grnt_n_i    (bus_grnt_n_i),
        .bus_req_n_o     (bus_req_n_o),
        .bus_addr_o      (bus_addr_o),
        .bus_as_n_o      (bus_as_n_o),
        .bus_rw_o        (bus_rw_o),
        .bus_wr_data_o   (bus_wr_data_o)
    );

    /********** MEM阶段流水线寄存器 **********/
    mem_reg u_mem_reg (
        .clk             (clk),
        .reset           (reset),
        /********** 内存访问结果 **********/
        .result_i        (result),
        .miss_align_i    (miss_align),
        /********** 流水线控制信号 **********/
        .stall_i         (stall_i),
        .flush_i         (flush_i),
        /********** EX/MEM流水线寄存器 **********/
        .ex_pc_i         (ex_pc_i),
        .ex_en_i         (ex_en_i),
        .ex_br_flag_i    (ex_br_flag_i),
        .ex_ctrl_op_i    (ex_ctrl_op_i),
        .ex_dst_addr_i   (ex_dst_addr_i),
        .ex_gpr_we_n_i   (ex_gpr_we_n_i),
        .ex_exp_code_i   (ex_exp_code_i),
        /********** MEM/WB流水线寄存器 **********/
        .mem_pc_o        (mem_pc_o),
        .mem_en_o        (mem_en_o),
        .mem_br_flag_o   (mem_br_flag_o),
        .mem_ctrl_op_o   (mem_ctrl_op_o),
        .mem_dst_addr_o  (mem_dst_addr_o),
        .mem_gpr_we_n_o  (mem_gpr_we_n_o),
        .mem_exp_code_o  (mem_exp_code_o),
        .mem_out_o       (mem_out_o)
    );

endmodule