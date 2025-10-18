`include "riscv64_instruction_defs.v"

module riscv64_branch_executor #(
    parameter DATA_WIDTH = 64
)(
    input wire [6:0]            opcode,        // 指令操作码
    input wire [2:0]            funct3,        // 功能码
    input wire [DATA_WIDTH-1:0] pc_in_i,       // 当前PC值
    input wire [DATA_WIDTH-1:0] rs1_data_i,    // 源寄存器1数据
    input wire [DATA_WIDTH-1:0] rs2_data_i,    // 源寄存器2数据
    input wire [DATA_WIDTH-1:0] imm_i,         // 立即数
    input wire [DATA_WIDTH-1:0] alu_result_i,  // ALU计算结果（用于JALR）
    output reg                  branch_taken_o,// 分支是否被执行
    output reg [DATA_WIDTH-1:0] branch_target_o// 分支目标地址
);

    always @(*)
    begin
        branch_taken_o = 1'b0;
        branch_target_o = pc_in_i + imm_i; // 默认目标地址是PC+立即数

        // 处理不同类型的跳转指令
        if (opcode == `OPCODE_BRANCH) begin // B-type分支指令
            case (funct3)
                `FUNCT3_BEQ:     branch_taken_o = (rs1_data_i == rs2_data_i); // BEQ
                `FUNCT3_BNE:     branch_taken_o = (rs1_data_i != rs2_data_i); // BNE
                `FUNCT3_BLT:     branch_taken_o = ($signed(rs1_data_i) < $signed(rs2_data_i)); // BLT
                `FUNCT3_BGE:     branch_taken_o = ($signed(rs1_data_i) >= $signed(rs2_data_i)); // BGE
                `FUNCT3_BLTU:    branch_taken_o = (rs1_data_i < rs2_data_i); // BLTU
                `FUNCT3_BGEU:    branch_taken_o = (rs1_data_i >= rs2_data_i); // BGEU
                default:         branch_taken_o = 1'b0;
            endcase
        `ifdef DEBUG
            $display("[Branch] Check: rs1=%h rs2=%h branch_taken=%b",
                     rs1_data_i, rs2_data_i, branch_taken_o);
        `endif
        end else if (opcode == `OPCODE_JAL) begin // JAL指令
            branch_taken_o = 1'b1; // JAL总是跳转
            branch_target_o = pc_in_i + imm_i;
        `ifdef DEBUG
            $display("[JAL] Instruction detected: branch_taken=%b, target=%h",
                     branch_taken_o, branch_target_o);
        `endif
        end else if (opcode == `OPCODE_JALR) begin // JALR指令
            branch_taken_o = 1'b1; // JALR总是跳转
            branch_target_o = {alu_result_i[63:1], 1'b0}; // 设置最低位为0
        `ifdef DEBUG
            $display("[JALR] Instruction detected: branch_taken=%b, target=%h",
                     branch_taken_o, branch_target_o);
        `endif
        end else begin
            branch_taken_o = 1'b0;
        end
    end

endmodule