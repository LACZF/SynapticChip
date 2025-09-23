// cache_arbiter.v
module cache_arbiter (
    input wire clk,
    input wire rst_n,

    // 请求信号
    input wire icache_req,
    input wire dcache_req,

    // 授权信号
    output reg grant_icache,
    output reg grant_dcache,

    // 状态信号
    input wire icache_busy,
    input wire dcache_busy
);

    reg [1:0] state;
    localparam STATE_IDLE = 2'b00;
    localparam STATE_ICACHE = 2'b01;
    localparam STATE_DCACHE = 2'b10;

    reg [7:0] icache_priority;  // 指令缓存优先级计数器
    reg [7:0] dcache_priority;  // 数据缓存优先级计数器

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            grant_icache <= 1'b0;
            grant_dcache <= 1'b0;
            icache_priority <= 8'h0;
            dcache_priority <= 8'h0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    grant_icache <= 1'b0;
                    grant_dcache <= 1'b0;

                    if (icache_req && dcache_req) begin
                        // 两个请求同时到达，使用优先级仲裁
                        if (icache_priority >= dcache_priority) begin
                            state <= STATE_ICACHE;
                            grant_icache <= 1'b1;
                            icache_priority <= 8'h0;
                            dcache_priority <= dcache_priority + 1;
                        end else begin
                            state <= STATE_DCACHE;
                            grant_dcache <= 1'b1;
                            dcache_priority <= 8'h0;
                            icache_priority <= icache_priority + 1;
                        end
                    end else if (icache_req) begin
                        state <= STATE_ICACHE;
                        grant_icache <= 1'b1;
                    end else if (dcache_req) begin
                        state <= STATE_DCACHE;
                        grant_dcache <= 1'b1;
                    end
                end

                STATE_ICACHE: begin
                    if (!icache_busy || !icache_req) begin
                        state <= STATE_IDLE;
                        grant_icache <= 1'b0;
                    end
                end

                STATE_DCACHE: begin
                    if (!dcache_busy || !dcache_req) begin
                        state <= STATE_IDLE;
                        grant_dcache <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
