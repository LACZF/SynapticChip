
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module ex_reg (
    input  wire                  clk,
    input  wire                  reset,

    /********** ALU的输出 **********/
    input  wire [`WordDataBus]   alu_out_i,           // 运算结果
    input  wire                  alu_of_i,            // 溢出
    /********** 流水线控制信号 **********/
    input  wire                  stall_i,             // 延迟
    input  wire                  flush_i,             // 刷新
    input  wire                  int_detect_i,        // 中断检测
    /********** ID/EX流水线寄存器 **********/
    input  wire [`WordAddrBus]   id_pc_i,             // 程序计数器
    input  wire [`WordDataBus]   id_insn_i,
    input  wire                  id_en_i,             // 流水线的数据是否有效
    input  wire                  id_br_flag_i,        // 分支标志位
    input  wire [`MemOpBus]      id_mem_op_i,         // 内存操作
    input  wire [`WordDataBus]   id_mem_wr_data_i,    // 内存写入数据
    input  wire [`CtrlOpBus]     id_ctrl_op_i,        // 控制寄存器操作
    input  wire [`RegAddrBus]    id_dst_addr_i,       // 通用寄存器写入地址
    input  wire                  id_gpr_we_n_i,       // 通用寄存器写入有效
    input  wire [`IsaExpBus]     id_exp_code_i,       // 异常代码
    /********** EX/MEM流水线寄存器 **********/
    output reg  [`WordAddrBus]   ex_pc_o,             // 程序计数器
    output reg  [`WordDataBus]   ex_insn_o,
    output reg                   ex_en_o,             // 流水线的数据是否有效
    output reg                   ex_br_flag_o,        // 分支标志位
    output reg  [`MemOpBus]      ex_mem_op_o,         // 内存操作
    output reg  [`WordDataBus]   ex_mem_wr_data_o,    // 内存写入数据
    output reg  [`CtrlOpBus]     ex_ctrl_op_o,        // 控制寄存器操作
    output reg  [`RegAddrBus]    ex_dst_addr_o,       // 通用寄存器写入地址
    output reg                   ex_gpr_we_n_o,       // 通用寄存器写入有效
    output reg  [`IsaExpBus]     ex_exp_code_o,       // 异常代码
    output reg  [`WordDataBus]   ex_out_o             // 处理结果
);

    /********** 流水线寄存器 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        /* 异步复位 */
        if (reset == `RESET_ENABLE) begin
            ex_pc_o             <= `WORD_ADDR_W'h0;
            ex_insn_o           <= `ISA_NOP;
            ex_en_o             <= `DISABLE;
            ex_br_flag_o        <= `DISABLE;
            ex_mem_op_o         <= `MEM_OP_NOP;
            ex_mem_wr_data_o    <= `WORD_DATA_W'h0;
            ex_ctrl_op_o        <= `CTRL_OP_NOP;
            ex_dst_addr_o       <= `REG_ADDR_W'd0;
            ex_gpr_we_n_o       <= `DISABLE_N;
            ex_exp_code_o       <= `ISA_EXP_NO_EXP;
            ex_out_o            <= `WORD_DATA_W'h0;
        end else begin
            /* 流水线寄存器的更新 */
            if (stall_i == `DISABLE) begin
                if (flush_i == `ENABLE) begin          // 刷新
                    ex_pc_o           <= `WORD_ADDR_W'h0;
                    ex_insn_o         <= `ISA_NOP;
                    ex_en_o           <= `DISABLE;
                    ex_br_flag_o      <= `DISABLE;
                    ex_mem_op_o       <= `MEM_OP_NOP;
                    ex_mem_wr_data_o  <= `WORD_DATA_W'h0;
                    ex_ctrl_op_o      <= `CTRL_OP_NOP;
                    ex_dst_addr_o     <= `REG_ADDR_W'd0;
                    ex_gpr_we_n_o     <= `DISABLE_N;
                    ex_exp_code_o     <= `ISA_EXP_NO_EXP;
                    ex_out_o          <= `WORD_DATA_W'h0;
                end else if (int_detect_i == `ENABLE) begin // 中断检测
                    ex_pc_o           <= id_pc_i;
                    ex_insn_o         <= id_insn_i;
                    ex_en_o           <= id_en_i;
                    ex_br_flag_o      <= id_br_flag_i;
                    ex_mem_op_o       <= `MEM_OP_NOP;
                    ex_mem_wr_data_o  <= `WORD_DATA_W'h0;
                    ex_ctrl_op_o      <= `CTRL_OP_NOP;
                    ex_dst_addr_o     <= `REG_ADDR_W'd0;
                    ex_gpr_we_n_o     <= `DISABLE_N;
                    ex_exp_code_o     <= `ISA_EXP_EXT_INT;
                    ex_out_o          <= `WORD_DATA_W'h0;
                end else if (alu_of_i == `ENABLE) begin      // 算术溢出
                    ex_pc_o           <= id_pc_i;
                    ex_insn_o         <= id_insn_i;
                    ex_en_o           <= id_en_i;
                    ex_br_flag_o      <= id_br_flag_i;
                    ex_mem_op_o       <= `MEM_OP_NOP;
                    ex_mem_wr_data_o  <= `WORD_DATA_W'h0;
                    ex_ctrl_op_o      <= `CTRL_OP_NOP;
                    ex_dst_addr_o     <= `REG_ADDR_W'd0;
                    ex_gpr_we_n_o     <= `DISABLE_N;
                    ex_exp_code_o     <= `ISA_EXP_OVERFLOW;
                    ex_out_o          <= `WORD_DATA_W'h0;
                end else begin               // 下一个数据
                    ex_pc_o           <= id_pc_i;
                    ex_insn_o         <= id_insn_i;
                    ex_en_o           <= id_en_i;
                    ex_br_flag_o      <= id_br_flag_i;
                    ex_mem_op_o       <= id_mem_op_i;
                    ex_mem_wr_data_o  <= id_mem_wr_data_i;
                    ex_ctrl_op_o      <= id_ctrl_op_i;
                    ex_dst_addr_o     <= id_dst_addr_i;
                    ex_gpr_we_n_o     <= id_gpr_we_n_i;
                    ex_exp_code_o     <= id_exp_code_i;
                    ex_out_o          <= alu_out_i;
                end
            end
        end
    end

endmodule