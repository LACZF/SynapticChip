// control_unit.v
module control_unit (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,

    output reg [2:0] alu_op,
    output reg alu_src,
    output reg mem_we,
    output reg mem_re,
    output reg [1:0] wb_sel,
    output reg branch,
    output reg jump,
    output reg reg_we,
    output reg mret_exec
);

    // 操作码定义
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_OP_IMM  = 7'b0010011;
    localparam OP_OP      = 7'b0110011;
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;
    localparam OP_SYSTEM  = 7'b1110011;

    // ALU操作定义
    localparam ALU_ADD  = 3'b000;
    localparam ALU_SUB  = 3'b001;
    localparam ALU_AND  = 3'b010;
    localparam ALU_OR   = 3'b011;
    localparam ALU_XOR  = 3'b100;
    localparam ALU_SLT  = 3'b101;
    localparam ALU_SLTU = 3'b110;
    localparam ALU_SLL  = 3'b111;

    always @(*) begin
        // 默认值
        alu_op = ALU_ADD;
        alu_src = 1'b0;
        mem_we = 1'b0;
        mem_re = 1'b0;
        wb_sel = 2'b00;  // ALU结果
        branch = 1'b0;
        jump = 1'b0;
        reg_we = 1'b0;
        mret_exec = 1'b0;

        case (opcode)
            OP_LOAD: begin
                alu_src = 1'b1;
                mem_re = 1'b1;
                wb_sel = 2'b01;  // 内存数据
                reg_we = 1'b1;
            end

            OP_STORE: begin
                alu_src = 1'b1;
                mem_we = 1'b1;
            end

            OP_BRANCH: begin
                branch = 1'b1;
                alu_op = ALU_SUB;  // 用于比较
            end

            OP_JALR: begin
                jump = 1'b1;
                alu_src = 1'b1;
                wb_sel = 2'b10;  // PC+4
                reg_we = 1'b1;
            end

            OP_JAL: begin
                jump = 1'b1;
                wb_sel = 2'b10;  // PC+4
                reg_we = 1'b1;
            end

            OP_OP_IMM: begin
                alu_src = 1'b1;
                reg_we = 1'b1;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;  // ADDI
                    3'b010: alu_op = ALU_SLT;  // SLTI
                    3'b011: alu_op = ALU_SLTU; // SLTIU
                    3'b100: alu_op = ALU_XOR;  // XORI
                    3'b110: alu_op = ALU_OR;   // ORI
                    3'b111: alu_op = ALU_AND;  // ANDI
                    3'b001: alu_op = ALU_SLL;  // SLLI
                    /* TODO */
                    // 3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL); // SRLI/SRAI
                endcase
            end

            OP_OP: begin
                reg_we = 1'b1;
                case (funct3)
                    3'b000: alu_op = (funct7[5] ? ALU_SUB : ALU_ADD); // ADD/SUB
                    3'b010: alu_op = ALU_SLT;  // SLT
                    3'b011: alu_op = ALU_SLTU; // SLTU
                    3'b100: alu_op = ALU_XOR;  // XOR
                    3'b110: alu_op = ALU_OR;   // OR
                    3'b111: alu_op = ALU_AND;  // AND
                    3'b001: alu_op = ALU_SLL;  // SLL
                    /* TODO */
                    // 3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL); // SRL/SRA
                endcase
            end

            OP_LUI: begin
                alu_src = 1'b1;
                wb_sel = 2'b00;  // ALU结果（立即数）
                reg_we = 1'b1;
            end

            OP_AUIPC: begin
                alu_src = 1'b1;
                reg_we = 1'b1;
            end

            OP_SYSTEM: begin
                if (funct3 == 3'b000) begin
                    // MRET指令
                    if (funct7 == 7'b0011000) begin
                        mret_exec = 1'b1;
                    end
                end
            end
        endcase
    end

endmodule
