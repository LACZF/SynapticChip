`include "riscv64_instruction_defs.v"

module riscv64_f_extension #(
    parameter DATA_WIDTH = 64
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [DATA_WIDTH-1:0]        pc_in_i,
    input  wire [31:0]                  instr_in_i,
    input  wire [15:0]                  ctrl_in_i,
    input  wire                         funct7_30,
    input  wire [2:0]                   funct3,
    input  wire [6:0]                   opcode,
    input  wire [DATA_WIDTH-1:0]        rs1_data_i,
    input  wire [DATA_WIDTH-1:0]        rs2_data_i,
    output wire [DATA_WIDTH-1:0]        alu_result_o,
    output wire                         is_f_extension
);

    // IEEE 754 单精度浮点数常量定义
    localparam EXP_BITS = 8;
    localparam MAN_BITS = 23;
    localparam EXP_BIAS = 127;
    localparam MAX_EXP = 255;
    localparam ZERO_EXP = 0;
    localparam INF_EXP = 255;
    localparam ZERO_MAN = 23'h000000;

    // 信号定义
    reg [DATA_WIDTH-1:0] f_result;
    wire [31:0]          f32_rs1;  // 单精度浮点操作数1
    wire [31:0]          f32_rs2;  // 单精度浮点操作数2
    reg [31:0]           f32_result; // 单精度浮点结果

    // 浮点数组件提取
    wire sign1 = f32_rs1[31];
    wire [EXP_BITS-1:0] exp1 = f32_rs1[30:23];
    wire [MAN_BITS-1:0] man1 = f32_rs1[22:0];

    wire sign2 = f32_rs2[31];
    wire [EXP_BITS-1:0] exp2 = f32_rs2[30:23];
    wire [MAN_BITS-1:0] man2 = f32_rs2[22:0];

    // 特殊值检测
    wire is_nan1 = (exp1 == MAX_EXP) && (man1 != 0);
    wire is_nan2 = (exp2 == MAX_EXP) && (man2 != 0);
    wire is_inf1 = (exp1 == MAX_EXP) && (man1 == 0);
    wire is_inf2 = (exp2 == MAX_EXP) && (man2 == 0);
    wire is_zero1 = (exp1 == 0) && (man1 == 0);
    wire is_zero2 = (exp2 == 0) && (man2 == 0);

    // 从64位整数中提取32位浮点值（假设低位存储）
    assign f32_rs1 = rs1_data_i[31:0];
    assign f32_rs2 = rs2_data_i[31:0];

    // 判断是否为F扩展指令
    assign is_f_extension = (opcode == `OPCODE_FLOAT_ARITH);

    // 临时变量（模块级别，符合标准Verilog语法）
    reg sign_res;
    reg [EXP_BITS-1:0] exp_res;
    reg [MAN_BITS-1:0] man_res;
    reg [MAN_BITS:0] man_add;
    reg [MAN_BITS:0] man_sub;
    reg [2*MAN_BITS+1:0] man_mul;
    reg [MAN_BITS:0] man_div;
    integer i;
    integer int_result;
    integer uint_result;
    integer temp_int;
    integer temp_uint;

    // 浮点算术操作处理
    always @(*) begin
        if (is_f_extension) begin
            case (funct3)
                // 加法操作
                `FUNCT3_FADD_S: begin
                    if (is_nan1 || is_nan2) begin
                        // NaN + 任何数 = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_inf1 && is_inf2) begin
                        // INF + INF = INF, INF + (-INF) = NaN
                        if (sign1 == sign2) begin
                            f32_result = {sign1, INF_EXP, ZERO_MAN};
                        end else begin
                            f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                        end
                    end else if (is_inf1 || is_inf2) begin
                        // INF + 有限数 = INF
                        f32_result = {is_inf1 ? sign1 : sign2, INF_EXP, ZERO_MAN};
                    end else if (is_zero1) begin
                        // 0 + x = x
                        f32_result = f32_rs2;
                    end else if (is_zero2) begin
                        // x + 0 = x
                        f32_result = f32_rs1;
                    end else begin
                        // 使用位操作实现的简化版单精度加法器
                        // 这里使用简化逻辑，实际的浮点加法需要更复杂的实现
                        sign_res = sign1;
                        if (exp1 > exp2) begin
                            man_add = {1'b1, man1} + ({1'b1, man2} >> (exp1 - exp2));
                            exp_res = exp1;
                        end else if (exp2 > exp1) begin
                            man_add = {1'b1, man2} + ({1'b1, man1} >> (exp2 - exp1));
                            exp_res = exp2;
                        end else begin
                            // 指数相等
                            man_add = {1'b1, man1} + {1'b1, man2};
                            exp_res = exp1;
                            // 处理溢出
                            if (man_add[MAN_BITS+1]) begin
                                man_add = man_add >> 1;
                                exp_res = exp_res + 1;
                            end
                        end
                        // 规范化结果
                        f32_result = {sign_res, exp_res, man_add[MAN_BITS-1:0]};
                    end
                end

                // 减法操作
                `FUNCT3_FSUB_S: begin
                    if (is_nan1 || is_nan2) begin
                        // NaN - 任何数 = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_inf1 && is_inf2) begin
                        // INF - INF = NaN, INF - (-INF) = INF
                        if (sign1 == sign2) begin
                            f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                        end else begin
                            f32_result = {sign1, INF_EXP, ZERO_MAN};
                        end
                    end else if (is_inf1 || is_inf2) begin
                        // INF - 有限数 = INF
                        f32_result = {sign1, INF_EXP, ZERO_MAN};
                    end else if (is_zero1) begin
                        // 0 - x = -x
                        f32_result = {~sign2, exp2, man2};
                    end else if (is_zero2) begin
                        // x - 0 = x
                        f32_result = f32_rs1;
                    end else begin
                        // 使用位操作实现的简化版单精度减法器
                        // 这里使用简化逻辑，实际的浮点减法需要更复杂的实现
                        sign_res = sign1;
                        if (exp1 > exp2) begin
                            man_sub = {1'b1, man1} - ({1'b1, man2} >> (exp1 - exp2));
                            exp_res = exp1;
                        end else if (exp2 > exp1) begin
                            man_sub = {1'b1, man2} - ({1'b1, man1} >> (exp2 - exp1));
                            exp_res = exp2;
                            sign_res = ~sign_res;
                        end else begin
                            // 指数相等
                            if ({1'b1, man1} >= {1'b1, man2}) begin
                                man_sub = {1'b1, man1} - {1'b1, man2};
                                exp_res = exp1;
                            end else begin
                                man_sub = {1'b1, man2} - {1'b1, man1};
                                exp_res = exp1;
                                sign_res = ~sign_res;
                            end
                        end
                        // 规范化结果
                        f32_result = {sign_res, exp_res, man_sub[MAN_BITS-1:0]};
                    end
                end

                // 乘法操作
                `FUNCT3_FMUL_S: begin
                    if (is_nan1 || is_nan2) begin
                        // NaN * 任何数 = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if ((is_zero1 && is_inf2) || (is_inf1 && is_zero2)) begin
                        // 0 * INF = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_zero1 || is_zero2) begin
                        // 0 * x = 0
                        f32_result = {sign1 ^ sign2, ZERO_EXP, ZERO_MAN};
                    end else if (is_inf1 || is_inf2) begin
                        // INF * x = INF
                        f32_result = {sign1 ^ sign2, INF_EXP, ZERO_MAN};
                    end else begin
                        // 使用位操作实现的简化版单精度乘法器
                        sign_res = sign1 ^ sign2;
                        exp_res = exp1 + exp2 - EXP_BIAS;
                        man_mul = {1'b1, man1} * {1'b1, man2};
                        // 规范化结果
                        if (man_mul[2*MAN_BITS+1]) begin
                            man_mul = man_mul >> 1;
                            exp_res = exp_res + 1;
                        end
                        f32_result = {sign_res, exp_res, man_mul[2*MAN_BITS-1:MAN_BITS]};
                    end
                end

                // 除法操作
                `FUNCT3_FDIV_S: begin
                    if (is_nan1 || is_nan2) begin
                        // NaN / 任何数 = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_zero1 && is_zero2) begin
                        // 0 / 0 = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_inf1 && is_inf2) begin
                        // INF / INF = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_zero1) begin
                        // 0 / x = 0
                        f32_result = {sign1 ^ sign2, ZERO_EXP, ZERO_MAN};
                    end else if (is_zero2) begin
                        // x / 0 = INF
                        f32_result = {sign1 ^ sign2, INF_EXP, ZERO_MAN};
                    end else if (is_inf1) begin
                        // INF / x = INF
                        f32_result = {sign1 ^ sign2, INF_EXP, ZERO_MAN};
                    end else if (is_inf2) begin
                        // x / INF = 0
                        f32_result = {sign1 ^ sign2, ZERO_EXP, ZERO_MAN};
                    end else begin
                        // 使用位操作实现的简化版单精度除法器
                        sign_res = sign1 ^ sign2;
                        exp_res = exp1 - exp2 + EXP_BIAS;
                        // 简化的除法实现，实际需要更复杂的逻辑
                        man_div = {1'b1, man1} / {1'b1, man2};
                        f32_result = {sign_res, exp_res, man_div[MAN_BITS-1:0]};
                    end
                end

                // 平方根操作
                `FUNCT3_FSQRT_S: begin
                    if (is_nan1) begin
                        // sqrt(NaN) = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else if (is_inf1) begin
                        // sqrt(INF) = INF
                        f32_result = {1'b0, INF_EXP, ZERO_MAN};
                    end else if (is_zero1) begin
                        // sqrt(0) = 0
                        f32_result = {1'b0, ZERO_EXP, ZERO_MAN};
                    end else if (sign1) begin
                        // sqrt(负数) = NaN
                        f32_result = {1'b0, INF_EXP, 1'b1, {MAN_BITS-1{1'b0}}};
                    end else begin
                        // 使用位操作实现的简化版单精度平方根器
                        // 这里使用近似方法，实际实现需要更复杂的算法
                        sign_res = 1'b0;
                        exp_res = (exp1 - EXP_BIAS) / 2 + EXP_BIAS;
                        if (exp1 % 2 == 1) begin
                            // 对于奇数指数，需要调整尾数
                            man_res = man1 >> 1;
                        end else begin
                            man_res = man1;
                        end
                        f32_result = {sign_res, exp_res, man_res};
                    end
                end

                // 浮点比较操作
                `FUNCT3_FCMP_S: begin
                    if (is_nan1 || is_nan2) begin
                        f32_result = 32'b0;  // 无序
                    end else if (is_zero1 && is_zero2) begin
                        f32_result = 32'b100; // 等于
                    end else if (is_inf1 && is_inf2) begin
                        if (sign1 == sign2) begin
                            f32_result = 32'b100; // 等于
                        end else if (sign1) begin
                            f32_result = 32'b1;  // rs1 < rs2
                        end else begin
                            f32_result = 32'b10; // rs1 > rs2
                        end
                    end else if (is_inf1) begin
                        if (sign1) begin
                            f32_result = 32'b1;  // rs1 < rs2
                        end else begin
                            f32_result = 32'b10; // rs1 > rs2
                        end
                    end else if (is_inf2) begin
                        if (sign2) begin
                            f32_result = 32'b10; // rs1 > rs2
                        end else begin
                            f32_result = 32'b1;  // rs1 < rs2
                        end
                    end else if (is_zero1) begin
                        if (sign2) begin
                            f32_result = 32'b10; // rs1 > rs2
                        end else begin
                            f32_result = 32'b1;  // rs1 < rs2
                        end
                    end else if (is_zero2) begin
                        if (sign1) begin
                            f32_result = 32'b1;  // rs1 < rs2
                        end else begin
                            f32_result = 32'b10; // rs1 > rs2
                        end
                    end else begin
                        // 简化的比较逻辑
                        if (sign1 != sign2) begin
                            f32_result = sign1 ? 32'b1 : 32'b10; // 符号不同时，负的较小
                        end else if (exp1 != exp2) begin
                            if (sign1) begin
                                f32_result = (exp1 > exp2) ? 32'b1 : 32'b10; // 负数时，指数小的较大
                            end else begin
                                f32_result = (exp1 < exp2) ? 32'b1 : 32'b10; // 正数时，指数小的较小
                            end
                        end else if (man1 != man2) begin
                            if (sign1) begin
                                f32_result = (man1 > man2) ? 32'b1 : 32'b10; // 负数时，尾数小的较大
                            end else begin
                                f32_result = (man1 < man2) ? 32'b1 : 32'b10; // 正数时，尾数小的较小
                            end
                        end else begin
                            f32_result = 32'b100; // 等于
                        end
                    end
                end

                // 浮点到整数转换（有符号）
                `FUNCT3_FCVT_W_S: begin
                    if (is_nan1 || is_inf1) begin
                        // NaN或INF转换为最大整数
                        f32_result = 32'h80000000; // 最小负整数
                    end else if (is_zero1) begin
                        f32_result = 32'b0;
                    end else begin
                        // 简化的转换逻辑
                        int_result = 0;
                        if (!sign1) begin
                            // 正数
                            for (i = 0; i < MAN_BITS; i = i + 1) begin
                                if (man1[i]) begin
                                    int_result = int_result + (1 << (i + exp1 - EXP_BIAS - MAN_BITS));
                                end
                            end
                            int_result = int_result + (1 << (exp1 - EXP_BIAS));
                        end else begin
                            // 负数
                            for (i = 0; i < MAN_BITS; i = i + 1) begin
                                if (man1[i]) begin
                                    int_result = int_result - (1 << (i + exp1 - EXP_BIAS - MAN_BITS));
                                end
                            end
                            int_result = int_result - (1 << (exp1 - EXP_BIAS));
                        end
                        f32_result = int_result;
                    end
                end

                // 浮点到整数转换（无符号）
                `FUNCT3_FCVT_WU_S: begin
                    if (is_nan1 || is_inf1 || sign1) begin
                        // NaN、INF或负数转换为最大无符号整数
                        f32_result = 32'hFFFFFFFF;
                    end else if (is_zero1) begin
                        f32_result = 32'b0;
                    end else begin
                        // 简化的无符号转换逻辑
                        uint_result = 0;
                        for (i = 0; i < MAN_BITS; i = i + 1) begin
                            if (man1[i]) begin
                                uint_result = uint_result + (1 << (i + exp1 - EXP_BIAS - MAN_BITS));
                            end
                        end
                        uint_result = uint_result + (1 << (exp1 - EXP_BIAS));
                        f32_result = uint_result;
                    end
                end

                // 整数到浮点转换（有符号）
                `FUNCT3_FCVT_S_W: begin
                    if (f32_rs1 == 32'b0) begin
                        f32_result = {1'b0, ZERO_EXP, ZERO_MAN};
                    end else begin
                        sign_res = f32_rs1[31];
                        // 简化的转换逻辑
                        temp_int = $signed(f32_rs1);
                        if (temp_int < 0) temp_int = -temp_int; // 取绝对值

                        // 找出最高有效位的位置
                        exp_res = 0;
                        for (i = 30; i >= 0; i = i - 1) begin
                            if (temp_int[i] && (exp_res == 0)) begin
                                exp_res = i + EXP_BIAS;
                            end
                        end

                        // 提取尾数
                        if (exp_res > 0) begin
                            man_res = temp_int << (MAN_BITS - (exp_res - EXP_BIAS));
                        end else begin
                            man_res = temp_int >> (EXP_BIAS - exp_res);
                        end

                        f32_result = {sign_res, exp_res, man_res[MAN_BITS-1:0]};
                    end
                end

                // 整数到浮点转换（无符号）
                `FUNCT3_FCVT_S_WU: begin
                    if (f32_rs1 == 32'b0) begin
                        f32_result = {1'b0, ZERO_EXP, ZERO_MAN};
                    end else begin
                        sign_res = 1'b0;
                        // 简化的无符号转换逻辑
                        temp_uint = $unsigned(f32_rs1);

                        // 找出最高有效位的位置
                        exp_res = 0;
                        for (i = 31; i >= 0; i = i - 1) begin
                            if (temp_uint[i] && (exp_res == 0)) begin
                                exp_res = i + EXP_BIAS;
                            end
                        end

                        // 提取尾数
                        if (exp_res > 0) begin
                            man_res = temp_uint << (MAN_BITS - (exp_res - EXP_BIAS));
                        end else begin
                            man_res = temp_uint >> (EXP_BIAS - exp_res);
                        end

                        f32_result = {sign_res, exp_res, man_res[MAN_BITS-1:0]};
                    end
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
            $display("[F-Extension] rs1=%h, rs2=%h", f32_rs1, f32_rs2);
            $display("[F-Extension] Result: %h", f_result);
        end
    end
`endif

endmodule