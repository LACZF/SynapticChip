`include "riscv64_instruction_defs.v"

module riscv64_m_extension #(
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
    output wire                         is_m_extension
);

    // 信号定义
    reg [DATA_WIDTH-1:0] m_result;
    wire [DATA_WIDTH-1:0] mult_result;
    wire [DATA_WIDTH-1:0] div_result;
    wire [DATA_WIDTH-1:0] rem_result;

    // 判断是否为M扩展指令（根据funct7_30和opcode）
    assign is_m_extension = (opcode == `OPCODE_REG_ARITH) && (funct7_30 == 1'b1);

    // 乘法指令处理
    function [DATA_WIDTH-1:0] handle_multiplication;
        input [2:0] funct3;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] rs2;
        // 在函数开始处声明所有需要的中间变量
        reg signed [2*DATA_WIDTH-1:0] signed_wide_result;
        reg [2*DATA_WIDTH-1:0] unsigned_wide_result;
        begin
            case (funct3)
                // MUL: 有符号乘法，取结果的低64位
                `FUNCT3_MUL: handle_multiplication = $signed(rs1) * $signed(rs2);

                // MULH: 有符号乘法，取结果的高64位
                `FUNCT3_MULH: begin
                    signed_wide_result = $signed(rs1) * $signed(rs2);
                    handle_multiplication = signed_wide_result[2*DATA_WIDTH-1:DATA_WIDTH];
                end

                // MULHSU: 无符号乘法（rs1有符号，rs2无符号），取结果的高64位
                `FUNCT3_MULHSU: begin
                    signed_wide_result = $signed(rs1) * $unsigned(rs2);
                    handle_multiplication = signed_wide_result[2*DATA_WIDTH-1:DATA_WIDTH];
                end

                // MULHU: 无符号乘法，取结果的高64位
                `FUNCT3_MULHU: begin
                    unsigned_wide_result = $unsigned(rs1) * $unsigned(rs2);
                    handle_multiplication = unsigned_wide_result[2*DATA_WIDTH-1:DATA_WIDTH];
                end

                default: handle_multiplication = 64'b0;
            endcase
        end
    endfunction

    // 除法指令处理
    function [DATA_WIDTH-1:0] handle_division;
        input [2:0] funct3;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] rs2;
        begin
            case (funct3)
                // DIV: 有符号除法
                `FUNCT3_DIV: begin
                    if (rs2 == 64'b0) begin
                        handle_division = {DATA_WIDTH{1'b1}}; // 除以0时结果为全1
                    end else if (rs1 == {1'b1, {63{1'b0}}} && rs2 == {64{1'b1}}) begin
                        // 特殊情况：-2^63除以-1，结果溢出
                        handle_division = {1'b1, {63{1'b0}}}; // 保持原值
                    end else begin
                        handle_division = $signed(rs1) / $signed(rs2);
                    end
                end

                // DIVU: 无符号除法
                `FUNCT3_DIVU: begin
                    if (rs2 == 64'b0) begin
                        handle_division = {DATA_WIDTH{1'b1}}; // 除以0时结果为全1
                    end else begin
                        handle_division = rs1 / rs2;
                    end
                end

                default: handle_division = 64'b0;
            endcase
        end
    endfunction

    // 取模指令处理
    function [DATA_WIDTH-1:0] handle_remainder;
        input [2:0] funct3;
        input [DATA_WIDTH-1:0] rs1;
        input [DATA_WIDTH-1:0] rs2;
        begin
            case (funct3)
                // REM: 有符号余数
                `FUNCT3_REM: begin
                    if (rs2 == 64'b0) begin
                        handle_remainder = rs1; // 除以0时余数为被除数
                    end else if (rs1 == {1'b1, {63{1'b0}}} && rs2 == {64{1'b1}}) begin
                        // 特殊情况：-2^63除以-1，余数为0
                        handle_remainder = 64'b0;
                    end else begin
                        handle_remainder = $signed(rs1) % $signed(rs2);
                    end
                end

                // REMU: 无符号余数
                `FUNCT3_REMU: begin
                    if (rs2 == 64'b0) begin
                        handle_remainder = rs1; // 除以0时余数为被除数
                    end else begin
                        handle_remainder = rs1 % rs2;
                    end
                end

                default: handle_remainder = 64'b0;
            endcase
        end
    endfunction

    // 根据funct3确定要执行的乘除法操作
    always @(*) begin
        if (is_m_extension) begin
            case (funct3)
                `FUNCT3_MUL, `FUNCT3_MULH, `FUNCT3_MULHSU, `FUNCT3_MULHU: begin
                    m_result = handle_multiplication(funct3, rs1_data_i, rs2_data_i);
                end
                `FUNCT3_DIV, `FUNCT3_DIVU: begin
                    m_result = handle_division(funct3, rs1_data_i, rs2_data_i);
                end
                `FUNCT3_REM, `FUNCT3_REMU: begin
                    m_result = handle_remainder(funct3, rs1_data_i, rs2_data_i);
                end
                default: begin
                    m_result = 64'b0;
                end
            endcase
        end else begin
            m_result = 64'b0;
        end
    end

    // 输出ALU结果
    assign alu_result_o = m_result;

`ifdef DEBUG
    always @(*) begin
        if (is_m_extension) begin
            $display("[M-Extension] Handling instruction: Opcode=%h, funct3=%h, rs1=%h, rs2=%h",
                     opcode, funct3, rs1_data_i, rs2_data_i);
            case (funct3)
                `FUNCT3_MUL: $display("[M-Extension] MUL Result: %h", m_result);
                `FUNCT3_MULH: $display("[M-Extension] MULH Result: %h", m_result);
                `FUNCT3_MULHSU: $display("[M-Extension] MULHSU Result: %h", m_result);
                `FUNCT3_MULHU: $display("[M-Extension] MULHU Result: %h", m_result);
                `FUNCT3_DIV: $display("[M-Extension] DIV Result: %h", m_result);
                `FUNCT3_DIVU: $display("[M-Extension] DIVU Result: %h", m_result);
                `FUNCT3_REM: $display("[M-Extension] REM Result: %h", m_result);
                `FUNCT3_REMU: $display("[M-Extension] REMU Result: %h", m_result);
            endcase
        end
    end
`endif

endmodule