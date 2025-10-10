// riscv64_execution.v
module riscv64_execution #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire flush,
    input wire [63:0] pc_in,
    input wire [31:0] instr_in,
    input wire [63:0] rs1_data,
    input wire [63:0] rs2_data,
    input wire [63:0] imm,
    input wire [15:0] ctrl_in,
    output reg [63:0] pc_out,
    output reg [31:0] instr_out,
    output reg [63:0] alu_result,
    output reg branch_taken,
    output reg [63:0] branch_target,
    output reg [15:0] ctrl_out
);

    wire [2:0] alu_op = ctrl_in[14:12];
    wire alu_src = ctrl_in[11];
    wire [63:0] alu_src2 = alu_src ? imm : rs2_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 64'b0;
            instr_out <= 32'h0000_0013;
            alu_result <= 64'b0;
            branch_taken <= 1'b0;
            branch_target <= 64'b0;
            ctrl_out <= 16'b0;
        end else if (flush) begin
            instr_out <= 32'h0000_0013;
            branch_taken <= 1'b0;
            ctrl_out <= 16'b0;
        end else if (!stall) begin
            pc_out <= pc_in;
            instr_out <= instr_in;
            ctrl_out <= ctrl_in;

            // ALU操作
            case (alu_op)
                3'b000: alu_result <= rs1_data + alu_src2; // ADD
                3'b001: alu_result <= rs1_data - alu_src2; // SUB
                3'b010: alu_result <= rs1_data & alu_src2; // AND
                3'b011: alu_result <= rs1_data | alu_src2; // OR
                3'b100: alu_result <= rs1_data ^ alu_src2; // XOR
                3'b101: alu_result <= ($signed(rs1_data) < $signed(alu_src2)) ? 64'd1 : 64'd0; // SLT
                3'b110: alu_result <= (rs1_data < alu_src2) ? 64'd1 : 64'd0; // SLTU
                3'b111: alu_result <= alu_src2 << rs1_data[5:0]; // SLL
            endcase

            // 分支判断 - 只有当指令是分支指令时才进行判断
            branch_taken <= 1'b0;
            branch_target <= pc_in + imm;

            // RISC-V架构中，分支指令的opcode是7'b1100011
            if (instr_in[6:0] == 7'b1100011) begin
                case (instr_in[14:12]) // funct3
                    3'b000: branch_taken <= (rs1_data == rs2_data); // BEQ
                    3'b001: branch_taken <= (rs1_data != rs2_data); // BNE
                    3'b100: branch_taken <= ($signed(rs1_data) < $signed(rs2_data)); // BLT
                    3'b101: branch_taken <= ($signed(rs1_data) >= $signed(rs2_data)); // BGE
                    3'b110: branch_taken <= (rs1_data < rs2_data); // BLTU
                    3'b111: branch_taken <= (rs1_data >= rs2_data); // BGEU
                    default: branch_taken <= 1'b0;
                endcase
            end else begin
                branch_taken <= 1'b0;
            end
        end
    end

endmodule