module memory_response_node #(
    parameter NODE_ID        = 3,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 64
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Ring总线接口
    output reg                          ring_req_valid_o,
    input  wire                         ring_req_ready_i,
    output reg  [ADDR_WIDTH-1:0]        ring_req_addr_o,
    output reg  [DATA_WIDTH-1:0]        ring_req_data_o,
    output reg                          ring_req_wr_o,
    output reg  [7:0]                   ring_req_dest_o,

    input  wire                         ring_resp_valid_i,
    output reg                          ring_resp_ready_o,
    input  wire [DATA_WIDTH-1:0]        ring_resp_data_i,
    input  wire                         ring_resp_error_i,

    // 外部响应接口（到内存控制器）
    output reg                          ext_resp_enable_o,
    output reg  [ADDR_WIDTH-1:0]        ext_resp_addr_o,
    output reg  [DATA_WIDTH-1:0]        ext_resp_data_o,
    output reg                          ext_resp_wr_o,
    input  wire [DATA_WIDTH-1:0]        ext_resp_data_i,
    input  wire                         ext_resp_ready_i
);

    // 内存阵列
    reg [DATA_WIDTH-1:0] memory [0:1023]; // 4KB内存
    reg [DATA_WIDTH-1:0] response_data;

    // 状态机
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        PROCESS_REQUEST = 2'b01,
        SEND_RESPONSE = 2'b10
    } state_t;

    state_t current_state;

    // 请求信息寄存器
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_data;
    reg saved_wr;
    reg [7:0] saved_src_node;

    // 初始化内存
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            memory[i] = {32'h1000 + i, 32'h2000 + i};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            ring_resp_ready_o <= 1'b0;
            ext_resp_enable_o <= 1'b0;
            response_data <= {DATA_WIDTH{1'b0}};
        end else begin
            case (current_state)
                IDLE: begin
                    if (ring_resp_valid_i) begin
                        // 接收来自Ring总线的请求（实际上是响应，因为这是响应节点）
                        // 这里ring_resp_valid_i表示有请求到达本节点
                        saved_addr <= ring_resp_data_i[ADDR_WIDTH-1:0]; // 假设地址在低32位
                        saved_wr <= ring_resp_data_i[32]; // 假设写使能在第32位
                        saved_data <= ring_resp_data_i[63:32]; // 假设数据在63:32位
                        saved_src_node <= 0; // 简化处理，实际应该从请求中提取源节点

                        ring_resp_ready_o <= 1'b1;
                        current_state <= PROCESS_REQUEST;
                    end
                end

                PROCESS_REQUEST: begin
                    ring_resp_ready_o <= 1'b0;

                    // 处理内存请求
                    if (saved_wr) begin
                        // 写操作
                        if (saved_addr < 4096) begin // 地址在4KB范围内
                            memory[saved_addr[11:3]] <= saved_data; // 8字节对齐
                            response_data <= {saved_data[DATA_WIDTH-1:32], 32'hACCE_55ED};
                        end else begin
                            response_data <= {saved_data[DATA_WIDTH-1:32], 32'hDEAD_BEEF};
                        end
                    end else begin
                        // 读操作
                        if (saved_addr < 4096) begin
                            response_data <= memory[saved_addr[11:3]];
                        end else begin
                            response_data <= {saved_addr, 32'hDEAD_BEEF};
                        end
                    end

                    // 通知外部内存控制器（可选）
                    ext_resp_enable_o <= 1'b1;
                    ext_resp_addr_o <= saved_addr;
                    ext_resp_data_o <= saved_data;
                    ext_resp_wr_o <= saved_wr;

                    current_state <= SEND_RESPONSE;
                end

                SEND_RESPONSE: begin
                    ext_resp_enable_o <= 1'b0;

                    // 发送响应回源节点
                    ring_req_valid_o <= 1'b1;
                    ring_req_data_o <= response_data;
                    ring_req_wr_o <= 1'b0; // 响应是读操作
                    ring_req_dest_o <= saved_src_node;

                    if (ring_req_ready_i) begin
                        ring_req_valid_o <= 1'b0;
                        current_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
