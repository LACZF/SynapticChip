// alu.v
module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [2:0] alu_op,

    output reg [31:0] result,
    output reg zero
);

    localparam ALU_ADD  = 3'b000;
    localparam ALU_SUB  = 3'b001;
    localparam ALU_AND  = 3'b010;
    localparam ALU_OR   = 3'b011;
    localparam ALU_XOR  = 3'b100;
    localparam ALU_SLT  = 3'b101;
    localparam ALU_SLTU = 3'b110;
    localparam ALU_SLL  = 3'b111;

    wire [31:0] b_actual = (alu_op == ALU_SUB) ? ~b + 1 : b;
    wire [32:0] sum = {1'b0, a} + {1'b0, b_actual};

    always @(*) begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'h1 : 32'h0;
            ALU_SLTU: result = (a < b) ? 32'h1 : 32'h0;
            ALU_SLL:  result = a << b[4:0];
            default:  result = 32'h0;
        endcase

        zero = (result == 32'h0);
    end

endmodule
