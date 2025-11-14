module pe_router #(
    parameter DATA_WIDTH    = 32,
    parameter PE_ARRAY_ROWS = 2,
    parameter PE_ARRAY_COLS = 2
) (
    input                      clk,
    input                      rst_n,

    // PE计算结果输入
    input [PE_ARRAY_ROWS*PE_ARRAY_COLS-1:0]             pe_done_i,
    input [PE_ARRAY_ROWS*PE_ARRAY_COLS*DATA_WIDTH-1:0]  pe_result_i,

    // 路由配置输入（来自内存）
    input [PE_ARRAY_ROWS*PE_ARRAY_COLS*DATA_WIDTH-1:0]  route_config_i,

    // PE数据输出
    output [PE_ARRAY_ROWS*PE_ARRAY_COLS*DATA_WIDTH-1:0] pe_data_o
);

    // 路由方向定义
    localparam DIR_NONE  = 2'b00;
    localparam DIR_NORTH = 2'b01;
    localparam DIR_SOUTH = 2'b10;
    localparam DIR_EAST  = 2'b11;
    localparam DIR_WEST  = 2'b11;

    // 内部数据寄存器
    reg [DATA_WIDTH-1:0] data_buffer [0:PE_ARRAY_ROWS-1][0:PE_ARRAY_COLS-1];

    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : col
                localparam pe_idx = i * PE_ARRAY_COLS + j;

                // 路由配置解析
                wire [1:0] route_dir = route_config_i[pe_idx*DATA_WIDTH+4:pe_idx*DATA_WIDTH+3];
                wire route_enable = route_config_i[pe_idx*DATA_WIDTH+5];

                // 路由逻辑
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        data_buffer[i][j] <= {DATA_WIDTH{1'b0}};
                    end else begin
                        // 如果PE计算完成且路由使能，则进行数据传输
                        if (pe_done_i[pe_idx] && route_enable) begin
                            case (route_dir)
                                DIR_NORTH: begin
                                    if (i > 0) begin
                                        data_buffer[i-1][j] <= pe_result_i[pe_idx*DATA_WIDTH +: DATA_WIDTH];
                                    end
                                end
                                DIR_SOUTH: begin
                                    if (i < PE_ARRAY_ROWS-1) begin
                                        data_buffer[i+1][j] <= pe_result_i[pe_idx*DATA_WIDTH +: DATA_WIDTH];
                                    end
                                end
                                DIR_EAST: begin
                                    if (j < PE_ARRAY_COLS-1) begin
                                        data_buffer[i][j+1] <= pe_result_i[pe_idx*DATA_WIDTH +: DATA_WIDTH];
                                    end
                                end
                                DIR_WEST: begin
                                    if (j > 0) begin
                                        data_buffer[i][j-1] <= pe_result_i[pe_idx*DATA_WIDTH +: DATA_WIDTH];
                                    end
                                end
                                default: begin
                                    // 不路由，数据保留在原地
                                    data_buffer[i][j] <= pe_result_i[pe_idx*DATA_WIDTH +: DATA_WIDTH];
                                end
                            endcase
                        end
                    end
                end

                // 输出连接
                assign pe_data_o[pe_idx*DATA_WIDTH +: DATA_WIDTH] = data_buffer[i][j];
            end
        end
    endgenerate

endmodule