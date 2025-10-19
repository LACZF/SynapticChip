`include "riscv64_instruction_defs.v"

module riscv64_i_extension #(
    parameter DATA_WIDTH = 64
)(
    input wire                  funct7_30,
    input wire [2:0]            funct3,
    input wire [6:0]            opcode,
    input wire [DATA_WIDTH-1:0] rs1_data_i,
    input wire [DATA_WIDTH-1:0] rs2_data_i,
    input wire [DATA_WIDTH-1:0] imm_i,
    input wire [DATA_WIDTH-1:0] pc_in_i,
    input wire [2:0]            alu_op,
    output wire [DATA_WIDTH-1:0] alu_result_o,
    output wire                 branch_taken_o,
    output wire [DATA_WIDTH-1:0] branch_target_o,
    output wire                 is_i_extension
);

    // 信号定义
    wire [DATA_WIDTH-1:0] rtype_result;
    wire [DATA_WIDTH-1:0] itype_result;
    wire [DATA_WIDTH-1:0] utype_result;
    wire [DATA_WIDTH-1:0] stype_result;
    wire [DATA_WIDTH-1:0] branch_result;
    reg                   branch_taken;
    reg  [DATA_WIDTH-1:0] branch_target;

    // 判断是否为I扩展指令
    assign is_i_extension = (
        (opcode == `OPCODE_REG_ARITH) ||
        (opcode == `OPCODE_IMM_ARITH) ||
        (opcode == `OPCODE_LUI) ||
        (opcode == `OPCODE_AUIPC) ||
        (opcode == `OPCODE_LOAD) ||
        (opcode == `OPCODE_STORE) ||
        (opcode == `OPCODE_BRANCH) ||
        (opcode == `OPCODE_JAL) ||
        (opcode == `OPCODE_JALR)
    );

    // R-type 指令处理
    function [DATA_WIDTH-1:0] handle_rtype;
        input [2:0] funct3;
        input funct7_30;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] rs2;
        begin
        `ifdef DEBUG
            $display("[I-Extension] handle_rtype: funct3=%b, funct7_30=%b, rs1=%h, rs2=%h", funct3, funct7_30, rs1, rs2);
        `endif

            case (funct3)
                `FUNCT3_ADD_SUB: handle_rtype = (funct7_30) ? (rs1 - rs2) : (rs1 + rs2);
                `FUNCT3_SLL:     handle_rtype = rs1 << rs2[5:0];
                `FUNCT3_SLT:     handle_rtype = ($signed(rs1) < $signed(rs2)) ? 64'd1 : 64'd0;
                `FUNCT3_SLTU:    handle_rtype = (rs1 < rs2) ? 64'd1 : 64'd0;
                `FUNCT3_XOR:     handle_rtype = rs1 ^ rs2;
                `FUNCT3_SRL_SRA: begin
                    if (funct7_30) begin
                        handle_rtype = $signed(rs1) >>> rs2[5:0];
                    end else begin
                        handle_rtype = rs1 >> rs2[5:0];
                    end
                end
                `FUNCT3_OR:      handle_rtype = rs1 | rs2;
                `FUNCT3_AND:     handle_rtype = rs1 & rs2;
                default:         handle_rtype = 64'b0;
            endcase

        `ifdef DEBUG
            $display("[I-Extension] handle_rtype result: %h", handle_rtype);
        `endif
        end
    endfunction

    // I-type 指令处理
    function [DATA_WIDTH-1:0] handle_itype;
        input [2:0] alu_op;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] imm;
        begin
        `ifdef DEBUG
            $display("[I-Extension] handle_itype: alu_op=%b, rs1=%h, imm=%h", alu_op, rs1, imm);
        `endif
            case (alu_op)
                `ALU_OP_ADD:  handle_itype = rs1 + imm;
                `ALU_OP_SUB:  handle_itype = rs1 - imm;
                `ALU_OP_AND:  handle_itype = rs1 & imm;
                `ALU_OP_OR:   handle_itype = rs1 | imm;
                `ALU_OP_XOR:  handle_itype = rs1 ^ imm;
                `ALU_OP_SLT:  handle_itype = ($signed(rs1) < $signed(imm)) ? 64'd1 : 64'd0;
                `ALU_OP_SLTU: handle_itype = (rs1 < imm) ? 64'd1 : 64'd0;
                `ALU_OP_SLL:  handle_itype = rs1 << imm[5:0];
                default:      handle_itype = 64'b0;
            endcase
        `ifdef DEBUG
            $display("[I-Extension] handle_itype result: %h", handle_itype);
        `endif
        end
    endfunction

    // U-type 指令处理
    function [DATA_WIDTH-1:0] handle_utype;
        input [6:0] opcode;
        input [DATA_WIDTH-1:0] pc;
        input [DATA_WIDTH-1:0] imm;
        begin
            case (opcode)
                `OPCODE_LUI: handle_utype = {imm[31:12], 12'b0};
                `OPCODE_AUIPC: handle_utype = pc + {imm[31:12], 12'b0};
                default: handle_utype = 64'b0;
            endcase
        end
    endfunction

    // S-type 指令处理（地址计算）
    function [DATA_WIDTH-1:0] handle_stype;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] imm;
        begin
            handle_stype = rs1 + imm;
        end
    endfunction



    // 执行对应类型的指令
    assign rtype_result = (opcode == `OPCODE_REG_ARITH) ? handle_rtype(funct3, funct7_30, rs1_data_i, rs2_data_i) : 64'b0;
    assign itype_result = (opcode == `OPCODE_IMM_ARITH || opcode == `OPCODE_LOAD) ? handle_itype(alu_op, rs1_data_i, imm_i) : 64'b0;
    assign utype_result = (opcode == `OPCODE_LUI || opcode == `OPCODE_AUIPC) ? handle_utype(opcode, pc_in_i, imm_i) : 64'b0;
    assign stype_result = (opcode == `OPCODE_STORE) ? handle_stype(rs1_data_i, imm_i) : 64'b0;

    // 用于JALR指令计算的中间变量
    reg [DATA_WIDTH-1:0] sum;

    // 处理分支指令
    always @(*) begin
        branch_taken = 1'b0;
        branch_target = pc_in_i + imm_i;

        if (opcode == `OPCODE_BRANCH) begin
            case (funct3)
                `FUNCT3_BEQ:  branch_taken = (rs1_data_i == rs2_data_i);
                `FUNCT3_BNE:  branch_taken = (rs1_data_i != rs2_data_i);
                `FUNCT3_BLT:  branch_taken = ($signed(rs1_data_i) < $signed(rs2_data_i));
                `FUNCT3_BGE:  branch_taken = ($signed(rs1_data_i) >= $signed(rs2_data_i));
                `FUNCT3_BLTU: branch_taken = (rs1_data_i < rs2_data_i);
                `FUNCT3_BGEU: branch_taken = (rs1_data_i >= rs2_data_i);
                default:      branch_taken = 1'b0;
            endcase
        end else if (opcode == `OPCODE_JAL) begin
            branch_taken = 1'b1;
        end else if (opcode == `OPCODE_JALR) begin
            branch_taken = 1'b1;
            // JALR指令的目标地址计算：rs1 + imm
            sum = rs1_data_i + imm_i;
            branch_target = sum;
        end else begin
            branch_taken = 1'b0;
        end
    end

    // 选择最终的ALU结果
    assign alu_result_o = (
        (opcode == `OPCODE_REG_ARITH) ? rtype_result :
        (opcode == `OPCODE_IMM_ARITH || opcode == `OPCODE_LOAD) ? itype_result :
        (opcode == `OPCODE_STORE) ? stype_result :
        (opcode == `OPCODE_LUI || opcode == `OPCODE_AUIPC) ? utype_result :
        // 对于JALR指令，ALU结果是PC+4（返回地址）
        (opcode == `OPCODE_JALR) ? (pc_in_i + 64'd4) :
        64'b0
    );

    // 输出分支结果
    assign branch_taken_o = branch_taken;
    assign branch_target_o = branch_target;

`ifdef DEBUG
    always @(*) begin
        if (is_i_extension) begin
            $display("[I-Extension] Handling instruction: PC=%h, Opcode=%h", pc_in_i, opcode);
            $display("[I-Extension] ALU Result: %h", alu_result_o);
            if (opcode == `OPCODE_BRANCH || opcode == `OPCODE_JAL || opcode == `OPCODE_JALR) begin
                $display("[I-Extension] Branch: taken=%b, target=%h", branch_taken, branch_target);
            end
        end
    end
`endif

endmodule