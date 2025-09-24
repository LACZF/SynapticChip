// l1_dcache.v
`include "cache_params.v"

module l1_dcache (
    input wire clk,
    input wire rst_n,

    // CPU接口
    input wire [63:0] cpu_addr,
    input wire [63:0] cpu_wdata,
    input wire cpu_req,
    input wire cpu_we,
    input wire [7:0] cpu_byte_en,
    output reg [63:0] cpu_rdata,
    output reg cpu_ready,
    output reg cache_hit,

    // L2缓存接口
    output reg l2_req,
    output reg [63:0] l2_addr,
    output reg [511:0] l2_wdata,
    input wire [511:0] l2_rdata,
    output reg l2_we,
    input wire l2_ready,

    // 核间一致性接口
    input wire snoop_valid,
    input wire [63:0] snoop_addr,
    input wire snoop_we,
    output reg snoop_hit,
    output reg [511:0] snoop_data
);

    // 缓存存储
    reg [511:0] cache_data [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg [`CACHE_TAG_BITS-1:0] cache_tag [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg valid [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg dirty [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg [1:0] mesi [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg lru [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];

    // 地址分解
    wire [`CACHE_OFFSET_BITS-1:0] offset;
    wire [`CACHE_INDEX_BITS-1:0] index;
    wire [`CACHE_TAG_BITS-1:0] tag;

    assign offset = cpu_addr[5:0];
    assign index = cpu_addr[11:6];
    assign tag = cpu_addr[63:12];

    // 内部信号
    reg [2:0] state;
    reg [63:0] saved_addr;
    reg [63:0] saved_wdata;
    reg [7:0] saved_byte_en;
    reg saved_we;
    reg [511:0] fill_buffer;
    reg need_writeback;
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
        need_writeback = 1'b0;

        for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
            if (!valid[index][i] || mesi[index][i] == `MESI_I) begin
                way_replace = i;
                need_writeback = 1'b0;
            end else if (lru[index][i] < lru[index][way_replace]) begin
                way_replace = i;
                need_writeback = dirty[index][i] && (mesi[index][i] == `MESI_M);
            end
        end
    end

    // 字节使能掩码生成
    function [511:0] generate_write_mask;
        input [7:0] byte_en;
        input [5:0] offset;
        integer i;
        begin
            generate_write_mask = 512'b0;
            for (i = 0; i < 8; i = i + 1) begin
                if (byte_en[i]) begin
                    generate_write_mask[offset[5:3]*64 + i*8 +: 8] = 8'hFF;
                end
            end
        end
    endfunction

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `CACHE_IDLE;
            cpu_ready <= 1'b0;
            l2_req <= 1'b0;
            l2_we <= 1'b0;
            need_writeback <= 1'b0;

            // 初始化缓存
            for (integer i = 0; i < `CACHE_NUM_LINES; i = i + 1) begin
                for (integer j = 0; j < `CACHE_NUM_WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                    dirty[i][j] <= 1'b0;
                    mesi[i][j] <= `MESI_I;
                    lru[i][j] <= j;
                end
            end
        end else begin
            case (state)
                `CACHE_IDLE: begin
                    cpu_ready <= 1'b0;

                    if (cpu_req) begin
                        saved_addr <= cpu_addr;
                        saved_wdata <= cpu_wdata;
                        saved_byte_en <= cpu_byte_en;
                        saved_we <= cpu_we;

                        if (cache_hit && way_hit >= 0) begin
                            // 缓存命中
                            if (cpu_we) begin
                                state <= `CACHE_WRITE_HIT;

                                // 更新缓存数据
                                for (integer b = 0; b < 8; b = b + 1) begin
                                    if (cpu_byte_en[b]) begin
                                        cache_data[index][way_hit][offset[5:3]*64 + b*8 +: 8] <=
                                            cpu_wdata[b*8 +: 8];
                                    end
                                end

                                dirty[index][way_hit] <= 1'b1;
                                mesi[index][way_hit] <= `MESI_M;
                            end else begin
                                state <= `CACHE_READ_HIT;
                                cpu_rdata <= cache_data[index][way_hit][offset[5:3]*64 +: 64];
                            end

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
                            l2_addr <= {tag, index, 6'b0};

                            if (need_writeback && dirty[index][way_replace]) begin
                                // 需要写回
                                l2_we <= 1'b1;
                                l2_wdata <= cache_data[index][way_replace];
                                l2_addr <= {cache_tag[index][way_replace], index, 6'b0};
                            end else begin
                                l2_we <= 1'b0;
                            end
                        end
                    end
                end

                `CACHE_READ_HIT: begin
                    cpu_ready <= 1'b1;
                    state <= `CACHE_IDLE;
                end

                `CACHE_WRITE_HIT: begin
                    cpu_ready <= 1'b1;
                    state <= `CACHE_IDLE;
                end

                `CACHE_MISS: begin
                    if (l2_ready) begin
                        if (l2_we) begin
                            // 写回完成，开始填充
                            l2_we <= 1'b0;
                            l2_addr <= {tag, index, 6'b0};
                        end else begin
                            // 读取完成
                            fill_buffer <= l2_rdata;
                            state <= `CACHE_FILL;
                            l2_req <= 1'b0;
                        end
                    end
                end

                `CACHE_FILL: begin
                    // 写入缓存行
                    cache_data[index][way_replace] <= fill_buffer;
                    cache_tag[index][way_replace] <= tag;
                    valid[index][way_replace] <= 1'b1;
                    dirty[index][way_replace] <= 1'b0;
                    mesi[index][way_replace] <= saved_we ? `MESI_M : `MESI_E;

                    if (saved_we) begin
                        // 写分配：先填充再写入
                        for (integer b = 0; b < 8; b = b + 1) begin
                            if (saved_byte_en[b]) begin
                                cache_data[index][way_replace][offset[5:3]*64 + b*8 +: 8] <=
                                    saved_wdata[b*8 +: 8];
                            end
                        end
                        dirty[index][way_replace] <= 1'b1;
                        cpu_rdata <= saved_wdata; // 写操作返回写入值
                    end else begin
                        cpu_rdata <= fill_buffer[offset[5:3]*64 +: 64];
                    end

                    cpu_ready <= 1'b1;
                    state <= `CACHE_IDLE;
                end

                default: begin
                    state <= `CACHE_IDLE;
                end
            endcase

            // 监听处理
            if (snoop_valid) begin
                for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
                    if (valid[index][i] && (cache_tag[index][i] == snoop_addr[63:12])) begin
                        if (snoop_we) begin
                            // 写无效化
                            mesi[index][i] <= `MESI_I;
                        end else begin
                            // 读共享
                            if (mesi[index][i] == `MESI_M) begin
                                // 写回数据
                                snoop_data <= cache_data[index][i];
                                mesi[index][i] <= `MESI_S;
                            end else if (mesi[index][i] == `MESI_E) begin
                                mesi[index][i] <= `MESI_S;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule
