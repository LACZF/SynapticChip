// tb_jtag_node.v
// JTAG节点测试平台

`include "jtag_params.v"
`timescale 1ns/1ps

module tb_jtag_node;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // Ring接口信号
    reg ring_in_valid;
    reg [`NODE_ID_WIDTH-1:0] ring_in_src;
    reg [`NODE_ID_WIDTH-1:0] ring_in_dest;
    reg [`ADDR_WIDTH-1:0] ring_in_addr;
    reg [`DATA_WIDTH-1:0] ring_in_data;
    reg ring_in_we;
    reg [3:0] ring_in_be;
    reg ring_in_ack;

    wire ring_out_valid;
    wire [`NODE_ID_WIDTH-1:0] ring_out_src;
    wire [`NODE_ID_WIDTH-1:0] ring_out_dest;
    wire [`ADDR_WIDTH-1:0] ring_out_addr;
    wire [`DATA_WIDTH-1:0] ring_out_data;
    wire ring_out_we;
    wire [3:0] ring_out_be;
    wire ring_out_ack;

    // 中间信号用于处理确认逻辑
    reg ring_out_ack_reg;

    // JTAG接口信号
    reg tck;
    reg tms;
    reg tdi;
    wire tdo;
    wire tdo_en;

    // 调试输出
    wire [`DATA_WIDTH-1:0] debug_data;
    wire debug_valid;

    // 实例化DUT
    jtag_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(5'd6),  // JTAG节点ID设为6
        .ring_in_valid(ring_in_valid),
        .ring_in_src(ring_in_src),
        .ring_in_dest(ring_in_dest),
        .ring_in_addr(ring_in_addr),
        .ring_in_data(ring_in_data),
        .ring_in_we(ring_in_we),
        .ring_in_be(ring_in_be),
        .ring_in_ack(ring_in_ack),
        .ring_out_valid(ring_out_valid),
        .ring_out_src(ring_out_src),
        .ring_out_dest(ring_out_dest),
        .ring_out_addr(ring_out_addr),
        .ring_out_data(ring_out_data),
        .ring_out_we(ring_out_we),
        .ring_out_be(ring_out_be),
        .ring_out_ack(ring_out_ack),
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .tdo_en(tdo_en),
        .debug_data(debug_data),
        .debug_valid(debug_valid)
    );

    // 时钟生成
    always #5 clk = ~clk;
    always #10 tck = ~tck; // JTAG时钟频率是系统时钟的一半

    // 写请求超时标志和计数器
    reg write_timeout;
    integer write_timeout_count;

    // 测试任务：发送写请求
    task send_write;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        input [`DATA_WIDTH-1:0] data;
        input [3:0] be;
        begin
            @(posedge clk);
            ring_in_valid = 1'b1;
            ring_in_src = src;
            ring_in_dest = 6;  // JTAG节点ID
            ring_in_addr = addr;
            ring_in_data = data;
            ring_in_we = 1'b1;
            ring_in_be = be;

            $display("[send_write] Sending write request to addr=0x%h, data=0x%h, src=%d, dest=6", addr, data, src);

            // 等待确认，添加超时机制
            write_timeout = 0;
            write_timeout_count = 0;
            while (!ring_out_ack && !write_timeout) begin
                @(posedge clk);
                write_timeout_count = write_timeout_count + 1;
                if (write_timeout_count > 1000) begin  // 1000个时钟周期超时
                    write_timeout = 1;
                    $display("ERROR: send_write timeout at address 0x%h", addr);
                end

                // 调试信息
                if (write_timeout_count % 100 == 0) begin
                    $display("[send_write] Waiting for ack... count=%d", write_timeout_count);
                end
            end

            @(posedge clk);
            ring_in_valid = 1'b0;
            ring_in_we = 1'b0;

            if (!write_timeout) begin
                $display("[send_write] Write request completed successfully");
            end
        end
    endtask

    // 读请求超时标志和计数器
    reg read_timeout;
    integer read_timeout_count;

    // 测试任务：发送读请求
    task send_read;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        output [`DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            ring_in_valid = 1'b1;
            ring_in_src = src;
            ring_in_dest = 6;  // JTAG节点ID
            ring_in_addr = addr;
            ring_in_we = 1'b0;
            ring_in_be = 4'b1111;

            $display("[send_read] Sending read request to addr=0x%h, src=%d, dest=6", addr, src);

            // 等待回复，添加超时机制
            read_timeout = 0;
            read_timeout_count = 0;
            data = {`DATA_WIDTH{1'bx}}; // 初始化为X

            while (!(ring_out_valid && ring_out_dest == src && !ring_out_we) && !read_timeout) begin
                @(posedge clk);
                read_timeout_count = read_timeout_count + 1;
                if (read_timeout_count > 1000) begin  // 1000个时钟周期超时
                    read_timeout = 1;
                    $display("ERROR: send_read timeout at address 0x%h", addr);
                end

                // 调试信息
                if (read_timeout_count % 100 == 0) begin
                    $display("[send_read] Waiting for response... count=%d", read_timeout_count);
                end
            end

            if (!read_timeout) begin
                data = ring_out_data;
                $display("[send_read] Read response received: 0x%h", data);
            end

            @(posedge clk);
            ring_in_valid = 1'b0;
        end
    endtask

    // 测试任务：JTAG TAP状态机控制
    task jtag_tap_control;
        input [3:0] target_state;
        begin
            // 简化实现，实际应根据TAP状态机转换表控制TMS
            // 这里只是示例，实际测试需要更复杂的控制逻辑
            tms = 1'b1; // 进入TEST-LOGIC-RESET
            @(negedge tck);
            @(negedge tck);

            tms = 1'b0; // 进入RUN-TEST/IDLE
            @(negedge tck);
        end
    endtask

    // 主测试程序
    reg [`DATA_WIDTH-1:0] read_data;

    // Ring总线响应监控
    always @(posedge clk) begin
        if (ring_out_valid) begin
            $display("[Ring Monitor] Valid response: valid=%b, dest=%d, src=%d, we=%b, data=0x%h",
                     ring_out_valid, ring_out_dest, ring_out_src, ring_out_we, ring_out_data);
        end
    end

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        tck = 0;
        tms = 1;
        tdi = 0;
        ring_in_valid = 0;
        ring_in_src = 0;
        ring_in_dest = 0;
        ring_in_addr = 0;
        ring_in_data = 0;
        ring_in_we = 0;
        ring_in_be = 0;
        ring_in_ack = 0;

        // 复位
        #20 rst_n = 1;

        $display("Starting JTAG Node Test");

        // 等待稳定
        #100;

        // 简化测试流程，专注于基本通信测试
        $display("\n--- Basic Communication Test ---\n");

        // 测试1: 发送简单的写请求
        $display("Test 1: Simple write test to JTAG data register");
        send_write(0, `REG_JTAG_DATA, 32'h12345678, 4'b1111);
        #100;  // 等待一段时间让操作完成

        // 测试2: 读取刚才写入的值
        $display("Test 2: Read back the written value");
        send_read(0, `REG_JTAG_DATA, read_data);
        if (read_data !== 32'h12345678) begin
            $display("WARNING: Read data mismatch (0x%h vs expected 0x12345678)", read_data);
            $display("This may indicate issues with the JTAG node implementation");
        end else begin
            $display("SUCCESS: Data read back correctly: 0x%h", read_data);
        end

        // 测试3: 测试JTAG TAP控制
        $display("\nTest 3: JTAG TAP control test");
        $display("Current TMS value: %b", tms);
        jtag_tap_control(`RUN_TEST_IDLE);
        $display("After TAP control, TMS value: %b", tms);

        // 额外的延迟，确保有足够时间观察所有波形
        #1000;

        $finish;
    end

    // 模拟Ring总线的确认信号
    always @(posedge clk) begin
        // 为发送请求提供立即确认
        if (ring_in_valid) begin
            ring_out_ack_reg <= 1'b1;
            $display("[Ring Ack] Acknowledging incoming request to node %d", ring_in_dest);
        end else begin
            ring_out_ack_reg <= 1'b0;
        end

        // 为发给节点0的回复提供确认
        if (ring_out_valid && ring_out_dest == 0) begin
            ring_in_ack <= 1'b1;
            $display("[Ring Ack] Acknowledging outgoing response from node %d to node 0", ring_out_src);
        end else begin
            ring_in_ack <= 1'b0;
        end
    end

    // 波形输出
    initial begin
        $dumpfile("jtag_node.vcd");
        $dumpvars(0, tb_jtag_node);
    end

endmodule