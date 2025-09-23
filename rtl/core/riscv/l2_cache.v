// l2_cache.v
module l2_cache #(
    parameter CACHE_SIZE = 32768,     // 32KB
    parameter LINE_SIZE = 32,         // 32字节行
    parameter ASSOCIATIVITY = 4       // 4路组相联
)(
    input wire clk,
    input wire rst_n,

    // L1缓存接口
    input wire [31:0] l1_req_addr,
    input wire [31:0] l1_req_data,
    output reg [31:0] l1_resp_data,
    input wire l1_req_we,
    input wire [3:0] l1_req_sel,
    input wire l1_req_valid,
    output reg l1_resp_valid,
    output reg l1_busy,

    // 主存接口
    output reg [31:0] mem_addr,
    output reg [31:0] mem_data_out,
    input wire [31:0] mem_data_in,
    output reg mem_we,
    output reg [3:0] mem_sel,
    output reg mem_req,
    input wire mem_ack,

    // 性能统计
    output reg [31:0] cache_hits,
    output reg [31:0] cache_misses
);

    // ==================== 缓存参数计算 ====================
    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(CACHE_SIZE / (LINE_SIZE * ASSOCIATIVITY));
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;

    localparam NUM_SETS = CACHE_SIZE / (LINE_SIZE * ASSOCIATIVITY);
    localparam NUM_LINES = NUM_SETS * ASSOCIATIVITY;

    // ==================== 缓存存储结构 ====================

    reg [TAG_BITS-1:0] tag_mem [0:NUM_LINES-1];
    reg valid_mem [0:NUM_LINES-1];
    reg dirty_mem [0:NUM_LINES-1];
    reg [31:0] lru_counter [0:NUM_SETS-1];

    reg [7:0] data_mem [0:NUM_LINES-1][0:LINE_SIZE-1];

    // ==================== 内部信号 ====================

    wire [OFFSET_BITS-1:0] offset;
    wire [INDEX_BITS-1:0] index;
    wire [TAG_BITS-1:0] tag;

    assign offset = l1_req_addr[OFFSET_BITS-1:0];
    assign index = l1_req_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    assign tag = l1_req_addr[31:OFFSET_BITS+INDEX_BITS];

    wire [ASSOCIATIVITY-1:0] hit;
    wire [ASSOCIATIVITY-1:0] valid;
    wire [TAG_BITS-1:0] tag_out [0:ASSOCIATIVITY-1];
    reg [7:0] way_select;
    wire cache_hit;

    reg [2:0] state;
    localparam STATE_IDLE = 3'b000;
    localparam STATE_CHECK = 3'b001;
    localparam STATE_READ_MISS = 3'b010;
    localparam STATE_WRITE_HIT = 3'b011;
    localparam STATE_FILL = 3'b100;
    localparam STATE_WRITE_BACK = 3'b101;

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
            l1_resp_valid <= 1'b0;
            l1_busy <= 1'b0;
            mem_req <= 1'b0;
            cache_hits <= 32'h0;
            cache_misses <= 32'h0;
            fill_count <= 8'h0;
            writeback_count <= 8'h0;

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
                    l1_resp_valid <= 1'b0;
                    l1_busy <= 1'b0;

                    if (l1_req_valid) begin
                        saved_addr <= l1_req_addr;
                        saved_data <= l1_req_data;
                        saved_sel <= l1_req_sel;
                        saved_we <= l1_req_we;
                        state <= STATE_CHECK;
                        l1_busy <= 1'b1;
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
                            l1_resp_data <= {
                                data_mem[index * ASSOCIATIVITY + way_select][offset+3],
                                data_mem[index * ASSOCIATIVITY + way_select][offset+2],
                                data_mem[index * ASSOCIATIVITY + way_select][offset+1],
                                data_mem[index * ASSOCIATIVITY + way_select][offset]
                            };
                            l1_resp_valid <= 1'b1;
                            state <= STATE_IDLE;
                            l1_busy <= 1'b0;
                        end
                    end else begin
                        cache_misses <= cache_misses + 32'h1;

                        if (saved_we) begin
                            // 写未命中：直接写入内存（非写分配）
                            mem_req <= 1'b1;
                            mem_we <= 1'b1;
                            mem_addr <= saved_addr;
                            mem_data_out <= saved_data;
                            mem_sel <= saved_sel;

                            if (mem_ack) begin
                                l1_resp_valid <= 1'b1;
                                state <= STATE_IDLE;
                                l1_busy <= 1'b0;
                            end
                        end else begin
                            // 读未命中：从内存加载
                            state <= STATE_READ_MISS;
                        end
                    end
                end

                STATE_WRITE_HIT: begin
                    // 写命中：更新缓存
                    if (saved_sel[0]) data_mem[index * ASSOCIATIVITY + way_select][offset]   <= saved_data[7:0];
                    if (saved_sel[1]) data_mem[index * ASSOCIATIVITY + way_select][offset+1] <= saved_data[15:8];
                    if (saved_sel[2]) data_mem[index * ASSOCIATIVITY + way_select][offset+2] <= saved_data[23:16];
                    if (saved_sel[3]) data_mem[index * ASSOCIATIVITY + way_select][offset+3] <= saved_data[31:24];

                    dirty_mem[index * ASSOCIATIVITY + way_select] <= 1'b1;

                    // 同时写入内存（写直达）
                    mem_req <= 1'b1;
                    mem_we <= 1'b1;
                    mem_addr <= saved_addr;
                    mem_data_out <= saved_data;
                    mem_sel <= saved_sel;

                    if (mem_ack) begin
                        l1_resp_valid <= 1'b1;
                        state <= STATE_IDLE;
                        l1_busy <= 1'b0;
                    end
                end

                STATE_READ_MISS: begin
                    // 检查是否需要写回
                    if (dirty_mem[index * ASSOCIATIVITY + way_select]) begin
                        state <= STATE_WRITE_BACK;
                        writeback_count <= 8'h0;
                    end else begin
                        mem_req <= 1'b1;
                        mem_we <= 1'b0;
                        mem_addr <= {saved_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};

                        if (mem_ack) begin
                            state <= STATE_FILL;
                            fill_count <= 8'h0;
                        end
                    end
                end

                STATE_FILL: begin
                    if (mem_ack) begin
                        // 填充缓存行
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4]   <= mem_data_in[7:0];
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4+1] <= mem_data_in[15:8];
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4+2] <= mem_data_in[23:16];
                        data_mem[index * ASSOCIATIVITY + way_select][fill_count*4+3] <= mem_data_in[31:24];

                        fill_count <= fill_count + 1;

                        if (fill_count == (LINE_SIZE/4 - 1)) begin
                            // 填充完成
                            tag_mem[index * ASSOCIATIVITY + way_select] <= tag;
                            valid_mem[index * ASSOCIATIVITY + way_select] <= 1'b1;

                            // 返回请求的数据
                            l1_resp_data <= {
                                data_mem[index * ASSOCIATIVITY + way_select][offset+3],
                                data_mem[index * ASSOCIATIVITY + way_select][offset+2],
                                data_mem[index * ASSOCIATIVITY + way_select][offset+1],
                                data_mem[index * ASSOCIATIVITY + way_select][offset]
                            };
                            l1_resp_valid <= 1'b1;
                            state <= STATE_IDLE;
                            l1_busy <= 1'b0;
                            mem_req <= 1'b0;
                        end else begin
                            // 继续填充
                            mem_addr <= mem_addr + 4;
                        end
                    end
                end

                STATE_WRITE_BACK: begin
                    // 写回脏缓存行
                    mem_req <= 1'b1;
                    mem_we <= 1'b1;
                    mem_addr <= {tag_mem[index * ASSOCIATIVITY + way_select], index, {OFFSET_BITS{1'b0}}} + (writeback_count * 4);
                    mem_data_out <= {
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4+3],
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4+2],
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4+1],
                        data_mem[index * ASSOCIATIVITY + way_select][writeback_count*4]
                    };
                    mem_sel <= 4'b1111;

                    if (mem_ack) begin
                        writeback_count <= writeback_count + 1;

                        if (writeback_count == (LINE_SIZE/4 - 1)) begin
                            // 写回完成，清除脏位
                            dirty_mem[index * ASSOCIATIVITY + way_select] <= 1'b0;
                            state <= STATE_READ_MISS;
                        end else begin
                            mem_addr <= mem_addr + 4;
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
