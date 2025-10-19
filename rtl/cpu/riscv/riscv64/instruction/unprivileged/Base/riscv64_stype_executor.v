`include "riscv64_instruction_defs.v"

module riscv64_stype_executor #(
    parameter DATA_WIDTH = 64
)(
    input wire [63:0]           rs1_data_i,
    input wire [63:0]           imm_i,
    output reg [63:0]           alu_result_o
);

    // S-type指令主要用于存储操作，计算内存地址
    // 通常是 rs1 + imm 的形式
    always @(*) begin
        // 计算有效地址：rs1 + immediate
        alu_result_o = rs1_data_i + imm_i;

    `ifdef DEBUG
        $display("[%0t ps] S-type: rs1_data_i=%h + imm_i=%h = %h",
                 $time, rs1_data_i, imm_i, alu_result_o);
    `endif
    end

endmodule