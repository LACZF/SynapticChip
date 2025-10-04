module uart_request_node #(
    parameter NODE_ID        = 1,
    parameter TARGET_NODE_ID = 4,  // 目标节点ID（UART响应节点）
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

    // 外部请求接口（从CPU）
    input  wire                         ext_req_enable_i,
    input  wire [ADDR_WIDTH-1:0]        ext_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        ext_req_data_i,
    input  wire                         ext_req_wr_i,
    output reg  [DATA_WIDTH-1:0]        ext_req_data_o,
    output reg                          ext_req_ready_o
);

    // 状态机
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        SEND_REQUEST = 2'b01,
        WAIT_RESPONSE = 2'b10
    } state_t;

    state_t current_state;

    // 请求信息寄存器
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_data;
    reg saved_wr;

    // 超时计数器
    reg [31:0] timeout_counter;
    localparam TIMEOUT_CYCLES = 1000; // 1000个时钟周期超时

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            ring_req_valid_o <= 1'b0;
            ext_req_ready_o <= 1'b1;
            ring_resp_ready_o <= 1'b0;
            ext_req_data_o <= {DATA_WIDTH{1'b0}};
            timeout_counter <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    timeout_counter <= 0;
                    if (ext_req_enable_i && ext_req_ready_o) begin
                        // 保存请求信息
                        saved_addr <= ext_req_addr_i;
                        saved_data <= ext_req_data_i;
                        saved_wr <= ext_req_wr_i;

                        // 准备发送请求到Ring总线
                        ring_req_valid_o <= 1'b1;
                        ring_req_addr_o <= ext_req_addr_i;
                        ring_req_data_o <= ext_req_data_i;
                        ring_req_wr_o <= ext_req_wr_i;
                        ring_req_dest_o <= TARGET_NODE_ID;

                        ext_req_ready_o <= 1'b0;
                        current_state <= SEND_REQUEST;
                    end
                end

                SEND_REQUEST: begin
                    if (ring_req_ready_i) begin
                        ring_req_valid_o <= 1'b0;
                        ring_resp_ready_o <= 1'b1;
                        timeout_counter <= 0;
                        current_state <= WAIT_RESPONSE;
                    end
                end

                WAIT_RESPONSE: begin
                    // 增加超时计数
                    timeout_counter <= timeout_counter + 1;

                    if (ring_resp_valid_i) begin
                        // 接收响应并返回给CPU
                        ext_req_data_o <= ring_resp_data_i;
                        ext_req_ready_o <= 1'b1;
                        ring_resp_ready_o <= 1'b0;
                        current_state <= IDLE;
                    end else if (timeout_counter >= TIMEOUT_CYCLES) begin
                        // 超时处理
                        $display("UART Request Node: Timeout waiting for response!");
                        ext_req_data_o <= {DATA_WIDTH{1'b1}}; // 超时标记
                        ext_req_ready_o <= 1'b1;
                        ring_resp_ready_o <= 1'b0;
                        current_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule