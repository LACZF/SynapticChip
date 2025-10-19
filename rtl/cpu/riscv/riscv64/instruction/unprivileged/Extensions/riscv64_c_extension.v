`define RISCV64_C_EXTENSION_V
`include "riscv64_instruction_defs.v"

module riscv64_c_extension #(
    parameter DATA_WIDTH = 64
)(
    input wire                  funct7_30,
    input wire [2:0]            funct3,
    input wire [6:0]            opcode,
    input wire [DATA_WIDTH-1:0] rs1_data_i,
    input wire [DATA_WIDTH-1:0] rs2_data_i,
    input wire [DATA_WIDTH-1:0] imm_i,
    input wire [DATA_WIDTH-1:0] pc_in_i,
    input wire [2:0]            alu_op,
    input wire [31:0]           instr_in_i,
    output wire [DATA_WIDTH-1:0] alu_result_o,
    output wire                 is_c_extension
);

    // 信号定义
    reg [DATA_WIDTH-1:0] c_result;
    wire [15:0] instr_16bit = instr_in_i[15:0]; // 提取16位压缩指令
    wire [1:0] c_opcode = instr_16bit[1:0]; // 压缩指令的opcode在最低两位
    wire [2:0] c_funct3 = instr_16bit[14:12]; // C.B-type指令的funct3
    wire [3:0] c_funct4 = instr_16bit[15:12]; // C.R-type指令的funct4
    wire [4:0] c_rd = {2'b0, instr_16bit[9:7]}; // C.R-type指令的rd字段
    wire [4:0] c_rs1 = {2'b0, instr_16bit[11:7]}; // C.I-type指令的rs1字段
    wire [4:0] c_rs2 = {2'b0, instr_16bit[6:2]}; // C.S-type指令的rs2字段
    wire [5:0] c_imm6 = instr_16bit[15:10]; // 6位立即数
    wire [4:0] c_imm5 = instr_16bit[12:8]; // 5位立即数
    wire [3:0] c_imm4 = instr_16bit[15:12]; // 4位立即数

    // 判断是否为C扩展指令（压缩指令的opcode特定模式）
    assign is_c_extension = (c_opcode == `OPCODE_C_RTYPE ||
                           c_opcode == `OPCODE_C_ITYPE ||
                           c_opcode == `OPCODE_C_STYPE ||
                           c_opcode == `OPCODE_C_BTYPE ||
                           (c_opcode == `OPCODE_C_JAL && instr_16bit[15:13] == 3'b001) ||
                           (c_opcode == `OPCODE_C_LUI && instr_16bit[15:13] == 3'b010) ||
                           (c_opcode == `OPCODE_C_ADDI4SPN && instr_16bit[15:13] == 3'b000));

    // C.R-type 指令处理
    function [DATA_WIDTH-1:0] handle_c_rtype;
        input [3:0] c_funct4;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] rs2;
        begin
            case (c_funct4)
                `FUNCT4_C_ADD: handle_c_rtype = rs1 + rs2;
                `FUNCT4_C_SUB: handle_c_rtype = rs1 - rs2;
                `FUNCT4_C_XOR: handle_c_rtype = rs1 ^ rs2;
                `FUNCT4_C_OR : handle_c_rtype = rs1 | rs2;
                `FUNCT4_C_AND: handle_c_rtype = rs1 & rs2;
                `FUNCT4_C_SLL: handle_c_rtype = rs1 << rs2[5:0]; // 取低6位作为移位量
                `FUNCT4_C_SRL: handle_c_rtype = rs1 >> rs2[5:0]; // 逻辑右移
                `FUNCT4_C_SRA: handle_c_rtype = $signed(rs1) >>> rs2[5:0]; // 算术右移
                `FUNCT4_C_SLT: handle_c_rtype = ($signed(rs1) < $signed(rs2)) ? 64'd1 : 64'd0;
                `FUNCT4_C_SLTU: handle_c_rtype = (rs1 < rs2) ? 64'd1 : 64'd0;
                default: handle_c_rtype = 64'b0;
            endcase
        end
    endfunction

    // C.I-type 指令处理
    function [DATA_WIDTH-1:0] handle_c_itype;
        input [15:0] instr;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] pc;
        begin
            casez (instr)
                // C.ADDI4SPN (指令格式：000sssss000fffff00)
                16'b000?????000?????: begin
                    // 立即数生成：s[4:0] << 2
                    handle_c_itype = rs1 + {{59{instr[12]}}, instr[12:10], instr[6:2], 2'b00};
                end
                // C.LW (指令格式：?????010?????00)
                16'b?????_010_?????: begin
                    // 地址计算，实际加载在内存阶段处理
                    handle_c_itype = rs1 + {{60{instr[12]}}, instr[12], instr[6:2], 2'b00};
                end
                // C.LD (指令格式：?????011?????00)
                16'b?????_011_?????: begin
                    // 地址计算，实际加载在内存阶段处理
                    handle_c_itype = rs1 + {{59{instr[12]}}, instr[12:10], instr[6:2], 3'b000};
                end
                // C.ADDI (指令格式：001?????000?????00)
                16'b001?????000?????: begin
                    // 立即数是 instr[12:10], instr[6:2]
                    handle_c_itype = rs1 + {{58{instr[12]}}, instr[12:10], instr[6:2]};
                end
                // C.JALR (指令格式：110?????000?????00)
                16'b110?????000?????: begin
                    // 跳转目标计算
                    handle_c_itype = rs1 + {{59{instr[12]}}, instr[12], instr[8], instr[10:9], instr[6], instr[7], 1'b0};
                end
                default: handle_c_itype = 64'b0;
            endcase
        end
    endfunction

    // C.S-type 指令处理
    function [DATA_WIDTH-1:0] handle_c_stype;
        input [15:0] instr;
        input [DATA_WIDTH-1:0] rs1;
        begin
            case (c_funct3)
                `FUNCT3_C_SW: begin
                    // 地址计算，实际存储在内存阶段处理
                    handle_c_stype = rs1 + {{60{instr[12]}}, instr[12], instr[6:2], 2'b00};
                end
                `FUNCT3_C_SD: begin
                    // 地址计算，实际存储在内存阶段处理
                    handle_c_stype = rs1 + {{59{instr[12]}}, instr[12:10], instr[6:2], 3'b000};
                end
                default: handle_c_stype = 64'b0;
            endcase
        end
    endfunction

    // C.B-type 指令处理
    function [DATA_WIDTH-1:0] handle_c_btype;
        input [15:0] instr;
        input [DATA_WIDTH-1:0] pc;
        input [DATA_WIDTH-1:0] rs1;
        begin
            case (c_funct3)
                `FUNCT3_C_BEQZ: begin
                    // 计算分支目标地址
                    if (rs1 == 64'b0) begin
                        handle_c_btype = pc + {{53{instr[12]}}, instr[12], instr[6], instr[10:9], instr[7], instr[8], instr[11], 1'b0};
                    end else begin
                        handle_c_btype = pc + 2; // 继续执行下一条指令
                    end
                end
                `FUNCT3_C_BNEZ: begin
                    // 计算分支目标地址
                    if (rs1 != 64'b0) begin
                        handle_c_btype = pc + {{53{instr[12]}}, instr[12], instr[6], instr[10:9], instr[7], instr[8], instr[11], 1'b0};
                    end else begin
                        handle_c_btype = pc + 2; // 继续执行下一条指令
                    end
                end
                `FUNCT3_C_BLTZ: begin
                    // 计算分支目标地址
                    if ($signed(rs1) < 0) begin
                        handle_c_btype = pc + {{53{instr[12]}}, instr[12], instr[6], instr[10:9], instr[7], instr[8], instr[11], 1'b0};
                    end else begin
                        handle_c_btype = pc + 2; // 继续执行下一条指令
                    end
                end
                `FUNCT3_C_BGEZ: begin
                    // 计算分支目标地址
                    if ($signed(rs1) >= 0) begin
                        handle_c_btype = pc + {{53{instr[12]}}, instr[12], instr[6], instr[10:9], instr[7], instr[8], instr[11], 1'b0};
                    end else begin
                        handle_c_btype = pc + 2; // 继续执行下一条指令
                    end
                end
                default: handle_c_btype = pc + 2; // 默认继续执行下一条指令
            endcase
        end
    endfunction

    // C.JAL 指令处理
    function [DATA_WIDTH-1:0] handle_c_jal;
        input [15:0] instr;
        input [DATA_WIDTH-1:0] pc;
        begin
            // 计算跳转目标地址
            handle_c_jal = pc + {{48{instr[12]}}, instr[12], instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
        end
    endfunction

    // C.LUI 指令处理
    function [DATA_WIDTH-1:0] handle_c_lui;
        input [15:0] instr;
        begin
            // 加载立即数到高位
            handle_c_lui = {{40{instr[12]}}, instr[12:10], instr[6:2], 12'b0};
        end
    endfunction

    // 主处理逻辑
    always @(*) begin
        if (is_c_extension) begin
            case (c_opcode)
                `OPCODE_C_RTYPE: begin
                    // 检查是否是C.R-type指令的特定模式
                    if (instr_16bit[15:13] == 3'b101) begin
                        c_result = handle_c_rtype(c_funct4, rs1_data_i, rs2_data_i);
                    end else begin
                        c_result = 64'b0;
                    end
                end
                `OPCODE_C_ITYPE: begin
                    c_result = handle_c_itype(instr_16bit, rs1_data_i, pc_in_i);
                end
                `OPCODE_C_STYPE: begin
                    c_result = handle_c_stype(instr_16bit, rs1_data_i);
                end
                `OPCODE_C_BTYPE: begin
                    c_result = handle_c_btype(instr_16bit, pc_in_i, rs1_data_i);
                end
                `OPCODE_C_JAL: begin
                    // 检查是否是C.JAL指令的特定模式
                    if (instr_16bit[15:13] == 3'b001) begin
                        c_result = handle_c_jal(instr_16bit, pc_in_i);
                    end else begin
                        c_result = 64'b0;
                    end
                end
                `OPCODE_C_LUI: begin
                    // 检查是否是C.LUI指令的特定模式
                    if (instr_16bit[15:13] == 3'b010) begin
                        c_result = handle_c_lui(instr_16bit);
                    end else begin
                        c_result = 64'b0;
                    end
                end
                default: begin
                    c_result = 64'b0;
                end
            endcase
        end else begin
            c_result = 64'b0;
        end
    end

    // 输出结果
    assign alu_result_o = c_result;

endmodule
`undef RISCV64_C_EXTENSION_V