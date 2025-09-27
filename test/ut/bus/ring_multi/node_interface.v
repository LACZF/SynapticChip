module node_interface #(
    parameter NODE_ID        = 0,
    parameter NUM_RINGS      = 2,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 64,
    parameter NODE_ID_WIDTH  = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 外部节点接口
    input  wire                         ext_req_valid_i,
    output reg                          ext_req_ready_o,
    input  wire [ADDR_WIDTH-1:0]        ext_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        ext_req_data_i,
    input  wire                         ext_req_wr_i,
    input  wire [NODE_ID_WIDTH-1:0]     ext_req_dest_i,

    output reg                          ext_resp_valid_o,
    input  wire                         ext_resp_ready_i,
    output reg  [DATA_WIDTH-1:0]        ext_resp_data_o,
    output reg                          ext_resp_error_o,

    // Ring总线接口 - 完全展开的一维数组
    output reg  [NUM_RINGS-1:0]         ring_req_valid_o,
    input  wire [NUM_RINGS-1:0]         ring_req_ready_i,
    output reg  [NUM_RINGS*ADDR_WIDTH-1:0] ring_req_addr_o,
    output reg  [NUM_RINGS*DATA_WIDTH-1:0] ring_req_data_o,
    output reg  [NUM_RINGS-1:0]         ring_req_wr_o,
    output reg  [NUM_RINGS*NODE_ID_WIDTH-1:0] ring_req_dest_o,

    input  wire [NUM_RINGS-1:0]         ring_resp_valid_i,
    output reg  [NUM_RINGS-1:0]         ring_resp_ready_o,
    input  wire [NUM_RINGS*DATA_WIDTH-1:0] ring_resp_data_i,
    input  wire [NUM_RINGS-1:0]         ring_resp_error_i,

    // 负载信息
    input  wire [NUM_RINGS-1:0]         ring_busy_i,
    input  wire [NUM_RINGS*8-1:0]       ring_load_i
);

    // 请求状态机
    typedef enum logic [1:0] {
        REQ_IDLE = 2'b00,
        REQ_SELECT = 2'b01,
        REQ_SEND = 2'b10
    } req_state_t;

    req_state_t req_state;

    // 响应状态机
    typedef enum logic [1:0] {
        RESP_IDLE = 2'b00,
        RESP_RECEIVE = 2'b01
    } resp_state_t;

    resp_state_t resp_state;

    // 从打包的负载数组中提取各个Ring的负载
    wire [7:0] ring_load [0:NUM_RINGS-1];
    generate
        genvar i;
        for (i = 0; i < NUM_RINGS; i = i + 1) begin : load_unpack
            assign ring_load[i] = ring_load_i[i*8 +: 8];
        end
    endgenerate

    // 选择最佳Ring总线
    function integer select_best_ring;
        integer best_ring;
        integer min_load;
        integer i;
        begin
            best_ring = 0;
            min_load = 255;

            for (i = 0; i < NUM_RINGS; i = i + 1) begin
                if (ring_load[i] < min_load) begin
                    min_load = ring_load[i];
                    best_ring = i;
                end
            end

            select_best_ring = best_ring;
        end
    endfunction

    // 请求处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_state <= REQ_IDLE;
            ext_req_ready_o <= 1'b1;
            ring_req_valid_o <= {NUM_RINGS{1'b0}};
            ring_req_wr_o <= {NUM_RINGS{1'b0}};
        end else begin
            case (req_state)
                REQ_IDLE: begin
                    if (ext_req_valid_i && ext_req_ready_o) begin
                        req_state <= REQ_SELECT;
                        ext_req_ready_o <= 1'b0;
                    end
                end

                REQ_SELECT: begin
                    integer best_ring = select_best_ring();
                    ring_req_valid_o[best_ring] <= 1'b1;
                    // 设置选中的Ring总线的信号
                    ring_req_addr_o[best_ring*ADDR_WIDTH +: ADDR_WIDTH] <= ext_req_addr_i;
                    ring_req_data_o[best_ring*DATA_WIDTH +: DATA_WIDTH] <= ext_req_data_i;
                    ring_req_wr_o[best_ring] <= ext_req_wr_i;
                    ring_req_dest_o[best_ring*NODE_ID_WIDTH +: NODE_ID_WIDTH] <= ext_req_dest_i;

                    req_state <= REQ_SEND;
                end

                REQ_SEND: begin
                    for (int i = 0; i < NUM_RINGS; i = i + 1) begin
                        if (ring_req_valid_o[i] && ring_req_ready_i[i]) begin
                            ring_req_valid_o[i] <= 1'b0;
                            ring_req_wr_o[i] <= 1'b0;
                            ext_req_ready_o <= 1'b1;
                            req_state <= REQ_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // 响应处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            resp_state <= RESP_IDLE;
            ext_resp_valid_o <= 1'b0;
            ring_resp_ready_o <= {NUM_RINGS{1'b0}};
        end else begin
            // 总是准备接收所有Ring的响应
            ring_resp_ready_o <= ring_resp_valid_i;

            case (resp_state)
                RESP_IDLE: begin
                    if (|ring_resp_valid_i) begin
                        // 选择第一个有效的响应
                        for (int i = 0; i < NUM_RINGS; i = i + 1) begin
                            if (ring_resp_valid_i[i]) begin
                                ext_resp_valid_o <= 1'b1;
                                ext_resp_data_o <= ring_resp_data_i[i*DATA_WIDTH +: DATA_WIDTH];
                                ext_resp_error_o <= ring_resp_error_i[i];
                                resp_state <= RESP_RECEIVE;
                                break;
                            end
                        end
                    end
                end

                RESP_RECEIVE: begin
                    if (ext_resp_ready_i && ext_resp_valid_o) begin
                        ext_resp_valid_o <= 1'b0;
                        resp_state <= RESP_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
