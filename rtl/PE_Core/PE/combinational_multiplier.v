module ip4_combinational_multiplier #(
    parameter DATA_WIDTH = 32
) (
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    output wire [DATA_WIDTH*2-1:0] result
);

    // 使用Wallace树结构优化的组合逻辑乘法器
    // 将32位乘法分解为4个16位乘法，然后组合结果

    wire [15:0] a_low  = a[15:0];
    wire [15:0] a_high = a[31:16];
    wire [15:0] b_low  = b[15:0];
    wire [15:0] b_high = b[31:16];

    // 计算4个16位乘法
    wire [31:0] p_ll = a_low * b_low;
    wire [31:0] p_lh = a_low * b_high;
    wire [31:0] p_hl = a_high * b_low;
    wire [31:0] p_hh = a_high * b_high;

    // 组合结果
    wire [63:0] result_full;
    assign result_full[31:0]  = p_ll[31:0];
    assign result_full[47:32] = p_ll[31:16] + p_lh[15:0] + p_hl[15:0];
    assign result_full[63:48] = p_lh[31:16] + p_hl[31:16] + p_hh[31:0];

    // 处理进位
    wire [15:0] carry1 = (p_ll[31:16] + p_lh[15:0] + p_hl[15:0]) >> 16;
    wire [15:0] carry2 = (p_lh[31:16] + p_hl[31:16] + p_hh[31:0] + carry1) >> 16;

    assign result = {result_full[63:48] + carry1 + carry2, result_full[47:32] + carry1, result_full[31:0]};

endmodule