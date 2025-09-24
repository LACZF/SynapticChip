// memory_interface_adapter.v
module memory_interface_adapter (
    input wire clk,
    input wire rst_n,

    // 缓存系统接口
    input wire [63:0] cache_addr,
    input wire [63:0] cache_data_out,
    output reg [63:0] cache_data_in,
    input wire cache_we,
    input wire [7:0] cache_sel,
    input wire cache_req,
    output reg cache_ack,

    // 外部存储器接口
    output reg [63:0] ext_mem_addr,
    output reg [63:0] ext_mem_data_out,
    input wire [63:0] ext_mem_data_in,
    output reg ext_mem_we,
    output reg [7:0] ext_mem_sel,
    output reg ext_mem_req,
    input wire ext_mem_ack
);

    // 状态机
    reg [1:0] state;
    localparam STATE_IDLE = 2'b00;
    localparam STATE_READ = 2'b01;
    localparam STATE_WRITE = 2'b10;

    // 地址映射（简化：直接映射）
    always @(*) begin
        ext_mem_addr = cache_addr;
        ext_mem_data_out = cache_data_out;
        ext_mem_we = cache_we;
        ext_mem_sel = cache_sel;
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cache_ack <= 1'b0;
            ext_mem_req <= 1'b0;
            cache_data_in <= 64'h0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    cache_ack <= 1'b0;

                    if (cache_req) begin
                        ext_mem_req <= 1'b1;
                        state <= cache_we ? STATE_WRITE : STATE_READ;
                    end
                end

                STATE_READ: begin
                    if (ext_mem_ack) begin
                        cache_data_in <= ext_mem_data_in;
                        cache_ack <= 1'b1;
                        ext_mem_req <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end

                STATE_WRITE: begin
                    if (ext_mem_ack) begin
                        cache_ack <= 1'b1;
                        ext_mem_req <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
