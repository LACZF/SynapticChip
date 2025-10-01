// 仲裁器模块 - 支持基于负载的动态总线选择
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
    input  wire [NUM_RINGS-1:0]         req_ring_mask,      // 可选总线掩码
    input  wire [NUM_RINGS-1:0]         req_ring_disable,   // 禁用的总线
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

    reg [NUM_RINGS-1:0] ring_priority; // 轮询优先级指针
    reg [NUM_RINGS-1:0] valid_rings;   // 有效的总线
    wire [NUM_RINGS-1:0] available_rings; // 可用的总线
    reg [2:0] load_count [NUM_RINGS-1:0]; // 各总线负载计数

    // 计算可用的Ring总线
    assign available_rings = ring_req_ready & ~req_ring_disable;

    // 负载监控计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < NUM_RINGS; i = i + 1) begin
                load_count[i] <= 0;
            end
        end else begin
            for (integer i = 0; i < NUM_RINGS; i = i + 1) begin
                // 增加负载计数
                if (ring_req_valid[i] && ring_req_ready[i]) begin
                    load_count[i] <= load_count[i] + 1;
                end
                // 定期减少负载计数（模拟负载衰减）
                if (load_count[i] > 0 && (load_count[i] % 4) == 0) begin
                    load_count[i] <= load_count[i] - 1;
                end
            end
        end
    end

    // 基于负载的动态总线选择逻辑
    function [NUM_RINGS-1:0] select_best_ring;
        input [NUM_RINGS-1:0] available; // 可用总线
        input [NUM_RINGS-1:0] mask;      // 指定总线掩码
        integer i;
        integer min_load;
        integer best_ring;
        begin
            // 初始化
            min_load = 8; // 最大可能负载值+1
            best_ring = 0;
            select_best_ring = {NUM_RINGS{1'b0}};

            // 结合掩码和可用性
            valid_rings = available & mask;

            // 如果有指定的总线掩码，优先从掩码中选择负载最轻的
            if (|valid_rings) begin
                for (i = 0; i < NUM_RINGS; i = i + 1) begin
                    if (valid_rings[i] && (load_count[i] < min_load)) begin
                        min_load = load_count[i];
                        best_ring = i;
                    end
                end
                select_best_ring[best_ring] = 1'b1;
            end else if (|available) begin
                // 如果没有指定掩码或指定的掩码都不可用，则从所有可用总线中选择
                for (i = 0; i < NUM_RINGS; i = i + 1) begin
                    if (available[i] && (load_count[i] < min_load)) begin
                        min_load = load_count[i];
                        best_ring = i;
                    end
                end
                select_best_ring[best_ring] = 1'b1;
            end
        end
    endfunction

    // 优先级仲裁逻辑
    always @(*) begin
        ring_req_valid = {NUM_RINGS{1'b0}};

        if (req_valid) begin
            // 使用基于负载的动态选择函数
            ring_req_valid = select_best_ring(available_rings, req_ring_mask);
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

    // 总线忙状态
    assign ring_busy = ~ring_req_ready;

endmodule