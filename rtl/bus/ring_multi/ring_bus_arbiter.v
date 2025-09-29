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
