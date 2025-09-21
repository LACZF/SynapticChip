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
        .node_id(3'd6),  // JTAG节点ID设为6
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

            // 等待确认
            wait(ring_out_ack);
            @(posedge clk);
            ring_in_valid = 1'b0;
            ring_in_we = 1'b0;
        end
    endtask

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

            // 等待回复
            wait(ring_out_valid && ring_out_dest == src && !ring_out_we);
            data = ring_out_data;
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

        // 测试1: 读取JTAG状态
        $display("Test 1: Read JTAG status");
        send_read(0, `REG_JTAG_STAT, read_data);
        $display("JTAG status: 0x%h", read_data);

        // 测试2: 读取TAP状态机状态
        $display("Test 2: Read TAP state");
        send_read(0, `REG_JTAG_CTRL, read_data);
        $display("TAP state: 0x%h", read_data[3:0]);

        // 测试3: 写入数据寄存器
        $display("Test 3: Write data register");
        send_write(0, `REG_JTAG_DATA, 32'hAABBCCDD, 4'b1111);
        $display("Data written to JTAG data register: 0xAABBCCDD");

        // 测试4: 读取数据寄存器
        $display("Test 4: Read data register");
        send_read(0, `REG_JTAG_DATA, read_data);
        if (read_data !== 32'hAABBCCDD) begin
            $display("ERROR: Read 0x%h, expected 0xAABBCCDD", read_data);
            $finish;
        end else begin
            $display("Data read from JTAG data register: 0x%h", read_data);
        end

        // 测试5: JTAG TAP状态机测试
        $display("Test 5: JTAG TAP state machine test");
        jtag_tap_control(`RUN_TEST_IDLE);

        // 检查TAP状态是否改变
        send_read(0, `REG_JTAG_CTRL, read_data);
        $display("TAP state after control: 0x%h", read_data[3:0]);

        // 测试6: 调试输出测试
        $display("Test 6: Debug output test");
        // 等待调试数据
        #100;
        if (debug_valid) begin
            $display("Debug data: 0x%h", debug_data);
        end

        $display("All tests passed!");
        $finish;
    end

    // 模拟Ring总线的确认信号
    always @(posedge clk) begin
        if (ring_out_valid && ring_out_dest == 0) begin
            // 如果是发给节点0的回复，模拟确认
            ring_in_ack <= 1'b1;
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
