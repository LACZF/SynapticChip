// synaptic_core.v
// 集成PE阵列和路由的Fabric模块

`include "top_system_params.v"

module synaptic_core #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2
) (
    input clk,
    input rst_n,

    // Ring总线接口
    input ring_in_valid,
    input [`NODE_ID_WIDTH-1:0] ring_in_src,
    input [`NODE_ID_WIDTH-1:0] ring_in_dest,
    input [`ADDR_WIDTH-1:0] ring_in_addr,
    input [`DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,

    output ring_out_valid,
    output [`NODE_ID_WIDTH-1:0] ring_out_src,
    output [`NODE_ID_WIDTH-1:0] ring_out_dest,
    output [`ADDR_WIDTH-1:0] ring_out_addr,
    output [`DATA_WIDTH-1:0] ring_out_data,
    output ring_out_we,
    output [3:0] ring_out_be,
    output ring_out_ack,

    // 发送请求
    input  wire [NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire                         rx_req_valid_o,
    output wire                         rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire                         rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [DATA_WIDTH-1:0]        rsp_data_o,

    // 外部接口
    output [`DATA_WIDTH-1:0] fabric_status
);

    // PE控制信号
    wire [`NUM_PES-1:0] pe_enable;
    wire [`NUM_PES-1:0] pe_reset;
    wire [(`NUM_PES*`INST_WIDTH)-1:0] pe_instructions;
    wire pe_inst_valid;

    // PE状态信号
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_status;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_outputs;
    wire [`NUM_PES-1:0] pe_busy;

    // 路由配置信号
    wire [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] route_config;
    wire route_cfg_valid;

    // PE间连接信号
    wire [`NUM_PES-1:0] pe_north_valid;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_north_data;
    wire [`NUM_PES-1:0] pe_north_ready;

    wire [`NUM_PES-1:0] pe_south_valid;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_south_data;
    wire [`NUM_PES-1:0] pe_south_ready;

    wire [`NUM_PES-1:0] pe_east_valid;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_east_data;
    wire [`NUM_PES-1:0] pe_east_ready;

    wire [`NUM_PES-1:0] pe_west_valid;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0] pe_west_data;
    wire [`NUM_PES-1:0] pe_west_ready;

    // 实例化PE控制器
    pe_controller pe_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .ring_in_valid(ring_in_valid),
        .ring_in_src(ring_in_src),
        .ring_in_dest(ring_in_dest),
        .ring_in_addr(ring_in_addr),
        .ring_in_data(ring_in_data),
        .ring_in_we(ring_in_we),
        .ring_in_be(ring_in_be),
        .ring_in_ack(ring_in_ack),
        .ring_out_valid(ring_out_valid),
        .ring_out_src(ring_out_src),
        .ring_out_dest(ring_out_dest),
        .ring_out_addr(ring_out_addr),
        .ring_out_data(ring_out_data),
        .ring_out_we(ring_out_we),
        .ring_out_be(ring_out_be),
        .ring_out_ack(ring_out_ack),
        .pe_enable(pe_enable),
        .pe_reset(pe_reset),
        .pe_instructions(pe_instructions),
        .pe_inst_valid(pe_inst_valid),
        .pe_status(pe_status),
        .pe_outputs(pe_outputs),
        .pe_busy(pe_busy),
        .route_config(route_config),
        .route_cfg_valid(route_cfg_valid)
    );

    // 实例化PE阵列
    genvar i, j;
    generate
        for (i = 0; i < `PE_ARRAY_ROWS; i = i + 1) begin : pe_row
            for (j = 0; j < `PE_ARRAY_COLS; j = j + 1) begin : pe_col
                localparam pe_idx = i * `PE_ARRAY_COLS + j;

                pe_node pe (
                    .clk(clk),
                    .rst_n(rst_n & !pe_reset[pe_idx]),
                    .enable(pe_enable[pe_idx]),
                    .instruction(pe_instructions[pe_idx*`INST_WIDTH +: `INST_WIDTH]),
                    .inst_valid(pe_inst_valid),
                    .north_valid(pe_north_valid[pe_idx]),
                    .north_data(pe_north_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .north_ready(pe_north_ready[pe_idx]),
                    .south_valid(pe_south_valid[pe_idx]),
                    .south_data(pe_south_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .south_ready(pe_south_ready[pe_idx]),
                    .east_valid(pe_east_valid[pe_idx]),
                    .east_data(pe_east_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .east_ready(pe_east_ready[pe_idx]),
                    .west_valid(pe_west_valid[pe_idx]),
                    .west_data(pe_west_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .west_ready(pe_west_ready[pe_idx]),
                    .out_data(pe_outputs[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .out_valid(),
                    .busy(pe_busy[pe_idx]),
                    .status(pe_status[pe_idx*`DATA_WIDTH +: `DATA_WIDTH])
                );
            end
        end
    endgenerate

    // 实例化路由配置模块
    wire [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] north_routes;
    wire [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] south_routes;
    wire [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] east_routes;
    wire [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] west_routes;

    route_config route_cfg (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid(route_cfg_valid),
        .cfg_data(route_config),
        .north_routes(north_routes),
        .south_routes(south_routes),
        .east_routes(east_routes),
        .west_routes(west_routes)
    );

    // 连接PE间的路由
    generate
        for (i = 0; i < `PE_ARRAY_ROWS; i = i + 1) begin : connect_row
            for (j = 0; j < `PE_ARRAY_COLS; j = j + 1) begin : connect_col
                localparam pe_idx = i * `PE_ARRAY_COLS + j;

                // 北向连接
                if (i > 0) begin
                    assign pe_north_valid[pe_idx] = pe_south_valid[(i-1)*`PE_ARRAY_COLS+j];
                    assign pe_north_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_south_data[((i-1)*`PE_ARRAY_COLS+j)*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_south_ready[(i-1)*`PE_ARRAY_COLS+j] = pe_north_ready[pe_idx];
                end else begin
                    assign pe_north_valid[pe_idx] = 1'b0;
                    assign pe_north_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end

                // 南向连接
                if (i < `PE_ARRAY_ROWS-1) begin
                    assign pe_south_valid[pe_idx] = pe_north_valid[(i+1)*`PE_ARRAY_COLS+j];
                    assign pe_south_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_north_data[((i+1)*`PE_ARRAY_COLS+j)*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_north_ready[(i+1)*`PE_ARRAY_COLS+j] = pe_south_ready[pe_idx];
                end else begin
                    assign pe_south_valid[pe_idx] = 1'b0;
                    assign pe_south_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end

                // 东向连接
                if (j < `PE_ARRAY_COLS-1) begin
                    assign pe_east_valid[pe_idx] = pe_west_valid[i*`PE_ARRAY_COLS+(j+1)];
                    assign pe_east_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_west_data[(i*`PE_ARRAY_COLS+(j+1))*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_west_ready[i*`PE_ARRAY_COLS+(j+1)] = pe_east_ready[pe_idx];
                end else begin
                    assign pe_east_valid[pe_idx] = 1'b0;
                    assign pe_east_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end

                // 西向连接
                if (j > 0) begin
                    assign pe_west_valid[pe_idx] = pe_east_valid[i*`PE_ARRAY_COLS+(j-1)];
                    assign pe_west_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_east_data[(i*`PE_ARRAY_COLS+(j-1))*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_east_ready[i*`PE_ARRAY_COLS+(j-1)] = pe_west_ready[pe_idx];
                end else begin
                    assign pe_west_valid[pe_idx] = 1'b0;
                    assign pe_west_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end
            end
        end
    endgenerate

    // 状态输出
    assign fabric_status = {
        pe_busy,        // PE忙碌状态
        pe_enable,      // PE使能状态
        pe_reset        // PE复位状态
    };

endmodule
