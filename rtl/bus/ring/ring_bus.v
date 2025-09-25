// Ring总线模块
module ring_bus #(
    parameter NUM_RINGS     = 2,        // Ring总线数量
    parameter NUM_NODES     = 4,        // 每个Ring的节点数
    parameter ADDR_WIDTH    = 32,       // 地址宽度
    parameter DATA_WIDTH    = 64,       // 数据宽度
    parameter NODE_ID_WIDTH = 8,        // 节点ID宽度
    parameter MATCH_TYPE_WIDTH = 2      // 匹配类型宽度
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 主接口 - 发送请求
    input  wire                         req_valid,
    input  wire [ADDR_WIDTH-1:0]        req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     req_target_id,
    input  wire [DATA_WIDTH-1:0]        req_data,
    input  wire [NUM_RINGS-1:0]         req_ring_mask,      // 指定使用的Ring
    input  wire [NUM_RINGS-1:0]         req_ring_disable,   // 禁用的Ring

    output wire                         req_ready,

    // 从接口 - 接收响应
    output wire                         rsp_valid,
    output wire [DATA_WIDTH-1:0]        rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     rsp_src_id,
    output wire [NUM_RINGS-1:0]         rsp_ring_id,

    // Ring总线状态
    output wire [NUM_RINGS-1:0]         ring_busy
);

// 匹配类型定义
localparam MATCH_BY_ADDR  = 2'b00;  // 地址匹配
localparam MATCH_BY_ID    = 2'b01;  // ID匹配
localparam MATCH_BROADCAST = 2'b10; // 广播

// Ring总线内部信号
wire [NUM_RINGS-1:0] ring_req_valid;
wire [NUM_RINGS-1:0] ring_req_ready;
wire [ADDR_WIDTH-1:0] ring_req_addr [NUM_RINGS-1:0];
wire [MATCH_TYPE_WIDTH-1:0] ring_req_match_type [NUM_RINGS-1:0];
wire [NODE_ID_WIDTH-1:0] ring_req_target_id [NUM_RINGS-1:0];
wire [DATA_WIDTH-1:0] ring_req_data [NUM_RINGS-1:0];

wire [NUM_RINGS-1:0] ring_rsp_valid;
wire [DATA_WIDTH-1:0] ring_rsp_data [NUM_RINGS-1:0];
wire [NODE_ID_WIDTH-1:0] ring_rsp_src_id [NUM_RINGS-1:0];

// 仲裁器
ring_arbiter #(
    .NUM_RINGS(NUM_RINGS)
) u_arbiter (
    .clk(clk),
    .rst_n(rst_n),

    .req_valid(req_valid),
    .req_addr(req_addr),
    .req_match_type(req_match_type),
    .req_target_id(req_target_id),
    .req_data(req_data),
    .req_ring_mask(req_ring_mask),
    .req_ring_disable(req_ring_disable),
    .req_ready(req_ready),

    .ring_req_valid(ring_req_valid),
    .ring_req_ready(ring_req_ready),
    .ring_req_addr(ring_req_addr),
    .ring_req_match_type(ring_req_match_type),
    .ring_req_target_id(ring_req_target_id),
    .ring_req_data(ring_req_data),

    .ring_busy(ring_busy)
);

// 响应选择器
rsp_selector #(
    .NUM_RINGS(NUM_RINGS),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH)
) u_rsp_selector (
    .clk(clk),
    .rst_n(rst_n),

    .ring_rsp_valid(ring_rsp_valid),
    .ring_rsp_data(ring_rsp_data),
    .ring_rsp_src_id(ring_rsp_src_id),

    .rsp_valid(rsp_valid),
    .rsp_data(rsp_data),
    .rsp_src_id(rsp_src_id),
    .rsp_ring_id(rsp_ring_id)
);

// 生成多条Ring总线
genvar i;
generate
    for (i = 0; i < NUM_RINGS; i = i + 1) begin : ring_gen
        single_ring #(
            .NUM_NODES(NUM_NODES),
            .ADDR_WIDTH(ADDR_WIDTH),
            .DATA_WIDTH(DATA_WIDTH),
            .NODE_ID_WIDTH(NODE_ID_WIDTH),
            .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
            .RING_ID(i)
        ) u_single_ring (
            .clk(clk),
            .rst_n(rst_n),

            .req_valid(ring_req_valid[i]),
            .req_addr(ring_req_addr[i]),
            .req_match_type(ring_req_match_type[i]),
            .req_target_id(ring_req_target_id[i]),
            .req_data(ring_req_data[i]),
            .req_ready(ring_req_ready[i]),

            .rsp_valid(ring_rsp_valid[i]),
            .rsp_data(ring_rsp_data[i]),
            .rsp_src_id(ring_rsp_src_id[i]),

            .ring_busy(ring_busy[i])
        );
    end
endgenerate

endmodule

// 仲裁器模块
module ring_arbiter #(
    parameter NUM_RINGS = 2,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter MATCH_TYPE_WIDTH = 2
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 主请求接口
    input  wire                         req_valid,
    input  wire [ADDR_WIDTH-1:0]        req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     req_target_id,
    input  wire [DATA_WIDTH-1:0]        req_data,
    input  wire [NUM_RINGS-1:0]         req_ring_mask,
    input  wire [NUM_RINGS-1:0]         req_ring_disable,
    output wire                         req_ready,

    // Ring总线接口
    output reg  [NUM_RINGS-1:0]         ring_req_valid,
    input  wire [NUM_RINGS-1:0]         ring_req_ready,
    output reg  [ADDR_WIDTH-1:0]        ring_req_addr [NUM_RINGS-1:0],
    output reg  [MATCH_TYPE_WIDTH-1:0]  ring_req_match_type [NUM_RINGS-1:0],
    output reg  [NODE_ID_WIDTH-1:0]     ring_req_target_id [NUM_RINGS-1:0],
    output reg  [DATA_WIDTH-1:0]        ring_req_data [NUM_RINGS-1:0],

    // 状态输出
    output wire [NUM_RINGS-1:0]         ring_busy
);

reg [NUM_RINGS-1:0] ring_priority;
reg [NUM_RINGS-1:0] valid_rings;
wire [NUM_RINGS-1:0] available_rings;

// 计算可用的Ring总线
assign available_rings = ring_req_ready & ~req_ring_disable;

// 优先级仲裁逻辑
always @(*) begin
    ring_req_valid = {NUM_RINGS{1'b0}};
    valid_rings = available_rings & req_ring_mask;

    if (req_valid && |valid_rings) begin
        // 优先级仲裁
        for (integer i = 0; i < NUM_RINGS; i = i + 1) begin
            if (valid_rings[ring_priority]) begin
                ring_req_valid[ring_priority] = 1'b1;
            end else begin
                ring_priority = (ring_priority + 1) % NUM_RINGS;
            end
        end
    end
end

// 输出数据到选中的Ring总线
always @(*) begin
    for (integer i = 0; i < NUM_RINGS; i = i + 1) begin
        ring_req_addr[i] = req_addr;
        ring_req_match_type[i] = req_match_type;
        ring_req_target_id[i] = req_target_id;
        ring_req_data[i] = req_data;
    end
end

// 就绪信号
assign req_ready = |(ring_req_valid & ring_req_ready);

// 优先级轮转
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ring_priority <= 0;
    end else if (req_valid && req_ready) begin
        ring_priority <= (ring_priority + 1) % NUM_RINGS;
    end
end

// 总线忙状态
assign ring_busy = ~ring_req_ready;

endmodule

// 单条Ring总线模块
module single_ring #(
    parameter NUM_NODES = 4,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter MATCH_TYPE_WIDTH = 2,
    parameter RING_ID = 0
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 外部接口
    input  wire                         req_valid,
    input  wire [ADDR_WIDTH-1:0]        req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     req_target_id,
    input  wire [DATA_WIDTH-1:0]        req_data,
    output wire                         req_ready,

    output wire                         rsp_valid,
    output wire [DATA_WIDTH-1:0]        rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     rsp_src_id,

    output wire                         ring_busy
);

// Ring节点内部连接
wire [NUM_NODES-1:0] node_req_valid;
wire [NUM_NODES-1:0] node_req_ready;
wire [ADDR_WIDTH-1:0] node_req_addr [NUM_NODES-1:0];
wire [MATCH_TYPE_WIDTH-1:0] node_req_match_type [NUM_NODES-1:0];
wire [NODE_ID_WIDTH-1:0] node_req_target_id [NUM_NODES-1:0];
wire [DATA_WIDTH-1:0] node_req_data [NUM_NODES-1:0];

wire [NUM_NODES-1:0] node_rsp_valid;
wire [DATA_WIDTH-1:0] node_rsp_data [NUM_NODES-1:0];
wire [NODE_ID_WIDTH-1:0] node_rsp_src_id [NUM_NODES-1:0];

// 输入控制器
ring_input_ctrl u_input_ctrl (
    .clk(clk),
    .rst_n(rst_n),

    .ext_req_valid(req_valid),
    .ext_req_addr(req_addr),
    .ext_req_match_type(req_match_type),
    .ext_req_target_id(req_target_id),
    .ext_req_data(req_data),
    .ext_req_ready(req_ready),

    .node_req_valid(node_req_valid[0]),
    .node_req_addr(node_req_addr[0]),
    .node_req_match_type(node_req_match_type[0]),
    .node_req_target_id(node_req_target_id[0]),
    .node_req_data(node_req_data[0]),
    .node_req_ready(node_req_ready[0])
);

// 生成Ring节点
genvar i;
generate
    for (i = 0; i < NUM_NODES; i = i + 1) begin : node_gen
        ring_node #(
            .ADDR_WIDTH(ADDR_WIDTH),
            .DATA_WIDTH(DATA_WIDTH),
            .NODE_ID_WIDTH(NODE_ID_WIDTH),
            .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
            .NODE_ID(i)
        ) u_node (
            .clk(clk),
            .rst_n(rst_n),

            // .in_req_valid(i == 0 ? node_req_valid[0] : node_req_valid[i]),
            // .in_req_addr(i == 0 ? node_req_addr[0] : node_req_addr[i]),
            // .in_req_match_type(i == 0 ? node_req_match_type[0] : node_req_match_type[i]),
            // .in_req_target_id(i == 0 ? node_req_target_id[0] : node_req_target_id[i]),
            // .in_req_data(i == 0 ? node_req_data[0] : node_req_data[i]),
            // .in_req_ready(i == 0 ? node_req_ready[0] : node_req_ready[i]),

            .in_req_valid(node_req_valid[i]),
            .in_req_addr(node_req_addr[i]),
            .in_req_match_type(node_req_match_type[i]),
            .in_req_target_id(node_req_target_id[i]),
            .in_req_data(node_req_data[i]),
            .in_req_ready(node_req_ready[i]),

            .out_req_valid(node_req_valid[(i+1)%NUM_NODES]),
            .out_req_addr(node_req_addr[(i+1)%NUM_NODES]),
            .out_req_match_type(node_req_match_type[(i+1)%NUM_NODES]),
            .out_req_target_id(node_req_target_id[(i+1)%NUM_NODES]),
            .out_req_data(node_req_data[(i+1)%NUM_NODES]),
            .out_req_ready(node_req_ready[(i+1)%NUM_NODES]),

            .in_rsp_valid(node_rsp_valid[i]),
            .in_rsp_data(node_rsp_data[i]),
            .in_rsp_src_id(node_rsp_src_id[i]),

            .out_rsp_valid(node_rsp_valid[(i+1)%NUM_NODES]),
            .out_rsp_data(node_rsp_data[(i+1)%NUM_NODES]),
            .out_rsp_src_id(node_rsp_src_id[(i+1)%NUM_NODES])
        );
    end
endgenerate

// 输出控制器
ring_output_ctrl u_output_ctrl (
    .clk(clk),
    .rst_n(rst_n),

    .node_rsp_valid(node_rsp_valid[0]),
    .node_rsp_data(node_rsp_data[0]),
    .node_rsp_src_id(node_rsp_src_id[0]),

    .ext_rsp_valid(rsp_valid),
    .ext_rsp_data(rsp_data),
    .ext_rsp_src_id(rsp_src_id)
);

assign ring_busy = ~req_ready;

endmodule

// Ring节点模块
module ring_node #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter MATCH_TYPE_WIDTH = 2,
    parameter NODE_ID = 0
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 上游接口
    input  wire                         in_req_valid,
    input  wire [ADDR_WIDTH-1:0]        in_req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  in_req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     in_req_target_id,
    input  wire [DATA_WIDTH-1:0]        in_req_data,
    output wire                         in_req_ready,

    // 下游接口
    output wire                         out_req_valid,
    output wire [ADDR_WIDTH-1:0]        out_req_addr,
    output wire [MATCH_TYPE_WIDTH-1:0]  out_req_match_type,
    output wire [NODE_ID_WIDTH-1:0]     out_req_target_id,
    output wire [DATA_WIDTH-1:0]        out_req_data,
    input  wire                         out_req_ready,

    // 响应上游接口
    input  wire                         in_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        in_rsp_data,
    input  wire [NODE_ID_WIDTH-1:0]     in_rsp_src_id,

    // 响应下游接口
    output wire                         out_rsp_valid,
    output wire [DATA_WIDTH-1:0]        out_rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     out_rsp_src_id
);

// 地址匹配逻辑
wire address_match;
wire id_match;
wire is_broadcast;
wire packet_for_me;

assign address_match = (in_req_match_type == 2'b00) &&
                      (in_req_addr >= NODE_ID * 16 && in_req_addr < (NODE_ID + 1) * 16);
assign id_match = (in_req_match_type == 2'b01) && (in_req_target_id == NODE_ID);
assign is_broadcast = (in_req_match_type == 2'b10);
assign packet_for_me = address_match || id_match || is_broadcast;

// 本地处理逻辑
reg local_processing;
reg [DATA_WIDTH-1:0] local_rsp_data;

// 请求转发逻辑
assign out_req_valid = in_req_valid && !packet_for_me && !local_processing;
assign out_req_addr = in_req_addr;
assign out_req_match_type = in_req_match_type;
assign out_req_target_id = in_req_target_id;
assign out_req_data = in_req_data;

assign in_req_ready = out_req_ready || packet_for_me;

// 本地处理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        local_processing <= 1'b0;
        local_rsp_data <= {DATA_WIDTH{1'b0}};
    end else if (in_req_valid && packet_for_me && in_req_ready) begin
        local_processing <= 1'b1;
        // 模拟处理延迟
        local_rsp_data <= in_req_data + NODE_ID;
    end else if (local_processing) begin
        local_processing <= 1'b0;
    end
end

// 响应生成
reg rsp_valid;
reg [DATA_WIDTH-1:0] rsp_data;
reg [NODE_ID_WIDTH-1:0] rsp_src_id;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rsp_valid <= 1'b0;
        rsp_data <= {DATA_WIDTH{1'b0}};
        rsp_src_id <= {NODE_ID_WIDTH{1'b0}};
    end else if (local_processing) begin
        rsp_valid <= 1'b1;
        rsp_data <= local_rsp_data;
        rsp_src_id <= NODE_ID;
    end else begin
        rsp_valid <= 1'b0;
    end
end

// 响应转发
assign out_rsp_valid = in_rsp_valid || rsp_valid;
assign out_rsp_data = rsp_valid ? rsp_data : in_rsp_data;
assign out_rsp_src_id = rsp_valid ? rsp_src_id : in_rsp_src_id;

endmodule

// 输入控制器
module ring_input_ctrl #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter MATCH_TYPE_WIDTH = 2
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 外部接口
    input  wire                         ext_req_valid,
    input  wire [ADDR_WIDTH-1:0]        ext_req_addr,
    input  wire [MATCH_TYPE_WIDTH-1:0]  ext_req_match_type,
    input  wire [NODE_ID_WIDTH-1:0]     ext_req_target_id,
    input  wire [DATA_WIDTH-1:0]        ext_req_data,
    output wire                         ext_req_ready,

    // 节点接口
    output wire                         node_req_valid,
    output wire [ADDR_WIDTH-1:0]        node_req_addr,
    output wire [MATCH_TYPE_WIDTH-1:0]  node_req_match_type,
    output wire [NODE_ID_WIDTH-1:0]     node_req_target_id,
    output wire [DATA_WIDTH-1:0]        node_req_data,
    input  wire                         node_req_ready
);

reg req_pending;
reg [ADDR_WIDTH-1:0] pending_addr;
reg [MATCH_TYPE_WIDTH-1:0] pending_match_type;
reg [NODE_ID_WIDTH-1:0] pending_target_id;
reg [DATA_WIDTH-1:0] pending_data;

assign node_req_valid = ext_req_valid || req_pending;
assign node_req_addr = req_pending ? pending_addr : ext_req_addr;
assign node_req_match_type = req_pending ? pending_match_type : ext_req_match_type;
assign node_req_target_id = req_pending ? pending_target_id : ext_req_target_id;
assign node_req_data = req_pending ? pending_data : ext_req_data;

assign ext_req_ready = node_req_ready && !req_pending;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        req_pending <= 1'b0;
        pending_addr <= {ADDR_WIDTH{1'b0}};
        pending_match_type <= {MATCH_TYPE_WIDTH{1'b0}};
        pending_target_id <= {NODE_ID_WIDTH{1'b0}};
        pending_data <= {DATA_WIDTH{1'b0}};
    end else begin
        if (ext_req_valid && !ext_req_ready) begin
            req_pending <= 1'b1;
            pending_addr <= ext_req_addr;
            pending_match_type <= ext_req_match_type;
            pending_target_id <= ext_req_target_id;
            pending_data <= ext_req_data;
        end else if (node_req_valid && node_req_ready) begin
            req_pending <= 1'b0;
        end
    end
end

endmodule

// 输出控制器
module ring_output_ctrl #(
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 节点接口
    input  wire                         node_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        node_rsp_data,
    input  wire [NODE_ID_WIDTH-1:0]     node_rsp_src_id,

    // 外部接口
    output reg                          ext_rsp_valid,
    output reg  [DATA_WIDTH-1:0]        ext_rsp_data,
    output reg  [NODE_ID_WIDTH-1:0]     ext_rsp_src_id
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ext_rsp_valid <= 1'b0;
        ext_rsp_data <= {DATA_WIDTH{1'b0}};
        ext_rsp_src_id <= {NODE_ID_WIDTH{1'b0}};
    end else begin
        ext_rsp_valid <= node_rsp_valid;
        if (node_rsp_valid) begin
            ext_rsp_data <= node_rsp_data;
            ext_rsp_src_id <= node_rsp_src_id;
        end
    end
end

endmodule

// 响应选择器
module rsp_selector #(
    parameter NUM_RINGS = 2,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Ring响应接口
    input  wire [NUM_RINGS-1:0]         ring_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        ring_rsp_data [NUM_RINGS-1:0],
    input  wire [NODE_ID_WIDTH-1:0]     ring_rsp_src_id [NUM_RINGS-1:0],

    // 外部响应接口
    output reg                          rsp_valid,
    output reg  [DATA_WIDTH-1:0]        rsp_data,
    output reg  [NODE_ID_WIDTH-1:0]     rsp_src_id,
    output reg  [NUM_RINGS-1:0]         rsp_ring_id
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rsp_valid <= 1'b0;
        rsp_data <= {DATA_WIDTH{1'b0}};
        rsp_src_id <= {NODE_ID_WIDTH{1'b0}};
        rsp_ring_id <= {NUM_RINGS{1'b0}};
    end else begin
        rsp_valid <= |ring_rsp_valid;

        if (ring_rsp_valid[0]) begin
            rsp_data <= ring_rsp_data[0];
            rsp_src_id <= ring_rsp_src_id[0];
            rsp_ring_id <= 1'b1 << 0;
        end else if (ring_rsp_valid[1]) begin
            rsp_data <= ring_rsp_data[1];
            rsp_src_id <= ring_rsp_src_id[1];
            rsp_ring_id <= 1'b1 << 1;
        end
        // 可以扩展更多Ring的判断
    end
end

endmodule
