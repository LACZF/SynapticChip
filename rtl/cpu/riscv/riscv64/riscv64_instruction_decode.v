`include "riscv64_instruction_defs.v"

module riscv64_instruction_decode #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 stall_i,
    input  wire                 flush_i,
    input  wire [63:0]          pc_in_i,
    input  wire [31:0]          instr_in_i,
    input  wire                 if_valid_i,
    output reg  [63:0]          pc_out_o,
    output reg  [31:0]          instr_out_o,
    output reg                  id_valid_o,
    input  wire [2:0]           funct3_i,
    output wire [4:0]           rs1_o,
    output wire [4:0]           rs2_o,
    output wire [4:0]           rd_o,
    output reg  [63:0]          imm_o,
    output reg  [15:0]          ctrl_signals_o
);

    wire [6:0] opcode = instr_in_i[6:0];
    wire [2:0] funct3 = instr_in_i[14:12];
    wire       funct7_30 = instr_in_i[30]; // 用于区分 ADD/SUB, SRL/SRA 等指令

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h0000_0013; // NOP
            imm_o <= 64'b0;
            ctrl_signals_o <= 16'b0;
            id_valid_o <= 1'b0; // 初始化为无效
        end else if (flush_i) begin
            instr_out_o <= 32'h0000_0013; // Insert NOP
            ctrl_signals_o <= 16'b0;
            id_valid_o <= 1'b0; // 刷新时设置为无效
        end else if (!stall_i) begin
            if (if_valid_i) begin // 只有当上一级输入有效时才处理指令
                pc_out_o <= pc_in_i;
                instr_out_o <= instr_in_i;
                id_valid_o <= 1'b1; // 当前级设置为有效

                // Immediate value generation
                case (opcode)
                    `OPCODE_LUI, `OPCODE_AUIPC: // LUI, AUIPC
                        imm_o <= {instr_in_i[31:12], 12'b0};
                    `OPCODE_JAL: // JAL
                        imm_o <= {{44{instr_in_i[31]}}, instr_in_i[19:12], instr_in_i[20], instr_in_i[30:21], 1'b0};
                    `OPCODE_JALR: // JALR
                        imm_o <= {{53{instr_in_i[31]}}, instr_in_i[30:20]};
                    `OPCODE_BRANCH: // Branch instructions
                        imm_o <= {{52{instr_in_i[31]}}, instr_in_i[7], instr_in_i[30:25], instr_in_i[11:8], 1'b0};
                    `OPCODE_LOAD: // Load instructions
                        imm_o <= {{53{instr_in_i[31]}}, instr_in_i[30:20]};
                    `OPCODE_STORE: // Store instructions
                        imm_o <= {{53{instr_in_i[31]}}, instr_in_i[30:25], instr_in_i[11:7]};
                    `OPCODE_IMM_ARITH: // Immediate arithmetic
                        imm_o <= (instr_in_i[14:12] == 3'b101) ?
                               {{59{instr_in_i[24]}}, instr_in_i[23:20]} : // SRAI, SRLI
                               {{53{instr_in_i[31]}}, instr_in_i[30:20]};
                    default:
                        imm_o <= 64'b0;
                endcase

                // Control signal generation with correct bit assignments
                case (opcode)
                    `OPCODE_LUI: begin                                        // LUI
                        ctrl_signals_o[15]    <= 1'b1;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b000;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b0;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b0;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= 5'b0;                        // unused
                    end
                    `OPCODE_AUIPC: begin                                      // AUIPC
                        ctrl_signals_o[15]    <= 1'b1;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b000;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b1;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b1;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= 5'b0;                        // unused
                    end
                    `OPCODE_JAL: begin                                        // JAL
                        ctrl_signals_o[15]    <= 1'b1;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b000;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b1;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b1;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b1;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= 5'b0;                        // unused
                    end
                    `OPCODE_JALR: begin                                       // JALR
                        ctrl_signals_o[15]    <= 1'b1;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b000;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b0;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b0;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b1;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= 5'b0;                        // unused
                    end
                    `OPCODE_BRANCH: begin                                     // Branch
                        ctrl_signals_o[15]    <= 1'b0;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b001;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b1;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b0;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b1;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= 5'b0;                        // unused
                    end
                    `OPCODE_LOAD: begin                                       // Load
                        ctrl_signals_o[15]    <= 1'b1;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b010;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b0;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b1;                        // mem_read
                        ctrl_signals_o[8]     <= 1'b1;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b0;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= {funct3_i, 2'b0};            // funct3
                    end
                    `OPCODE_STORE: begin                                      // Store
                        ctrl_signals_o[15]    <= 1'b0;                        // reg_op
                        ctrl_signals_o[14:12] <= 3'b011;                      // alu_op
                        ctrl_signals_o[11]    <= 1'b0;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b0;                        // unused
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b0;                        // reg_write
                        ctrl_signals_o[6]     <= 1'b0;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= {funct3_i, 2'b0};            // funct3
                    end
                    `OPCODE_IMM_ARITH: begin                                  // Immediate arithmetic - 修复：将reg_op设置为0，alu_src设置为1
                        ctrl_signals_o[15]    <= 1'b0;                        // reg_op: 设置为0，使执行阶段使用alu_op选择操作
                        ctrl_signals_o[14:12] <= funct3;                      // alu_op: 使用funct3作为操作码
                        ctrl_signals_o[11]    <= 1'b1;                        // alu_src: 设置为1，使用立即数作为第二个操作数
                        ctrl_signals_o[10]    <= 1'b1;                        // reg_write: 用于WB阶段判断是否需要回写
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // 冗余的reg_write位
                        ctrl_signals_o[6]     <= 1'b0;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= {funct3_i, 2'b0};            // funct3
                    end
                        `OPCODE_REG_ARITH: begin                                  // Register arithmetic with reg_op
                        ctrl_signals_o[15]    <= 1'b1;                        // reg_op: 标识为寄存器算术指令
                        ctrl_signals_o[14:12] <= funct3;                      // alu_op: 使用 funct3 作为操作码
                        ctrl_signals_o[11]    <= 1'b0;                        // alu_src
                        ctrl_signals_o[10]    <= 1'b1;                        // reg_write: 用于WB阶段判断是否需要回写
                        ctrl_signals_o[9]     <= 1'b0;                        // unused
                        ctrl_signals_o[8]     <= 1'b0;                        // mem_to_reg
                        ctrl_signals_o[7]     <= 1'b1;                        // 冗余的reg_write位
                        ctrl_signals_o[6]     <= 1'b0;                        // alu_src_pc
                        ctrl_signals_o[5]     <= 1'b0;                        // pc_to_reg
                        ctrl_signals_o[4:0]   <= {funct3_i, funct7_30, 1'b0}; // 其他控制信号
                    end
                    default: begin
                        ctrl_signals_o <= 16'b0;
                    end
                endcase
            end else begin
                // 当上一级输入无效时，输出NOP指令
                instr_out_o <= 32'h0000_0013;
                ctrl_signals_o <= 16'b0;
                id_valid_o <= 1'b0;
            end
        end else begin
            // 当流水线停滞时，保持当前状态
            // valid信号保持不变
        end
    end

    assign rs1_o = instr_in_i[19:15];
    assign rs2_o = instr_in_i[24:20];
    assign rd_o  = instr_in_i[11:7];

endmodule