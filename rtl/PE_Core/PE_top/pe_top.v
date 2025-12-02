module ip4_pe_top #(
    parameter PE_ARRAY_X = 4,
    parameter PE_ARRAY_Y = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter HIGH_BW_DW = 320  // 高带宽数据宽度
)(
    input wire                   clk,
    input wire                   rst_n,

    // OBI Bus Interface - 更新为32位地址
    input  wire                  req_i,
    input  wire                  we_i,
    input  wire [31:0]           addr_i,
    input  wire [DATA_WIDTH-1:0] wdata_i,
    output wire                  gnt_o,
    output wire                  rvalid_o,
    output wire [DATA_WIDTH-1:0] rdata_o,

    // 高带宽内存接口（直接与RAM对接）
    output wire                  mem_req_o,
    output wire                  mem_we_o,
    output wire [31:0]           mem_addr_o,
    output wire [HIGH_BW_DW-1:0] mem_data_o,
    input  wire                  mem_ack_i,
    input  wire [HIGH_BW_DW-1:0] mem_data_i
);

    // Internal signals - 简化信号连接
    wire                  start_computation;
    wire                  computation_done;

    // PE array signals - 使用一维数组表示二维结构
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_result;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand1;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand2;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_config;

    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 pe_result_valid;

    // 高带宽内存接口信号直接连接到模块接口

    // Inter-PE connections
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] north_in;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] south_in;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] east_in;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] west_in;

    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 north_valid_in;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 south_valid_in;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 east_valid_in;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 west_valid_in;

    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] north_out;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] south_out;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] east_out;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] west_out;

    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 north_valid_out;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 south_valid_out;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 east_valid_out;
    wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 west_valid_out;

    // Instantiate combined control and memory module - 集成版本
    ip4_pe_control #(
        .PE_ARRAY_X(PE_ARRAY_X),
        .PE_ARRAY_Y(PE_ARRAY_Y),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .HIGH_BW_DW(HIGH_BW_DW)
    ) u_pe_control (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(req_i),
        .we_i(we_i),
        .addr_i(addr_i),
        .wdata_i(wdata_i),
        .gnt_o(gnt_o),
        .rvalid_o(rvalid_o),
        .rdata_o(rdata_o),
        .start_computation(start_computation),
        .computation_done(computation_done),
        .high_bw_req_o(mem_req_o),
        .high_bw_we_o(mem_we_o),
        .high_bw_addr_o(mem_addr_o),
        .high_bw_data_o(mem_data_o),
        .high_bw_ack_i(mem_ack_i),
        .high_bw_data_i(mem_data_i),
        .pe_result(pe_result),
        .pe_result_valid(pe_result_valid),
        .pe_operand1(pe_operand1),
        .pe_operand2(pe_operand2),
        .pe_config(pe_config)
    );

    // Instantiate PE array with individual routing
    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_X; i = i + 1) begin : pe_row
            for (j = 0; j < PE_ARRAY_Y; j = j + 1) begin : pe_col
                localparam idx = i * PE_ARRAY_Y + j;

                // PE module
                ip4_pe #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable(1'b1),  // PE默认使能
                    .start(start_computation),
                    .operand1(pe_operand1[idx]),
                    .operand2(pe_operand2[idx]),
                    .config_data(pe_config[idx]),
                    .north_in(north_in[idx]),
                    .south_in(south_in[idx]),
                    .east_in(east_in[idx]),
                    .west_in(west_in[idx]),
                    .north_valid_in(north_valid_in[idx]),
                    .south_valid_in(south_valid_in[idx]),
                    .east_valid_in(east_valid_in[idx]),
                    .west_valid_in(west_valid_in[idx]),
                    .result(pe_result[idx]),
                    .result_valid(pe_result_valid[idx])
                );

                // Individual routing module for each PE
                ip4_pe_router #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_pe_route (
                    .clk(clk),
                    .rst_n(rst_n),
                    .pe_result_i(pe_result[idx]),
                    .pe_result_valid_i(pe_result_valid[idx]),
                    .pe_config_i(pe_config[idx]),
                    .north_out_o(north_out[idx]),
                    .south_out_o(south_out[idx]),
                    .east_out_o(east_out[idx]),
                    .west_out_o(west_out[idx]),
                    .north_valid_out_o(north_valid_out[idx]),
                    .south_valid_out_o(south_valid_out[idx]),
                    .east_valid_out_o(east_valid_out[idx]),
                    .west_valid_out_o(west_valid_out[idx])
                );
            end
        end
    endgenerate

    // Connect inter-PE routing
    generate
        for (i = 0; i < PE_ARRAY_X; i = i + 1) begin : connect_row
            for (j = 0; j < PE_ARRAY_Y; j = j + 1) begin : connect_col
                localparam idx       = i * PE_ARRAY_Y + j;
                localparam north_idx = (i > 0) ? (i-1)*PE_ARRAY_Y + j : 0;
                localparam south_idx = (i < PE_ARRAY_X-1) ? (i+1)*PE_ARRAY_Y + j : 0;
                localparam east_idx  = (j < PE_ARRAY_Y-1) ? i*PE_ARRAY_Y + (j+1) : 0;
                localparam west_idx  = (j > 0) ? i*PE_ARRAY_Y + (j-1) : 0;

                // Connect to North PE (if exists)
                if (i > 0) begin
                    assign north_in[idx]       = south_out[north_idx];
                    assign north_valid_in[idx] = south_valid_out[north_idx];
                end else begin
                    assign north_in[idx]       = {DATA_WIDTH{1'b0}};
                    assign north_valid_in[idx] = 1'b0;
                end

                // Connect to South PE (if exists)
                if (i < PE_ARRAY_X-1) begin
                    assign south_in[idx]       = north_out[south_idx];
                    assign south_valid_in[idx] = north_valid_out[south_idx];
                end else begin
                    assign south_in[idx]       = {DATA_WIDTH{1'b0}};
                    assign south_valid_in[idx] = 1'b0;
                end

                // Connect to East PE (if exists)
                if (j < PE_ARRAY_Y-1) begin
                    assign east_in[idx]       = west_out[east_idx];
                    assign east_valid_in[idx] = west_valid_out[east_idx];
                end else begin
                    assign east_in[idx]       = {DATA_WIDTH{1'b0}};
                    assign east_valid_in[idx] = 1'b0;
                end

                // Connect to West PE (if exists)
                if (j > 0) begin
                    assign west_in[idx]       = east_out[west_idx];
                    assign west_valid_in[idx] = east_valid_out[west_idx];
                end else begin
                    assign west_in[idx]       = {DATA_WIDTH{1'b0}};
                    assign west_valid_in[idx] = 1'b0;
                end
            end
        end
    endgenerate

    // Computation done logic - 修复数组索引问题
    wire all_pe_valid;
    generate
        if (PE_ARRAY_X * PE_ARRAY_Y > 1) begin
            // 对于多个PE的情况，使用按位与
            wire [PE_ARRAY_X*PE_ARRAY_Y-1:0] pe_valid_bits;
            for (genvar k = 0; k < PE_ARRAY_X*PE_ARRAY_Y; k = k + 1) begin
                assign pe_valid_bits[k] = pe_result_valid[k];
            end
            assign all_pe_valid = &pe_valid_bits;
        end else begin
            // 对于单个PE的情况
            assign all_pe_valid = pe_result_valid[0];
        end
    endgenerate

    assign computation_done = all_pe_valid;

endmodule