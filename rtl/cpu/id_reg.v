
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module id_reg (
    input  wire                   clk,
    input  wire                   reset,
    /********** 解码结果 **********/
    input  wire [`AluOpBus]       alu_op_i,
    input  wire [`WordDataBus]    alu_in_0_i,
    input  wire [`WordDataBus]    alu_in_1_i,
    input  wire                   br_flag_i,
    input  wire [`MemOpBus]       mem_op_i,
    input  wire [`WordDataBus]    mem_wr_data_i,
    input  wire [`CtrlOpBus]      ctrl_op_i,
    input  wire [`RegAddrBus]     dst_addr_i,
    input  wire                   gpr_we_n_i,
    input  wire [`IsaExpBus]      exp_code_i,
    /********** 流水线控制信号 **********/
    input  wire                   stall_i,
    input  wire                   flush_i,
    /********** IF/ID流水线寄存器 **********/
    input  wire [`WordAddrBus]    if_pc_i,
    input  wire                   if_en_i,
    /********** ID/EX流水线寄存器 **********/
    output reg    [`WordAddrBus]  id_pc_o,
    output reg                    id_en_o,
    output reg    [`AluOpBus]     id_alu_op_o,
    output reg    [`WordDataBus]  id_alu_in_0_o,
    output reg    [`WordDataBus]  id_alu_in_1_o,
    output reg                    id_br_flag_o,
    output reg    [`MemOpBus]     id_mem_op_o,
    output reg    [`WordDataBus]  id_mem_wr_data_o,
    output reg    [`CtrlOpBus]    id_ctrl_op_o,
    output reg    [`RegAddrBus]   id_dst_addr_o,
    output reg                    id_gpr_we_n_o,
    output reg [`IsaExpBus]       id_exp_code_o
);

    /********** 流水线寄存器 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            id_pc_o             <= `WORD_ADDR_W'h0;
            id_en_o             <= `DISABLE;
            id_alu_op_o         <= `ALU_OP_NOP;
            id_alu_in_0_o       <= `WORD_DATA_W'h0;
            id_alu_in_1_o       <= `WORD_DATA_W'h0;
            id_br_flag_o        <= `DISABLE;
            id_mem_op_o         <= `MEM_OP_NOP;
            id_mem_wr_data_o    <= `WORD_DATA_W'h0;
            id_ctrl_op_o        <= `CTRL_OP_NOP;
            id_dst_addr_o       <= `REG_ADDR_W'd0;
            id_gpr_we_n_o       <= `DISABLE_N;
            id_exp_code_o       <= `ISA_EXP_NO_EXP;
        end else begin
            /* 流水线寄存器的更新 */
            if (stall_i == `DISABLE) begin
                if (flush_i == `ENABLE) begin // 刷新
                    id_pc_o            <= `WORD_ADDR_W'h0;
                    id_en_o            <= `DISABLE;
                    id_alu_op_o        <= `ALU_OP_NOP;
                    id_alu_in_0_o      <= `WORD_DATA_W'h0;
                    id_alu_in_1_o      <= `WORD_DATA_W'h0;
                    id_br_flag_o       <= `DISABLE;
                    id_mem_op_o        <= `MEM_OP_NOP;
                    id_mem_wr_data_o   <= `WORD_DATA_W'h0;
                    id_ctrl_op_o       <= `CTRL_OP_NOP;
                    id_dst_addr_o      <= `REG_ADDR_W'd0;
                    id_gpr_we_n_o      <= `DISABLE_N;
                    id_exp_code_o      <= `ISA_EXP_NO_EXP;
                end else begin            // 下一个数据
                    if (if_en_i == 1'b0) begin
                        id_br_flag_o   <= 1'b0;
                    end else begin
                        id_br_flag_o   <= br_flag_i;
                    end
                    id_pc_o            <= if_pc_i;
                    id_en_o            <= if_en_i;
                    id_alu_op_o        <= alu_op_i;
                    id_alu_in_0_o      <= alu_in_0_i;
                    id_alu_in_1_o      <= alu_in_1_i;
                    id_mem_op_o        <= mem_op_i;
                    id_mem_wr_data_o   <= mem_wr_data_i;
                    id_ctrl_op_o       <= ctrl_op_i;
                    id_dst_addr_o      <= dst_addr_i;
                    id_gpr_we_n_o      <= gpr_we_n_i;
                    id_exp_code_o      <= exp_code_i;
                end
            end
        end
    end

endmodule