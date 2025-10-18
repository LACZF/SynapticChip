`include "riscv64_instruction_defs.v"

module riscv64_rtype_executor #(
    parameter DATA_WIDTH = 64
)(
    input wire                  funct7_30,     // 用于区分 ADD/SUB, SRL/SRA 等指令
    input wire [2:0]            funct3,        // 功能码
    input wire [DATA_WIDTH-1:0] rs1_data_i,    // 源寄存器1数据
    input wire [DATA_WIDTH-1:0] rs2_data_i,    // 源寄存器2数据
    output reg [DATA_WIDTH-1:0] alu_result_o   // ALU计算结果
);

    always @(*)
    begin
        case (funct3)
            `FUNCT3_ADD_SUB: begin // ADD/SUB
                if (funct7_30) begin
                    alu_result_o = rs1_data_i - rs2_data_i; // SUB
                end else begin
                    alu_result_o = rs1_data_i + rs2_data_i; // ADD
                end
            `ifdef DEBUG
                $display("[R-type] ADD/SUB: rs1=%h %s rs2=%h = %h",
                         rs1_data_i, funct7_30 ? "-" : "+", rs2_data_i, alu_result_o);
            `endif
            end
            `FUNCT3_SLL: begin
                alu_result_o = rs1_data_i << rs2_data_i[5:0]; // SLL
            `ifdef DEBUG
                $display("[R-type] SLL: rs1=%h << %h = %h",
                         rs1_data_i, rs2_data_i[5:0], alu_result_o);
            `endif
            end
            `FUNCT3_SLT: begin
                alu_result_o = ($signed(rs1_data_i) < $signed(rs2_data_i)) ? 64'd1 : 64'd0; // SLT
            `ifdef DEBUG
                $display("[R-type] SLT: rs1=%h < rs2=%h = %h",
                         rs1_data_i, rs2_data_i, alu_result_o);
            `endif
            end
            `FUNCT3_SLTU: begin
                alu_result_o = (rs1_data_i < rs2_data_i) ? 64'd1 : 64'd0; // SLTU
            `ifdef DEBUG
                $display("[R-type] SLTU: rs1=%h < rs2=%h = %h",
                         rs1_data_i, rs2_data_i, alu_result_o);
            `endif
            end
            `FUNCT3_XOR: begin
                alu_result_o = rs1_data_i ^ rs2_data_i; // XOR
            `ifdef DEBUG
                $display("[R-type] XOR: rs1=%h ^ rs2=%h = %h",
                         rs1_data_i, rs2_data_i, alu_result_o);
            `endif
            end
            `FUNCT3_SRL_SRA: begin // SRL/SRA
                if (funct7_30) begin
                    alu_result_o = $signed(rs1_data_i) >>> rs2_data_i[5:0]; // SRA
                end else begin
                    alu_result_o = rs1_data_i >> rs2_data_i[5:0]; // SRL
                end
            `ifdef DEBUG
                $display("[R-type] SRL/SRA: rs1=%h %s %h = %h",
                         rs1_data_i, funct7_30 ? ">>>" : ">>", rs2_data_i[5:0], alu_result_o);
            `endif
            end
            `FUNCT3_OR: begin
                alu_result_o = rs1_data_i | rs2_data_i; // OR
            `ifdef DEBUG
                $display("[R-type] OR: rs1=%h | rs2=%h = %h",
                         rs1_data_i, rs2_data_i, alu_result_o);
            `endif
            end
            `FUNCT3_AND: begin
                alu_result_o = rs1_data_i & rs2_data_i; // AND
            `ifdef DEBUG
                $display("[R-type] AND: rs1=%h & rs2=%h = %h",
                         rs1_data_i, rs2_data_i, alu_result_o);
            `endif
            end
            default: begin
                alu_result_o = 64'b0;
            `ifdef DEBUG
                $display("[R-type] unknown funct3=%b, result=0", funct3);
            `endif
            end
        endcase
    end

endmodule