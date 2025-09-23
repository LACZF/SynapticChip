// l1_dcache.v
module l1_dcache #(
    parameter CACHE_SIZE = 8192,      // 8KB
    parameter LINE_SIZE = 16,         // 16字节行
    parameter ASSOCIATIVITY = 2       // 2路组相联
)(
    input wire clk,
    input wire rst_n,

    // CPU接口
    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_data_in,
    output reg [31:0] cpu_data_out,
    input wire cpu_req,
    output reg cpu_ack,
    input wire cpu_we,
    input wire [3:0] cpu_sel,

    // L2缓存接口
    output reg l2_req_valid,
    input wire l2_req_ready,
    output reg [31:0] l2_req_addr,
    output reg [31:0] l2_req_data,
    input wire [31:0] l2_resp_data,
    output reg l2_req_we,
    output reg [3:0] l2_req_sel,
    input wire l2_resp_valid,

    // 性能统计
    output reg [31:0] cache_hits,
    output reg [31:0] cache_misses,
    output reg cache_miss
);

    // ==================== 缓存参数计算 ====================
    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SIZE / (LINE_SIZE * ASSOCIATIVITY));
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;

    localparam NUM_SETS = CACHE_SIZE / (LINE_SIZE * ASSOCIATIVITY);
    localparam NUM_LINES = NUM_SETS * ASSOCIATIVITY;

    // ==================== 缓存存储结构 ====================

    // 标签存储器
    reg [TAG_BITS-1:0] tag_mem [0:NUM_LINES-1];
    reg valid_mem [0:NUM_LINES-1];
    reg dirty_mem [0:NUM_LINES-1];  // 脏位，用于写回策略
    reg [31:0] lru_counter [0:NUM_SETS-1];

    // 数据存储器
    reg [7:0] data_mem [0:NUM_LINES-1][0:LINE_SIZE-1];

    // ==================== 内部信号 ====================

    // 地址解码
    wire [OFFSET_BITS-1:0] offset;
    wire [INDEX_BITS-1:0] index;
    wire [TAG_BITS-1:0] tag;

    assign offset = cpu_addr[OFFSET_BITS-1:0];
    assign index = cpu_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    assign tag = cpu_addr[31:OFFSET_BITS+INDEX_BITS];

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
    localparam STATE_READ_MISS = 3'b010;
    localparam STATE_WRITE_HIT = 3'b011;
    localparam STATE_WRITE_MISS = 3'b100;
    localparam STATE_FILL = 3'b101;
    localparam STATE_WRITE_BACK = 3'b110;

    // 临时寄存器
    reg [31:0] saved_addr;
    reg [31:0] saved_data;
    reg [3:0] saved_sel;
    reg saved_we;
    reg [7:0] fill_count;
    reg [7:0] writeback_count;

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
            writeback_count <= 8'h0;

            // 初始化缓存
            for (integer i = 0; i < NUM_LINES; i = i + 1) begin
                valid_mem[i] <= 1'b0;
                dirty_mem[i] <= 1'b0;
                tag_mem[i] <= {TAG_BITS{1'b0}};
                for (integer j = 0; j < LINE_SIZE; j = j + 1) begin
                    data_mem[i][j] <= 8'h00;
                end
            end

            for (integer i = 0; i < NUM_SETS; i = i + 1) begin
                lru_counter[i] <= 32'h0;
            end
        end else begin
            case (state)
                STATE_IDLE: begin
                    cpu_ack <= 1'b0;
                    cache_miss <= 1'b0;

                    if (cpu_req) begin
                        saved_addr <= cpu_addr;
                        saved_data <= cpu_data_in;
                        saved_sel <= cpu_sel;
                        saved_we <= cpu_we;
                        state <= STATE_CHECK;
                    end
                end

                STATE_CHECK: begin
                    if (cache_hit) begin
                        cache_hits <= cache_hits + 32'h1;

                        if (saved_we) begin
                            // 写命中
                            state <= STATE_WRITE_HIT;
                        end else begin
                            // 读命中
                            cpu_data_out <= {
                                data_mem[index * ASSOCIATIVITY + way_select][offset+3],
                                data_mem[index * ASSOCIATIVITY + way_select][offset+2],
                                data_mem[index * ASSOCIATIVITY + way_select][offset+1],
                                data_mem[index * ASSOCIATIVITY + way_select][offset]
                            };
                            cpu_ack <= 1'b1;
                            state <= STATE_IDLE;

                            // 更新LRU
                            lru_counter[index] <= lru_counter[index] + 1;
                        end
                    end else begin
                        cache_misses <= cache_misses + 32'h1;
                        cache_miss <= 1'b1;

                        if (saved_we) begin
                            state <= STATE_WRITE_MISS;
                        end else begin
                            state <= STATE_READ_MISS;
                        end
                    end
                end

                STATE_WRITE_HIT: begin
                    // 写命中：更新缓存和内存（写直达）
                    if (saved_sel[0]) data_mem[index * ASSOCIATIVITY + way_select][offset]   <= saved_data[7:0];
                    if (saved_sel[1]) data_mem[index * ASSOCIATIVITY + way_select][offset+1] <= saved_data[15:8];
                    if (saved_sel[2]) data_mem[index * ASSOCIATIVITY + way_select][offset+2] <= saved_data[23:16];
                    if (saved_sel[3]) data_mem[index * ASSOCIATIVITY + way_select][offset+3] <= saved_data[31:24];

                    // 标记为脏
                    dirty_mem[index * ASSOCIATIVITY + way_select] <= 1'b1;

                    // 同时写入L2缓存（写直达）
                    l2_req_valid <= 1'b1;
                    l2_req_addr <= saved_addr;
                    l2_req_data <= saved_data;
                    l2_req_we <= 1'b1;
                    l2_req_sel <= saved_sel;

                    if (l2_req_ready) begin
                        cpu_ack <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                STATE_READ_MISS: begin
                    // 读未命中：从L2缓存加载数据
                    l2_req_valid <= 1'b1;
                    l2_req_addr <= {saved_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
                    l2_req_we <= 1'b0;

                    if (l2_req_ready) begin
                        state <= STATE_FILL;
                        fill_count <= 8'h0;
                    end
                end

                STATE_WRITE_MISS: begin
                    // 写未命中：先加载再写入（写分配）
                    // 检查是否需要写回
                    if (dirty_mem[index * ASSOCIATIVITY + way_select]) begin
                        state <= STATE_WRITE_BACK;
                        writeback_count <= 8'h0;
                    end else begin
                        l2_req_valid <= 1'b1;
                        l2_req_addr <= {saved_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
                        l2_req_we <= 1'b0;

                        if (l2_req_ready) begin
                            state <= STATE_FILL;
                            fill_count <= 8'h0;
                        end
                    end
                end

                STATE_FILL: begin
                    l2_req_valid <= 1'b0;

                    if (l2_resp_valid) begin
                        // 填充缓存行
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4]   <= l2_resp_data[7:0];
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4+1] <= l2_resp_data[15:8];
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4+2] <= l2_resp_data[23:16];
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4+3] <= l2_resp_data[31:24];

                        fill_count <= fill_count + 1;

                        if (fill_count == (LINE_SIZE/4 - 1)) begin
                            // 填充完成
                            tag_mem[index * ASSOCIATIVITY + way_select] <= tag;
                            valid_mem[index * ASSOCIATIVITY + way_select] <= 1'b1;

                            if (saved_we) begin
                                // 如果是写未命中，现在执行写操作
                                if (saved_sel[0]) data_mem[index * ASSOCIATIVITY + way_select][offset]   <= saved_data[7:0];
                                if (saved_sel[1]) data_mem[index * ASSOCIATIVITY + way_select][offset+1] <= saved_data[15:8];
                                if (saved_sel[2]) data_mem[index * ASSOCIATIVITY + way_select][offset+2] <= saved_data[23:16];
                                if (saved_sel[3]) data_mem[index * ASSOCIATIVITY + way_select][offset+3] <= saved_data[31:24];
                                dirty_mem[index * ASSOCIATIVITY + way_select] <= 1'b1;

                                // 写入L2缓存
                                l2_req_valid <= 1'b1;
                                l2_req_addr <= saved_addr;
                                l2_req_data <= saved_data;
                                l2_req_we <= 1'b1;
                                l2_req_sel <= saved_sel;
                            end else begin
                                // 读未命中：返回数据
                                cpu_data_out <= {
                                    data_mem[index * ASSOCIATIVITY + way_select][offset+3],
                                    data_mem[index * ASSOCIATIVITY + way_select][offset+2],
                                    data_mem[index * ASSOCIATIVITY + way_select][offset+1],
                                    data_mem[index * ASSOCIATIVITY + way_select][offset]
                                };
                                cpu_ack <= 1'b1;
                            end

                            state <= STATE_IDLE;
                        end
                    end
                end

                STATE_WRITE_BACK: begin
                    // 写回脏缓存行到L2缓存
                    l2_req_valid <= 1'b1;
                    l2_req_we <= 1'b1;
                    l2_req_addr <= {tag_mem[index * ASSOCIATIVITY + way_select], index, {OFFSET_BITS{1'b0}}} + (writeback_count * 4);
                    l2_req_data <= {
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4+3],
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4+2],
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4+1],
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4]
                    };
                    l2_req_sel <= 4'b1111;

                    if (l2_req_ready) begin
                        writeback_count <= writeback_count + 1;

                        if (writeback_count == (LINE_SIZE/4 - 1)) begin
                            // 写回完成，清除脏位
                            dirty_mem[index * ASSOCIATIVITY + way_select] <= 1'b0;
                            state <= STATE_WRITE_MISS;
                        end
                    end
                end
            endcase
        end
    end

    // ==================== LRU替换策略 ====================

    always @(*) begin
        way_select = lru_counter[index] % ASSOCIATIVITY;
    end

endmodule
