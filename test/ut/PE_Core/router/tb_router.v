// tb_router.v
// 路由模块测试平台（纯Verilog）

`include "pe_router_params.v"
`timescale 1ns/1ps

module tb_router;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 配置接口
    reg cfg_valid;
    reg [`ADDR_WIDTH-1:0] cfg_addr;
    reg [`DATA_WIDTH-1:0] cfg_data;
    wire cfg_ack;

    // 数据输入接口
    reg [`NUM_PORTS-1:0] data_in_valid;
    reg [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_in;
    wire [`NUM_PORTS-1:0] data_in_ready;

    // 数据输出接口
    wire [`NUM_PORTS-1:0] data_out_valid;
    wire [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_out;
    reg [`NUM_PORTS-1:0] data_out_ready;

    // 状态输出
    wire [`DATA_WIDTH-1:0] status;

    // 实例化DUT - 显式传递参数以确保一致性
    pe_router_top #(
        .NUM_PORTS(`NUM_PORTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid(cfg_valid),
        .cfg_addr(cfg_addr),
        .cfg_data(cfg_data),
        .cfg_ack(cfg_ack),
        .data_in_valid(data_in_valid),
        .data_in(data_in),
        .data_in_ready(data_in_ready),
        .data_out_valid(data_out_valid),
        .data_out(data_out),
        .data_out_ready(data_out_ready),
        .status(status)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 定义超时周期参数
    localparam TIMEOUT_CYCLES = 1000;

    // 测试任务：发送配置（带超时机制）
    task send_config;
        input [`ADDR_WIDTH-1:0] addr;
        input [`DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            @(posedge clk);
            cfg_valid = 1'b1;
            cfg_addr = addr;
            cfg_data = data;
            timeout = 0;

            while (!cfg_ack && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Configuration timeout for address 0x%h", addr);
            end

            @(posedge clk);
            cfg_valid = 1'b0;
        end
    endtask

    // 测试任务：发送数据（带超时机制）
    task send_data;
        input integer port;
        input [`DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            @(posedge clk);
            data_in_valid[port] = 1'b1;
            data_in[port*`DATA_WIDTH +: `DATA_WIDTH] = data;
            timeout = 0;

            while (!data_in_ready[port] && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Send data timeout on port %0d", port);
            end

            @(posedge clk);
            data_in_valid[port] = 1'b0;
        end
    endtask

    // 测试任务：接收数据（带超时机制）
    task receive_data;
        input integer port;
        output [`DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            timeout = 0;
            while (!data_out_valid[port] && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Receive data timeout on port %0d", port);
                data = 32'hDEADBEEF; // 超时标志值
            end else begin
                data = data_out[port*`DATA_WIDTH +: `DATA_WIDTH];
            end

            @(posedge clk);
            data_out_ready[port] = 1'b1;
            @(posedge clk);
            data_out_ready[port] = 1'b0;
        end
    endtask

    // 主测试程序
    reg [`DATA_WIDTH-1:0] received_data;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        cfg_valid = 0;
        cfg_addr = 0;
        cfg_data = 0;
        data_in_valid = 5'b00000;
        data_in = 0;
        data_out_ready = 5'b11111; // 默认所有输出端口就绪

        // 复位
        #20 rst_n = 1;

        fork
            // 主测试流程
            begin
                $display("Starting Router Test");

                // 测试1: 配置路由算法
                $display("Test 1: Configure routing algorithm");
                send_config(`REG_ROUTE_ALGO, `ROUTE_XY);
                $display("Routing algorithm configured to XY");

                // 测试2: 配置路由表
                $display("Test 2: Configure routing table");
                // 设置路由表: 本地端口 -> 北端口
                send_config(`REG_ROUTE_TABLE, 25'b0000100000000000000000000);
                $display("Routing table configured");

                // 测试3: 发送数据从本地到北
                $display("Test 3: Send data from local to north");
                fork
                    begin
                        send_data(4, 32'hAABBCCDD); // 从本地端口发送数据
                        $display("Data sent from local port: 0x%h", 32'hAABBCCDD);
                    end
                    begin
                        receive_data(0, received_data); // 从北端口接收数据
                        if (received_data !== 32'hAABBCCDD && received_data !== 32'hDEADBEEF) begin
                            $display("ERROR: Received 0x%h, expected 0xAABBCCDD", received_data);
                        end else if (received_data === 32'hAABBCCDD) begin
                            $display("Data received at north port: 0x%h", received_data);
                        end
                    end
                join

                // 测试4: 测试背压机制
                $display("Test 4: Test backpressure mechanism");

                // 先填满北端口的输出缓冲区
                data_out_ready[0] = 1'b0; // 不让北端口接收数据

                // 发送多个数据包
                send_data(4, 32'h11223344);
                send_data(4, 32'h55667788);
                send_data(4, 32'h99AABBCC);

                // 检查本地端口的ready信号是否变低（背压）
                if (data_in_ready[4] !== 1'b0) begin
                    $display("ERROR: Backpressure not working, local port ready: %b", data_in_ready[4]);
                end else begin
                    $display("Backpressure working correctly");
                end

                // 释放北端口
                data_out_ready[0] = 1'b1;

                // 接收所有数据
                receive_data(0, received_data);
                $display("Received: 0x%h", received_data);
                receive_data(0, received_data);
                $display("Received: 0x%h", received_data);
                receive_data(0, received_data);
                $display("Received: 0x%h", received_data);

                // 测试5: 测试端口禁用
                $display("Test 5: Test port disable");

                // 禁用北端口
                send_config(`REG_PORT_CTRL, 5'b01111); // 只有北端口禁用

                // 尝试发送数据到北端口
                send_data(4, 32'hDEADBEEF);

                // 检查数据是否没有被路由到北端口
                #50; // 等待一段时间
                if (data_out_valid[0] !== 1'b0) begin
                    $display("ERROR: Data routed to disabled north port");
                end else begin
                    $display("Port disable working correctly");
                end

                // 重新启用北端口
                send_config(`REG_PORT_CTRL, 5'b11111); // 所有端口启用

                // 测试6: 读取状态寄存器
                $display("Test 6: Read status register");
                // 状态寄存器包含缓冲区状态和端口使能状态
                $display("Status register: 0x%h", status);

                $display("All tests completed!");
                $finish;
            end

            // 全局超时机制
            begin
                #1000000; // 1毫秒超时 (假设时间单位是ns)
                $display("ERROR: Global test timeout after 1ms");
                $finish;
            end
        join
    end

    // 波形输出
    initial begin
        $dumpfile("router.vcd");
        $dumpvars(0, tb_router);
    end

endmodule