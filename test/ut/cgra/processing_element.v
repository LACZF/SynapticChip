module processing_element #(
    parameter DATA_WIDTH = 32,
    parameter CONFIG_WIDTH = 64,
    parameter NUM_CONTEXTS = 4
)(
    input wire clk,
    input wire rst_n,

    // Configuration
    input wire [1:0] config_context,
    input wire [CONFIG_WIDTH-1:0] config_in,

    // Data Inputs with valid signals
    input wire [DATA_WIDTH-1:0] north_in,
    input wire north_valid_in,
    input wire [DATA_WIDTH-1:0] south_in,
    input wire south_valid_in,
    input wire [DATA_WIDTH-1:0] east_in,
    input wire east_valid_in,
    input wire [DATA_WIDTH-1:0] west_in,
    input wire west_valid_in,
    input wire [DATA_WIDTH-1:0] reg_in,
    input wire reg_valid_in,

    // Output with valid signal
    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_valid_out,

    // Status
    output reg pe_busy
);

// 提取配置字段
wire [3:0] opcode = config_in[3:0];
wire [1:0] src1_sel = config_in[5:4];
wire [1:0] src2_sel = config_in[7:6];
wire use_immediate = config_in[8];
wire [DATA_WIDTH-1:0] immediate = config_in[40:9];
wire [1:0] dest_sel = config_in[42:41];

// 源操作数选择和有效信号
reg [DATA_WIDTH-1:0] src1;
reg src1_valid;
reg [DATA_WIDTH-1:0] src2;
reg src2_valid;

// 内部寄存器文件
reg [DATA_WIDTH-1:0] register_file [0:3];
reg [DATA_WIDTH-1:0] register_valid [0:3];

// ALU结果
reg [DATA_WIDTH-1:0] alu_result;
reg alu_result_valid;

// 源操作数选择逻辑
always @(*) begin
    case (src1_sel)
        2'b00: begin src1 = north_in; src1_valid = north_valid_in; end
        2'b01: begin src1 = south_in; src1_valid = south_valid_in; end
        2'b10: begin src1 = east_in;  src1_valid = east_valid_in;  end
        2'b11: begin src1 = west_in;  src1_valid = west_valid_in;  end
        default: begin src1 = north_in; src1_valid = north_valid_in; end
    endcase

    if (use_immediate) begin
        src2 = immediate;
        src2_valid = 1'b1; // 立即数总是有效的
    end else begin
        case (src2_sel)
            2'b00: begin src2 = north_in; src2_valid = north_valid_in; end
            2'b01: begin src2 = south_in; src2_valid = south_valid_in; end
            2'b10: begin src2 = east_in;  src2_valid = east_valid_in;  end
            2'b11: begin src2 = west_in;  src2_valid = west_valid_in;  end
            default: begin src2 = north_in; src2_valid = north_valid_in; end
        endcase
    end
end

// ALU操作
always @(*) begin
    alu_result_valid = src1_valid && src2_valid; // 只有两个操作数都有效时才计算

    if (alu_result_valid) begin
        case (opcode)
            4'b0000: alu_result = src1 + src2; // ADD
            4'b0001: alu_result = src1 - src2; // SUB
            4'b0010: alu_result = src1 & src2; // AND
            4'b0011: alu_result = src1 | src2; // OR
            4'b0100: alu_result = src1 ^ src2; // XOR
            4'b0101: alu_result = src1 << src2[4:0]; // SHL
            4'b0110: alu_result = src1 >> src2[4:0]; // SHR
            4'b0111: alu_result = $signed(src1) >>> src2[4:0]; // ASHR
            4'b1000: alu_result = (src1 == src2) ? 32'h1 : 32'h0; // EQ
            4'b1001: alu_result = ($signed(src1) < $signed(src2)) ? 32'h1 : 32'h0; // LT
            4'b1010: alu_result = src1; // PASS
            4'b1011: alu_result = register_file[dest_sel]; // REG_READ
            default: alu_result = src1;
        endcase
    end else begin
        alu_result = src1; // 默认值
    end
end

// 检查操作码是否需要寄存器写入
wire opcode_requires_reg_write;
assign opcode_requires_reg_write =
    (opcode == 4'b0000) | (opcode == 4'b0001) | (opcode == 4'b0010) |
    (opcode == 4'b0011) | (opcode == 4'b0100) | (opcode == 4'b0101) |
    (opcode == 4'b0110) | (opcode == 4'b0111) | (opcode == 4'b1000) |
    (opcode == 4'b1001) | (opcode == 4'b1010);

// 主PE流水线
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= {DATA_WIDTH{1'b0}};
        data_valid_out <= 1'b0;
        pe_busy <= 1'b0;

        for (i = 0; i < 4; i = i + 1) begin
            register_file[i] <= {DATA_WIDTH{1'b0}};
            register_valid[i] <= 1'b0;
        end
    end else begin
        // 输出ALU结果
        data_out <= alu_result;
        data_valid_out <= alu_result_valid;

        // 更新PE忙状态
        pe_busy <= src1_valid || src2_valid || data_valid_out;

        // 如果ALU结果有效且需要寄存器写入，则更新寄存器文件
        if (alu_result_valid && opcode_requires_reg_write) begin
            register_file[dest_sel] <= alu_result;
            register_valid[dest_sel] <= 1'b1;
        end

        // 对于寄存器读取操作，需要源寄存器有效
        if (opcode == 4'b1011) begin // REG_READ
            data_valid_out <= register_valid[dest_sel];
        end
    end
end

endmodule