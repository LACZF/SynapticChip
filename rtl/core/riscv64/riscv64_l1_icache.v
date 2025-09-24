// l1_icache_64bit.v
module l1_icache_64bit #(
    parameter CACHE_SIZE = 16384,      // 16KB
    parameter LINE_SIZE = 32,          // 32字节行
    parameter ASSOCIATIVITY = 4        // 4路组相联
)(
    input wire clk,
    input wire rst_n,

    // CPU接口
    input wire [63:0] cpu_addr,
    output reg [63:0] cpu_data,
    input wire cpu_req,
    output reg cpu_ack,

    // L2缓存接口
    output reg l2_req_valid,
    input wire l2_req_ready,
    output reg [63:0] l2_req_addr,
    input wire [63:0] l2_resp_data,
    input wire l2_resp_valid,

    // 性能统计
    output reg [31:0] cache_hits,
    output reg [31:0] cache_misses,
    output reg cache_miss
);

    // ==================== 64位缓存参数计算 ====================
    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SIZE / (LINE_SIZE * ASSOCIATIVITY));
    localparam TAG_BITS = 64 - INDEX_BITS - OFFSET_BITS;

    localparam NUM_SETS = CACHE_SIZE / (LINE_SIZE * ASSOCIATIVITY);
    localparam NUM_LINES = NUM_SETS * ASSOCIATIVITY;

    // ==================== 缓存存储结构 ====================

    // 标签存储器
    reg [TAG_BITS-1:0] tag_mem [0:NUM_LINES-1];
    reg valid_mem [0:NUM_LINES-1];
    reg [63:0] lru_counter [0:NUM_SETS-1];

    // 数据存储器（每个缓存行LINE_SIZE字节）
    reg [7:0] data_mem [0:NUM_LINES-1][0:LINE_SIZE-1];

    // ==================== 内部信号 ====================

    // 地址解码
    wire [OFFSET_BITS-1:0] offset;
    wire [INDEX_BITS-1:0] index;
    wire [TAG_BITS-1:0] tag;

    assign offset = cpu_addr[OFFSET_BITS-1:0];
    assign index = cpu_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    assign tag = cpu_addr[63:OFFSET_BITS+INDEX_BITS];

    // 缓存查找
    wire [ASSOCIATIVITY-1:0] hit;
    wire [ASSOCIATIVITY-1:0] valid;
    wire [TAG_BITS-1:0] tag_out [0:ASSOCIATIVITY-1];
    reg [7:0] way_select;
    wire cache_hit;

    // 状态机
    reg [2:0] state;
    localparam STATE_IDLE = 3'b000;
    localparam STATE_CHECK = 3'b001;
    localparam STATE_MISS = 3'b010;
    localparam STATE_FILL = 3'b011;
    localparam STATE_UPDATE = 3'b100;

    // 临时寄存器
    reg [63:0] saved_addr;
    reg [7:0] fill_count;

    // ==================== 缓存查找逻辑 ====================
    genvar i, j;
    generate
        for (i = 0; i < ASSOCIATIVITY; i = i + 1) begin : cache_ways
            assign tag_out[i] = tag_mem[index * ASSOCIATIVITY + i];
            assign valid[i] = valid_mem[index * ASSOCIATIVITY + i];
            assign hit[i] = valid[i] && (tag_out[i] == tag);
        end
    endgenerate

    assign cache_hit = |hit;

    // 命中路选择
    always @(*) begin
        way_select = 0;
        for (integer i = 0; i < ASSOCIATIVITY; i = i + 1) begin
            if (hit[i]) begin
                way_select = i;
            end
        end
    end

    // ==================== 主状态机 ====================

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cpu_ack <= 1'b0;
            l2_req_valid <= 1'b0;
            cache_hits <= 32'h0;
            cache_misses <= 32'h0;
            cache_miss <= 1'b0;
            fill_count <= 8'h0;

            // 初始化缓存
            for (integer i = 0; i < NUM_LINES; i = i + 1) begin
                valid_mem[i] <= 1'b0;
                tag_mem[i] <= {TAG_BITS{1'b0}};
                for (integer j = 0; j < LINE_SIZE; j = j + 1) begin
                    data_mem[i][j] <= 8'h00;
                end
            end

            for (integer i = 0; i < NUM_SETS; i = i + 1) begin
                lru_counter[i] <= 64'h0;
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    cpu_ack <= 1'b0;
                    cache_miss <= 1'b0;

                    if (cpu_req) begin
                        saved_addr <= cpu_addr;
                        state <= STATE_CHECK;
                    end
                end

                STATE_CHECK: begin
                    if (cache_hit) begin
                        // 缓存命中
                        cache_hits <= cache_hits + 32'h1;

                        // 读取数据（64位对齐）
                        cpu_data <= {
                            data_mem[index * ASSOCIATIVITY + way_select][offset+7],
                            data_mem[index * ASSOCIATIVITY + way_select][offset+6],
                            data_mem[index * ASSOCIATIVITY + way_select][offset+5],
                            data_mem[index * ASSOCIATIVITY + way_select][offset+4],
                            data_mem[index * ASSOCIATIVITY + way_select][offset+3],
                            data_mem[index * ASSOCIATIVITY + way_select][offset+2],
                            data_mem[index * ASSOCIATIVITY + way_select][offset+1],
                            data_mem[index * ASSOCIATIVITY + way_select][offset]
                        };

                        cpu_ack <= 1'b1;
                        state <= STATE_IDLE;

                        // 更新LRU
                        lru_counter[index] <= lru_counter[index] + 1;
                    end else begin
                        // 缓存未命中
                        cache_misses <= cache_misses + 32'h1;
                        cache_miss <= 1'b1;
                        state <= STATE_MISS;
                    end
                end

                STATE_MISS: begin
                    // 向L2缓存请求数据
                    l2_req_valid <= 1'b1;
                    l2_req_addr <= {saved_addr[63:OFFSET_BITS], {OFFSET_BITS{1'b0}}}; // 对齐地址

                    if (l2_req_ready) begin
                        state <= STATE_FILL;
                        fill_count <= 8'h0;
                    end
                end

                STATE_FILL: begin
                    l2_req_valid <= 1'b0;

                    if (l2_resp_valid) begin
                        // 填充缓存行（每次接收8字节）
                        for (integer j = 0; j < 8; j = j + 1) begin
                            data_mem[index * ASSOCIATIVITY + way_select][fill_count*8 + j] <=
                                l2_resp_data[(7-j)*8 +: 8];
                        end

                        fill_count <= fill_count + 1;

                        if (fill_count == (LINE_SIZE/8 - 1)) begin
                            state <= STATE_UPDATE;
                        end
                    end
                end

                STATE_UPDATE: begin
                    // 更新标签和有效位
                    tag_mem[index * ASSOCIATIVITY + way_select] <= tag;
                    valid_mem[index * ASSOCIATIVITY + way_select] <= 1'b1;

                    // 返回请求的数据
                    cpu_data <= {
                        data_mem[index * ASSOCIATIVITY + way_select][offset+7],
                        data_mem[index * ASSOCIATIVITY + way_select][offset+6],
                        data_mem[index * ASSOCIATIVITY + way_select][offset+5],
                        data_mem[index * ASSOCIATIVITY + way_select][offset+4],
                        data_mem[index * ASSOCIATIVITY + way_select][offset+3],
                        data_mem[index * ASSOCIATIVITY + way_select][offset+2],
                        data_mem[index * ASSOCIATIVITY + way_select][offset+1],
                        data_mem[index * ASSOCIATIVITY + way_select][offset]
                    };

                    cpu_ack <= 1'b1;
                    cache_miss <= 1'b0;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    // ==================== LRU替换策略 ====================

    always @(*) begin
        way_select = lru_counter[index] % ASSOCIATIVITY;
    end

endmodule
