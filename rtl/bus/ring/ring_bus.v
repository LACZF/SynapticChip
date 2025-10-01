`include "ring_bus_params.v"

module ring_bus #(
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 4,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
) (
    input  wire                                   clk,
    input  wire                                   rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // 发送请求
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
    input  wire [NUM_NODES-1:0]                   tx_req_valid_i,
    input  wire [NUM_NODES-1:0]                   tx_req_is_order_i,
    input  wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire [NUM_NODES-1:0]                   rx_req_valid_o,
    output wire [NUM_NODES-1:0]                   rx_req_is_order_o,
    output wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire [NUM_NODES-1:0]                   rsp_valid_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data_o,

    // Ring总线状态
    output wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id_o,
    output wire [NUM_RINGS-1:0]                   ring_busy
);
    // 内部信号定义
    wire [NUM_RINGS-1:0]                             ring_req_valid;
    wire [NUM_RINGS-1:0]                             ring_req_ready;
    wire [NUM_RINGS*ADDR_WIDTH-1:0]                  ring_req_addr;
    wire [NUM_RINGS*MATCH_TYPE_WIDTH-1:0]            ring_req_match_type;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]               ring_req_source_id;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]               ring_req_target_id;
    wire [NUM_RINGS*DATA_WIDTH-1:0]                  ring_req_data;
    wire [NUM_RINGS*RING_ID_WIDTH-1:0]               ring_id;
    wire [NUM_RINGS-1:0]                             ring_busy_int;

    // 增加内部信号，用于每条总线的请求和响应
    wire [NUM_RINGS*NUM_NODES-1:0]                   ring_rx_req_valid;
    wire [NUM_RINGS*NUM_NODES-1:0]                   ring_rx_req_is_order;
    wire [NUM_RINGS*NUM_NODES*OPCODE_WIDTH-1:0]      ring_rx_req_opcode;
    wire [NUM_RINGS*NUM_NODES*MATCH_TYPE_WIDTH-1:0]  ring_rx_req_match_type;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rx_req_source_id;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rx_req_target_id;
    wire [NUM_RINGS*NUM_NODES*ADDR_WIDTH-1:0]        ring_rx_req_addr;
    wire [NUM_RINGS*NUM_NODES*DATA_WIDTH-1:0]        ring_rx_req_data;

    wire [NUM_RINGS*NUM_NODES-1:0]                   ring_rsp_valid;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rsp_source_id;
    wire [NUM_RINGS*NUM_NODES*NODE_ID_WIDTH-1:0]     ring_rsp_target_id;
    wire [NUM_RINGS*NUM_NODES*ADDR_WIDTH-1:0]        ring_rsp_addr;
    wire [NUM_RINGS*NUM_NODES*DATA_WIDTH-1:0]        ring_rsp_data;

    // 每个节点的仲裁器实例化
    generate
        genvar j, r;
        for (j = 0; j < NUM_NODES; j = j + 1) begin : node_arbiter_gen
            // 为每个节点创建临时信号，用于连接仲裁器的2D数组端口
            wire [NUM_RINGS-1:0]          node_ring_req_valid;
            wire [NUM_RINGS-1:0]          node_ring_req_ready;
            wire [NUM_RINGS-1:0]          node_ring_busy;
            wire [ADDR_WIDTH-1:0]         node_ring_req_addr [NUM_RINGS-1:0];
            wire [MATCH_TYPE_WIDTH-1:0]   node_ring_req_match_type [NUM_RINGS-1:0];
            wire [NODE_ID_WIDTH-1:0]      node_ring_req_target_id [NUM_RINGS-1:0];
            wire [DATA_WIDTH-1:0]         node_ring_req_data [NUM_RINGS-1:0];
            wire [RING_ID_WIDTH-1:0]      node_ring_id [NUM_RINGS-1:0];

            ring_arbiter #(
                .NUM_RINGS(NUM_RINGS),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
            ) node_arbiter (
                .clk(clk),
                .rst_n(rst_n),

                // 主请求接口
                .req_valid(tx_req_valid_i[j]),
                .req_addr(tx_req_addr_i[j*ADDR_WIDTH +: ADDR_WIDTH]),
                .req_match_type(tx_req_match_type_i[j*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
                .req_target_id(tx_req_target_id_i[j*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
                .req_data(tx_req_data_i[j*DATA_WIDTH +: DATA_WIDTH]),
                .req_ring_mask(tx_req_ring_mask_i[j*NUM_RINGS +: NUM_RINGS]),
                .req_ring_disable(tx_req_ring_disable_i[j*NUM_RINGS +: NUM_RINGS]),
                .req_ready(/* 预留 */),

                // Ring总线接口
                .ring_req_valid(node_ring_req_valid),
                .ring_req_ready(node_ring_req_ready),
                .ring_req_addr(node_ring_req_addr),
                .ring_req_match_type(node_ring_req_match_type),
                .ring_req_target_id(node_ring_req_target_id),
                .ring_req_data(node_ring_req_data),

                // 状态输出
                .ring_busy(node_ring_busy)
            );

            // 将节点仲裁器的2D数组端口转换为1D向量信号
            for (r = 0; r < NUM_RINGS; r = r + 1) begin : ring_signal_gen
                // 使用逻辑OR合并来自所有节点的请求有效信号
                assign ring_req_valid[r] = ring_req_valid[r] | node_ring_req_valid[r];
                // 将2D数组端口数据映射到1D向量
                assign ring_req_addr[r*ADDR_WIDTH +: ADDR_WIDTH] = node_ring_req_addr[r];
                assign ring_req_match_type[r*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] = node_ring_req_match_type[r];
                assign ring_req_target_id[r*NODE_ID_WIDTH +: NODE_ID_WIDTH] = node_ring_req_target_id[r];
                assign ring_req_data[r*DATA_WIDTH +: DATA_WIDTH] = node_ring_req_data[r];
                // 总线忙状态也需要合并
                assign ring_busy_int[r] = ring_busy_int[r] | node_ring_busy[r];
            end
        end
    endgenerate

    // 实例化多条ring_single_bus总线
    generate
        genvar i;
        for (i = 0; i < NUM_RINGS; i = i + 1) begin : ring_single_bus_gen
            ring_single_bus #(
                .NUM_NODES(NUM_NODES),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .OPCODE_WIDTH(OPCODE_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
                .RING_ID_WIDTH(RING_ID_WIDTH),
                .RING_ID(i)
            ) ring_single_bus_inst (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i),
                .node_end_addr_i(node_end_addr_i),

                // 发送请求 - 从仲裁器获取
                .tx_req_valid_i({{(NUM_NODES-1){1'b0}}, ring_req_valid[i]}),  // 仅设置第一个节点为有效
                .tx_req_is_order_i({{(NUM_NODES-1){1'b0}}, 1'b0}),  // 全部设置为非顺序
                .tx_req_opcode_i({{(NUM_NODES-1)*OPCODE_WIDTH{1'b0}}, {OPCODE_WIDTH{1'b0}}}),  // 全部设置为0
                .tx_req_match_type_i({{(NUM_NODES-1)*MATCH_TYPE_WIDTH{1'b0}}, {MATCH_TYPE_WIDTH{1'b0}}}),  // 全部设置为0
                .tx_req_source_id_i({{(NUM_NODES-1)*NODE_ID_WIDTH{1'b0}}, {NODE_ID_WIDTH{1'b0}}}),  // 全部设置为0
                .tx_req_target_id_i({{(NUM_NODES-1)*NODE_ID_WIDTH{1'b0}}, {NODE_ID_WIDTH{1'b0}}}),  // 全部设置为0
                .tx_req_addr_i({{(NUM_NODES-1)*ADDR_WIDTH{1'b0}}, ring_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH]}),  // 仅第一个节点有地址
                .tx_req_data_i({{(NUM_NODES-1)*DATA_WIDTH{1'b0}}, ring_req_data[i*DATA_WIDTH +: DATA_WIDTH]}),  // 仅第一个节点有数据,

                // 接受请求 - 连接到内部信号，而不是直接连接到输出
                .rx_req_valid_o(ring_rx_req_valid[i*NUM_NODES +: NUM_NODES]),
                .rx_req_is_order_o(ring_rx_req_is_order[i*NUM_NODES +: NUM_NODES]),
                .rx_req_opcode_o(ring_rx_req_opcode[i*NUM_NODES*OPCODE_WIDTH +: NUM_NODES*OPCODE_WIDTH]),
                .rx_req_match_type_o(ring_rx_req_match_type[i*NUM_NODES*MATCH_TYPE_WIDTH +: NUM_NODES*MATCH_TYPE_WIDTH]),
                .rx_req_source_id_o(ring_rx_req_source_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rx_req_target_id_o(ring_rx_req_target_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rx_req_addr_o(ring_rx_req_addr[i*NUM_NODES*ADDR_WIDTH +: NUM_NODES*ADDR_WIDTH]),
                .rx_req_data_o(ring_rx_req_data[i*NUM_NODES*DATA_WIDTH +: NUM_NODES*DATA_WIDTH]),

                // 接收响应 - 连接到内部信号，而不是直接连接到输出
                .rsp_valid_o(ring_rsp_valid[i*NUM_NODES +: NUM_NODES]),
                .rsp_source_id_o(ring_rsp_source_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rsp_target_id_o(ring_rsp_target_id[i*NUM_NODES*NODE_ID_WIDTH +: NUM_NODES*NODE_ID_WIDTH]),
                .rsp_addr_o(ring_rsp_addr[i*NUM_NODES*ADDR_WIDTH +: NUM_NODES*ADDR_WIDTH]),
                .rsp_data_o(ring_rsp_data[i*NUM_NODES*DATA_WIDTH +: NUM_NODES*DATA_WIDTH]),

                .ring_busy_o(ring_busy_int[i])
            );
        end
    endgenerate

    // 修正genvar定义位置
    genvar k;
    genvar m;

    // 在node_cache_gen generate块外部定义rsp_fifo_rd_en信号
    generate
        // 先定义共享信号
        wire [NUM_NODES-1:0][NUM_RINGS-1:0] rsp_fifo_rd_en;

        for (k = 0; k < NUM_NODES; k = k + 1) begin : node_cache_gen
            // 定义FIFO输入输出信号
            wire [NUM_RINGS-1:0] node_ring_rx_valid;
            wire [NUM_RINGS-1:0] node_ring_rsp_valid;
            wire [NUM_RINGS-1:0] rx_fifo_wr_en;
            wire [NUM_RINGS-1:0] rsp_fifo_wr_en;
            wire [NUM_RINGS-1:0] rx_fifo_full;
            wire [NUM_RINGS-1:0] rsp_fifo_full;

            // 为每个节点的每个总线创建响应FIFO
            wire [NUM_RINGS-1:0] rsp_fifo_empty;
            wire [NUM_RINGS*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH)-1:0] rsp_fifo_data;

            // 为每个节点的每个总线创建请求FIFO
            wire [NUM_RINGS-1:0] rx_fifo_empty;
            wire [NUM_RINGS*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH)-1:0] rx_fifo_data;

            // 请求FIFO的读取控制逻辑
            wire [NUM_RINGS-1:0] rx_fifo_rd_en;
            reg [RING_ID_WIDTH-1:0] selected_rx_fifo;

            // 响应FIFO的读取控制逻辑
            reg [RING_ID_WIDTH-1:0] selected_rsp_fifo;

            // 提取当前节点来自各总线的有效信号
            for (m = 0; m < NUM_RINGS; m = m + 1) begin : node_valid_gen
                assign node_ring_rx_valid[m] = ring_rx_req_valid[m*NUM_NODES + k];
                assign node_ring_rsp_valid[m] = ring_rsp_valid[m*NUM_NODES + k];
                // 当FIFO未满且有有效数据时，写入FIFO
                assign rx_fifo_wr_en[m] = node_ring_rx_valid[m] && !rx_fifo_full[m];
                assign rsp_fifo_wr_en[m] = node_ring_rsp_valid[m] && !rsp_fifo_full[m];
            end

            for (m = 0; m < NUM_RINGS; m = m + 1) begin : rx_fifo_gen
                // 组合请求数据信号
                wire [OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH-1:0] rx_req_combined;
                assign rx_req_combined = {
                    ring_rx_req_opcode[m*NUM_NODES*OPCODE_WIDTH + k*OPCODE_WIDTH +: OPCODE_WIDTH],
                    ring_rx_req_match_type[m*NUM_NODES*MATCH_TYPE_WIDTH + k*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH],
                    ring_rx_req_source_id[m*NUM_NODES*NODE_ID_WIDTH + k*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    ring_rx_req_target_id[m*NUM_NODES*NODE_ID_WIDTH + k*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    ring_rx_req_addr[m*NUM_NODES*ADDR_WIDTH + k*ADDR_WIDTH +: ADDR_WIDTH],
                    ring_rx_req_data[m*NUM_NODES*DATA_WIDTH + k*DATA_WIDTH +: DATA_WIDTH]
                };

                // 实例化请求FIFO
                simple_fifo #(
                    .DATA_WIDTH(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH),
                    .FIFO_DEPTH(RX_FIFO_DEPTH)
                ) rx_fifo (
                    .clk(clk),
                    .rst_n(rst_n),
                    .wr_en(rx_fifo_wr_en[m]),
                    .data_in(rx_req_combined),
                    .full(rx_fifo_full[m]),
                    .rd_en(rx_fifo_rd_en[m]),
                    .data_out(rx_fifo_data[m*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +:
                             OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH]),
                    .empty(rx_fifo_empty[m])
                );
            end

            for (m = 0; m < NUM_RINGS; m = m + 1) begin : rsp_fifo_gen
                // 组合响应数据信号
                wire [2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH-1:0] rsp_combined;
                assign rsp_combined = {
                    ring_rsp_source_id[m*NUM_NODES*NODE_ID_WIDTH + k*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    ring_rsp_target_id[m*NUM_NODES*NODE_ID_WIDTH + k*NODE_ID_WIDTH +: NODE_ID_WIDTH],
                    ring_rsp_addr[m*NUM_NODES*ADDR_WIDTH + k*ADDR_WIDTH +: ADDR_WIDTH],
                    ring_rsp_data[m*NUM_NODES*DATA_WIDTH + k*DATA_WIDTH +: DATA_WIDTH]
                };

                // 实例化响应FIFO
                simple_fifo #(
                    .DATA_WIDTH(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH),
                    .FIFO_DEPTH(RSP_FIFO_DEPTH)
                ) rsp_fifo (
                    .clk(clk),
                    .rst_n(rst_n),
                    .wr_en(rsp_fifo_wr_en[m]),
                    .data_in(rsp_combined),
                    .full(rsp_fifo_full[m]),
                    // 使用正确的作用域路径
                    .rd_en(rsp_fifo_rd_en[k][m]),
                    .data_out(rsp_fifo_data[m*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +: 2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH]),
                    .empty(rsp_fifo_empty[m])
                );

            end

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    selected_rx_fifo <= 0;
                end else begin
                    // 轮询查找非空的FIFO
                    for (integer m = 0; m < NUM_RINGS; m = m + 1) begin
                        if (!rx_fifo_empty[(selected_rx_fifo + m) % NUM_RINGS]) begin
                            selected_rx_fifo <= (selected_rx_fifo + m) % NUM_RINGS;
                            break;
                        end
                    end
                end
            end

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    selected_rsp_fifo <= 0;
                end else begin
                    // 轮询查找非空的FIFO
                    for (integer m = 0; m < NUM_RINGS; m = m + 1) begin
                        if (!rsp_fifo_empty[(selected_rsp_fifo + m) % NUM_RINGS]) begin
                            selected_rsp_fifo <= (selected_rsp_fifo + m) % NUM_RINGS;
                            break;
                        end
                    end
                end
            end

            // 生成读取使能信号
            assign rx_fifo_rd_en = (1 << selected_rx_fifo) & {NUM_RINGS{!rx_fifo_empty[selected_rx_fifo]}};
            // 修复：使用正确的二维数组索引
            assign rsp_fifo_rd_en[k] = (1 << selected_rsp_fifo) & {NUM_RINGS{!rsp_fifo_empty[selected_rsp_fifo]}};

            // 输出请求数据
            assign rx_req_valid_o[k] = !rx_fifo_empty[selected_rx_fifo];
            assign rx_req_is_order_o[k] = ring_rx_req_is_order[selected_rx_fifo*NUM_NODES + k];
            assign rx_req_opcode_o[k*OPCODE_WIDTH +: OPCODE_WIDTH] =
                rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +: OPCODE_WIDTH];
            assign rx_req_match_type_o[k*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] =
                rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH +: MATCH_TYPE_WIDTH];
            assign rx_req_source_id_o[k*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH +: NODE_ID_WIDTH];
            assign rx_req_target_id_o[k*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH +: NODE_ID_WIDTH];
            assign rx_req_addr_o[k*ADDR_WIDTH +: ADDR_WIDTH] =
                rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH + 2*NODE_ID_WIDTH +: ADDR_WIDTH];
            assign rx_req_data_o[k*DATA_WIDTH +: DATA_WIDTH] =
                rx_fifo_data[selected_rx_fifo*(OPCODE_WIDTH+MATCH_TYPE_WIDTH+2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + OPCODE_WIDTH + MATCH_TYPE_WIDTH + 2*NODE_ID_WIDTH + ADDR_WIDTH +: DATA_WIDTH];

            // 输出响应数据
            assign rsp_valid_o[k] = !rsp_fifo_empty[selected_rsp_fifo];
            assign rsp_source_id_o[k*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) +: NODE_ID_WIDTH];
            assign rsp_target_id_o[k*NODE_ID_WIDTH +: NODE_ID_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + NODE_ID_WIDTH +: NODE_ID_WIDTH];
            assign rsp_addr_o[k*ADDR_WIDTH +: ADDR_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + 2*NODE_ID_WIDTH +: ADDR_WIDTH];
            assign rsp_data_o[k*DATA_WIDTH +: DATA_WIDTH] =
                rsp_fifo_data[selected_rsp_fifo*(2*NODE_ID_WIDTH+ADDR_WIDTH+DATA_WIDTH) + 2*NODE_ID_WIDTH + ADDR_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // 输出信号赋值
    assign ring_id_o = ring_id;
    assign ring_busy = ring_busy_int;

endmodule