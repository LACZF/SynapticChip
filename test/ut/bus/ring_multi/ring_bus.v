module ring_bus #(
    parameter RING_ID        = 0,
    parameter NUM_NODES      = 4,
    parameter ADDR_WIDTH     = 32,
    parameter DATA_WIDTH     = 64,
    parameter NODE_ID_WIDTH  = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 节点请求接口 - 完全展开的一维数组
    input  wire [NUM_NODES-1:0]         node_req_valid_i,
    output reg                          node_req_ready_o,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0] node_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0] node_req_data_i,
    input  wire [NUM_NODES-1:0]         node_req_wr_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0] node_req_dest_i,

    // 节点响应接口 - 完全展开的一维数组
    output reg  [NUM_NODES-1:0]         node_resp_valid_o,
    input  wire [NUM_NODES-1:0]         node_resp_ready_i,
    output reg  [NUM_NODES*DATA_WIDTH-1:0] node_resp_data_o,
    output reg  [NUM_NODES-1:0]         node_resp_error_o,

    // 状态输出
    output reg                          ring_busy_o,
    output reg  [7:0]                   ring_load_o
);

    // Ring内部信号 - 完全展开的一维数组
    wire [NUM_NODES-1:0]                ring_req_valid [0:NUM_NODES-1];
    wire [NUM_NODES-1:0]                ring_req_ready [0:NUM_NODES-1];
    wire [ADDR_WIDTH-1:0]               ring_req_addr [0:NUM_NODES-1];
    wire [DATA_WIDTH-1:0]               ring_req_data [0:NUM_NODES-1];
    wire                                ring_req_wr [0:NUM_NODES-1];
    wire [NODE_ID_WIDTH-1:0]            ring_req_dest [0:NUM_NODES-1];

    wire [NUM_NODES-1:0]                ring_resp_valid [0:NUM_NODES-1];
    wire [NUM_NODES-1:0]                ring_resp_ready [0:NUM_NODES-1];
    wire [DATA_WIDTH-1:0]               ring_resp_data [0:NUM_NODES-1];
    wire                                ring_resp_error [0:NUM_NODES-1];

    // 仲裁器
    wire [$clog2(NUM_NODES)-1:0]        grant_node;
    wire                                arb_valid;
    wire                                arb_ready;

    round_robin_arbiter #(
        .NUM_REQUESTS(NUM_NODES)
    ) u_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(node_req_valid_i),
        .grant_o(grant_node),
        .valid_o(arb_valid),
        .ready_i(arb_ready)
    );

    // 输入接口 - 直接使用位选择
    assign arb_ready = ring_req_ready[0];

    // 解包输入信号到内部数组
    generate
        genvar i;
        for (i = 0; i < NUM_NODES; i = i + 1) begin : unpack_inputs
            assign ring_req_valid[i] = node_req_valid_i[i];
            assign ring_req_addr[i] = node_req_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH];
            assign ring_req_data[i] = node_req_data_i[i*DATA_WIDTH +: DATA_WIDTH];
            assign ring_req_wr[i] = node_req_wr_i[i];
            assign ring_req_dest[i] = node_req_dest_i[i*NODE_ID_WIDTH +: NODE_ID_WIDTH];
        end
    endgenerate

    // Ring节点链 - 完全展开的连接
    wire [NUM_NODES-1:0]                node_req_valid_chain [0:NUM_NODES-1];
    wire [NUM_NODES-1:0]                node_req_ready_chain [0:NUM_NODES-1];
    wire [ADDR_WIDTH-1:0]               node_req_addr_chain [0:NUM_NODES-1];
    wire [DATA_WIDTH-1:0]               node_req_data_chain [0:NUM_NODES-1];
    wire [NUM_NODES-1:0]                node_req_wr_chain [0:NUM_NODES-1];
    wire [NODE_ID_WIDTH-1:0]            node_req_dest_chain [0:NUM_NODES-1];

    wire [NUM_NODES-1:0]                node_resp_valid_chain [0:NUM_NODES-1];
    wire [NUM_NODES-1:0]                node_resp_ready_chain [0:NUM_NODES-1];
    wire [DATA_WIDTH-1:0]               node_resp_data_chain [0:NUM_NODES-1];
    wire [NUM_NODES-1:0]                node_resp_error_chain [0:NUM_NODES-1];

    // 连接第一个节点
    assign node_req_valid_chain[0] = arb_valid;
    assign node_req_addr_chain[0] = node_req_addr_i[grant_node*ADDR_WIDTH +: ADDR_WIDTH];
    assign node_req_data_chain[0] = node_req_data_i[grant_node*DATA_WIDTH +: DATA_WIDTH];
    assign node_req_wr_chain[0] = node_req_wr_i[grant_node];
    assign node_req_dest_chain[0] = node_req_dest_i[grant_node*NODE_ID_WIDTH +: NODE_ID_WIDTH];
    assign ring_req_ready[0] = arb_ready;
    assign node_req_ready_o = arb_valid && arb_ready;

    // 生成Ring节点
    genvar j;
    generate
        for (j = 0; j < NUM_NODES; j = j + 1) begin : node_chain
            ring_node #(
                .NODE_ID(j + (RING_ID << 4)),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH)
            ) u_node (
                .clk(clk),
                .rst_n(rst_n),
                // 上游接口
                .up_req_valid_i(node_req_valid_chain[j]),
                .up_req_ready_o(node_req_ready_chain[j]),
                .up_req_addr_i(node_req_addr_chain[j]),
                .up_req_data_i(node_req_data_chain[j]),
                .up_req_wr_i(node_req_wr_chain[j]),
                .up_req_dest_i(node_req_dest_chain[j]),
                // 下游接口
                .dn_req_valid_o(node_req_valid_chain[(j+1)%NUM_NODES]),
                .dn_req_ready_i(1'b1),
                .dn_req_addr_o(node_req_addr_chain[(j+1)%NUM_NODES]),
                .dn_req_data_o(node_req_data_chain[(j+1)%NUM_NODES]),
                .dn_req_wr_o(node_req_wr_chain[(j+1)%NUM_NODES]),
                .dn_req_dest_o(node_req_dest_chain[(j+1)%NUM_NODES]),
                // 响应接口
                .resp_valid_o(node_resp_valid_chain[j]),
                .resp_ready_i(node_resp_ready_chain[j]),
                .resp_data_o(node_resp_data_chain[j]),
                .resp_error_o(node_resp_error_chain[j])
            );

            // 连接响应信号
            assign ring_resp_valid[j] = node_resp_valid_chain[j];
            assign ring_resp_data[j] = node_resp_data_chain[j];
            assign ring_resp_error[j] = node_resp_error_chain[j];
            assign node_resp_ready_chain[j] = node_resp_ready_i[j];
        end
    endgenerate

    // 打包输出信号
    generate
        for (i = 0; i < NUM_NODES; i = i + 1) begin : pack_outputs
            assign node_resp_valid_o[i] = ring_resp_valid[i];
            assign node_resp_data_o[i*DATA_WIDTH +: DATA_WIDTH] = ring_resp_data[i];
            assign node_resp_error_o[i] = ring_resp_error[i];
        end
    endgenerate

    // 负载监控
    reg [15:0] req_counter;
    reg [15:0] cycle_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_counter <= 0;
            cycle_counter <= 0;
            ring_load_o <= 0;
            ring_busy_o <= 0;
        end else begin
            cycle_counter <= cycle_counter + 1;
            ring_busy_o <= |node_req_valid_i;

            if (|node_req_valid_i && node_req_ready_o) begin
                req_counter <= req_counter + 1;
            end

            // 每256周期更新负载
            if (cycle_counter == 255) begin
                ring_load_o <= req_counter[15:8];
                req_counter <= 0;
                cycle_counter <= 0;
            end
        end
    end

endmodule
