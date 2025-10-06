`timescale 1ns/1ps

// CPU顶层模块单元测试平台
module tb_cpu_top;

    // 时钟和复位信号
    reg         clk;
    reg         rst_n;
    reg         ext_int;

    // Ring Bus 接口
    reg  [1:0]   tx_req_ring_mask_i;
    reg  [1:0]   tx_req_ring_disable_i;
    reg          tx_req_valid_i;
    reg          tx_req_is_order_i;
    reg  [7:0]   tx_req_opcode_i;
    reg  [1:0]   tx_req_match_type_i;
    reg  [7:0]   tx_req_source_id_i;
    reg  [7:0]   tx_req_target_id_i;
    reg  [63:0]  tx_req_addr_i;
    reg  [63:0]  tx_req_data_i;

    // 接收请求端口
    wire         rx_req_valid_o;
    wire         rx_req_is_order_o;
    wire [7:0]   rx_req_opcode_o;
    wire [1:0]   rx_req_match_type_o;
    wire [7:0]   rx_req_source_id_o;
    wire [7:0]   rx_req_target_id_o;
    wire [63:0]  rx_req_addr_o;
    wire [63:0]  rx_req_data_o;

    // 响应端口
    wire         rsp_valid_o;
    wire [7:0]   rsp_source_id_o;
    wire [7:0]   rsp_target_id_o;
    wire [63:0]  rsp_addr_o;
    wire [63:0]  rsp_data_o;

    // 时钟生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 实例化被测模块 (DUT)
    cpu_top u_cpu_top (
        // 时钟和复位
        .clk                (clk),
        .rst_n              (rst_n),
        .ext_int            (ext_int),

        // Ring Bus 发送请求
        .tx_req_ring_mask_i (tx_req_ring_mask_i),
        .tx_req_ring_disable_i(tx_req_ring_disable_i),
        .tx_req_valid_i     (tx_req_valid_i),
        .tx_req_is_order_i  (tx_req_is_order_i),
        .tx_req_opcode_i    (tx_req_opcode_i),
        .tx_req_match_type_i(tx_req_match_type_i),
        .tx_req_source_id_i (tx_req_source_id_i),
        .tx_req_target_id_i (tx_req_target_id_i),
        .tx_req_addr_i      (tx_req_addr_i),
        .tx_req_data_i      (tx_req_data_i),

        // Ring Bus 接收请求
        .rx_req_valid_o     (rx_req_valid_o),
        .rx_req_is_order_o  (rx_req_is_order_o),
        .rx_req_opcode_o    (rx_req_opcode_o),
        .rx_req_match_type_o(rx_req_match_type_o),
        .rx_req_source_id_o (rx_req_source_id_o),
        .rx_req_target_id_o (rx_req_target_id_o),
        .rx_req_addr_o      (rx_req_addr_o),
        .rx_req_data_o      (rx_req_data_o),

        // Ring Bus 响应
        .rsp_valid_o        (rsp_valid_o),
        .rsp_source_id_o    (rsp_source_id_o),
        .rsp_target_id_o    (rsp_target_id_o),
        .rsp_addr_o         (rsp_addr_o),
        .rsp_data_o         (rsp_data_o)
    );

    // 主测试程序
    initial begin
        // 初始化
        rst_n = 1;
        ext_int = 0;
        tx_req_ring_mask_i = 0;
        tx_req_ring_disable_i = 0;
        tx_req_valid_i = 0;
        tx_req_is_order_i = 0;
        tx_req_opcode_i = 0;
        tx_req_match_type_i = 0;
        tx_req_source_id_i = 0;
        tx_req_target_id_i = 0;
        tx_req_addr_i = 0;
        tx_req_data_i = 0;

        // 执行复位
        $display("执行CPU复位...");
        rst_n = 0;
        #20 rst_n = 1;
        $display("CPU复位完成");

        // 启动测试
        $display("开始CPU单元测试...");

        // 测试1: CPU启动和指令获取
        $display("测试1: CPU启动和指令获取");
        #1000;

        // 测试2: 注入外部中断
        $display("测试2: 注入外部中断");
        ext_int = 1;
        #10 ext_int = 0;
        #500;

        // 测试3: Ring Bus 通信
        $display("测试3: Ring Bus 通信");
        #500;
        // 发送一个测试请求
        tx_req_valid_i = 1;
        tx_req_opcode_i = 8'h01; // 假设1表示读操作
        tx_req_addr_i = 64'h0000000000001000;
        tx_req_source_id_i = 8'h01;
        tx_req_target_id_i = 8'h00;
        #10 tx_req_valid_i = 0;
        #1000;

        // 测试完成
        $display("所有CPU测试完成!");
        $finish;
    end

    // 全局超时监控
    initial begin
        #20000;
        $display("错误: 测试执行超时! 强制结束仿真.");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_cpu_top.vcd");
        $dumpvars(0, tb_cpu_top);
    end

    // 监控Ring Bus 通信
    always @(posedge clk) begin
        if (rx_req_valid_o) begin
            $display("时间: %t - Ring Bus 请求: 地址=0x%h, 操作码=0x%h", $time, rx_req_addr_o, rx_req_opcode_o);
        end
        if (rsp_valid_o) begin
            $display("时间: %t - Ring Bus 响应: 地址=0x%h, 数据=0x%h", $time, rsp_addr_o, rsp_data_o);
        end
    end

endmodule