// riscv64_instruction_decode.v
module riscv64_instruction_decode (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire flush,
    input wire [63:0] pc_in,
    input wire [31:0] instr_in,
    output reg [63:0] pc_out,
    output reg [31:0] instr_out,
    input wire [2:0] funct3,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output reg [63:0] imm,
    output reg [15:0] ctrl_signals
);

    // 控制信号定义
    localparam [2:0] ALU_ADD = 3'b000;
    localparam [2:0] ALU_SUB = 3'b001;
    localparam [2:0] ALU_AND = 3'b010;
    localparam [2:0] ALU_OR  = 3'b011;
    localparam [2:0] ALU_XOR = 3'b100;
    localparam [2:0] ALU_SLT = 3'b101;
    localparam [2:0] ALU_SLTU = 3'b110;

    wire [6:0] opcode = instr_in[6:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 64'b0;
            instr_out <= 32'h0000_0013; // NOP
            imm <= 64'b0;
            ctrl_signals <= 16'b0;
        end else if (flush) begin
            instr_out <= 32'h0000_0013; // 插入NOP
            ctrl_signals <= 16'b0;
        end else if (!stall) begin
            pc_out <= pc_in;
            instr_out <= instr_in;

            // 立即数生成
            case (opcode)
                7'b0110111, 7'b0010111: // LUI, AUIPC
                    imm <= {instr_in[31:12], 12'b0};
                7'b1101111: // JAL
                    imm <= {{44{instr_in[31]}}, instr_in[19:12], instr_in[20], instr_in[30:21], 1'b0};
                7'b1100111: // JALR
                    imm <= {{53{instr_in[31]}}, instr_in[30:20]};
                7'b1100011: // 分支指令
                    imm <= {{52{instr_in[31]}}, instr_in[7], instr_in[30:25], instr_in[11:8], 1'b0};
                7'b0000011: // 加载指令
                    imm <= {{53{instr_in[31]}}, instr_in[30:20]};
                7'b0100011: // 存储指令
                    imm <= {{53{instr_in[31]}}, instr_in[30:25], instr_in[11:7]};
                7'b0010011: // 立即数运算
                    imm <= (instr_in[14:12] == 3'b101) ?
                           {{59{instr_in[24]}}, instr_in[23:20]} : // SRAI, SRLI
                           {{53{instr_in[31]}}, instr_in[30:20]};
                default:
                    imm <= 64'b0;
            endcase

            // 控制信号生成
            case (opcode)
                7'b0110111: ctrl_signals <= {1'b1, 3'b000, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // LUI
                7'b0010111: ctrl_signals <= {1'b1, 3'b000, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // AUIPC
                7'b1101111: ctrl_signals <= {1'b1, 3'b000, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // JAL
                7'b1100111: ctrl_signals <= {1'b1, 3'b000, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // JALR
                7'b1100011: ctrl_signals <= {1'b0, 3'b001, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0}; // 分支
                7'b0000011: ctrl_signals <= {1'b1, 3'b010, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, funct3, 1'b0}; // 加载
                7'b0100011: ctrl_signals <= {1'b0, 3'b011, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, funct3, 1'b0}; // 存储
                7'b0010011: ctrl_signals <= {1'b1, 3'b100, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, funct3, 1'b0}; // 立即数运算
                7'b0110011: ctrl_signals <= {1'b1, 3'b101, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, funct3, instr_in[30]}; // 寄存器运算
                default:     ctrl_signals <= 16'b0;
            endcase
        end
    end

    assign rs1 = instr_in[19:15];
    assign rs2 = instr_in[24:20];
    assign rd = instr_in[11:7];

endmodule
