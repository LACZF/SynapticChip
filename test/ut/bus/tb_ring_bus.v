// tb_ring_bus.v
// Ring总线测试平台

`include "ring_params.v"
`timescale 1ns/1ps

module tb_ring_bus;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 本地接口
    reg [`NODES-1:0] local_req;
    reg [`NODES*`ADDR_WIDTH-1:0] local_addr;
    reg [`NODES*`DATA_WIDTH-1:0] local_data_in;
    wire [`NODES-1:0] local_ack;
    wire [`NODES*`DATA_WIDTH-1:0] local_data_out;

    // 实例化DUT
    ring_bus dut (
        .clk(clk),
        .rst_n(rst_n),
        .local_req(local_req),
        .local_addr(local_addr),
        .local_data_in(local_data_in),
        .local_ack(local_ack),
        .local_data_out(local_data_out)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：节点发送数据
    task node_send;
        input [(`NODE_ID_WIDTH-1):0] node_id;
        input [(`ADDR_WIDTH-1):0] addr;
        input [(`DATA_WIDTH-1):0] data;
        begin
            local_req[node_id] = 1'b1;
            local_addr[node_id*`ADDR_WIDTH +: `ADDR_WIDTH] = addr;
            local_data_in[node_id*`DATA_WIDTH +: `DATA_WIDTH] = data;

            // 等待确认
            wait(local_ack[node_id] == 1'b1);
            #10;
            local_req[node_id] = 1'b0;
        end
    endtask

    // 测试任务：检查接收数据
    task check_receive;
        input [(`NODE_ID_WIDTH-1):0] node_id;
        input [(`DATA_WIDTH-1):0] expected_data;
        begin
            if (local_data_out[node_id*`DATA_WIDTH +: `DATA_WIDTH] !== expected_data) begin
                $display("ERROR: Node %d received %h, expected %h",
                         node_id,
                         local_data_out[node_id*`DATA_WIDTH +: `DATA_WIDTH],
                         expected_data);
                $finish;
            end else begin
                $display("PASS: Node %d correctly received %h", node_id, expected_data);
            end
        end
    endtask

    // 主测试程序
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        local_req = {`NODES{1'b0}};
        local_addr = {(`NODES*`ADDR_WIDTH){1'b0}};
        local_data_in = {(`NODES*`DATA_WIDTH){1'b0}};

        // 复位
        #20 rst_n = 1;

        $display("Starting Ring Bus Test with %d nodes", `NODES);

        // 测试1: 节点0发送数据到节点1
        $display("Test 1: Node0 -> Node1");
        fork
            begin
                // 节点0发送数据
                #30;
                node_send(0, 8'h10, 32'hAABBCCDD);
            end
            begin
                // 节点1检查接收
                #100;
                check_receive(1, 32'hAABBCCDD);
            end
        join

        // 测试2: 节点1发送数据到节点2
        $display("Test 2: Node1 -> Node2");
        fork
            begin
                #30;
                node_send(1, 8'h20, 32'h11223344);
            end
            begin
                #100;
                check_receive(2, 32'h11223344);
            end
        join

        // 测试3: 节点2发送数据到节点3
        $display("Test 3: Node2 -> Node3");
        fork
            begin
                #30;
                node_send(2, 8'h30, 32'h55667788);
            end
            begin
                #100;
                check_receive(3, 32'h55667788);
            end
        join

        // 测试4: 节点3发送数据到节点0
        $display("Test 4: Node3 -> Node0");
        fork
            begin
                #30;
                node_send(3, 8'h40, 32'h99AABBCC);
            end
            begin
                #100;
                check_receive(0, 32'h99AABBCC);
            end
        join

        // 测试5: 多节点同时发送（测试仲裁）
        $display("Test 5: Multiple nodes sending simultaneously");
        fork
            begin
                // 节点0发送
                #30;
                node_send(0, 8'h50, 32'hDEADBEEF);
            end
            begin
                // 节点2发送
                #30;
                node_send(2, 8'h60, 32'hCAFEBABE);
            end
            begin
                // 检查节点1接收
                #150;
                check_receive(1, 32'hDEADBEEF);
            end
            begin
                // 检查节点3接收
                #200;
                check_receive(3, 32'hCAFEBABE);
            end
        join

        $display("All tests passed!");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("ring_bus.vcd");
        $dumpvars(0, tb_ring_bus);
    end

endmodule
