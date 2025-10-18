`include "riscv64_instruction_defs.v"

module riscv64_f_extension #(
    parameter DATA_WIDTH = 64
)(
    input wire                  funct7_30,
    input wire [2:0]            funct3,
    input wire [6:0]            opcode,
    input wire [DATA_WIDTH-1:0] rs1_data_i,
    input wire [DATA_WIDTH-1:0] rs2_data_i,
    output wire [DATA_WIDTH-1:0] alu_result_o,
    output wire                 is_f_extension
);

    // 信号定义
    reg [DATA_WIDTH-1:0] f_result;
    wire [31:0]          f32_rs1;  // 单精度浮点操作数1
    wire [31:0]          f32_rs2;  // 单精度浮点操作数2
    reg [31:0]           f32_result; // 单精度浮点结果

    // 从64位整数中提取32位浮点值（假设低位存储）
    assign f32_rs1 = rs1_data_i[31:0];
    assign f32_rs2 = rs2_data_i[31:0];

    // 判断是否为F扩展指令
    assign is_f_extension = (opcode == `OPCODE_FLOAT_ARITH);

    // 浮点算术操作处理
    always @(*) begin
        if (is_f_extension) begin
            case (funct3)
                // 加法操作
                `FUNCT3_FADD_S: begin
                    f32_result = $shortrealtobits($bitstoshortreal(f32_rs1) + $bitstoshortreal(f32_rs2));
                end

                // 减法操作
                `FUNCT3_FSUB_S: begin
                    f32_result = $shortrealtobits($bitstoshortreal(f32_rs1) - $bitstoshortreal(f32_rs2));
                end

                // 乘法操作
                `FUNCT3_FMUL_S: begin
                    f32_result = $shortrealtobits($bitstoshortreal(f32_rs1) * $bitstoshortreal(f32_rs2));
                end

                // 除法操作
                `FUNCT3_FDIV_S: begin
                    f32_result = $shortrealtobits($bitstoshortreal(f32_rs1) / $bitstoshortreal(f32_rs2));
                end

                // 平方根操作
                `FUNCT3_FSQRT_S: begin
                    f32_result = $shortrealtobits($sqrt($bitstoshortreal(f32_rs1)));
                end

                // 浮点比较操作
                `FUNCT3_FCMP_S: begin
                    if ($bitstoshortreal(f32_rs1) < $bitstoshortreal(f32_rs2)) begin
                        f32_result = 32'b1;  // 小于
                    end else if ($bitstoshortreal(f32_rs1) > $bitstoshortreal(f32_rs2)) begin
                        f32_result = 32'b10; // 大于
                    end else if ($bitstoshortreal(f32_rs1) == $bitstoshortreal(f32_rs2)) begin
                        f32_result = 32'b100; // 等于
                    end else begin
                        f32_result = 32'b0;  // 无序
                    end
                end

                // 浮点到整数转换（有符号）
                `FUNCT3_FCVT_W_S: begin
                    f32_result = $signed($rtoi($bitstoshortreal(f32_rs1)));
                end

                // 浮点到整数转换（无符号）
                `FUNCT3_FCVT_WU_S: begin
                    f32_result = $unsigned($rtoi($bitstoshortreal(f32_rs1)));
                end

                // 整数到浮点转换（有符号）
                `FUNCT3_FCVT_S_W: begin
                    f32_result = $shortrealtobits($itor($signed(f32_rs1)));
                end

                // 整数到浮点转换（无符号）
                `FUNCT3_FCVT_S_WU: begin
                    f32_result = $shortrealtobits($itor($unsigned(f32_rs1)));
                end

                default: begin
                    f32_result = 32'b0;
                end
            endcase

            // 将32位浮点结果扩展为64位整数结果
            f_result = {{32{1'b0}}, f32_result};
        end else begin
            f_result = 64'b0;
        end
    end

    // 输出ALU结果
    assign alu_result_o = f_result;

`ifdef DEBUG
    always @(*) begin
        if (is_f_extension) begin
            $display("[F-Extension] Handling instruction: Opcode=%h, funct3=%h", opcode, funct3);
            $display("[F-Extension] rs1=%h (float: %0f), rs2=%h (float: %0f)",
                     f32_rs1, $bitstoshortreal(f32_rs1), f32_rs2, $bitstoshortreal(f32_rs2));
            $display("[F-Extension] Result: %h", f_result);
        end
    end
`endif

endmodule