// tb_uart_node.v
// UART节点测试平台

`include "uart_params.v"
`timescale 1ns/1ps

module tb_uart_node;

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

    // 串行接口
    wire txd;
    reg rxd;
    wire rts;
    reg cts;

    // 中断信号
    wire int_out;

    // 实例化DUT
    uart_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(5'd4),  // 假设UART节点ID为4
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
        .uart_txd(txd),
        .uart_rxd(rxd),
        .rts(rts),
        .cts(cts),
        .int_out(int_out)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：发送写请求
    task send_write;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        input [`DATA_WIDTH-1:0] data;
        input [3:0] be;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 4;  // UART节点ID
            ring_in_addr <= addr;
            ring_in_data <= data;
            ring_in_we <= 1'b1;
            ring_in_be <= be;

            // 等待确认
            wait(ring_out_ack);
            @(posedge clk);
            ring_in_valid <= 1'b0;
            ring_in_we <= 1'b0;
        end
    endtask

    // 测试任务：发送读请求
    task send_read;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        output [`DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 4;  // UART节点ID
            ring_in_addr <= addr;
            ring_in_we <= 1'b0;
            ring_in_be <= 4'b1111;

            // 等待回复
            wait(ring_out_valid && ring_out_dest == src && !ring_out_we);
            data = ring_out_data;
            @(posedge clk);
            ring_in_valid <= 1'b0;
        end
    endtask

    // 模拟UART接收数据
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // 起始位
            rxd <= 1'b0;
            #8680; // 115200波特率的位时间 (1/115200 ≈ 8.68μs)

            // 数据位
            for (i = 0; i < 8; i = i + 1) begin
                rxd <= data[i];
                #8680;
            end

            // 停止位
            rxd <= 1'b1;
            #8680;
        end
    endtask

    // 主测试程序
    reg [`DATA_WIDTH-1:0] read_data;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        ring_in_valid = 0;
        ring_in_src = 0;
        ring_in_dest = 0;
        ring_in_addr = 0;
        ring_in_data = 0;
        ring_in_we = 0;
        ring_in_be = 0;
        ring_in_ack = 0;
        rxd = 1'b1;
        cts = 1'b0;

        // 复位
        #20 rst_n = 1;

        $display("Starting UART Node Test");

        // 测试1: 配置UART
        $display("Test 1: Configure UART");
        send_write(0, `REG_LCR, 32'h00000083, 4'b1111); // 8位数据，1位停止位，无奇偶校验，使能DLAB
        send_write(0, `REG_DLL, 32'h0000000C, 4'b1111); // 设置波特率为115200 (100MHz/16/115200 ≈ 54)
        send_write(0, `REG_DLM, 32'h00000000, 4'b1111); // 高位为0
        send_write(0, `REG_LCR, 32'h00000003, 4'b1111); // 禁用DLAB
        send_write(0, `REG_IER, 32'h00000001, 4'b1111); // 使能接收中断

        // 测试2: 发送数据
        $display("Test 2: Send data");
        send_write(0, `REG_THR, 32'h00000041, 4'b1111); // 发送字符'A'
        send_write(0, `REG_THR, 32'h00000042, 4'b1111); // 发送字符'B'
        send_write(0, `REG_THR, 32'h00000043, 4'b1111); // 发送字符'C'

        // 等待发送完成
        #100000;

        // 测试3: 接收数据
        $display("Test 3: Receive data");
        uart_send_byte(8'h31); // 发送字符'1'
        uart_send_byte(8'h32); // 发送字符'2'
        uart_send_byte(8'h33); // 发送字符'3'

        // 等待接收完成
        #100000;

        // 测试4: 读取接收数据
        $display("Test 4: Read received data");
        send_read(0, `REG_RBR, read_data);
        if (read_data[7:0] !== 8'h31) begin
            $display("ERROR: Received 0x%h, expected 0x31", read_data[7:0]);
            $finish;
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        send_read(0, `REG_RBR, read_data);
        if (read_data[7:0] !== 8'h32) begin
            $display("ERROR: Received 0x%h, expected 0x32", read_data[7:0]);
            $finish;
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        send_read(0, `REG_RBR, read_data);
        if (read_data[7:0] !== 8'h33) begin
            $display("ERROR: Received 0x%h, expected 0x33", read_data[7:0]);
            $finish;
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // 测试5: 检查线状态
        $display("Test 5: Check line status");
        send_read(0, `REG_LSR, read_data);
        $display("Line status: 0x%h", read_data[7:0]);

        // 测试6: 检查中断状态
        $display("Test 6: Check interrupt status");
        send_read(0, `REG_IIR, read_data);
        $display("Interrupt status: 0x%h", read_data[7:0]);

        $display("All tests passed!");
        $finish;
    end

    // 监控TX输出
    reg [7:0] tx_byte;
    integer tx_bit_count;
    initial begin
        forever begin
            // 等待起始位
            wait(txd === 1'b0);
            #4340; // 等待到位中间

            // 接收数据位
            for (tx_bit_count = 0; tx_bit_count < 8; tx_bit_count = tx_bit_count + 1) begin
                #8680;
                tx_byte[tx_bit_count] = txd;
            end

            // 等待停止位
            #8680;

            $display("TX: 0x%h ('%c')", tx_byte, tx_byte);
        end
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
        $dumpfile("uart_node.vcd");
        $dumpvars(0, tb_uart_node);
    end

endmodule
