// UART核心模块测试平台

`include "uart_params.v"
`timescale 1ns/1ps

module tb_uart_core;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 控制接口信号
    reg req;
    reg we;
    reg [`ADDR_WIDTH-1:0] addr;
    reg [`DATA_WIDTH-1:0] data_in;
    wire [`DATA_WIDTH-1:0] data_out;
    wire ack;

    // 串行接口
    wire txd;
    reg rxd;
    wire rts;
    reg cts;

    // 中断信号
    wire int_out;

    // 实例化DUT
    uart_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .ack(ack),
        .txd(txd),
        .rxd(rxd),
        .rts(rts),
        .cts(cts),
        .int_out(int_out)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：发送写请求
    task write_reg;
        input [`ADDR_WIDTH-1:0] reg_addr;
        input [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b1;
            addr <= reg_addr;
            data_in <= reg_data;

            // 等待确认
            wait(ack);
            @(posedge clk);
            req <= 1'b0;
            we <= 1'b0;
        end
    endtask

    // 测试任务：发送读请求
    task read_reg;
        input [`ADDR_WIDTH-1:0] reg_addr;
        output [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b0;
            addr <= reg_addr;

            // 等待数据
            wait(ack);
            reg_data = data_out;
            @(posedge clk);
            req <= 1'b0;
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
            `ifdef DEBUG
                $display("Sending bit %d: %b", i, data[i]);
            `endif
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
        req = 0;
        we = 0;
        addr = 0;
        data_in = 0;
        rxd = 1'b1;
        cts = 1'b0;

        // 复位
        #20 rst_n = 1;

        $display("Starting UART Core Test");

        // 测试1: 配置UART
        $display("Test 1: Configure UART");
        write_reg(`REG_LCR, 32'h00000083); // 8位数据，1位停止位，无奇偶校验，使能DLAB
        write_reg(`REG_DLL, 32'h0000000C); // 设置波特率为115200
        write_reg(`REG_DLM, 32'h00000000); // 高位为0
        write_reg(`REG_LCR, 32'h00000003); // 禁用DLAB
        write_reg(`REG_IER, 32'h00000001); // 使能接收中断

        // 读取线状态寄存器确认配置成功
        read_reg(`REG_LSR, read_data);
        $display("Initial line status: 0x%h", read_data[7:0]);

        // 测试2: 发送数据
        $display("Test 2: Send data");
        write_reg(`REG_THR, 32'h00000041); // 发送字符'A'
        write_reg(`REG_THR, 32'h00000042); // 发送字符'B'
        write_reg(`REG_THR, 32'h00000043); // 发送字符'C'

        // 等待发送完成
        #100000;

        // 测试3: 接收数据
        $display("Test 3: Receive data");

        // 检查接收FIFO是否为空
        read_reg(`REG_LSR, read_data);
        $display("Line status before receive: 0x%h", read_data[7:0]);

        // 发送数据
        uart_send_byte(8'h31); // 发送字符'1'
        #100000;

        // 检查接收FIFO状态
        read_reg(`REG_LSR, read_data);
        $display("Line status after first byte: 0x%h", read_data[7:0]);

        uart_send_byte(8'h32); // 发送字符'2'
        #100000;

        read_reg(`REG_LSR, read_data);
        $display("Line status after second byte: 0x%h", read_data[7:0]);

        uart_send_byte(8'h33); // 发送字符'3'
        #100000;

        read_reg(`REG_LSR, read_data);
        $display("Line status after third byte: 0x%h", read_data[7:0]);

        // 测试4: 读取接收数据
        $display("Test 4: Read received data");

        // 再次检查线状态寄存器
        read_reg(`REG_LSR, read_data);
        $display("Line status before read: 0x%h", read_data[7:0]);

        // 读取第一个字符
        read_reg(`REG_RBR, read_data);
        $display("Read from RBR: 0x%h", read_data[7:0]);
        if (read_data[7:0] !== 8'h31) begin
            $display("ERROR: Received 0x%h, expected 0x31", read_data[7:0]);
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // 检查线状态寄存器
        read_reg(`REG_LSR, read_data);
        $display("Line status after first read: 0x%h", read_data[7:0]);

        // 读取第二个字符
        read_reg(`REG_RBR, read_data);
        if (read_data[7:0] !== 8'h32) begin
            $display("ERROR: Received 0x%h, expected 0x32", read_data[7:0]);
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // 检查线状态寄存器
        read_reg(`REG_LSR, read_data);
        $display("Line status after second read: 0x%h", read_data[7:0]);

        // 读取第三个字符
        read_reg(`REG_RBR, read_data);
        if (read_data[7:0] !== 8'h33) begin
            $display("ERROR: Received 0x%h, expected 0x33", read_data[7:0]);
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // 检查接收FIFO是否为空
        read_reg(`REG_LSR, read_data);
        $display("Final line status: 0x%h", read_data[7:0]);

        // 测试5: 检查线状态
        $display("Test 5: Check line status");
        read_reg(`REG_LSR, read_data);
        $display("Line status: 0x%h", read_data[7:0]);

        // 测试6: 检查中断状态
        $display("Test 6: Check interrupt status");
        read_reg(`REG_IIR, read_data);
        $display("Interrupt status: 0x%h", read_data[7:0]);

        $display("All tests completed!");
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

    // 波形输出
    initial begin
        $dumpfile("uart_core.vcd");
        $dumpvars(0, tb_uart_core);
    end

endmodule