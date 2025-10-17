// riscv64_execution.v
`include "riscv64_instruction_defs.v"

module riscv64_execution #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire                  stall_i,
    input wire                  flush_i,
    input wire [63:0]           pc_in_i,
    input wire [31:0]           instr_in_i,
    input wire [63:0]           rs1_data_i,
    input wire [63:0]           rs2_data_i,
    input wire [63:0]           imm_i,
    input wire [15:0]           ctrl_in_i,
    output reg [63:0]           pc_out_o,
    output reg [31:0]           instr_out_o,
    output reg [63:0]           alu_result_o,
    output reg                  branch_taken_o,
    output reg [63:0]           branch_target_o,
    output reg [15:0]           ctrl_out_o
);

    wire [2:0]  alu_op      = ctrl_in_i[14:12];
    wire        alu_src     = ctrl_in_i[11];
    wire        reg_op      = ctrl_in_i[15]; // 标识是否为寄存器算术指令
    wire [2:0]  funct3      = instr_in_i[14:12];
    wire        funct7_30   = instr_in_i[30]; // 用于区分 ADD/SUB, SRL/SRA 等指令
    wire [63:0] alu_src2    = alu_src ? imm_i : rs2_data_i;
    wire [6:0]  opcode      = instr_in_i[6:0]; // 提取指令的opcode字段，便于统一使用

    // 中间变量，用于调试
    reg [63:0] alu_result_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h0000_0013;
            alu_result_o <= 64'b0;
            branch_taken_o <= 1'b0;
            branch_target_o <= 64'b0;
            ctrl_out_o <= 16'b0;
            alu_result_temp <= 64'b0;
        end else if (flush_i) begin
            instr_out_o <= 32'h0000_0013;
            branch_taken_o <= 1'b0;
            ctrl_out_o <= 16'b0;
        end else if (!stall_i) begin
            pc_out_o <= pc_in_i;
            instr_out_o <= instr_in_i;
            ctrl_out_o <= ctrl_in_i;

        `ifdef DEBUG
            // 添加更详细的调试信息
            $display("[%0t ps] EX: PC=%h, Instr=%h, Opcode=%h", $time, pc_in_i, instr_in_i, opcode);
            $display("[%0t ps] EX: rs1_data_i=%h, rs2_data_i=%h, imm_i=%h", $time, rs1_data_i, rs2_data_i, imm_i);
            $display("[%0t ps] EX: reg_op=%b, alu_op=%b, alu_src=%b, alu_src2=%h", $time, reg_op, alu_op, alu_src, alu_src2);
            $display("[%0t ps] EX: funct3=%b, funct7_30=%b", $time, funct3, funct7_30);
        `endif
            // ALU operations
            if (reg_op) begin // 寄存器算术指令，根据 funct3 和 funct7_30 选择操作
                case (funct3)
                    `FUNCT3_ADD_SUB: begin // ADD/SUB
                        if (funct7_30) begin
                            alu_result_temp = rs1_data_i - rs2_data_i; // SUB
                        end else begin
                            alu_result_temp = rs1_data_i + rs2_data_i; // ADD
                        end
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type ADD/SUB: rs1=%h %s rs2=%h = %h",
                                 $time, rs1_data_i, funct7_30 ? "-" : "+", rs2_data_i, alu_result_temp);
                    `endif
                    end
                    `FUNCT3_SLL: begin
                        alu_result_temp = rs1_data_i << rs2_data_i[5:0]; // SLL
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type SLL: rs1=%h << %h = %h",
                                 $time, rs1_data_i, rs2_data_i[5:0], alu_result_temp);
                    `endif
                    end
                    `FUNCT3_SLT: begin
                        alu_result_temp = ($signed(rs1_data_i) < $signed(rs2_data_i)) ? 64'd1 : 64'd0; // SLT
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type SLT: rs1=%h < rs2=%h = %h",
                                 $time, rs1_data_i, rs2_data_i, alu_result_temp);
                    `endif
                    end
                    `FUNCT3_SLTU: begin
                        alu_result_temp = (rs1_data_i < rs2_data_i) ? 64'd1 : 64'd0; // SLTU
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type SLTU: rs1=%h < rs2=%h = %h",
                                 $time, rs1_data_i, rs2_data_i, alu_result_temp);
                    `endif
                    end
                    `FUNCT3_XOR: begin
                        alu_result_temp = rs1_data_i ^ rs2_data_i; // XOR
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type XOR: rs1=%h ^ rs2=%h = %h",
                                 $time, rs1_data_i, rs2_data_i, alu_result_temp);
                    `endif
                    end
                    `FUNCT3_SRL_SRA: begin // SRL/SRA
                        if (funct7_30) begin
                            alu_result_temp = $signed(rs1_data_i) >>> rs2_data_i[5:0]; // SRA
                        end else begin
                            alu_result_temp = rs1_data_i >> rs2_data_i[5:0]; // SRL
                        end
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type SRL/SRA: rs1=%h %s %h = %h",
                                 $time, rs1_data_i, funct7_30 ? ">>>" : ">>", rs2_data_i[5:0], alu_result_temp);
                    `endif
                    end
                    `FUNCT3_OR: begin
                        alu_result_temp = rs1_data_i | rs2_data_i; // OR
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type OR: rs1=%h | rs2=%h = %h",
                                 $time, rs1_data_i, rs2_data_i, alu_result_temp);
                    `endif
                    end
                    `FUNCT3_AND: begin
                        alu_result_temp = rs1_data_i & rs2_data_i; // AND
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type AND: rs1=%h & rs2=%h = %h",
                                 $time, rs1_data_i, rs2_data_i, alu_result_temp);
                    `endif
                    end
                    default: begin
                        alu_result_temp = 64'b0;
                    `ifdef DEBUG
                        $display("[%0t ps] EX: R-type unknown funct3=%b, result=0", $time, funct3);
                    `endif
                    end
                endcase
            end else begin // 其他指令，根据 alu_op 选择操作
                case (alu_op)
                    `ALU_OP_ADD: begin
                        alu_result_temp = rs1_data_i + alu_src2; // ADD
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type ADD: rs1=%h + alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_SUB: begin
                        alu_result_temp = rs1_data_i - alu_src2; // SUB
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type SUB: rs1=%h - alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_AND: begin
                        alu_result_temp = rs1_data_i & alu_src2; // AND
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type AND: rs1=%h & alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_OR: begin
                        alu_result_temp = rs1_data_i | alu_src2; // OR
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type OR: rs1=%h | alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_XOR: begin
                        alu_result_temp = rs1_data_i ^ alu_src2; // XOR
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type XOR: rs1=%h ^ alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_SLT: begin
                        alu_result_temp = ($signed(rs1_data_i) < $signed(alu_src2)) ? 64'd1 : 64'd0; // SLT
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type SLT: rs1=%h < alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_SLTU: begin
                        alu_result_temp = (rs1_data_i < alu_src2) ? 64'd1 : 64'd0; // SLTU
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type SLTU: rs1=%h < alu_src2=%h = %h",
                                 $time, rs1_data_i, alu_src2, alu_result_temp);
                    `endif
                    end
                    `ALU_OP_SLL: begin
                        alu_result_temp = alu_src2 << rs1_data_i[5:0]; // SLL
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type SLL: alu_src2=%h << %h = %h",
                                 $time, alu_src2, rs1_data_i[5:0], alu_result_temp);
                    `endif
                    end
                    default: begin
                        alu_result_temp = 64'b0;
                    `ifdef DEBUG
                        $display("[%0t ps] EX: I-type unknown alu_op=%b, result=0", $time, alu_op);
                    `endif
                    end
                endcase
            end

            // 最终赋值给输出信号 - 修复：使用阻塞赋值确保在同一个时钟周期内更新
            alu_result_o = alu_result_temp;
        `ifdef DEBUG
            $display("[%0t ps] EX: Final ALU result: %h", $time, alu_result_o);
            $display("[%0t ps] EX: Pipeline signals - stall_i=%b, flush_i=%b", $time, stall_i, flush_i);
        `endif

            // Branch judgment - Handle branch, JAL and JALR instructions
            branch_taken_o <= 1'b0;
            branch_target_o <= pc_in_i + imm_i;

            // In RISC-V architecture, handle different types of jump instructions
            if (opcode == `OPCODE_BRANCH) begin // Branch instructions (BEQ, BNE, etc.)
                case (funct3) // funct3
                    `FUNCT3_BEQ:     branch_taken_o <= (rs1_data_i == rs2_data_i); // BEQ
                    `FUNCT3_BNE:     branch_taken_o <= (rs1_data_i != rs2_data_i); // BNE
                    `FUNCT3_BLT:     branch_taken_o <= ($signed(rs1_data_i) < $signed(rs2_data_i)); // BLT
                    `FUNCT3_BGE:     branch_taken_o <= ($signed(rs1_data_i) >= $signed(rs2_data_i)); // BGE
                    `FUNCT3_BLTU:    branch_taken_o <= (rs1_data_i < rs2_data_i); // BLTU
                    `FUNCT3_BGEU:    branch_taken_o <= (rs1_data_i >= rs2_data_i); // BGEU
                    default:         branch_taken_o <= 1'b0;
                endcase
            `ifdef DEBUG
                $display("[%0t ps] EX: Branch check: rs1=%h rs2=%h branch_taken=%b",
                         $time, rs1_data_i, rs2_data_i, branch_taken_o);
            `endif
            end else if (opcode == `OPCODE_JAL) begin // JAL instruction
                branch_taken_o <= 1'b1; // JAL always takes the jump
                branch_target_o <= pc_in_i + imm_i;
            `ifdef DEBUG
                $display("[%0t ps] EX: JAL instruction detected: branch_taken=%b, target=%h",
                         $time, branch_taken_o, branch_target_o);
            `endif
            end else if (opcode == `OPCODE_JALR) begin // JALR instruction
                branch_taken_o <= 1'b1; // JALR always takes the jump
                branch_target_o <= {alu_result_temp[63:1], 1'b0}; // Set least significant bit to 0
            `ifdef DEBUG
                $display("[%0t ps] EX: JALR instruction detected: branch_taken=%b, target=%h",
                         $time, branch_taken_o, branch_target_o);
            `endif
            end else begin
                branch_taken_o <= 1'b0;
            end
        end else begin
        `ifdef DEBUG
            $display("[%0t ps] EX: Pipeline stalled", $time);
        `endif
        end
    end

endmodule