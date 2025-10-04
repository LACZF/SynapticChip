// shared_l2_cache.v
`include "l2_cache_params.v"

module shared_l2_cache #(
    parameter NUM_CORES = 4,
    parameter CORE_ID_WIDTH = 2
) (
    input wire clk,
    input wire rst_n,

    // L1缓存接口（指令缓存）
    input wire [NUM_CORES-1:0] l1_icache_req,
    input wire [NUM_CORES*64-1:0] l1_icache_addr,
    output reg [NUM_CORES*512-1:0] l1_icache_data,
    output reg [NUM_CORES-1:0] l1_icache_ready,

    // L1缓存接口（数据缓存）
    input wire [NUM_CORES-1:0] l1_dcache_req,
    input wire [NUM_CORES*64-1:0] l1_dcache_addr,
    input wire [NUM_CORES*512-1:0] l1_dcache_wdata,
    output reg [NUM_CORES*512-1:0] l1_dcache_data,
    input wire [NUM_CORES-1:0] l1_dcache_we,
    input wire [NUM_CORES*2-1:0] l1_dcache_req_type, // 00:读, 01:写, 10:读独占
    output reg [NUM_CORES-1:0] l1_dcache_ready,

    // 内存接口
    output reg mem_req,
    output reg [63:0] mem_addr,
    output reg [511:0] mem_wdata,
    input wire [511:0] mem_rdata,
    output reg mem_we,
    input wire mem_ready,

    // 核间一致性接口（监听）
    output reg [NUM_CORES-1:0] snoop_valid,
    output reg [NUM_CORES*64-1:0] snoop_addr,
    output reg [NUM_CORES*2-1:0] snoop_req_type,
    input wire [NUM_CORES-1:0] snoop_ready,
    input wire [NUM_CORES-1:0] snoop_hit,
    input wire [NUM_CORES*2-1:0] snoop_state,
    input wire [NUM_CORES*512-1:0] snoop_data
);

    // L2缓存存储
    reg [511:0] cache_data [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1];
    reg [`L2_CACHE_TAG_BITS-1:0] cache_tag [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1];
    reg valid [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1];
    reg dirty [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1];
    reg [2:0] mesi [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1];
    reg [2:0] lru [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1];
    reg [NUM_CORES-1:0] shared [0:`L2_CACHE_NUM_LINES-1] [0:`L2_CACHE_NUM_WAYS-1]; // 共享位向量

    // 请求队列
    reg [63:0] req_addr [0:NUM_CORES*2-1];
    reg [511:0] req_wdata [0:NUM_CORES*2-1];
    reg [2:0] req_type [0:NUM_CORES*2-1]; // 0:ICache读, 1:DCache读, 2:DCache写, 3:DCache读独占
    reg [CORE_ID_WIDTH-1:0] req_core_id [0:NUM_CORES*2-1];
    reg req_valid [0:NUM_CORES*2-1];
    reg [2:0] req_priority [0:NUM_CORES*2-1];

    // 仲裁和状态机
    reg [2:0] state;
    reg [3:0] current_req_index;
    reg [CORE_ID_WIDTH-1:0] current_core;
    reg [2:0] current_req_type;
    reg [63:0] current_addr;
    reg [511:0] current_wdata;

    // 地址分解
    wire [`L2_CACHE_OFFSET_BITS-1:0] offset;
    wire [`L2_CACHE_INDEX_BITS-1:0] index;
    wire [`L2_CACHE_TAG_BITS-1:0] tag;

    assign offset = current_addr[5:0];
    assign index = current_addr[15:6];
    assign tag = current_addr[63:16];

    // 内部信号
    reg [2:0] fill_count;
    reg [511:0] fill_buffer;
    reg need_writeback;
    reg snoop_pending;
    reg [NUM_CORES-1:0] snoop_ack;
    integer way_hit;
    integer way_replace;

    // 命中检测
    always @(*) begin
        way_hit = -1;

        for (integer i = 0; i < `L2_CACHE_NUM_WAYS; i = i + 1) begin
            if (valid[index][i] && (cache_tag[index][i] == tag) &&
                (mesi[index][i] != `MOESI_I)) begin
                way_hit = i;
            end
        end
    end

    // LRU替换策略
    always @(*) begin
        way_replace = 0;
        need_writeback = 1'b0;

        for (integer i = 0; i < `L2_CACHE_NUM_WAYS; i = i + 1) begin
            if (!valid[index][i] || mesi[index][i] == `MOESI_I) begin
                way_replace = i;
                need_writeback = 1'b0;
            end else if (lru[index][i] < lru[index][way_replace]) begin
                way_replace = i;
                need_writeback = dirty[index][i] &&
                               (mesi[index][i] == `MOESI_M || mesi[index][i] == `MOESI_O);
            end
        end
    end

    // 请求队列管理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < NUM_CORES*2; i = i + 1) begin
                req_valid[i] <= 1'b0;
            end
        end else begin
            // 处理新的L1请求
            for (integer i = 0; i < NUM_CORES; i = i + 1) begin
                // 指令缓存请求
                if (l1_icache_req[i] && !req_valid[i]) begin
                    req_addr[i] <= l1_icache_addr[i*64 +: 64];
                    req_type[i] <= 3'b000; // ICache读
                    req_core_id[i] <= i[CORE_ID_WIDTH-1:0];
                    req_valid[i] <= 1'b1;
                    req_priority[i] <= 3'b100; // 高优先级
                end

                // 数据缓存请求
                if (l1_dcache_req[i] && !req_valid[i + NUM_CORES]) begin
                    req_addr[i + NUM_CORES] <= l1_dcache_addr[i*64 +: 64];
                    req_wdata[i + NUM_CORES] <= l1_dcache_wdata[i*512 +: 512];
                    req_type[i + NUM_CORES] <= l1_dcache_we[i] ? 3'b010 :
                                             (l1_dcache_req_type[i*2 +: 2] == `REQ_TYPE_READ_EXCLUSIVE) ? 3'b011 : 3'b001;
                    req_core_id[i + NUM_CORES] <= i[CORE_ID_WIDTH-1:0];
                    req_valid[i + NUM_CORES] <= 1'b1;
                    req_priority[i + NUM_CORES] <= 3'b110; // 最高优先级
                end
            end

            // 清除已处理的请求
            if (state == `L2_CACHE_READ_HIT || state == `L2_CACHE_WRITE_HIT) begin
                req_valid[current_req_index] <= 1'b0;
            end
        end
    end

    // 仲裁器
    always @(*) begin
        current_req_index = 0;
        current_core = 0;
        current_req_type = 0;
        current_addr = 64'b0;
        current_wdata = 512'b0;

        // 优先级仲裁
        for (integer i = 0; i < NUM_CORES*2; i = i + 1) begin
            if (req_valid[i] && req_priority[i] > req_priority[current_req_index]) begin
                current_req_index = i;
                current_core = req_core_id[i];
                current_req_type = req_type[i];
                current_addr = req_addr[i];
                current_wdata = req_wdata[i];
            end
        end
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `L2_CACHE_IDLE;
            l1_icache_ready <= {NUM_CORES{1'b0}};
            l1_dcache_ready <= {NUM_CORES{1'b0}};
            mem_req <= 1'b0;
            mem_we <= 1'b0;
            snoop_valid <= {NUM_CORES{1'b0}};
            snoop_pending <= 1'b0;
            snoop_ack <= {NUM_CORES{1'b0}};

            // 初始化L2缓存
            for (integer i = 0; i < `L2_CACHE_NUM_LINES; i = i + 1) begin
                for (integer j = 0; j < `L2_CACHE_NUM_WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                    dirty[i][j] <= 1'b0;
                    mesi[i][j] <= `MOESI_I;
                    lru[i][j] <= j;
                    shared[i][j] <= {NUM_CORES{1'b0}};
                end
            end
        end else begin
            case (state)
                `L2_CACHE_IDLE: begin
                    if (req_valid[current_req_index]) begin
                        state <= `L2_CACHE_SNOOP;
                        snoop_pending <= 1'b1;
                        snoop_ack <= {NUM_CORES{1'b0}};

                        // 向其他核发送监听请求
                        for (integer i = 0; i < NUM_CORES; i = i + 1) begin
                            if (i != current_core) begin
                                snoop_valid[i] <= 1'b1;
                                snoop_addr[i*64 +: 64] <= current_addr;
                                snoop_req_type[i*2 +: 2] <= (current_req_type == 3'b001) ? `REQ_TYPE_READ :
                                                          (current_req_type == 3'b010 || current_req_type == 3'b011) ? `REQ_TYPE_WRITE : `REQ_TYPE_READ;
                            end
                        end
                    end
                end

                `L2_CACHE_SNOOP: begin
                    // 等待监听响应
                    snoop_ack <= snoop_ack | snoop_ready;

                    if (snoop_ack == {(NUM_CORES-1){1'b1}}) begin
                        // 所有监听响应完成
                        snoop_valid <= {NUM_CORES{1'b0}};
                        snoop_pending <= 1'b0;

                        if (way_hit >= 0) begin
                            // L2缓存命中
                            if (current_req_type == 3'b000 || current_req_type == 3'b001) begin
                                state <= `L2_CACHE_READ_HIT;
                            end else begin
                                state <= `L2_CACHE_WRITE_HIT;
                            end
                        end else begin
                            // L2缓存未命中
                            state <= `L2_CACHE_MISS;
                            mem_req <= 1'b1;
                            mem_addr <= {tag, index, 6'b0};
                            mem_we <= 1'b0;

                            if (need_writeback) begin
                                // 需要写回脏行
                                mem_we <= 1'b1;
                                mem_wdata <= cache_data[index][way_replace];
                                mem_addr <= {cache_tag[index][way_replace], index, 6'b0};
                            end
                        end
                    end
                end

                `L2_CACHE_READ_HIT: begin
                    // 提供数据给L1缓存
                    if (current_req_type == 3'b000) begin
                        l1_icache_data[current_core*512 +: 512] <= cache_data[index][way_hit];
                        l1_icache_ready[current_core] <= 1'b1;
                    end else begin
                        l1_dcache_data[current_core*512 +: 512] <= cache_data[index][way_hit];
                        l1_dcache_ready[current_core] <= 1'b1;
                    end

                    // 更新状态
                    if (current_req_type == 3'b011) begin
                        // 读独占请求，升级为独占状态
                        mesi[index][way_hit] <= `MOESI_E;
                        shared[index][way_hit] <= (1 << current_core);
                    end else if (mesi[index][way_hit] == `MOESI_S) begin
                        // 共享状态，添加共享者
                        shared[index][way_hit] <= shared[index][way_hit] | (1 << current_core);
                    end

                    // 更新LRU
                    for (integer i = 0; i < `L2_CACHE_NUM_WAYS; i = i + 1) begin
                        if (i == way_hit) begin
                            lru[index][i] <= `L2_CACHE_NUM_WAYS - 1;
                        end else if (lru[index][i] > lru[index][way_hit]) begin
                            lru[index][i] <= lru[index][i] - 1;
                        end
                    end

                    state <= `L2_CACHE_IDLE;
                end

                `L2_CACHE_WRITE_HIT: begin
                    // 写入数据
                    cache_data[index][way_hit] <= current_wdata;
                    dirty[index][way_hit] <= 1'b1;
                    mesi[index][way_hit] <= `MOESI_M;
                    shared[index][way_hit] <= (1 << current_core); // 只有当前核有副本

                    // 响应L1缓存
                    l1_dcache_data[current_core*512 +: 512] <= current_wdata;
                    l1_dcache_ready[current_core] <= 1'b1;

                    // 更新LRU
                    for (integer i = 0; i < `L2_CACHE_NUM_WAYS; i = i + 1) begin
                        if (i == way_hit) begin
                            lru[index][i] <= `L2_CACHE_NUM_WAYS - 1;
                        end else if (lru[index][i] > lru[index][way_hit]) begin
                            lru[index][i] <= lru[index][i] - 1;
                        end
                    end

                    state <= `L2_CACHE_IDLE;
                end

                `L2_CACHE_MISS: begin
                    if (mem_ready) begin
                        if (mem_we) begin
                            // 写回完成，开始填充
                            mem_we <= 1'b0;
                            mem_addr <= {tag, index, 6'b0};
                        end else begin
                            // 内存读取完成
                            fill_buffer <= mem_rdata;
                            state <= `L2_CACHE_FILL;
                            mem_req <= 1'b0;
                        end
                    end
                end

                `L2_CACHE_FILL: begin
                    // 写入缓存行
                    cache_data[index][way_replace] <= fill_buffer;
                    cache_tag[index][way_replace] <= tag;
                    valid[index][way_replace] <= 1'b1;
                    dirty[index][way_replace] <= (current_req_type == 3'b010 || current_req_type == 3'b011);

                    // 设置状态
                    if (current_req_type == 3'b010 || current_req_type == 3'b011) begin
                        mesi[index][way_replace] <= `MOESI_M;
                        shared[index][way_replace] <= (1 << current_core);
                    end else if (snoop_hit != 0) begin
                        // 其他核有副本，设为共享状态
                        mesi[index][way_replace] <= `MOESI_S;
                        shared[index][way_replace] <= (1 << current_core) | snoop_hit;
                    end else begin
                        mesi[index][way_replace] <= `MOESI_E;
                        shared[index][way_replace] <= (1 << current_core);
                    end

                    // 提供数据给L1缓存
                    if (current_req_type == 3'b000) begin
                        l1_icache_data[current_core*512 +: 512] <= fill_buffer;
                        l1_icache_ready[current_core] <= 1'b1;
                    end else begin
                        if (current_req_type == 3'b010 || current_req_type == 3'b011) begin
                            // 写分配：先填充再写入
                            cache_data[index][way_replace] <= current_wdata;
                            l1_dcache_data[current_core*512 +: 512] <= current_wdata;
                        end else begin
                            l1_dcache_data[current_core*512 +: 512] <= fill_buffer;
                        end
                        l1_dcache_ready[current_core] <= 1'b1;
                    end

                    state <= `L2_CACHE_IDLE;
                end

                default: begin
                    state <= `L2_CACHE_IDLE;
                end
            endcase

            // 复位ready信号
            if (l1_icache_ready != 0) begin
                l1_icache_ready <= {NUM_CORES{1'b0}};
            end
            if (l1_dcache_ready != 0) begin
                l1_dcache_ready <= {NUM_CORES{1'b0}};
            end
        end
    end

endmodule
