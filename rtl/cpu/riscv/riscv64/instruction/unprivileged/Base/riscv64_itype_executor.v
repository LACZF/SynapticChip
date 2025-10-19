`include "riscv64_instruction_defs.v"

module riscv64_itype_executor #(
    parameter DATA_WIDTH = 64
)(
    input wire [2:0]            alu_op,        // ALU操作类型
    input wire [DATA_WIDTH-1:0] rs1_data_i,    // 源寄存器1数据
    input wire [DATA_WIDTH-1:0] imm_i,         // 立即数
    output reg [DATA_WIDTH-1:0] alu_result_o   // ALU计算结果
);

    always @(*)
    begin
        case (alu_op)
            `ALU_OP_ADD: begin
                alu_result_o = rs1_data_i + imm_i; // ADD
            `ifdef DEBUG
                $display("[I-type] ADD: rs1=%h + imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_SUB: begin
                alu_result_o = rs1_data_i - imm_i; // SUB
            `ifdef DEBUG
                $display("[I-type] SUB: rs1=%h - imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_AND: begin
                alu_result_o = rs1_data_i & imm_i; // AND
            `ifdef DEBUG
                $display("[I-type] AND: rs1=%h & imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_OR: begin
                alu_result_o = rs1_data_i | imm_i; // OR
            `ifdef DEBUG
                $display("[I-type] OR: rs1=%h | imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_XOR: begin
                alu_result_o = rs1_data_i ^ imm_i; // XOR
            `ifdef DEBUG
                $display("[I-type] XOR: rs1=%h ^ imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_SLT: begin
                alu_result_o = ($signed(rs1_data_i) < $signed(imm_i)) ? 64'd1 : 64'd0; // SLT
            `ifdef DEBUG
                $display("[I-type] SLT: rs1=%h < imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_SLTU: begin
                alu_result_o = (rs1_data_i < imm_i) ? 64'd1 : 64'd0; // SLTU
            `ifdef DEBUG
                $display("[I-type] SLTU: rs1=%h < imm=%h = %h",
                         rs1_data_i, imm_i, alu_result_o);
            `endif
            end
            `ALU_OP_SLL: begin
                alu_result_o = imm_i << rs1_data_i[5:0]; // SLL
            `ifdef DEBUG
                $display("[I-type] SLL: imm=%h << %h = %h",
                         imm_i, rs1_data_i[5:0], alu_result_o);
            `endif
            end
            default: begin
                alu_result_o = 64'b0;
            `ifdef DEBUG
                $display("[I-type] unknown alu_op=%b, result=0", alu_op);
            `endif
            end
        endcase
    end

endmodule