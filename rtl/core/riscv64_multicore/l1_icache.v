// l1_icache.v
`include "cache_params.v"

module l1_icache (
    input wire clk,
    input wire rst_n,

    // CPU接口
    input wire [63:0] cpu_addr,
    input wire cpu_req,
    output reg [31:0] cpu_data,
    output reg cpu_ready,
    output reg cache_hit,

    // L2缓存接口
    output reg l2_req,
    output reg [63:0] l2_addr,
    input wire [511:0] l2_data,      // 64字节缓存行
    input wire l2_ready,
    output reg l2_read,

    // 核间一致性接口
    input wire snoop_valid,
    input wire [63:0] snoop_addr,
    output reg snoop_hit
);

    // 缓存存储
    reg [511:0] cache_data [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg [`CACHE_TAG_BITS-1:0] cache_tag [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg valid [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg [1:0] mesi [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg lru [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1]; // 简化的LRU

    // 地址分解
    wire [`CACHE_OFFSET_BITS-1:0] offset;
    wire [`CACHE_INDEX_BITS-1:0] index;
    wire [`CACHE_TAG_BITS-1:0] tag;

    assign offset = cpu_addr[5:0];
    assign index = cpu_addr[11:6];
    assign tag = cpu_addr[63:12];

    // 内部信号
    reg [2:0] state;
    reg [2:0] fill_count;
    reg [63:0] saved_addr;
    reg [511:0] fill_buffer;
    integer way_hit;
    integer way_replace;

    // 命中检测
    always @(*) begin
        way_hit = -1;
        cache_hit = 1'b0;
        snoop_hit = 1'b0;

        for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && (cache_tag[index][i] == tag) &&
                (mesi[index][i] != `MESI_I)) begin
                way_hit = i;
                cache_hit = 1'b1;
            end

            // 监听命中检测
            if (snoop_valid && valid[index][i] &&
                (cache_tag[index][i] == snoop_addr[63:12])) begin
                snoop_hit = 1'b1;
            end
        end
    end

    // LRU替换策略
    always @(*) begin
        way_replace = 0;
        for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
            if (!valid[index][i] || mesi[index][i] == `MESI_I) begin
                way_replace = i;
            end else if (lru[index][i] < lru[index][way_replace]) begin
                way_replace = i;
            end
        end
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `CACHE_IDLE;
            cpu_ready <= 1'b0;
            l2_req <= 1'b0;
            l2_read <= 1'b0;
            fill_count <= 3'b0;

            // 初始化缓存
            for (integer i = 0; i < `CACHE_NUM_LINES; i = i + 1) begin
                for (integer j = 0; j < `CACHE_NUM_WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                    mesi[i][j] <= `MESI_I;
                    lru[i][j] <= j; // 初始LRU值
                end
            end
        end else begin
            case (state)
                `CACHE_IDLE: begin
                    cpu_ready <= 1'b0;

                    if (cpu_req) begin
                        saved_addr <= cpu_addr;

                        if (cache_hit && way_hit >= 0) begin
                            // 缓存命中
                            state <= `CACHE_READ_HIT;
                            cpu_data <= cache_data[index][way_hit][offset[5:2]*32 +: 32];

                            // 更新LRU
                            for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
                                if (i == way_hit) begin
                                    lru[index][i] <= `CACHE_NUM_WAYS - 1;
                                end else if (lru[index][i] > lru[index][way_hit]) begin
                                    lru[index][i] <= lru[index][i] - 1;
                                end
                            end
                        end else begin
                            // 缓存未命中
                            state <= `CACHE_MISS;
                            l2_req <= 1'b1;
                            l2_addr <= {tag, index, 6'b0}; // 缓存行对齐地址
                            l2_read <= 1'b1;
                            fill_count <= 3'b0;
                        end
                    end
                end

                `CACHE_READ_HIT: begin
                    cpu_ready <= 1'b1;
                    state <= `CACHE_IDLE;
                end

                `CACHE_MISS: begin
                    if (l2_ready) begin
                        fill_buffer <= l2_data;
                        state <= `CACHE_FILL;
                        l2_req <= 1'b0;
                    end
                end

                `CACHE_FILL: begin
                    // 写入缓存行
                    cache_data[index][way_replace] <= fill_buffer;
                    cache_tag[index][way_replace] <= tag;
                    valid[index][way_replace] <= 1'b1;
                    mesi[index][way_replace] <= `MESI_E; // 独占状态

                    // 提供请求的数据
                    cpu_data <= fill_buffer[offset[5:2]*32 +: 32];
                    cpu_ready <= 1'b1;

                    state <= `CACHE_IDLE;
                end

                default: begin
                    state <= `CACHE_IDLE;
                end
            endcase

            // 监听处理
            if (snoop_valid && snoop_hit) begin
                // 无效化缓存行
                for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
                    if (valid[index][i] && (cache_tag[index][i] == snoop_addr[63:12])) begin
                        mesi[index][i] <= `MESI_I;
                    end
                end
            end
        end
    end

endmodule
