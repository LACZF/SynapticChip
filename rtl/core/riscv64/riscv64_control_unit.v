// riscv64_control_unit.v
module riscv64_control_unit (
    input wire [6:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,

    output reg [3:0] alu_op,
    output reg alu_src,
    output reg mem_we,
    output reg mem_re,
    output reg [1:0] wb_sel,
    output reg branch,
    output reg jump,
    output reg reg_we,
    output reg [2:0] mem_size,
    output reg word_op,
    output reg mret_exec
);

    // RV64I操作码定义
    localparam OP_LOAD    = 7'b0000011;
    localparam OP_STORE   = 7'b0100011;
    localparam OP_BRANCH  = 7'b1100011;
    localparam OP_JALR    = 7'b1100111;
    localparam OP_JAL     = 7'b1101111;
    localparam OP_OP_IMM  = 7'b0010011;
    localparam OP_OP_IMM32 = 7'b0011011;  // RV64I新增：32位立即数操作
    localparam OP_OP      = 7'b0110011;
    localparam OP_OP32    = 7'b0111011;   // RV64I新增：32位操作
    localparam OP_LUI     = 7'b0110111;
    localparam OP_AUIPC   = 7'b0010111;
    localparam OP_SYSTEM  = 7'b1110011;

    // ALU操作定义（扩展支持64位和32位操作）
    localparam ALU_ADD    = 4'b0000;
    localparam ALU_SUB    = 4'b0001;
    localparam ALU_AND    = 4'b0010;
    localparam ALU_OR     = 4'b0011;
    localparam ALU_XOR    = 4'b0100;
    localparam ALU_SLT    = 4'b0101;
    localparam ALU_SLTU   = 4'b0110;
    localparam ALU_SLL    = 4'b0111;
    localparam ALU_SRL    = 4'b1000;
    localparam ALU_SRA    = 4'b1001;
    localparam ALU_ADDW   = 4'b1010;  // 32位加法
    localparam ALU_SUBW   = 4'b1011;  // 32位减法
    localparam ALU_SLLW   = 4'b1100;  // 32位左移
    localparam ALU_SRLW   = 4'b1101;  // 32位逻辑右移
    localparam ALU_SRAW   = 4'b1110;  // 32位算术右移

    // 内存访问大小
    localparam MEM_BYTE  = 3'b000;  // 字节
    localparam MEM_HALF  = 3'b001;  // 半字
    localparam MEM_WORD  = 3'b010;  // 字
    localparam MEM_DWORD = 3'b011;  // 双字

    always @(*) begin
        // 默认值
        alu_op = ALU_ADD;
        alu_src = 1'b0;
        mem_we = 1'b0;
        mem_re = 1'b0;
        wb_sel = 2'b00;
        branch = 1'b0;
        jump = 1'b0;
        reg_we = 1'b0;
        mem_size = MEM_DWORD;  // 默认双字访问
        word_op = 1'b0;
        mret_exec = 1'b0;

        case (opcode)
            OP_LOAD: begin
                alu_src = 1'b1;
                mem_re = 1'b1;
                wb_sel = 2'b01;
                reg_we = 1'b1;

                // 根据funct3确定加载大小
                case (funct3)
                    3'b000: mem_size = MEM_BYTE;   // LB
                    3'b001: mem_size = MEM_HALF;   // LH
                    3'b010: mem_size = MEM_WORD;   // LW
                    3'b011: mem_size = MEM_DWORD;  // LD
                    3'b100: mem_size = MEM_BYTE;   // LBU
                    3'b101: mem_size = MEM_HALF;   // LHU
                    3'b110: mem_size = MEM_WORD;   // LWU
                    default: mem_size = MEM_DWORD;
                endcase
            end

            OP_STORE: begin
                alu_src = 1'b1;
                mem_we = 1'b1;

                // 根据funct3确定存储大小
                case (funct3)
                    3'b000: mem_size = MEM_BYTE;   // SB
                    3'b001: mem_size = MEM_HALF;   // SH
                    3'b010: mem_size = MEM_WORD;   // SW
                    3'b011: mem_size = MEM_DWORD;  // SD
                    default: mem_size = MEM_DWORD;
                endcase
            end

            OP_BRANCH: begin
                branch = 1'b1;
                alu_op = ALU_SUB;
            end

            OP_JALR: begin
                jump = 1'b1;
                alu_src = 1'b1;
                wb_sel = 2'b10;
                reg_we = 1'b1;
            end

            OP_JAL: begin
                jump = 1'b1;
                wb_sel = 2'b10;
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
                    3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL); // SRLI/SRAI
                endcase
            end

            OP_OP_IMM32: begin
                alu_src = 1'b1;
                reg_we = 1'b1;
                word_op = 1'b1;  // 32位操作
                case (funct3)
                    3'b000: alu_op = ALU_ADDW; // ADDIW
                    3'b001: alu_op = ALU_SLLW; // SLLIW
                    3'b101: alu_op = (funct7[5] ? ALU_SRAW : ALU_SRLW); // SRLIW/SRAIW
                    default: alu_op = ALU_ADDW;
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
                    3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL); // SRL/SRA
                endcase
            end

            OP_OP32: begin
                reg_we = 1'b1;
                word_op = 1'b1;  // 32位操作
                case (funct3)
                    3'b000: alu_op = (funct7[5] ? ALU_SUBW : ALU_ADDW); // ADDW/SUBW
                    3'b001: alu_op = ALU_SLLW;  // SLLW
                    3'b101: alu_op = (funct7[5] ? ALU_SRAW : ALU_SRLW); // SRLW/SRAW
                    default: alu_op = ALU_ADDW;
                endcase
            end

            OP_LUI: begin
                alu_src = 1'b1;
                wb_sel = 2'b00;
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
