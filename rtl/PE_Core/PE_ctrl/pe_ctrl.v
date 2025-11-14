module pe_ctrl #(
    parameter DATA_WIDTH        = 32,
    parameter NUM_PES           = 4,
    parameter PE_ARRAY_ROWS     = 2,
    parameter PE_ARRAY_COLS     = 2
) (
    input                       clk,
    input                       rst_n,

    // 控制信号输入
    input  [NUM_PES-1:0]        pe_enable_i,
    input                       start_i,

    // 内存接口
    input  [DATA_WIDTH-1:0]     mem_data_i [0:PE_ARRAY_ROWS+2][0:PE_ARRAY_COLS-1],

    // PE控制信号输出
    output [NUM_PES-1:0]        pe_start_o,
    output [DATA_WIDTH-1:0]     op1_o [0:PE_ARRAY_COLS-1],
    output [DATA_WIDTH-1:0]     op2_o [0:PE_ARRAY_COLS-1],
    output [DATA_WIDTH-1:0]     config_o [0:PE_ARRAY_ROWS-1][0:PE_ARRAY_COLS-1]
);

    // 内部状态
    reg [NUM_PES-1:0] pe_start_reg;

    // 操作数和配置数据分配
    genvar i, j;
    generate
        for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : col_config
            // 第一行：操作数1
            assign op1_o[j] = mem_data_i[0][j];

            // 第二行：操作数2
            assign op2_o[j] = mem_data_i[1][j];

            // 第3行到倒数第二行：配置数据
            for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : row_config
                assign config_o[i][j] = mem_data_i[i+2][j];
            end
        end
    endgenerate

    // PE启动控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_start_reg <= {NUM_PES{1'b0}};
        end else begin
            pe_start_reg <= {NUM_PES{1'b0}}; // 默认清零

            if (start_i) begin
                // 启动所有使能的PE
                pe_start_reg <= pe_enable_i;
            end
        end
    end

    assign pe_start_o = pe_start_reg;

endmodule