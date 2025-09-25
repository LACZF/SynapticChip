// 总线节点模块 - 对接多条Ring总线，为业务模块提供统一接口
module ring_bus_node #(
    parameter NUM_RINGS         = 2,        // Ring总线数量
    parameter ADDR_WIDTH        = 32,       // 地址宽度
    parameter DATA_WIDTH        = 64,       // 数据宽度
    parameter NODE_ID_WIDTH     = 8,        // 节点ID宽度
    parameter MATCH_TYPE_WIDTH  = 2,        // 匹配类型宽度
    parameter TX_FIFO_DEPTH     = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH     = 4         // 接收FIFO深度
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 业务模块接口 - 统一接口
    input  wire                         bus_req_valid,
    input  wire [ADDR_WIDTH-1:0]        bus_req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  bus_req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     bus_req_target_id,
    input  wire [DATA_WIDTH-1:0]        bus_req_data,
    input  wire [NUM_RINGS-1:0]         bus_req_ring_select, // 指定Ring总线
    output wire                         bus_req_ready,

    output wire                         bus_rsp_valid,
    output wire [DATA_WIDTH-1:0]        bus_rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     bus_rsp_src_id,
    output wire [NUM_RINGS-1:0]         bus_rsp_ring_id,
    input  wire                         bus_rsp_ready,

    // Ring总线状态信息
    output wire                         node_busy,
    output wire [NUM_RINGS-1:0]         ring_status,

    // 多条Ring总线接口
    output wire [NUM_RINGS-1:0]         ring_req_valid,
    output wire [ADDR_WIDTH-1:0]        ring_req_addr [NUM_RINGS-1:0],
    output wire [MATCH_TYPE_WIDTH-1:0]  ring_req_match_type [NUM_RINGS-1:0],
    output wire [NODE_ID_WIDTH-1:0]     ring_req_target_id [NUM_RINGS-1:0],
    output wire [DATA_WIDTH-1:0]        ring_req_data [NUM_RINGS-1:0],
    input  wire [NUM_RINGS-1:0]         ring_req_ready,

    input  wire [NUM_RINGS-1:0]         ring_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        ring_rsp_data [NUM_RINGS-1:0],
    input  wire [NODE_ID_WIDTH-1:0]     ring_rsp_src_id [NUM_RINGS-1:0],
    input  wire [NUM_RINGS-1:0]         ring_busy
);

// 匹配类型定义
localparam MATCH_BY_ADDR    = 2'b00;
localparam MATCH_BY_ID      = 2'b01;
localparam MATCH_BROADCAST  = 2'b10;

// 自动选择所有Ring
localparam AUTO_SELECT_ALL = {NUM_RINGS{1'b1}};

// FIFO信号
wire                         tx_fifo_wr_en;
wire                         tx_fifo_rd_en;
wire                         tx_fifo_full;
wire                         tx_fifo_empty;
wire [ADDR_WIDTH-1:0]        tx_fifo_wr_addr;
wire [MATCH_TYPE_WIDTH-1:0]  tx_fifo_wr_match_type;
wire [NODE_ID_WIDTH-1:0]     tx_fifo_wr_target_id;
wire [DATA_WIDTH-1:0]        tx_fifo_wr_data;
wire [NUM_RINGS-1:0]         tx_fifo_wr_ring_select;

wire [ADDR_WIDTH-1:0]        tx_fifo_rd_addr;
wire [MATCH_TYPE_WIDTH-1:0]  tx_fifo_rd_match_type;
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

// 仲裁和选择逻辑
reg [NUM_RINGS-1:0]          ring_priority;
wire [NUM_RINGS-1:0]         available_rings;
wire [NUM_RINGS-1:0]         selected_ring;
reg [NUM_RINGS-1:0]          ring_selection;

// 发送FIFO控制
assign tx_fifo_wr_en = bus_req_valid && bus_req_ready;
assign tx_fifo_wr_addr = bus_req_addr;
assign tx_fifo_wr_match_type = bus_req_match_type;
assign tx_fifo_wr_target_id = bus_req_target_id;
assign tx_fifo_wr_data = bus_req_data;
assign tx_fifo_wr_ring_select = bus_req_ring_select;

assign bus_req_ready = !tx_fifo_full;

// 接收FIFO控制
assign rx_fifo_rd_en = bus_rsp_valid && bus_rsp_ready;
assign bus_rsp_valid = !rx_fifo_empty;
assign bus_rsp_data = rx_fifo_rd_data;
assign bus_rsp_src_id = rx_fifo_rd_src_id;
assign bus_rsp_ring_id = rx_fifo_rd_ring_id;

// Ring总线可用性判断
assign available_rings = ring_req_ready & ~ring_busy;

// Ring选择逻辑
always @(*) begin
    ring_selection = {NUM_RINGS{1'b0}};

    if (!tx_fifo_empty) begin
        if (tx_fifo_rd_ring_select == AUTO_SELECT_ALL) begin
            // 自动选择：使用优先级仲裁
            for (integer i = 0; i < NUM_RINGS; i = i + 1) begin
                if (available_rings[ring_priority]) begin
                    ring_selection[ring_priority] = 1'b1;
                end else begin
                    ring_priority = (ring_priority + 1) % NUM_RINGS;
                end
            end
        end else begin
            // 指定Ring：检查指定Ring是否可用
            ring_selection = tx_fifo_rd_ring_select & available_rings;
        end
    end
end

// 优先级轮转
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ring_priority <= 0;
    end else if (tx_fifo_rd_en && |ring_selection) begin
        ring_priority <= (ring_priority + 1) % NUM_RINGS;
    end
end

// 发送FIFO读使能
assign tx_fifo_rd_en = |ring_selection;

// 生成Ring总线输出
genvar i;
generate
    for (i = 0; i < NUM_RINGS; i = i + 1) begin : ring_output_gen
        assign ring_req_valid[i] = ring_selection[i];
        assign ring_req_addr[i] = tx_fifo_rd_addr;
        assign ring_req_match_type[i] = tx_fifo_rd_match_type;
        assign ring_req_target_id[i] = tx_fifo_rd_target_id;
        assign ring_req_data[i] = tx_fifo_rd_data;
    end
endgenerate

// 响应收集逻辑
reg [NUM_RINGS-1:0] rsp_pending;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rsp_pending <= {NUM_RINGS{1'b0}};
    end else begin
        // 记录哪些Ring有响应待处理
        rsp_pending <= ring_rsp_valid;
    end
end

// 响应FIFO写入控制
assign rx_fifo_wr_en = |ring_rsp_valid;
assign rx_fifo_wr_data = ring_rsp_valid[0] ? ring_rsp_data[0] :
                         ring_rsp_valid[1] ? ring_rsp_data[1] : {DATA_WIDTH{1'b0}};
assign rx_fifo_wr_src_id = ring_rsp_valid[0] ? ring_rsp_src_id[0] :
                           ring_rsp_valid[1] ? ring_rsp_src_id[1] : {NODE_ID_WIDTH{1'b0}};
assign rx_fifo_wr_ring_id = ring_rsp_valid;

// 状态输出
assign node_busy = tx_fifo_full || |ring_busy;
assign ring_status = available_rings;

// 发送FIFO实例化
tx_fifo #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH),
    .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
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

// 发送FIFO模块
module tx_fifo #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter MATCH_TYPE_WIDTH = 2,
    parameter NUM_RINGS = 2,
    parameter FIFO_DEPTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 写入接口
    input  wire                         wr_en,
    input  wire [ADDR_WIDTH-1:0]        wr_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  wr_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     wr_target_id,
    input  wire [DATA_WIDTH-1:0]        wr_data,
    input  wire [NUM_RINGS-1:0]         wr_ring_select,
    output wire                         full,

    // 读取接口
    input  wire                         rd_en,
    output wire [ADDR_WIDTH-1:0]        rd_addr,
    output wire [MATCH_TYPE_WIDTH-1:0]  rd_match_type,
    output wire [NODE_ID_WIDTH-1:0]     rd_target_id,
    output wire [DATA_WIDTH-1:0]        rd_data,
    output wire [NUM_RINGS-1:0]         rd_ring_select,
    output wire                         empty
);

localparam FIFO_WIDTH = ADDR_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + DATA_WIDTH + NUM_RINGS;
localparam FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH);

reg [FIFO_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
reg [FIFO_ADDR_WIDTH-1:0] wr_ptr;
reg [FIFO_ADDR_WIDTH-1:0] rd_ptr;
reg [FIFO_ADDR_WIDTH:0] count;

wire [FIFO_WIDTH-1:0] wr_data_packed;
wire [FIFO_WIDTH-1:0] rd_data_packed;

// 数据打包和解包
assign wr_data_packed = {wr_ring_select, wr_data, wr_target_id, wr_match_type, wr_addr};
assign {rd_ring_select, rd_data, rd_target_id, rd_match_type, rd_addr} = rd_data_packed;

// FIFO控制逻辑
assign full = (count == FIFO_DEPTH);
assign empty = (count == 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count <= 0;
    end else begin
        // 写入逻辑
        if (wr_en && !full) begin
            fifo_mem[wr_ptr] <= wr_data_packed;
            wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
            count <= count + 1;
        end

        // 读取逻辑
        if (rd_en && !empty) begin
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
            count <= count - 1;
        end
    end
end

// 输出数据
assign rd_data_packed = fifo_mem[rd_ptr];

endmodule

// 接收FIFO模块
module rx_fifo #(
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter NUM_RINGS = 2,
    parameter FIFO_DEPTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 写入接口
    input  wire                         wr_en,
    input  wire [DATA_WIDTH-1:0]        wr_data,
    input  wire [NODE_ID_WIDTH-1:0]     wr_src_id,
    input  wire [NUM_RINGS-1:0]         wr_ring_id,
    output wire                         full,

    // 读取接口
    input  wire                         rd_en,
    output wire [DATA_WIDTH-1:0]        rd_data,
    output wire [NODE_ID_WIDTH-1:0]     rd_src_id,
    output wire [NUM_RINGS-1:0]         rd_ring_id,
    output wire                         empty
);

localparam FIFO_WIDTH = DATA_WIDTH + NODE_ID_WIDTH + NUM_RINGS;
localparam FIFO_ADDR_WIDTH = $clog2(FIFO_DEPTH);

reg [FIFO_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
reg [FIFO_ADDR_WIDTH-1:0] wr_ptr;
reg [FIFO_ADDR_WIDTH-1:0] rd_ptr;
reg [FIFO_ADDR_WIDTH:0] count;

wire [FIFO_WIDTH-1:0] wr_data_packed;
wire [FIFO_WIDTH-1:0] rd_data_packed;

// 数据打包和解包
assign wr_data_packed = {wr_ring_id, wr_src_id, wr_data};
assign {rd_ring_id, rd_src_id, rd_data} = rd_data_packed;

// FIFO控制逻辑
assign full = (count == FIFO_DEPTH);
assign empty = (count == 0);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
        rd_ptr <= 0;
        count <= 0;
    end else begin
        // 写入逻辑
        if (wr_en && !full) begin
            fifo_mem[wr_ptr] <= wr_data_packed;
            wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
            count <= count + 1;
        end

        // 读取逻辑
        if (rd_en && !empty) begin
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
            count <= count - 1;
        end
    end
end

// 输出数据
assign rd_data_packed = fifo_mem[rd_ptr];

endmodule

// 业务模块接口包装器 - 简化业务模块的接口
module bus_interface_wrapper #(
    parameter NUM_RINGS = 2,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 简化的业务模块接口
    input  wire                         app_req_valid,
    input  wire [ADDR_WIDTH-1:0]        app_req_addr,
    input  wire [DATA_WIDTH-1:0]        app_req_data,
    input  wire [NODE_ID_WIDTH-1:0]     app_req_target_id,
    input  wire                         app_req_use_id_match, // 1: ID匹配, 0: 地址匹配
    input  wire [NUM_RINGS-1:0]         app_req_ring_select,
    output wire                         app_req_ready,

    output wire                         app_rsp_valid,
    output wire [DATA_WIDTH-1:0]        app_rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     app_rsp_src_id,
    input  wire                         app_rsp_ready,

    // Ring总线节点接口
    output wire                         bus_req_valid,
    output wire [ADDR_WIDTH-1:0]        bus_req_addr,
    output wire [1:0]                   bus_req_match_type,
    output wire [NODE_ID_WIDTH-1:0]     bus_req_target_id,
    output wire [DATA_WIDTH-1:0]        bus_req_data,
    output wire [NUM_RINGS-1:0]         bus_req_ring_select,
    input  wire                         bus_req_ready,

    input  wire                         bus_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        bus_rsp_data,
    input  wire [NODE_ID_WIDTH-1:0]     bus_rsp_src_id,
    input  wire [NUM_RINGS-1:0]         bus_rsp_ring_id,
    output wire                         bus_rsp_ready
);

// 匹配类型生成
wire [1:0] match_type;
assign match_type = app_req_use_id_match ? 2'b01 : 2'b00;

// 直接连接接口
assign bus_req_valid = app_req_valid;
assign bus_req_addr = app_req_addr;
assign bus_req_match_type = match_type;
assign bus_req_target_id = app_req_target_id;
assign bus_req_data = app_req_data;
assign bus_req_ring_select = app_req_ring_select;
assign app_req_ready = bus_req_ready;

assign app_rsp_valid = bus_rsp_valid;
assign app_rsp_data = bus_rsp_data;
assign app_rsp_src_id = bus_rsp_src_id;
assign bus_rsp_ready = app_rsp_ready;

endmodule
