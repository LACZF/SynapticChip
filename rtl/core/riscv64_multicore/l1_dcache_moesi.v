// l1_dcache_moesi.v
`include "cache_params.v"
`include "l2_cache_params.v"

module l1_dcache_moesi (
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
    output reg [1:0] l2_req_type,
    input wire l2_ready,

    // 核间一致性接口
    input wire snoop_valid,
    input wire [63:0] snoop_addr,
    input wire [1:0] snoop_req_type,
    output reg snoop_ready,
    output reg snoop_hit,
    output reg [2:0] snoop_state,
    output reg [511:0] snoop_data
);

    // 缓存存储（增加MOESI状态）
    reg [511:0] cache_data [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg [`CACHE_TAG_BITS-1:0] cache_tag [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg valid [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg dirty [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1];
    reg [2:0] mesi [0:`CACHE_NUM_LINES-1] [0:`CACHE_NUM_WAYS-1]; // 扩展为MOESI
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

    // MOESI协议处理
    always @(*) begin
        way_hit = -1;
        cache_hit = 1'b0;
        snoop_hit = 1'b0;
        snoop_state = `MOESI_I;

        for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && (cache_tag[index][i] == tag) &&
                (mesi[index][i] != `MOESI_I)) begin
                way_hit = i;
                cache_hit = 1'b1;
                snoop_state = mesi[index][i];
            end

            // 监听命中检测
            if (snoop_valid && valid[index][i] &&
                (cache_tag[index][i] == snoop_addr[63:12])) begin
                snoop_hit = 1'b1;
            end
        end
    end

    // 主状态机（增强MOESI支持）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `CACHE_IDLE;
            cpu_ready <= 1'b0;
            l2_req <= 1'b0;
            l2_we <= 1'b0;
            snoop_ready <= 1'b0;

            // 初始化缓存
            for (integer i = 0; i < `CACHE_NUM_LINES; i = i + 1) begin
                for (integer j = 0; j < `CACHE_NUM_WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                    dirty[i][j] <= 1'b0;
                    mesi[i][j] <= `MOESI_I;
                    lru[i][j] <= j;
                end
            end
        end else begin
            snoop_ready <= 1'b0;

            case (state)
                `CACHE_IDLE: begin
                    cpu_ready <= 1'b0;

                    // 处理监听请求
                    if (snoop_valid) begin
                        snoop_ready <= 1'b1;

                        for (integer i = 0; i < `CACHE_NUM_WAYS; i = i + 1) begin
                            if (valid[index][i] && (cache_tag[index][i] == snoop_addr[63:12])) begin
                                case (snoop_req_type)
                                    `REQ_TYPE_READ: begin
                                        if (mesi[index][i] == `MOESI_M || mesi[index][i] == `MOESI_O) begin
                                            // 提供数据，降级为共享状态
                                            snoop_data <= cache_data[index][i];
                                            mesi[index][i] <= `MOESI_S;
                                        end else if (mesi[index][i] == `MOESI_E) begin
                                            mesi[index][i] <= `MOESI_S;
                                        end
                                    end
                                    `REQ_TYPE_WRITE: begin
                                        // 写无效化
                                        mesi[index][i] <= `MOESI_I;
                                    end
                                    `REQ_TYPE_READ_EXCLUSIVE: begin
                                        // 读独占，无效化当前副本
                                        mesi[index][i] <= `MOESI_I;
                                    end
                                endcase
                            end
                        end
                    end else if (cpu_req) begin
                        saved_addr <= cpu_addr;
                        saved_wdata <= cpu_wdata;
                        saved_byte_en <= cpu_byte_en;
                        saved_we <= cpu_we;

                        if (cache_hit && way_hit >= 0) begin
                            // 缓存命中，根据MOESI状态处理
                            case (mesi[index][way_hit])
                                `MOESI_M, `MOESI_O, `MOESI_E: begin
                                    // 独占状态，可以直接访问
                                    if (cpu_we) begin
                                        state <= `CACHE_WRITE_HIT;
                                        for (integer b = 0; b < 8; b = b + 1) begin
                                            if (cpu_byte_en[b]) begin
                                                cache_data[index][way_hit][offset[5:3]*64 + b*8 +: 8] <=
                                                    cpu_wdata[b*8 +: 8];
                                            end
                                        end
                                        dirty[index][way_hit] <= 1'b1;
                                        mesi[index][way_hit] <= `MOESI_M;
                                    end else begin
                                        state <= `CACHE_READ_HIT;
                                        cpu_rdata <= cache_data[index][way_hit][offset[5:3]*64 +: 64];
                                    end
                                end
                                `MOESI_S: begin
                                    // 共享状态，写操作需要升级
                                    if (cpu_we) begin
                                        // 需要读独占访问
                                        state <= `CACHE_MISS;
                                        l2_req <= 1'b1;
                                        l2_addr <= {tag, index, 6'b0};
                                        l2_req_type <= `REQ_TYPE_READ_EXCLUSIVE;
                                    end else begin
                                        state <= `CACHE_READ_HIT;
                                        cpu_rdata <= cache_data[index][way_hit][offset[5:3]*64 +: 64];
                                    end
                                end
                                default: begin
                                    state <= `CACHE_MISS;
                                    l2_req <= 1'b1;
                                    l2_addr <= {tag, index, 6'b0};
                                    l2_req_type <= cpu_we ? `REQ_TYPE_READ_EXCLUSIVE : `REQ_TYPE_READ;
                                end
                            endcase

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
                            l2_req_type <= cpu_we ? `REQ_TYPE_READ_EXCLUSIVE : `REQ_TYPE_READ;
                        end
                    end
                end

                // ... 其他状态处理类似，增加MOESI状态管理

            endcase
        end
    end

endmodule
