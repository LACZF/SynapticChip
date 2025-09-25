// Ring总线响应节点 - 处理请求并返回响应的节点
module ring_response_node #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter NUM_RINGS = 2,
    parameter NODE_ID = 0,
    parameter BASE_ADDR = 32'h0000_0000,
    parameter ADDR_MASK = 32'hFFFF_0000
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 本地设备接口
    output wire                         dev_req_valid,
    output wire                         dev_req_type,       // 0:读, 1:写
    output wire [ADDR_WIDTH-1:0]        dev_req_addr,
    output wire [DATA_WIDTH-1:0]        dev_req_data,
    input  wire                         dev_req_ready,

    input  wire                         dev_rsp_valid,
    input  wire [DATA_WIDTH-1:0]        dev_rsp_data,
    input  wire                         dev_rsp_error,
    output wire                         dev_rsp_ready,

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
    output wire [1:0]                   node_state
);

    // 状态定义
    localparam STATE_IDLE       = 2'b00;
    localparam STATE_PROCESSING = 2'b01;
    localparam STATE_SEND_RSP   = 2'b10;

    // 匹配逻辑
    wire address_match;
    wire id_match;
    wire broadcast_match;
    wire request_for_me;

    // 地址匹配：检查地址是否在节点的地址范围内
    assign address_match = (in_req_match_type == 2'b00) &&
                        ((in_req_addr & ADDR_MASK) == (BASE_ADDR & ADDR_MASK));

    // ID匹配：检查目标ID是否匹配节点ID
    assign id_match = (in_req_match_type == 2'b01) && (in_req_target_id == NODE_ID);

    // 广播匹配
    assign broadcast_match = (in_req_match_type == 2'b10);

    // 请求是否针对本节点
    assign request_for_me = address_match || id_match || broadcast_match;

    // 内部信号
    reg [1:0] current_state;
    reg [1:0] next_state;

    reg                         req_pending;
    reg                         req_type_pending;
    reg [ADDR_WIDTH-1:0]        req_addr_pending;
    reg [DATA_WIDTH-1:0]        req_data_pending;
    reg [NUM_RINGS-1:0]         req_ring_pending;
    reg [NODE_ID_WIDTH-1:0]     req_src_id_pending;

    reg [DATA_WIDTH-1:0]        rsp_data_pending;
    reg                         rsp_error_pending;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;

        case (current_state)
            STATE_IDLE: begin
                if (in_req_valid && request_for_me) begin
                    next_state = STATE_PROCESSING;
                end
            end

            STATE_PROCESSING: begin
                if (dev_rsp_valid) begin
                    next_state = STATE_SEND_RSP;
                end
            end

            STATE_SEND_RSP: begin
                if (out_rsp_valid && out_req_ready) begin
                    next_state = STATE_IDLE;
                end
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // 请求处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_pending <= 1'b0;
            req_type_pending <= 1'b0;
            req_addr_pending <= {ADDR_WIDTH{1'b0}};
            req_data_pending <= {DATA_WIDTH{1'b0}};
            req_ring_pending <= {NUM_RINGS{1'b0}};
            req_src_id_pending <= {NODE_ID_WIDTH{1'b0}};
        end else begin
            if (in_req_valid && request_for_me && current_state == STATE_IDLE) begin
                req_pending <= 1'b1;
                // 判断请求类型：地址最低位为1表示写操作，0表示读操作
                req_type_pending <= in_req_addr[0];
                req_addr_pending <= in_req_addr;
                req_data_pending <= in_req_data;
                // 从请求数据中提取源ID（假设在高位）
                req_src_id_pending <= in_req_data[DATA_WIDTH-1:DATA_WIDTH-NODE_ID_WIDTH];
                // 记录Ring ID（从请求地址中提取）
                req_ring_pending <= in_req_addr[31:32-NUM_RINGS];
            end else if (current_state == STATE_SEND_RSP && out_rsp_valid && out_req_ready) begin
                req_pending <= 1'b0;
            end
        end
    end

    // 响应处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_data_pending <= {DATA_WIDTH{1'b0}};
            rsp_error_pending <= 1'b0;
        end else if (dev_rsp_valid) begin
            rsp_data_pending <= dev_rsp_data;
            rsp_error_pending <= dev_rsp_error;
        end
    end

    // 设备接口控制
    assign dev_req_valid = (current_state == STATE_PROCESSING) && req_pending;
    assign dev_req_type = req_type_pending;
    assign dev_req_addr = req_addr_pending;
    assign dev_req_data = req_data_pending;
    assign dev_rsp_ready = (current_state == STATE_PROCESSING);

    // Ring总线请求转发
    assign out_req_valid = in_req_valid && !request_for_me;
    assign out_req_addr = in_req_addr;
    assign out_req_match_type = in_req_match_type;
    assign out_req_target_id = in_req_target_id;
    assign out_req_data = in_req_data;

    assign in_req_ready = out_req_ready || request_for_me;

    // Ring总线响应处理
    assign out_rsp_valid = in_rsp_valid || (current_state == STATE_SEND_RSP);
    assign out_rsp_data = in_rsp_valid ? in_rsp_data : rsp_data_pending;
    assign out_rsp_src_id = in_rsp_valid ? in_rsp_src_id : NODE_ID;
    assign out_rsp_ring_id = in_rsp_valid ? in_rsp_ring_id : req_ring_pending;

    // 状态输出
    assign node_busy = (current_state != STATE_IDLE) || !in_req_ready;
    assign node_state = current_state;

endmodule
