// pe_top.v
// 集成PE阵列和路由的Fabric模块

`include "top_system_params.v"

module pe_top #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter NUM_PES           = 4,
    parameter INST_WIDTH        = 128,
    parameter PE_ID_WIDTH       = 3,
    parameter PE_ARRAY_ROWS     = `PE_ARRAY_ROWS,
    parameter PE_ARRAY_COLS     = `PE_ARRAY_COLS
) (
    input clk,
    input rst_n,

    input  reg [NUM_PES-1:0]                      pe_enable,
    input  reg [NUM_PES-1:0]                      pe_reset,
    input  reg [(NUM_PES*INST_WIDTH)-1:0]         pe_instructions,
    input  reg                                    pe_inst_valid,
    output     [(NUM_PES*DATA_WIDTH)-1:0]         pe_status,
    output     [(NUM_PES*DATA_WIDTH)-1:0]         pe_outputs,
    output     [NUM_PES-1:0]                      pe_busy,
    input  reg [(NUM_PES*4*PE_ID_WIDTH)-1:0]      route_config,
    input  reg                                    route_cfg_valid,

    output [DATA_WIDTH-1:0]                       fabric_status
);
    // PE间连接信号
    wire [NUM_PES-1:0] pe_north_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_north_data;
    wire [NUM_PES-1:0] pe_north_ready;

    wire [NUM_PES-1:0] pe_south_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_south_data;
    wire [NUM_PES-1:0] pe_south_ready;

    wire [NUM_PES-1:0] pe_east_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_east_data;
    wire [NUM_PES-1:0] pe_east_ready;

    wire [NUM_PES-1:0] pe_west_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_west_data;
    wire [NUM_PES-1:0] pe_west_ready;

    // 实例化PE阵列
    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : pe_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : pe_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;
                pe_node #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .NUM_PES(NUM_PES),
                    .INST_WIDTH(INST_WIDTH),
                    .PE_ID_WIDTH(PE_ID_WIDTH),
                    .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
                    .PE_ARRAY_COLS(PE_ARRAY_COLS)
                ) pe (
                    .clk(clk),
                    .rst_n(rst_n & !pe_reset[pe_idx]),
                    .enable(pe_enable[pe_idx]),
                    .instruction(pe_instructions[pe_idx*INST_WIDTH +: INST_WIDTH]),
                    .inst_valid(pe_inst_valid),
                    .north_valid(pe_north_valid[pe_idx]),
                    .north_data(pe_north_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .north_ready(pe_north_ready[pe_idx]),
                    .south_valid(pe_south_valid[pe_idx]),
                    .south_data(pe_south_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .south_ready(pe_south_ready[pe_idx]),
                    .east_valid(pe_east_valid[pe_idx]),
                    .east_data(pe_east_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .east_ready(pe_east_ready[pe_idx]),
                    .west_valid(pe_west_valid[pe_idx]),
                    .west_data(pe_west_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .west_ready(pe_west_ready[pe_idx]),
                    .out_data(pe_outputs[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .out_valid(),
                    .busy(pe_busy[pe_idx]),
                    .status(pe_status[pe_idx*DATA_WIDTH +: DATA_WIDTH])
                );
            end
        end
    endgenerate

    // 实例化路由配置模块
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] north_routes;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] south_routes;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] east_routes;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] west_routes;

    pe_route_config #(
        .NUM_PES(NUM_PES),
        .PE_ID_WIDTH(PE_ID_WIDTH)
    ) route_cfg (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid(route_cfg_valid),
        .cfg_data(route_config),
        .north_routes(north_routes),
        .south_routes(south_routes),
        .east_routes(east_routes),
        .west_routes(west_routes)
    );

    // PE阵列行列参数已在模块参数中定义

    // 连接PE间的路由
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : connect_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : connect_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;

                // 北向连接
                if (i > 0) begin
                    assign pe_north_valid[pe_idx] = pe_south_valid[(i-1)*PE_ARRAY_COLS+j];
                    assign pe_north_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_south_data[((i-1)*PE_ARRAY_COLS+j)*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_south_ready[(i-1)*PE_ARRAY_COLS+j] = pe_north_ready[pe_idx];
                end else begin
                    assign pe_north_valid[pe_idx] = 1'b0;
                    assign pe_north_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end

                // 南向连接
                if (i < PE_ARRAY_ROWS-1) begin
                    assign pe_south_valid[pe_idx] = pe_north_valid[(i+1)*PE_ARRAY_COLS+j];
                    assign pe_south_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_north_data[((i+1)*PE_ARRAY_COLS+j)*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_north_ready[(i+1)*PE_ARRAY_COLS+j] = pe_south_ready[pe_idx];
                end else begin
                    assign pe_south_valid[pe_idx] = 1'b0;
                    assign pe_south_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end

                // 东向连接
                if (j < PE_ARRAY_COLS-1) begin
                    assign pe_east_valid[pe_idx] = pe_west_valid[i*PE_ARRAY_COLS+(j+1)];
                    assign pe_east_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_west_data[(i*PE_ARRAY_COLS+(j+1))*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_west_ready[i*PE_ARRAY_COLS+(j+1)] = pe_east_ready[pe_idx];
                end else begin
                    assign pe_east_valid[pe_idx] = 1'b0;
                    assign pe_east_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end

                // 西向连接
                if (j > 0) begin
                    assign pe_west_valid[pe_idx] = pe_east_valid[i*PE_ARRAY_COLS+(j-1)];
                    assign pe_west_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_east_data[(i*PE_ARRAY_COLS+(j-1))*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_east_ready[i*PE_ARRAY_COLS+(j-1)] = pe_west_ready[pe_idx];
                end else begin
                    assign pe_west_valid[pe_idx] = 1'b0;
                    assign pe_west_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end
            end
        end
    endgenerate

    // 状态输出
    assign fabric_status = {
        pe_busy,        // PE忙碌状态
        pe_enable       // PE使能状态
    };

endmodule