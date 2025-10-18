`include "riscv64_instruction_defs.v"

module riscv64_utype_executor #(
    parameter DATA_WIDTH = 64
)(
    input wire [6:0]            opcode,        // 指令操作码
    input wire [DATA_WIDTH-1:0] pc_in_i,       // 当前PC值
    input wire [DATA_WIDTH-1:0] imm_i,         // 立即数
    output reg [DATA_WIDTH-1:0] alu_result_o   // ALU计算结果
);

    always @(*)
    begin
        case (opcode)
            `OPCODE_LUI: begin
                // LUI指令：将立即数左移12位作为结果
                alu_result_o = {imm_i[31:12], 12'b0};
            `ifdef DEBUG
                $display("[U-type] LUI: imm=%h -> %h",
                         imm_i, alu_result_o);
            `endif
            end
            `OPCODE_AUIPC: begin
                // AUIPC指令：将立即数左移12位后与PC相加
                alu_result_o = pc_in_i + {imm_i[31:12], 12'b0};
            `ifdef DEBUG
                $display("[U-type] AUIPC: pc=%h + imm=%h -> %h",
                         pc_in_i, imm_i, alu_result_o);
            `endif
            end
            default: begin
                alu_result_o = 64'b0;
            `ifdef DEBUG
                $display("[U-type] unknown opcode=%b, result=0", opcode);
            `endif
            end
        endcase
    end

endmodule