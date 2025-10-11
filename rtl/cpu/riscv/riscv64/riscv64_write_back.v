// riscv64_write_back.v
module riscv64_write_back #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire                  stall,

    // From memory access stage
    input  wire [63:0]          pc_in,
    input  wire [31:0]          instr_in,
    input  wire [63:0]          alu_result,
    input  wire [63:0]          mem_result,
    input  wire [15:0]          ctrl_in,

    // Output to register file
    output reg  [4:0]           rd,
    output reg                  reg_we,
    output reg  [63:0]          reg_wdata,

    // Debug output
    output reg  [63:0]          pc_out,
    output reg  [31:0]          instr_out,
    output reg                  wb_valid
);

    // Control signals
    wire       reg_write  = ctrl_in[10];
    wire       mem_to_reg = ctrl_in[4];
    wire       pc_to_reg  = ctrl_in[3];
    wire       alu_src_pc = ctrl_in[2];
    wire [2:0] alu_op     = ctrl_in[14:12];

    // Instruction fields
    wire [4:0] instr_rd   = instr_in[11:7];
    wire [6:0] opcode     = instr_in[6:0];
    wire [2:0] funct3     = instr_in[14:12];
    wire [6:0] funct7     = instr_in[31:25];

    // Internal signals
    reg [63:0] computed_result;

    // Result selection function
    function [63:0] select_result;
        input [63:0] alu_val;
        input [63:0] mem_val;
        input [63:0] pc_val;
        input mem_to_reg;
        input pc_to_reg;
        input alu_src_pc;
        begin
            if (pc_to_reg) begin
                select_result = pc_val;
            end else if (mem_to_reg) begin
                select_result = mem_val;
            end else if (alu_src_pc) begin
                select_result = alu_val;
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
                7'b0110111: begin // LUI
                    result = {instr[31:12], 12'b0};
                end
                7'b0010111: begin // AUIPC
                    result = pc_val + {instr[31:12], 12'b0};
                end
                7'b1101111: begin // JAL
                    result = pc_val + 4;
                end
                7'b1100111: begin // JALR
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
            rd <= 5'b0;
            reg_we <= 1'b0;
            reg_wdata <= 64'b0;
            pc_out <= 64'b0;
            instr_out <= 32'h00000013;
            wb_valid <= 1'b0;
        end else if (!stall) begin
            // Pass pipeline registers
            pc_out <= pc_in;
            instr_out <= instr_in;
            wb_valid <= 1'b1;

            // Calculate write-back data
            computed_result = select_result(alu_result, mem_result, pc_in + 4,
                                          mem_to_reg, pc_to_reg, alu_src_pc);

            // Process special instructions
            reg_wdata <= compute_special_result(computed_result, pc_in, instr_in, opcode);

            // Set write-back address and enable
            rd <= instr_rd;

            // Determine whether to write register
            case (opcode)
                7'b0110111, 7'b0010111, 7'b1101111, 7'b1100111: begin
                    // LUI, AUIPC, JAL, JALR always write registers (except x0)
                    reg_we <= (instr_rd != 5'b0);
                end
                7'b0110011, 7'b0010011, 7'b0000011: begin
                    // Arithmetic, immediate, load instructions: according to control signals
                    reg_we <= reg_write && (instr_rd != 5'b0);
                end
                7'b0100011: begin
                    // Store instructions: do not write registers
                    reg_we <= 1'b0;
                end
                7'b1100011: begin
                    // Branch instructions: do not write registers
                    reg_we <= 1'b0;
                end
                default: begin
                    reg_we <= 1'b0;
                end
            endcase

        `ifdef DEBUG
            // Debug information output
            if (reg_we && (instr_rd != 5'b0)) begin
                $display("WB: PC=%h, Instr=%h, RD=x%0d, Value=%h",
                         pc_in, instr_in, instr_rd, reg_wdata);
            end
        `endif
        end else begin
            wb_valid <= 1'b0;
        end
    end

endmodule