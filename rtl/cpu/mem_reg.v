
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module mem_reg (
    input  wire                       clk,
    input  wire                       reset,

    /********** 内存访问结果 **********/
    input  wire [`WordDataBus]        result_i,                // 结果
    input  wire                       miss_align_i,            // 未对齐
    /********** 流水线控制信号 **********/
    input  wire                       stall_i,                 // 延迟
    input  wire                       flush_i,                 // 刷新
    /********** EX/MEM流水线寄存器 **********/
    input  wire [`WordAddrBus]        ex_pc_i,                 // 程序计数器
    input  wire [`WordDataBus]        ex_insn_i,
    input  wire                       ex_en_i,                 // 流水线数据是否有效
    input  wire                       ex_br_flag_i,            // 分支标志位
    input  wire [`CtrlOpBus]          ex_ctrl_op_i,            // 控制寄存器操作
    input  wire [`RegAddrBus]         ex_dst_addr_i,           // 通用寄存器写入地址
    input  wire                       ex_gpr_we_n_i,           // 通用寄存器写入有效
    input  wire [`IsaExpBus]          ex_exp_code_i,           // 异常代码
    /********** MEM/WB流水线寄存器 **********/
    output reg  [`WordAddrBus]        mem_pc_o,                // 程序计数器
    output reg  [`WordDataBus]        mem_insn_o,
    output reg                        mem_en_o,               // 流水线数据是否有效
    output reg                        mem_br_flag_o,          // 分支标志位
    output reg  [`CtrlOpBus]          mem_ctrl_op_o,          // 控制寄存器操作
    output reg  [`RegAddrBus]         mem_dst_addr_o,         // 通用寄存器写入地址
    output reg                        mem_gpr_we_n_o,         // 通用寄存器写入有效
    output reg  [`IsaExpBus]          mem_exp_code_o,         // 异常代码
    output reg  [`WordDataBus]        mem_out_o               // 处理结果
);

    /********** 流水线寄存器 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            mem_pc_o          <= `WORD_ADDR_W'h0;
            mem_insn_o        <= `ISA_NOP;
            mem_en_o          <= `DISABLE;
            mem_br_flag_o     <= `DISABLE;
            mem_ctrl_op_o     <= `CTRL_OP_NOP;
            mem_dst_addr_o    <= `REG_ADDR_W'h0;
            mem_gpr_we_n_o    <= `DISABLE_N;
            mem_exp_code_o    <= `ISA_EXP_NO_EXP;
            mem_out_o         <= `WORD_DATA_W'h0;
        end else begin
            if (stall_i == `DISABLE) begin
                /* 流水线寄存器的更新 */
                if (flush_i == `ENABLE) begin              // 刷新
                    mem_pc_o          <= `WORD_ADDR_W'h0;
                    mem_insn_o        <= `ISA_NOP;
                    mem_en_o          <= `DISABLE;
                    mem_br_flag_o     <= `DISABLE;
                    mem_ctrl_op_o     <= `CTRL_OP_NOP;
                    mem_dst_addr_o    <= `REG_ADDR_W'h0;
                    mem_gpr_we_n_o    <= `DISABLE_N;
                    mem_exp_code_o    <= `ISA_EXP_NO_EXP;
                    mem_out_o         <= `WORD_DATA_W'h0;
                end else if (miss_align_i == `ENABLE) begin // 未对齐异常
                    mem_pc_o          <= ex_pc_i;
                    mem_insn_o        <= ex_insn_i;
                    mem_en_o          <= ex_en_i;
                    mem_br_flag_o     <= ex_br_flag_i;
                    mem_ctrl_op_o     <= `CTRL_OP_NOP;
                    mem_dst_addr_o    <= `REG_ADDR_W'h0;
                    mem_gpr_we_n_o    <= `DISABLE_N;
                    mem_exp_code_o    <= `ISA_EXP_MISS_ALIGN;
                    mem_out_o         <= `WORD_DATA_W'h0;
                end else begin                  // 下一个数据
                    mem_pc_o          <= ex_pc_i;
                    mem_insn_o        <= ex_insn_i;
                    mem_en_o          <= ex_en_i;
                    mem_br_flag_o     <= ex_br_flag_i;
                    mem_ctrl_op_o     <= ex_ctrl_op_i;
                    mem_dst_addr_o    <= ex_dst_addr_i;
                    mem_gpr_we_n_o    <= ex_gpr_we_n_i;
                    mem_exp_code_o    <= ex_exp_code_i;
                    mem_out_o         <= result_i;
                end
            end
        end
    end

endmodule