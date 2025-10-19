`include "riscv64_instruction_defs.v"

module riscv64_d_extension #(
    parameter DATA_WIDTH = 64
)(
    input wire                  funct7_30,
    input wire [2:0]            funct3,
    input wire [6:0]            opcode,
    input wire [DATA_WIDTH-1:0] rs1_data_i,
    input wire [DATA_WIDTH-1:0] rs2_data_i,
    output wire [DATA_WIDTH-1:0] alu_result_o,
    output wire                 is_d_extension
);

    // 信号定义
    reg [DATA_WIDTH-1:0] d_result;

    // 判断是否为D扩展指令
    assign is_d_extension = (opcode == `OPCODE_DOUBLE_ARITH);

    // 浮点算术操作处理
    always @(*) begin
        if (is_d_extension) begin
            case (funct3)
                // 加法操作
                `FUNCT3_FADD_D: begin
                    d_result = $realtobits($bitstoreal(rs1_data_i) + $bitstoreal(rs2_data_i));
                end

                // 减法操作
                `FUNCT3_FSUB_D: begin
                    d_result = $realtobits($bitstoreal(rs1_data_i) - $bitstoreal(rs2_data_i));
                end

                // 乘法操作
                `FUNCT3_FMUL_D: begin
                    d_result = $realtobits($bitstoreal(rs1_data_i) * $bitstoreal(rs2_data_i));
                end

                // 除法操作
                `FUNCT3_FDIV_D: begin
                    d_result = $realtobits($bitstoreal(rs1_data_i) / $bitstoreal(rs2_data_i));
                end

                // 平方根操作
                `FUNCT3_FSQRT_D: begin
                    d_result = $realtobits($sqrt($bitstoreal(rs1_data_i)));
                end

                // 浮点比较操作
                `FUNCT3_FCMP_D: begin
                    if ($bitstoreal(rs1_data_i) < $bitstoreal(rs2_data_i)) begin
                        d_result = 64'b1;  // 小于
                    end else if ($bitstoreal(rs1_data_i) > $bitstoreal(rs2_data_i)) begin
                        d_result = 64'b10; // 大于
                    end else if ($bitstoreal(rs1_data_i) == $bitstoreal(rs2_data_i)) begin
                        d_result = 64'b100; // 等于
                    end else begin
                        d_result = 64'b0;  // 无序
                    end
                end

                // 双精度浮点到64位整数转换（有符号）
                `FUNCT3_FCVT_L_D: begin
                    d_result = $signed($rtoi($bitstoreal(rs1_data_i)));
                end

                // 双精度浮点到64位整数转换（无符号）
                `FUNCT3_FCVT_LU_D: begin
                    d_result = $unsigned($rtoi($bitstoreal(rs1_data_i)));
                end

                // 64位整数到双精度浮点转换（有符号）
                `FUNCT3_FCVT_D_L: begin
                    d_result = $realtobits($itor($signed(rs1_data_i)));
                end

                // 64位整数到双精度浮点转换（无符号）
                `FUNCT3_FCVT_D_LU: begin
                    d_result = $realtobits($itor($unsigned(rs1_data_i)));
                end

                // 单精度到双精度转换
                `FUNCT3_FCVT_D_S: begin
                    d_result = $realtobits($itor($bitstoshortreal(rs1_data_i[31:0])));
                end

                // 双精度到单精度转换
                `FUNCT3_FCVT_S_D: begin
                    d_result = {{32{1'b0}}, $shortrealtobits($bitstoreal(rs1_data_i))};
                end

                default: begin
                    d_result = 64'b0;
                end
            endcase
        end else begin
            d_result = 64'b0;
        end
    end

    // 输出ALU结果
    assign alu_result_o = d_result;

`ifdef DEBUG
    always @(*) begin
        if (is_d_extension) begin
            $display("[D-Extension] Handling instruction: Opcode=%h, funct3=%h", opcode, funct3);
            $display("[D-Extension] rs1=%h (double: %0f), rs2=%h (double: %0f)",
                     rs1_data_i, $bitstoreal(rs1_data_i), rs2_data_i, $bitstoreal(rs2_data_i));
            $display("[D-Extension] Result: %h", d_result);
        end
    end
`endif

endmodule