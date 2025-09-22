// tb_gpio_node.v
// GPIO节点测试平台

`include "gpio_params.v"
`timescale 1ns/1ps

module tb_gpio_node;

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

    // GPIO引脚
    wire [`GPIO_WIDTH-1:0] gpio_pins;
    reg [`GPIO_WIDTH-1:0] gpio_ext_drive;
    assign gpio_pins = gpio_ext_drive;

    // 中断信号
    wire int_out;

    // 实例化DUT
    gpio_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(5'd3),  // 假设GPIO节点ID为3
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
        .gpio_pins(gpio_pins),
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
            ring_in_dest <= 3;  // GPIO节点ID
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
            ring_in_dest <= 3;  // GPIO节点ID
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
        gpio_ext_drive = {`GPIO_WIDTH{1'b0}};

        // 复位
        #20 rst_n = 1;

        $display("Starting GPIO Node Test");

        // 测试1: 设置GPIO方向为输出
        $display("Test 1: Set GPIO direction to output");
        send_write(0, `REG_DIR, 32'h0000FFFF, 4'b1111);
        $display("GPIO direction set: upper 16 bits input, lower 16 bits output");

        // 测试2: 设置输出值
        $display("Test 2: Set output values");
        send_write(0, `REG_DATA, 32'h0000AAAA, 4'b1111);
        $display("Output values set to 0xAAAA");

        // 测试3: 读取输出值
        $display("Test 3: Read output values");
        send_read(0, `REG_DATA, read_data);
        $display("Read output values: 0x%h", read_data);

        // 测试4: 设置外部输入
        $display("Test 4: Set external input values");
        gpio_ext_drive <= 32'hFFFF0000;
        #100;

        // 测试5: 读取输入值
        $display("Test 5: Read input values");
        send_read(0, `REG_DATA, read_data);
        if (read_data[31:16] !== 16'hFFFF) begin
            $display("ERROR: Input values read 0x%h, expected 0xFFFF0000", read_data);
            $finish;
        end else begin
            $display("Input values correctly read: 0x%h", read_data);
        end

        // 测试6: 配置中断
        $display("Test 6: Configure interrupts");
        send_write(0, `REG_INTEN, 32'h00010000, 4'b1111);  // 使能GPIO16中断
        send_write(0, `REG_INTPOL, 32'h00010000, 4'b1111); // 高电平/上升沿触发
        send_write(0, `REG_INTTYPE, 32'h00010000, 4'b1111); // 边沿触发

        // 测试7: 触发中断
        $display("Test 7: Trigger interrupt");
        gpio_ext_drive[16] <= 1'b1;  // 上升沿
        #20;
        gpio_ext_drive[16] <= 1'b0;  // 下降沿
        #20;
        gpio_ext_drive[16] <= 1'b1;  // 上升沿（应该触发中断）

        // 等待中断
        #100;
        if (!int_out) begin
            $display("ERROR: Interrupt not triggered");
            $finish;
        end else begin
            $display("Interrupt triggered successfully");
        end

        // 测试8: 读取中断状态
        $display("Test 8: Read interrupt status");
        send_read(0, `REG_INTSTAT, read_data);
        if (read_data[16] !== 1'b1) begin
            $display("ERROR: Interrupt status not set");
            $finish;
        end else begin
            $display("Interrupt status correctly set: 0x%h", read_data);
        end

        // 测试9: 清除中断
        $display("Test 9: Clear interrupt");
        send_write(0, `REG_INTSTAT, 32'h00010000, 4'b1111); // 写1清除

        // 测试10: 验证中断已清除
        $display("Test 10: Verify interrupt cleared");
        send_read(0, `REG_INTSTAT, read_data);
        if (read_data[16] !== 1'b0) begin
            $display("ERROR: Interrupt status not cleared");
            $finish;
        end else begin
            $display("Interrupt status correctly cleared");
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
        $dumpfile("gpio_node.vcd");
        $dumpvars(0, tb_gpio_node);
    end

endmodule
