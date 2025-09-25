module ring_bus_tb;

// 参数定义
parameter NUM_RINGS = 2;
parameter NUM_NODES = 4;
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 64;
parameter NODE_ID_WIDTH = 8;
parameter MATCH_TYPE_WIDTH = 2;

// 时钟和复位
reg clk;
reg rst_n;

// DUT接口
reg                         req_valid;
reg  [ADDR_WIDTH-1:0]       req_addr;
reg  [MATCH_TYPE_WIDTH-1:0] req_match_type;
reg  [NODE_ID_WIDTH-1:0]    req_target_id;
reg  [DATA_WIDTH-1:0]       req_data;
reg  [NUM_RINGS-1:0]        req_ring_mask;
reg  [NUM_RINGS-1:0]        req_ring_disable;
wire                        req_ready;

wire                        rsp_valid;
wire [DATA_WIDTH-1:0]       rsp_data;
wire [NODE_ID_WIDTH-1:0]    rsp_src_id;
wire [NUM_RINGS-1:0]        rsp_ring_id;
wire [NUM_RINGS-1:0]        ring_busy;

// 实例化DUT
ring_bus #(
    .NUM_RINGS(NUM_RINGS),
    .NUM_NODES(NUM_NODES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH),
    .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
) u_ring_bus (
    .clk(clk),
    .rst_n(rst_n),

    .req_valid(req_valid),
    .req_addr(req_addr),
    .req_match_type(req_match_type),
    .req_target_id(req_target_id),
    .req_data(req_data),
    .req_ring_mask(req_ring_mask),
    .req_ring_disable(req_ring_disable),
    .req_ready(req_ready),

    .rsp_valid(rsp_valid),
    .rsp_data(rsp_data),
    .rsp_src_id(rsp_src_id),
    .rsp_ring_id(rsp_ring_id),

    .ring_busy(ring_busy)
);

// 时钟生成
always #5 clk = ~clk;

// 测试任务：发送请求
task send_request;
    input [ADDR_WIDTH-1:0]        addr;
    input [MATCH_TYPE_WIDTH-1:0]  match_type;
    input [NODE_ID_WIDTH-1:0]     target_id;
    input [DATA_WIDTH-1:0]        data;
    input [NUM_RINGS-1:0]         ring_mask;
    input [NUM_RINGS-1:0]         ring_disable;
    begin
        @(posedge clk);
        req_valid <= 1'b1;
        req_addr <= addr;
        req_match_type <= match_type;
        req_target_id <= target_id;
        req_data <= data;
        req_ring_mask <= ring_mask;
        req_ring_disable <= ring_disable;

        wait(req_ready);
        @(posedge clk);
        req_valid <= 1'b0;
    end
endtask

initial begin
    // 初始化
    clk = 0;
    rst_n = 0;
    req_valid = 0;
    req_addr = 0;
    req_match_type = 0;
    req_target_id = 0;
    req_data = 0;
    req_ring_mask = {NUM_RINGS{1'b1}};
    req_ring_disable = 0;

    // 复位
    #20 rst_n = 1;

    // 测试用例1：地址匹配
    $display("Test 1: Address match");
    send_request(32'h10, 2'b00, 8'h1, 64'h1234, 2'b11, 2'b00);
    wait(rsp_valid);
    $display("Response received: data=%h, src_id=%h, ring_id=%b",
             rsp_data, rsp_src_id, rsp_ring_id);

    // 测试用例2：ID匹配
    $display("Test 2: ID match");
    send_request(32'h0, 2'b01, 8'h2, 64'h5678, 2'b11, 2'b00);
    wait(rsp_valid);
    $display("Response received: data=%h, src_id=%h, ring_id=%b",
             rsp_data, rsp_src_id, rsp_ring_id);

    // 测试用例3：指定Ring总线
    $display("Test 3: Specific ring");
    send_request(32'h20, 2'b00, 8'h1, 64'h9ABC, 2'b01, 2'b00);
    wait(rsp_valid);
    $display("Response received: data=%h, src_id=%h, ring_id=%b",
             rsp_data, rsp_src_id, rsp_ring_id);

    // 测试用例4：禁用Ring总线
    $display("Test 4: Disable ring");
    send_request(32'h30, 2'b00, 8'h1, 64'hDEF0, 2'b11, 2'b01);
    wait(rsp_valid);
    $display("Response received: data=%h, src_id=%h, ring_id=%b",
             rsp_data, rsp_src_id, rsp_ring_id);

    #100;
    $finish;
end

// 监控响应
always @(posedge clk) begin
    if (rsp_valid) begin
        $display("Time %0t: Response valid", $time);
    end
end

endmodule
