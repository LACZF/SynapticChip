// l2_cache_controller.v
`include "cache_params.v"

module l2_cache_controller #(
    parameter NUM_CORES = 2
) (
    input wire clk,
    input wire rst_n,

    // L1缓存接口
    input wire [NUM_CORES-1:0] l1_icache_req,
    input wire [NUM_CORES*64-1:0] l1_icache_addr,
    output reg [NUM_CORES*512-1:0] l1_icache_data,
    output reg [NUM_CORES-1:0] l1_icache_ready,

    input wire [NUM_CORES-1:0] l1_dcache_req,
    input wire [NUM_CORES*64-1:0] l1_dcache_addr,
    input wire [NUM_CORES*512-1:0] l1_dcache_wdata,
    output reg [NUM_CORES*512-1:0] l1_dcache_data,
    input wire [NUM_CORES-1:0] l1_dcache_we,
    output reg [NUM_CORES-1:0] l1_dcache_ready,

    // 内存接口
    output reg mem_req,
    output reg [63:0] mem_addr,
    output reg [511:0] mem_wdata,
    input wire [511:0] mem_rdata,
    output reg mem_we,
    input wire mem_ready,

    // 一致性接口
    output reg [NUM_CORES-1:0] snoop_valid,
    output reg [NUM_CORES*64-1:0] snoop_addr,
    output reg [NUM_CORES-1:0] snoop_we,
    input wire [NUM_CORES-1:0] snoop_hit,
    input wire [NUM_CORES*512-1:0] snoop_data
);

    // 仲裁和请求处理
    reg [2:0] state;
    reg [NUM_CORES-1:0] current_master;
    integer current_core;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `CACHE_IDLE;
            l1_icache_ready <= {NUM_CORES{1'b0}};
            l1_dcache_ready <= {NUM_CORES{1'b0}};
            mem_req <= 1'b0;
            snoop_valid <= {NUM_CORES{1'b0}};
        end else begin
            case (state)
                `CACHE_IDLE: begin
                    // 优先级仲裁：数据缓存优先于指令缓存
                    current_core = -1;

                    // 寻找活跃的数据缓存请求
                    for (integer i = 0; i < NUM_CORES; i = i + 1) begin
                        if (l1_dcache_req[i] && current_core == -1) begin
                            current_core = i;
                            current_master = (1 << i);
                        end
                    end

                    // 如果没有数据缓存请求，寻找活跃的指令缓存请求
                    if (current_core == -1) begin
                        for (integer i = 0; i < NUM_CORES; i = i + 1) begin
                            if (l1_icache_req[i] && current_core == -1) begin
                                current_core = i;
                                current_master = (1 << i);
                            end
                        end
                    end

                    if (current_core >= 0) begin
                        state <= `CACHE_MISS;
                        mem_req <= 1'b1;
                        mem_addr <= l1_dcache_req[current_core] ?
                                   l1_dcache_addr[current_core*64 +: 64] :
                                   l1_icache_addr[current_core*64 +: 64];
                        mem_we <= l1_dcache_we[current_core];

                        if (l1_dcache_we[current_core]) begin
                            mem_wdata <= l1_dcache_wdata[current_core*512 +: 512];
                        end

                        // 发送监听请求给其他核
                        for (integer i = 0; i < NUM_CORES; i = i + 1) begin
                            if (i != current_core) begin
                                snoop_valid[i] <= 1'b1;
                                snoop_addr[i*64 +: 64] <= mem_addr;
                                snoop_we[i] <= l1_dcache_we[current_core];
                            end
                        end
                    end
                end

                `CACHE_MISS: begin
                    if (mem_ready) begin
                        mem_req <= 1'b0;
                        snoop_valid <= {NUM_CORES{1'b0}};

                        // 返回数据给请求的核
                        if (current_master & l1_dcache_req) begin
                            l1_dcache_data[current_core*512 +: 512] <= mem_rdata;
                            l1_dcache_ready[current_core] <= 1'b1;
                        end else begin
                            l1_icache_data[current_core*512 +: 512] <= mem_rdata;
                            l1_icache_ready[current_core] <= 1'b1;
                        end

                        state <= `CACHE_IDLE;
                    end
                end

                default: begin
                    state <= `CACHE_IDLE;
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