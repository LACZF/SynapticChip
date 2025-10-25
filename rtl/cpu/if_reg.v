
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"

module if_reg (
    input  wire                  clk,
    input  wire                  reset,
    /********** 读取数据 **********/
    input  wire [`WordDataBus]   insn_i,
    /********** 流水线控制信号 **********/
    input  wire                  stall_i,
    input  wire                  flush_i,
    input  wire [`WordAddrBus]   new_pc_i,
    input  wire                  br_taken_i,
    input  wire [`WordAddrBus]   br_addr_i,
    /********** IF/ID流水线寄存器 **********/
    output reg    [`WordAddrBus] if_pc_o,
    output reg    [`WordDataBus] if_insn_o,
    output reg                   if_en_o
);

    /********** 流水线寄存器 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            if_pc_o      <= `RESET_VECTOR;
            if_insn_o    <= `ISA_NOP;
            if_en_o      <= `DISABLE;
        end else begin
            /* 更新流水线寄存器 */
            if (stall_i == `DISABLE) begin
                if (flush_i == `ENABLE) begin
                    if_pc_o      <= new_pc_i;
                    if_insn_o    <= `ISA_NOP;
                    if_en_o      <= `DISABLE;
                end else if (br_taken_i == `ENABLE) begin
                    if_pc_o      <= br_addr_i;
                    if_insn_o    <= insn_i;
                    /*
                     * 当分支条件成立时，下一条指令不应该被执行，而应该跳转到分支跳转后的指令执行，
                     * 下一个cycle到来时时下一条指令，而不是分支跳转后的指令，所有需要暂停一个cycle，
                     * 等待正确的指令到来。
                     */
                    if_en_o      <= `DISABLE;
                end else begin
                    if_pc_o      <= if_pc_o + 1'd1;
                    if_insn_o    <= insn_i;
                    if_en_o      <= `ENABLE;
                end
            end
        end
    end
endmodule