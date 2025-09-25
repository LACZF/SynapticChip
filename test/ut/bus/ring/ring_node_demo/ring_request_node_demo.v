// Ring总线请求节点 - 发起请求的节点
module ring_request_node #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter NUM_RINGS = 2,
    parameter TX_FIFO_DEPTH = 4,
    parameter RX_FIFO_DEPTH = 4,
    parameter NODE_ID = 0
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 业务模块接口
    input  wire                         req_valid,
    input  wire [ADDR_WIDTH-1:0]        req_addr,
    input  wire [1:0]                   req_match_type,    // 匹配类型
    input  wire [NODE_ID_WIDTH-1:0]     req_target_id,
    input  wire [DATA_WIDTH-1:0]        req_data,
    input  wire [NUM_RINGS-1:0]         req_ring_select,   // 指定Ring总线
    output wire                         req_ready,

    output wire                         rsp_valid,
    output wire [DATA_WIDTH-1:0]        rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     rsp_src_id,
    output wire [NUM_RINGS-1:0]         rsp_ring_id,
    input  wire                         rsp_ready,

    // Ring总线接口 - 上游（来自前一个节点）
    input  wire                         in_req_valid,
    input  wire [ADDR_WIDTH-1:0]        in_req_addr,
    input  wire [1:0]                   in_req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     in_req_target_id,
    input  wire [DATA_WIDTH-1:0]        in_req_data,
    output wire                         in_req_ready,

    // Ring总线接口 - 下游（到下一个节点）
    output wire                         out_req_valid,
    output wire [ADDR_WIDTH-1:0]        out_req_addr,
    output wire [1:0]                   out_req_match_type,
    output wire [NODE_ID_WIDTH-1:0]     out_req_target_id,
    output wire [DATA_WIDTH-1:0]        out_req_data,
    input  wire                         out_req_ready,

    // 响应上游接口
    input  wire                         in_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        in_rsp_data,
    input  wire [NODE_ID_WIDTH-1:0]     in_rsp_src_id,
    input  wire [NUM_RINGS-1:0]         in_rsp_ring_id,

    // 响应下游接口
    output wire                         out_rsp_valid,
    output wire [DATA_WIDTH-1:0]        out_rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     out_rsp_src_id,
    output wire [NUM_RINGS-1:0]         out_rsp_ring_id,

    // 状态输出
    output wire                         node_busy,
    output wire [NUM_RINGS-1:0]         ring_status
);

    // 匹配类型定义
    localparam MATCH_BY_ADDR    = 2'b00;
    localparam MATCH_BY_ID      = 2'b01;
    localparam MATCH_BROADCAST  = 2'b10;

    // FIFO信号
    wire                         tx_fifo_wr_en;
    wire                         tx_fifo_rd_en;
    wire                         tx_fifo_full;
    wire                         tx_fifo_empty;
    wire [ADDR_WIDTH-1:0]        tx_fifo_wr_addr;
    wire [1:0]                   tx_fifo_wr_match_type;
    wire [NODE_ID_WIDTH-1:0]     tx_fifo_wr_target_id;
    wire [DATA_WIDTH-1:0]        tx_fifo_wr_data;
    wire [NUM_RINGS-1:0]         tx_fifo_wr_ring_select;

    wire [ADDR_WIDTH-1:0]        tx_fifo_rd_addr;
    wire [1:0]                   tx_fifo_rd_match_type;
    wire [NODE_ID_WIDTH-1:0]     tx_fifo_rd_target_id;
    wire [DATA_WIDTH-1:0]        tx_fifo_rd_data;
    wire [NUM_RINGS-1:0]         tx_fifo_rd_ring_select;

    wire                         rx_fifo_wr_en;
    wire                         rx_fifo_rd_en;
    wire                         rx_fifo_full;
    wire                         rx_fifo_empty;
    wire [DATA_WIDTH-1:0]        rx_fifo_wr_data;
    wire [NODE_ID_WIDTH-1:0]     rx_fifo_wr_src_id;
    wire [NUM_RINGS-1:0]         rx_fifo_wr_ring_id;

    wire [DATA_WIDTH-1:0]        rx_fifo_rd_data;
    wire [NODE_ID_WIDTH-1:0]     rx_fifo_rd_src_id;
    wire [NUM_RINGS-1:0]         rx_fifo_rd_ring_id;

    // 请求仲裁逻辑
    reg [NUM_RINGS-1:0]          ring_priority;
    wire [NUM_RINGS-1:0]         ring_available;
    reg [NUM_RINGS-1:0]          ring_selected;
    reg                          local_req_active;

    // 发送FIFO控制
    assign tx_fifo_wr_en = req_valid && req_ready;
    assign tx_fifo_wr_addr = req_addr;
    assign tx_fifo_wr_match_type = req_match_type;
    assign tx_fifo_wr_target_id = req_target_id;
    assign tx_fifo_wr_data = req_data;
    assign tx_fifo_wr_ring_select = req_ring_select;

    assign req_ready = !tx_fifo_full;

    // 接收FIFO控制
    assign rx_fifo_rd_en = rsp_valid && rsp_ready;
    assign rsp_valid = !rx_fifo_empty;
    assign rsp_data = rx_fifo_rd_data;
    assign rsp_src_id = rx_fifo_rd_src_id;
    assign rsp_ring_id = rx_fifo_rd_ring_id;

    // Ring总线可用性判断
    assign ring_available = out_req_ready;

    // 请求选择逻辑：本地请求 vs 转发请求
    always @(*) begin
        ring_selected = {NUM_RINGS{1'b0}};
        local_req_active = 1'b0;

        if (!tx_fifo_empty && |ring_available) begin
            if (tx_fifo_rd_ring_select == {NUM_RINGS{1'b1}}) begin
                // 自动选择：使用优先级仲裁
                integer i;
                for (i = 0; i < NUM_RINGS; i = i + 1) begin
                    if (ring_available[ring_priority]) begin
                        ring_selected[ring_priority] = 1'b1;
                        local_req_active = 1'b1;
                    end else begin
                        ring_priority = (ring_priority + 1) % NUM_RINGS;
                    end
                end
            end else begin
                // 指定Ring：检查指定Ring是否可用
                ring_selected = tx_fifo_rd_ring_select & ring_available;
                local_req_active = |ring_selected;
            end
        end
    end

    // 优先级轮转
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ring_priority <= 0;
        end else if (tx_fifo_rd_en && local_req_active) begin
            ring_priority <= (ring_priority + 1) % NUM_RINGS;
        end
    end

    // 发送FIFO读使能
    assign tx_fifo_rd_en = local_req_active;

    // 请求输出选择
    assign out_req_valid = in_req_valid || local_req_active;
    assign out_req_addr = local_req_active ? tx_fifo_rd_addr : in_req_addr;
    assign out_req_match_type = local_req_active ? tx_fifo_rd_match_type : in_req_match_type;
    assign out_req_target_id = local_req_active ? tx_fifo_rd_target_id : in_req_target_id;
    assign out_req_data = local_req_active ? tx_fifo_rd_data : in_req_data;

    assign in_req_ready = out_req_ready && !local_req_active;

    // 响应输入处理
    assign rx_fifo_wr_en = in_rsp_valid;
    assign rx_fifo_wr_data = in_rsp_data;
    assign rx_fifo_wr_src_id = in_rsp_src_id;
    assign rx_fifo_wr_ring_id = in_rsp_ring_id;

    // 响应输出
    assign out_rsp_valid = in_rsp_valid || (rsp_valid && !rx_fifo_rd_en);
    assign out_rsp_data = in_rsp_valid ? in_rsp_data : rx_fifo_rd_data;
    assign out_rsp_src_id = in_rsp_valid ? in_rsp_src_id : rx_fifo_rd_src_id;
    assign out_rsp_ring_id = in_rsp_valid ? in_rsp_ring_id : rx_fifo_rd_ring_id;

    // 状态输出
    assign node_busy = tx_fifo_full || rx_fifo_full;
    assign ring_status = ring_available;

    // 发送FIFO实例化
    tx_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NUM_RINGS(NUM_RINGS),
        .FIFO_DEPTH(TX_FIFO_DEPTH)
    ) u_tx_fifo (
        .clk(clk),
        .rst_n(rst_n),

        .wr_en(tx_fifo_wr_en),
        .wr_addr(tx_fifo_wr_addr),
        .wr_match_type(tx_fifo_wr_match_type),
        .wr_target_id(tx_fifo_wr_target_id),
        .wr_data(tx_fifo_wr_data),
        .wr_ring_select(tx_fifo_wr_ring_select),
        .full(tx_fifo_full),

        .rd_en(tx_fifo_rd_en),
        .rd_addr(tx_fifo_rd_addr),
        .rd_match_type(tx_fifo_rd_match_type),
        .rd_target_id(tx_fifo_rd_target_id),
        .rd_data(tx_fifo_rd_data),
        .rd_ring_select(tx_fifo_rd_ring_select),
        .empty(tx_fifo_empty)
    );

    // 接收FIFO实例化
    rx_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NUM_RINGS(NUM_RINGS),
        .FIFO_DEPTH(RX_FIFO_DEPTH)
    ) u_rx_fifo (
        .clk(clk),
        .rst_n(rst_n),

        .wr_en(rx_fifo_wr_en),
        .wr_data(rx_fifo_wr_data),
        .wr_src_id(rx_fifo_wr_src_id),
        .wr_ring_id(rx_fifo_wr_ring_id),
        .full(rx_fifo_full),

        .rd_en(rx_fifo_rd_en),
        .rd_data(rx_fifo_rd_data),
        .rd_src_id(rx_fifo_rd_src_id),
        .rd_ring_id(rx_fifo_rd_ring_id),
        .empty(rx_fifo_empty)
    );

endmodule