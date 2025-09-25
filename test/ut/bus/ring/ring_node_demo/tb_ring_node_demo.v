// 完整的Ring总线系统测试
module tb_ring_node_demo;

    // 参数定义
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 64;
    parameter NODE_ID_WIDTH = 8;
    parameter NUM_RINGS = 2;
    parameter NUM_NODES = 4;
    parameter TX_FIFO_DEPTH = 4;
    parameter RX_FIFO_DEPTH = 4;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 节点0（请求节点）接口
    reg                         node0_req_valid;
    reg  [ADDR_WIDTH-1:0]       node0_req_addr;
    reg  [1:0]                  node0_req_match_type;
    reg  [NODE_ID_WIDTH-1:0]    node0_req_target_id;
    reg  [DATA_WIDTH-1:0]       node0_req_data;
    reg  [NUM_RINGS-1:0]        node0_req_ring_select;
    wire                        node0_req_ready;

    wire                        node0_rsp_valid;
    wire [DATA_WIDTH-1:0]       node0_rsp_data;
    wire [NODE_ID_WIDTH-1:0]    node0_rsp_src_id;
    wire [NUM_RINGS-1:0]        node0_rsp_ring_id;
    reg                         node0_rsp_ready;

    // 节点间连接信号
    wire [NUM_NODES-1:0]        req_valid;
    wire [ADDR_WIDTH-1:0]       req_addr [NUM_NODES-1:0];
    wire [1:0]                  req_match_type [NUM_NODES-1:0];
    wire [NODE_ID_WIDTH-1:0]    req_target_id [NUM_NODES-1:0];
    wire [DATA_WIDTH-1:0]       req_data [NUM_NODES-1:0];
    wire [NUM_NODES-1:0]        req_ready;

    wire [NUM_NODES-1:0]        rsp_valid;
    wire [DATA_WIDTH-1:0]       rsp_data [NUM_NODES-1:0];
    wire [NODE_ID_WIDTH-1:0]    rsp_src_id [NUM_NODES-1:0];
    wire [NUM_RINGS-1:0]        rsp_ring_id [NUM_NODES-1:0];
    wire [NUM_NODES-1:0]        rsp_ready;

    // 设备接口
    wire [NUM_NODES-1:0]        dev_req_valid;
    wire [NUM_NODES-1:0]        dev_req_type;
    wire [ADDR_WIDTH-1:0]       dev_req_addr [NUM_NODES-1:0];
    wire [DATA_WIDTH-1:0]       dev_req_data [NUM_NODES-1:0];
    wire [NUM_NODES-1:0]        dev_req_ready;

    wire [NUM_NODES-1:0]        dev_rsp_valid;
    wire [DATA_WIDTH-1:0]       dev_rsp_data [NUM_NODES-1:0];
    wire [NUM_NODES-1:0]        dev_rsp_error;
    wire [NUM_NODES-1:0]        dev_rsp_ready;

    // 生成节点连接
    genvar i;
    generate
        for (i = 0; i < NUM_NODES; i = i + 1) begin : node_gen
            if (i == 0) begin
                // 节点0：请求节点
                ring_request_node #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .NODE_ID_WIDTH(NODE_ID_WIDTH),
                    .NUM_RINGS(NUM_RINGS),
                    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
                    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
                    .NODE_ID(i)
                ) u_node (
                    .clk(clk),
                    .rst_n(rst_n),

                    // 业务接口
                    .req_valid(node0_req_valid),
                    .req_addr(node0_req_addr),
                    .req_match_type(node0_req_match_type),
                    .req_target_id(node0_req_target_id),
                    .req_data(node0_req_data),
                    .req_ring_select(node0_req_ring_select),
                    .req_ready(node0_req_ready),

                    .rsp_valid(node0_rsp_valid),
                    .rsp_data(node0_rsp_data),
                    .rsp_src_id(node0_rsp_src_id),
                    .rsp_ring_id(node0_rsp_ring_id),
                    .rsp_ready(node0_rsp_ready),

                    // Ring总线接口
                    .in_req_valid(req_valid[i]),
                    .in_req_addr(req_addr[i]),
                    .in_req_match_type(req_match_type[i]),
                    .in_req_target_id(req_target_id[i]),
                    .in_req_data(req_data[i]),
                    .in_req_ready(req_ready[i]),

                    .out_req_valid(req_valid[(i+1)%NUM_NODES]),
                    .out_req_addr(req_addr[(i+1)%NUM_NODES]),
                    .out_req_match_type(req_match_type[(i+1)%NUM_NODES]),
                    .out_req_target_id(req_target_id[(i+1)%NUM_NODES]),
                    .out_req_data(req_data[(i+1)%NUM_NODES]),
                    .out_req_ready(req_ready[(i+1)%NUM_NODES]),

                    .in_rsp_valid(rsp_valid[i]),
                    .in_rsp_data(rsp_data[i]),
                    .in_rsp_src_id(rsp_src_id[i]),
                    .in_rsp_ring_id(rsp_ring_id[i]),

                    .out_rsp_valid(rsp_valid[(i+1)%NUM_NODES]),
                    .out_rsp_data(rsp_data[(i+1)%NUM_NODES]),
                    .out_rsp_src_id(rsp_src_id[(i+1)%NUM_NODES]),
                    .out_rsp_ring_id(rsp_ring_id[(i+1)%NUM_NODES]),

                    .node_busy(),
                    .ring_status()
                );
            end else begin
                // 节点1-3：响应节点
                ring_response_node #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .NODE_ID_WIDTH(NODE_ID_WIDTH),
                    .NUM_RINGS(NUM_RINGS),
                    .NODE_ID(i),
                    .BASE_ADDR(i * 32'h1000),
                    .ADDR_MASK(32'hF000)
                ) u_node (
                    .clk(clk),
                    .rst_n(rst_n),

                    // 设备接口
                    .dev_req_valid(dev_req_valid[i]),
                    .dev_req_type(dev_req_type[i]),
                    .dev_req_addr(dev_req_addr[i]),
                    .dev_req_data(dev_req_data[i]),
                    .dev_req_ready(dev_req_ready[i]),

                    .dev_rsp_valid(dev_rsp_valid[i]),
                    .dev_rsp_data(dev_rsp_data[i]),
                    .dev_rsp_error(dev_rsp_error[i]),
                    .dev_rsp_ready(dev_rsp_ready[i]),

                    // Ring总线接口
                    .in_req_valid(req_valid[i]),
                    .in_req_addr(req_addr[i]),
                    .in_req_match_type(req_match_type[i]),
                    .in_req_target_id(req_target_id[i]),
                    .in_req_data(req_data[i]),
                    .in_req_ready(req_ready[i]),

                    .out_req_valid(req_valid[(i+1)%NUM_NODES]),
                    .out_req_addr(req_addr[(i+1)%NUM_NODES]),
                    .out_req_match_type(req_match_type[(i+1)%NUM_NODES]),
                    .out_req_target_id(req_target_id[(i+1)%NUM_NODES]),
                    .out_req_data(req_data[(i+1)%NUM_NODES]),
                    .out_req_ready(req_ready[(i+1)%NUM_NODES]),

                    .in_rsp_valid(rsp_valid[i]),
                    .in_rsp_data(rsp_data[i]),
                    .in_rsp_src_id(rsp_src_id[i]),
                    .in_rsp_ring_id(rsp_ring_id[i]),

                    .out_rsp_valid(rsp_valid[(i+1)%NUM_NODES]),
                    .out_rsp_data(rsp_data[(i+1)%NUM_NODES]),
                    .out_rsp_src_id(rsp_src_id[(i+1)%NUM_NODES]),
                    .out_rsp_ring_id(rsp_ring_id[(i+1)%NUM_NODES]),

                    .node_busy(),
                    .node_state()
                );

                // 为响应节点连接设备
                if (i == 1) begin
                    // 节点1连接内存设备
                    memory_device #(
                        .ADDR_WIDTH(ADDR_WIDTH),
                        .DATA_WIDTH(DATA_WIDTH),
                        .MEM_SIZE(1024)
                    ) u_mem (
                        .clk(clk),
                        .rst_n(rst_n),

                        .dev_req_valid(dev_req_valid[i]),
                        .dev_req_type(dev_req_type[i]),
                        .dev_req_addr(dev_req_addr[i]),
                        .dev_req_data(dev_req_data[i]),
                        .dev_req_ready(dev_req_ready[i]),

                        .dev_rsp_valid(dev_rsp_valid[i]),
                        .dev_rsp_data(dev_rsp_data[i]),
                        .dev_rsp_error(dev_rsp_error[i]),
                        .dev_rsp_ready(dev_rsp_ready[i]),

                        .mem_busy()
                    );
                end else begin
                    // 节点2-3连接UART设备
                    uart_device #(
                        .DATA_WIDTH(DATA_WIDTH)
                    ) u_uart (
                        .clk(clk),
                        .rst_n(rst_n),

                        .dev_req_valid(dev_req_valid[i]),
                        .dev_req_type(dev_req_type[i]),
                        .dev_req_addr(dev_req_addr[i]),
                        .dev_req_data(dev_req_data[i]),
                        .dev_req_ready(dev_req_ready[i]),

                        .dev_rsp_valid(dev_rsp_valid[i]),
                        .dev_rsp_data(dev_rsp_data[i]),
                        .dev_rsp_error(dev_rsp_error[i]),
                        .dev_rsp_ready(dev_rsp_ready[i]),

                        .uart_tx(),
                        .uart_rx(1'b1),

                        .uart_busy()
                    );
                end
            end
        end
    endgenerate

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：发送请求
    task send_request;
        input [ADDR_WIDTH-1:0]        addr;
        input [1:0]                   match_type;
        input [NODE_ID_WIDTH-1:0]     target_id;
        input [DATA_WIDTH-1:0]        data;
        input [NUM_RINGS-1:0]         ring_select;
        begin
            @(posedge clk);
            node0_req_valid <= 1'b1;
            node0_req_addr <= addr;
            node0_req_match_type <= match_type;
            node0_req_target_id <= target_id;
            node0_req_data <= data;
            node0_req_ring_select <= ring_select;

            wait(node0_req_ready);
            @(posedge clk);
            node0_req_valid <= 1'b0;
        end
    endtask

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        node0_req_valid = 0;
        node0_req_addr = 0;
        node0_req_match_type = 0;
        node0_req_target_id = 0;
        node0_req_data = 0;
        node0_req_ring_select = 2'b11;
        node0_rsp_ready = 1;

        // 复位
        #20 rst_n = 1;

        $display("=== Ring总线系统测试 ===");

        // 测试1：地址匹配的内存读操作
        $display("Test 1: Address match memory read");
        send_request(32'h1000, 2'b00, 8'h01, 64'h1234, 2'b01);

        // 等待响应
        wait(node0_rsp_valid);
        $display("Memory read response: data=%h, src_id=%h, ring_id=%b",
                node0_rsp_data, node0_rsp_src_id, node0_rsp_ring_id);

        // 测试2：地址匹配的内存写操作
        $display("Test 2: Address match memory write");
        send_request(32'h1001, 2'b00, 8'h01, 64'h5678, 2'b01);

        wait(node0_rsp_valid);
        $display("Memory write response: data=%h, src_id=%h, ring_id=%b",
                node0_rsp_data, node0_rsp_src_id, node0_rsp_ring_id);

        // 测试3：ID匹配的UART操作
        $display("Test 3: ID match UART operation");
        send_request(32'h0000, 2'b01, 8'h02, 64'hAABB, 2'b10);

        wait(node0_rsp_valid);
        $display("UART response: data=%h, src_id=%h, ring_id=%b",
                node0_rsp_data, node0_rsp_src_id, node0_rsp_ring_id);

        // 测试4：广播操作
        $display("Test 4: Broadcast operation");
        send_request(32'h0000, 2'b10, 8'h00, 64'hCCDD, 2'b11);

        wait(node0_rsp_valid);
        $display("Broadcast response: data=%h, src_id=%h, ring_id=%b",
                node0_rsp_data, node0_rsp_src_id, node0_rsp_ring_id);

        // 测试5：指定Ring总线
        $display("Test 5: Specific ring selection");
        send_request(32'h2000, 2'b00, 8'h01, 64'hEEFF, 2'b10);

        wait(node0_rsp_valid);
        $display("Specific ring response: data=%h, src_id=%h, ring_id=%b",
                node0_rsp_data, node0_rsp_src_id, node0_rsp_ring_id);

        #100;
        $display("All tests completed successfully");
        $finish;
    end

    // 监控信号
    always @(posedge clk) begin
        if (node0_req_valid && node0_req_ready) begin
            $display("Time %0t: Request sent - addr=%h, target_id=%h, ring=%b",
                    $time, node0_req_addr, node0_req_target_id, node0_req_ring_select);
        end

        if (node0_rsp_valid && node0_rsp_ready) begin
            $display("Time %0t: Response received - data=%h, src_id=%h",
                    $time, node0_rsp_data, node0_rsp_src_id);
        end
    end

    // 波形输出
    initial begin
        $dumpfile("ring_node_demo.vcd");
        $dumpvars(0, tb_ring_node_demo);
    end

endmodule
