// riscv64_alu.v
module riscv64_alu (
    input wire [63:0] a,
    input wire [63:0] b,
    input wire [3:0] alu_op,
    input wire word_op,  // 32位操作标志

    output reg [63:0] result,
    output reg zero
);

    // ALU操作定义
    localparam ALU_ADD    = 4'b0000;
    localparam ALU_SUB    = 4'b0001;
    localparam ALU_AND    = 4'b0010;
    localparam ALU_OR     = 4'b0011;
    localparam ALU_XOR    = 4'b0100;
    localparam ALU_SLT    = 4'b0101;
    localparam ALU_SLTU   = 4'b0110;
    localparam ALU_SLL    = 4'b0111;
    localparam ALU_SRL    = 4'b1000;
    /* TODO */
    // localparam ALU_SRA    = 4'b1009;
    localparam ALU_ADDW   = 4'b1010;
    localparam ALU_SUBW   = 4'b1011;
    localparam ALU_SLLW   = 4'b1100;
    localparam ALU_SRLW   = 4'b1101;
    localparam ALU_SRAW   = 4'b1110;

    // 内部信号
    wire [63:0] b_actual = (alu_op == ALU_SUB || alu_op == ALU_SUBW) ? ~b + 1 : b;
    wire [64:0] sum = {1'b0, a} + {1'b0, b_actual};

    // 32位操作数
    wire [31:0] a32 = a[31:0];
    wire [31:0] b32 = b[31:0];
    wire [31:0] b32_actual = (alu_op == ALU_SUBW) ? ~b32 + 1 : b32;
    wire [32:0] sum32 = {1'b0, a32} + {1'b0, b32_actual};

    always @(*) begin
        if (word_op) begin
            // 32位操作（结果符号扩展至64位）
            case (alu_op)
                ALU_ADDW:  result = {{32{sum32[31]}}, sum32[31:0]};
                ALU_SUBW:  result = {{32{sum32[31]}}, sum32[31:0]};
                ALU_SLLW:  result = {{32{a32[31]}}, a32 << b[4:0]};
                ALU_SRLW:  result = {{32{a32[31]}}, a32 >> b[4:0]};
                ALU_SRAW:  result = {{32{a32[31]}}, $signed(a32) >>> b[4:0]};
                default:   result = 64'h0;
            endcase
        end else begin
            // 64位操作
            case (alu_op)
                ALU_ADD:   result = a + b;
                ALU_SUB:   result = a - b;
                ALU_AND:   result = a & b;
                ALU_OR:    result = a | b;
                ALU_XOR:   result = a ^ b;
                ALU_SLT:   result = ($signed(a) < $signed(b)) ? 64'h1 : 64'h0;
                ALU_SLTU:  result = (a < b) ? 64'h1 : 64'h0;
                ALU_SLL:   result = a << b[5:0];
                ALU_SRL:   result = a >> b[5:0];
                // ALU_SRA:   result = $signed(a) >>> b[5:0];
                default:   result = 64'h0;
            endcase
        end

        zero = (result == 64'h0);
    end

endmodule
