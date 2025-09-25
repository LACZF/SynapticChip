module ring_bus_node_tb;

// 参数定义
parameter NUM_RINGS = 2;
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 64;
parameter NODE_ID_WIDTH = 8;
parameter MATCH_TYPE_WIDTH = 2;
parameter TX_FIFO_DEPTH = 4;
parameter RX_FIFO_DEPTH = 4;

// 时钟和复位
reg clk;
reg rst_n;

// 业务模块接口
reg                         app_req_valid;
reg  [ADDR_WIDTH-1:0]       app_req_addr;
reg  [DATA_WIDTH-1:0]       app_req_data;
reg  [NODE_ID_WIDTH-1:0]    app_req_target_id;
reg                         app_req_use_id_match;
reg  [NUM_RINGS-1:0]        app_req_ring_select;
wire                        app_req_ready;

wire                        app_rsp_valid;
wire [DATA_WIDTH-1:0]       app_rsp_data;
wire [NODE_ID_WIDTH-1:0]    app_rsp_src_id;
reg                         app_rsp_ready;

// Ring总线接口
wire [NUM_RINGS-1:0]        ring_req_valid;
wire [ADDR_WIDTH-1:0]       ring_req_addr [NUM_RINGS-1:0];
wire [MATCH_TYPE_WIDTH-1:0] ring_req_match_type [NUM_RINGS-1:0];
wire [NODE_ID_WIDTH-1:0]    ring_req_target_id [NUM_RINGS-1:0];
wire [DATA_WIDTH-1:0]       ring_req_data [NUM_RINGS-1:0];
reg  [NUM_RINGS-1:0]        ring_req_ready;

reg  [NUM_RINGS-1:0]        ring_rsp_valid;
reg  [DATA_WIDTH-1:0]       ring_rsp_data [NUM_RINGS-1:0];
reg  [NODE_ID_WIDTH-1:0]    ring_rsp_src_id [NUM_RINGS-1:0];
wire [NUM_RINGS-1:0]        ring_busy;

wire [ADDR_WIDTH-1:0]        bus_req_addr;
wire [MATCH_TYPE_WIDTH-1:0]  bus_req_match_type;
wire [NODE_ID_WIDTH-1:0]     bus_req_target_id;
wire [DATA_WIDTH-1:0]        bus_req_data;
wire [NUM_RINGS-1:0]         bus_req_ring_select;
wire [DATA_WIDTH-1:0]        bus_rsp_data;
wire [NODE_ID_WIDTH-1:0]     bus_rsp_src_id;
wire [NUM_RINGS-1:0]         bus_rsp_ring_id;

// 状态信号
wire                        node_busy;
wire [NUM_RINGS-1:0]        ring_status;

// 实例化包装器和总线节点
bus_interface_wrapper #(
    .NUM_RINGS(NUM_RINGS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH)
) u_wrapper (
    .clk(clk),
    .rst_n(rst_n),

    .app_req_valid(app_req_valid),
    .app_req_addr(app_req_addr),
    .app_req_data(app_req_data),
    .app_req_target_id(app_req_target_id),
    .app_req_use_id_match(app_req_use_id_match),
    .app_req_ring_select(app_req_ring_select),
    .app_req_ready(app_req_ready),

    .app_rsp_valid(app_rsp_valid),
    .app_rsp_data(app_rsp_data),
    .app_rsp_src_id(app_rsp_src_id),
    .app_rsp_ready(app_rsp_ready),

    .bus_req_valid(bus_req_valid),
    .bus_req_addr(bus_req_addr),
    .bus_req_match_type(bus_req_match_type),
    .bus_req_target_id(bus_req_target_id),
    .bus_req_data(bus_req_data),
    .bus_req_ring_select(bus_req_ring_select),
    .bus_req_ready(bus_req_ready),

    .bus_rsp_valid(bus_rsp_valid),
    .bus_rsp_data(bus_rsp_data),
    .bus_rsp_src_id(bus_rsp_src_id),
    .bus_rsp_ring_id(bus_rsp_ring_id),
    .bus_rsp_ready(bus_rsp_ready)
);

ring_bus_node #(
    .NUM_RINGS(NUM_RINGS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH),
    .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH)
) u_ring_bus_node (
    .clk(clk),
    .rst_n(rst_n),

    // 业务模块接口
    .bus_req_valid(bus_req_valid),
    .bus_req_addr(bus_req_addr),
    .bus_req_match_type(bus_req_match_type),
    .bus_req_target_id(bus_req_target_id),
    .bus_req_data(bus_req_data),
    .bus_req_ring_select(bus_req_ring_select),
    .bus_req_ready(bus_req_ready),

    .bus_rsp_valid(bus_rsp_valid),
    .bus_rsp_data(bus_rsp_data),
    .bus_rsp_src_id(bus_rsp_src_id),
    .bus_rsp_ring_id(bus_rsp_ring_id),
    .bus_rsp_ready(bus_rsp_ready),

    .node_busy(node_busy),
    .ring_status(ring_status),

    // Ring总线接口
    .ring_req_valid(ring_req_valid),
    .ring_req_addr(ring_req_addr),
    .ring_req_match_type(ring_req_match_type),
    .ring_req_target_id(ring_req_target_id),
    .ring_req_data(ring_req_data),
    .ring_req_ready(ring_req_ready),

    .ring_rsp_valid(ring_rsp_valid),
    .ring_rsp_data(ring_rsp_data),
    .ring_rsp_src_id(ring_rsp_src_id),
    .ring_busy(ring_busy)
);

// 时钟生成
always #5 clk = ~clk;

// 测试任务：发送应用请求
task send_app_request;
    input [ADDR_WIDTH-1:0]     addr;
    input [DATA_WIDTH-1:0]     data;
    input [NODE_ID_WIDTH-1:0]  target_id;
    input                      use_id_match;
    input [NUM_RINGS-1:0]      ring_select;
    begin
        @(posedge clk);
        app_req_valid <= 1'b1;
        app_req_addr <= addr;
        app_req_data <= data;
        app_req_target_id <= target_id;
        app_req_use_id_match <= use_id_match;
        app_req_ring_select <= ring_select;

        wait(app_req_ready);
        @(posedge clk);
        app_req_valid <= 1'b0;
    end
endtask

// 模拟Ring总线响应
task send_ring_response;
    input [NUM_RINGS-1:0]      ring_id;
    input [DATA_WIDTH-1:0]     data;
    input [NODE_ID_WIDTH-1:0]  src_id;
    begin
        @(posedge clk);
        ring_rsp_valid <= ring_id;
        ring_rsp_data[0] <= data;
        ring_rsp_data[1] <= data;
        ring_rsp_src_id[0] <= src_id;
        ring_rsp_src_id[1] <= src_id;

        @(posedge clk);
        ring_rsp_valid <= 2'b00;
    end
endtask

initial begin
    // 初始化
    clk = 0;
    rst_n = 0;
    app_req_valid = 0;
    app_req_addr = 0;
    app_req_data = 0;
    app_req_target_id = 0;
    app_req_use_id_match = 0;
    app_req_ring_select = 2'b11;
    app_rsp_ready = 1;

    ring_req_ready = 2'b11;
    ring_rsp_valid = 2'b00;
    ring_rsp_data[0] = 0;
    ring_rsp_data[1] = 0;
    ring_rsp_src_id[0] = 0;
    ring_rsp_src_id[1] = 0;
    // ring_busy = 2'b00;

    // 复位
    #20 rst_n = 1;

    // 测试用例1：自动选择Ring总线
    $display("Test 1: Auto ring selection");
    send_app_request(32'h1000, 64'h12345678, 8'h01, 0, 2'b11);

    // 检查请求是否发送到Ring总线
    @(posedge clk);
    if (|ring_req_valid) begin
        $display("Request sent to ring %b", ring_req_valid);
    end

    // 模拟响应
    #20 send_ring_response(2'b01, 64'h87654321, 8'h01);

    // 检查响应
    wait(app_rsp_valid);
    $display("Response received: data=%h, src_id=%h", app_rsp_data, app_rsp_src_id);

    // 测试用例2：指定Ring总线
    $display("Test 2: Specific ring selection");
    send_app_request(32'h2000, 64'hAABBCCDD, 8'h02, 1, 2'b10);

    @(posedge clk);
    if (ring_req_valid == 2'b10) begin
        $display("Request correctly sent to ring 1");
    end

    // 测试用例3：Ring总线忙状态
    $display("Test 3: Ring busy state");
    // ring_busy = 2'b01;  // Ring 0忙

    send_app_request(32'h3000, 64'h11223344, 8'h03, 0, 2'b11);

    @(posedge clk);
    if (ring_req_valid == 2'b10) begin
        $display("Request correctly avoided busy ring 0");
    end

    // ring_busy = 2'b00;

    // 测试用例4：背压测试
    $display("Test 4: Backpressure test");
    app_rsp_ready = 0;  // 模拟业务模块不准备接收响应

    send_ring_response(2'b01, 64'h55667788, 8'h04);

    // 检查节点是否变忙
    if (node_busy) begin
        $display("Node busy due to response backpressure");
    end

    app_rsp_ready = 1;
    #10;

    // 测试用例5：FIFO满测试
    $display("Test 5: FIFO full test");

    // 快速发送多个请求
    repeat(6) begin
        @(posedge clk);
        if (app_req_ready) begin
            app_req_valid <= 1'b1;
            app_req_addr <= app_req_addr + 32'h100;
            app_req_data <= app_req_data + 64'h10;
        end else begin
            app_req_valid <= 1'b0;
            $display("FIFO full detected");
        end
    end

    app_req_valid <= 1'b0;

    #100;
    $display("All tests completed");
    $finish;
end

// 监控信号
always @(posedge clk) begin
    if (app_req_valid && app_req_ready) begin
        $display("Time %0t: App request sent - addr=%h, data=%h", $time, app_req_addr, app_req_data);
    end

    if (app_rsp_valid && app_rsp_ready) begin
        $display("Time %0t: App response received - data=%h, src_id=%h", $time, app_rsp_data, app_rsp_src_id);
    end

    if (|ring_req_valid) begin
        $display("Time %0t: Ring request - valid=%b, addr=%h", $time, ring_req_valid,
                 ring_req_valid[0] ? ring_req_addr[0] : ring_req_addr[1]);
    end
end

endmodule
