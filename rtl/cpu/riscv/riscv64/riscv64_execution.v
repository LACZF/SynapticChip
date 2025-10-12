// riscv64_execution.v
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

    wire [2:0]  alu_op   = ctrl_in_i[14:12];
    wire        alu_src  = ctrl_in_i[11];
    wire [63:0] alu_src2 = alu_src ? imm_i : rs2_data_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h0000_0013;
            alu_result_o <= 64'b0;
            branch_taken_o <= 1'b0;
            branch_target_o <= 64'b0;
            ctrl_out_o <= 16'b0;
        end else if (flush_i) begin
            instr_out_o <= 32'h0000_0013;
            branch_taken_o <= 1'b0;
            ctrl_out_o <= 16'b0;
        end else if (!stall_i) begin
            pc_out_o <= pc_in_i;
            instr_out_o <= instr_in_i;
            ctrl_out_o <= ctrl_in_i;

            // ALU operations
            case (alu_op)
                3'b000: alu_result_o <= rs1_data_i + alu_src2; // ADD
                3'b001: alu_result_o <= rs1_data_i - alu_src2; // SUB
                3'b010: alu_result_o <= rs1_data_i & alu_src2; // AND
                3'b011: alu_result_o <= rs1_data_i | alu_src2; // OR
                3'b100: alu_result_o <= rs1_data_i ^ alu_src2; // XOR
                3'b101: alu_result_o <= ($signed(rs1_data_i) < $signed(alu_src2)) ? 64'd1 : 64'd0; // SLT
                3'b110: alu_result_o <= (rs1_data_i < alu_src2) ? 64'd1 : 64'd0; // SLTU
                3'b111: alu_result_o <= alu_src2 << rs1_data_i[5:0]; // SLL
            endcase

            // Branch judgment - Only judge when the instruction is a branch instruction
            branch_taken_o <= 1'b0;
            branch_target_o <= pc_in_i + imm_i;

            // In RISC-V architecture, the opcode of branch instructions is 7'b1100011
            if (instr_in_i[6:0] == 7'b1100011) begin
                case (instr_in_i[14:12]) // funct3
                    3'b000: branch_taken_o <= (rs1_data_i == rs2_data_i); // BEQ
                    3'b001: branch_taken_o <= (rs1_data_i != rs2_data_i); // BNE
                    3'b100: branch_taken_o <= ($signed(rs1_data_i) < $signed(rs2_data_i)); // BLT
                    3'b101: branch_taken_o <= ($signed(rs1_data_i) >= $signed(rs2_data_i)); // BGE
                    3'b110: branch_taken_o <= (rs1_data_i < rs2_data_i); // BLTU
                    3'b111: branch_taken_o <= (rs1_data_i >= rs2_data_i); // BGEU
                    default: branch_taken_o <= 1'b0;
                endcase
            end else begin
                branch_taken_o <= 1'b0;
            end
        end
    end

endmodule