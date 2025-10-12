// riscv64_instruction_decode.v
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
    output reg  [63:0]          pc_out_o,
    output reg  [31:0]          instr_out_o,
    input  wire [2:0]           funct3_i,
    output wire [4:0]           rs1_o,
    output wire [4:0]           rs2_o,
    output wire [4:0]           rd_o,
    output reg  [63:0]          imm_o,
    output reg  [15:0]          ctrl_signals_o
);

    // Control signal definitions
    localparam [2:0] ALU_ADD    = 3'b000;
    localparam [2:0] ALU_SUB    = 3'b001;
    localparam [2:0] ALU_AND    = 3'b010;
    localparam [2:0] ALU_OR     = 3'b011;
    localparam [2:0] ALU_XOR    = 3'b100;
    localparam [2:0] ALU_SLT    = 3'b101;
    localparam [2:0] ALU_SLTU   = 3'b110;

    wire [6:0] opcode = instr_in_i[6:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h0000_0013; // NOP
            imm_o <= 64'b0;
            ctrl_signals_o <= 16'b0;
        end else if (flush_i) begin
            instr_out_o <= 32'h0000_0013; // Insert NOP
            ctrl_signals_o <= 16'b0;
        end else if (!stall_i) begin
            pc_out_o <= pc_in_i;
            instr_out_o <= instr_in_i;

            // Immediate value generation
            case (opcode)
                7'b0110111, 7'b0010111: // LUI, AUIPC
                    imm_o <= {instr_in_i[31:12], 12'b0};
                7'b1101111: // JAL
                    imm_o <= {{44{instr_in_i[31]}}, instr_in_i[19:12], instr_in_i[20], instr_in_i[30:21], 1'b0};
                7'b1100111: // JALR
                    imm_o <= {{53{instr_in_i[31]}}, instr_in_i[30:20]};
                7'b1100011: // Branch instructions
                    imm_o <= {{52{instr_in_i[31]}}, instr_in_i[7], instr_in_i[30:25], instr_in_i[11:8], 1'b0};
                7'b0000011: // Load instructions
                    imm_o <= {{53{instr_in_i[31]}}, instr_in_i[30:20]};
                7'b0100011: // Store instructions
                    imm_o <= {{53{instr_in_i[31]}}, instr_in_i[30:25], instr_in_i[11:7]};
                7'b0010011: // Immediate arithmetic
                    imm_o <= (instr_in_i[14:12] == 3'b101) ?
                           {{59{instr_in_i[24]}}, instr_in_i[23:20]} : // SRAI, SRLI
                           {{53{instr_in_i[31]}}, instr_in_i[30:20]};
                default:
                    imm_o <= 64'b0;
            endcase

            // Control signal generation
            case (opcode)
                7'b0110111: ctrl_signals_o <= {1'b1, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // LUI
                7'b0010111: ctrl_signals_o <= {1'b1, 3'b000, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // AUIPC
                7'b1101111: ctrl_signals_o <= {1'b1, 3'b000, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // JAL
                7'b1100111: ctrl_signals_o <= {1'b1, 3'b000, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // JALR
                7'b1100011: ctrl_signals_o <= {1'b0, 3'b001, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // Branch
                7'b0000011: ctrl_signals_o <= {1'b1, 3'b010, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, funct3_i, 1'b0}; // Load
                7'b0100011: ctrl_signals_o <= {1'b0, 3'b011, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, funct3_i, 1'b0}; // Store
                7'b0010011: ctrl_signals_o <= {1'b1, 3'b100, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, funct3_i, 1'b0}; // Immediate arithmetic
                7'b0110011: ctrl_signals_o <= {1'b1, 3'b101, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, funct3_i, instr_in_i[30]}; // Register arithmetic
                default:    ctrl_signals_o <= 16'b0;
            endcase
        end
    end

    assign rs1_o = instr_in_i[19:15];
    assign rs2_o = instr_in_i[24:20];
    assign rd_o  = instr_in_i[11:7];

endmodule