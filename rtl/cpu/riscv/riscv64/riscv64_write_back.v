// riscv64_write_back.v
`timescale 1ns / 1ps
`include "riscv64_instruction_defs.v"

module riscv64_write_back #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire                  stall_i,

    // From memory access stage
    input  wire [63:0]          pc_in_i,
    input  wire [31:0]          instr_in_i,
    input  wire [63:0]          alu_result_i,
    input  wire [63:0]          mem_result_i,
    input  wire [15:0]          ctrl_in_i,
    input  wire                 mem_valid_i,

    // Output to register file
    output reg  [4:0]           rd_o,
    output reg                  reg_we_o,
    output reg  [63:0]          reg_wdata_o,

    // Debug output
    output reg  [63:0]          pc_out_o,
    output reg  [31:0]          instr_out_o,
    output reg                  wb_valid_o
);

    // Control signals - 与测试文件中的位定义保持一致
    wire       reg_write  = ctrl_in_i[10];  // 寄存器写使能信号位于第10位
    wire       mem_to_reg = ctrl_in_i[4];   // 内存到寄存器信号位于第4位
    wire       pc_to_reg  = ctrl_in_i[5];   // PC到寄存器信号位于第5位
    wire       alu_src_pc = ctrl_in_i[6];   // ALU源PC信号位于第6位
    wire [2:0] alu_op     = ctrl_in_i[14:12];

    // Instruction fields
    wire [4:0] instr_rd   = instr_in_i[11:7];
    wire [6:0] opcode     = instr_in_i[6:0];
    wire [2:0] funct3     = instr_in_i[14:12];
    wire [6:0] funct7     = instr_in_i[31:25];

    // Internal signals
    reg [63:0] computed_result;

    // Result selection function - 修复选择逻辑，确保正确选择结果源
    function [63:0] select_result;
        input [63:0] alu_val;
        input [63:0] mem_val;
        input [63:0] pc_val;
        input mem_to_reg;
        input pc_to_reg;
        begin
            if (pc_to_reg) begin
                select_result = pc_val;
            end else if (mem_to_reg) begin
                select_result = mem_val;
            end else begin
                select_result = alu_val;
            end
        end
    endfunction

    // Special instruction result calculation
    function [63:0] compute_special_result;
        input [63:0] alu_val;
        input [63:0] pc_val;
        input [31:0] instr;
        input [6:0] opcode;
        reg [63:0] result;
        begin
            case (opcode)
                `OPCODE_LUI: begin // LUI
                    result = {instr[31:12], 12'b0};
                end
                `OPCODE_AUIPC: begin // AUIPC
                    result = pc_val + {instr[31:12], 12'b0};
                end
                `OPCODE_JAL: begin // JAL
                    result = pc_val + 4;
                end
                `OPCODE_JALR: begin // JALR
                    result = pc_val + 4;
                end
                default: begin
                    result = alu_val;
                end
            endcase
            compute_special_result = result;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_o <= 5'b0;
            reg_we_o <= 1'b0;
            reg_wdata_o <= 64'b0;
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h00000013;
            wb_valid_o <= 1'b0;
        end else if (!stall_i) begin
            if (mem_valid_i) begin
                // 只有当上一级输入有效时才处理指令
                // Pass pipeline registers
                pc_out_o <= pc_in_i;
                instr_out_o <= instr_in_i;
                wb_valid_o <= 1'b1;
            `ifdef DEBUG
                // Debug: 追踪输入值
                $display("WB Debug: PC=%h, Instr=%h, Opcode=%h, alu_result_i=%h, mem_result_i=%h",
                         pc_in_i, instr_in_i, opcode, alu_result_i, mem_result_i);
                $display("WB Debug: reg_write=%b, mem_to_reg=%b, pc_to_reg=%b, alu_src_pc=%b",
                         reg_write, mem_to_reg, pc_to_reg, alu_src_pc);
            `endif

                // Calculate write-back data - 修复计算逻辑
                if (opcode == `OPCODE_LUI || opcode == `OPCODE_AUIPC || opcode == `OPCODE_JAL || opcode == `OPCODE_JALR) begin
                    // For special instructions, directly use compute_special_result
                    reg_wdata_o <= compute_special_result(alu_result_i, pc_in_i, instr_in_i, opcode);
                end else begin
                    // For other instructions, use select_result directly to avoid timing issues
                    reg_wdata_o <= select_result(alu_result_i, mem_result_i, pc_in_i + 4,
                                               mem_to_reg, pc_to_reg);
                    // Store computed_result for debug purposes only
                    computed_result = select_result(alu_result_i, mem_result_i, pc_in_i + 4,
                                                  mem_to_reg, pc_to_reg);
                end

            `ifdef DEBUG
                // Debug: 追踪计算结果
                $display("WB Debug: computed_result=%h, reg_wdata_o=%h", computed_result, reg_wdata_o);
            `endif

                // Set write-back address and enable
                rd_o <= instr_rd;

                // Determine whether to write register
                case (opcode)
                    `OPCODE_LUI, `OPCODE_AUIPC, `OPCODE_JAL, `OPCODE_JALR: begin
                        // LUI, AUIPC, JAL, JALR always write registers (except x0)
                        reg_we_o <= (instr_rd != 5'b0);
                    end
                    `OPCODE_REG_ARITH, `OPCODE_IMM_ARITH, `OPCODE_LOAD: begin
                        // Arithmetic, immediate, load instructions: according to control signals
                        reg_we_o <= reg_write && (instr_rd != 5'b0);
                    end
                    `OPCODE_STORE: begin
                        // Store instructions: do not write registers
                        reg_we_o <= 1'b0;
                    end
                    `OPCODE_BRANCH: begin
                        // Branch instructions: do not write registers
                        reg_we_o <= 1'b0;
                    end
                    default: begin
                        reg_we_o <= 1'b0;
                    end
                endcase

            `ifdef DEBUG
                // Debug information output
                if (reg_we_o && (instr_rd != 5'b0)) begin
                    $display("WB: PC=%h, Instr=%h, RD=x%0d, Value=%h",
                             pc_in_i, instr_in_i, instr_rd, reg_wdata_o);
                end
            `endif
            end else begin
                // 当上一级输入无效时，输出NOP状态
                instr_out_o <= 32'h00000013;
                rd_o <= 5'b0;
                reg_we_o <= 1'b0;
                reg_wdata_o <= 64'b0;
                wb_valid_o <= 1'b0;
            end
        end else begin
            wb_valid_o <= 1'b0;
        end
    end

endmodule