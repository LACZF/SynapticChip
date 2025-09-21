// tb_ram_node.v
// RAM节点测试平台

`include "ram_params.v"
`timescale 1ns/1ps

module tb_ram_node;

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

    // 实例化DUT
    ram_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(1),  // 假设RAM节点ID为1
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
        .ring_out_ack(ring_out_ack)
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
            ring_in_dest <= 1;  // RAM节点ID
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
        input [3:0] be;
        output [`DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 1;  // RAM节点ID
            ring_in_addr <= addr;
            ring_in_we <= 1'b0;
            ring_in_be <= be;

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

        // 复位
        #20 rst_n = 1;

        $display("Starting RAM Node Test");

        // 测试1: 写操作
        $display("Test 1: Write operation");
        send_write(0, 10'h000, 32'hAABBCCDD, 4'b1111);
        $display("Write completed: Address 0x000 = 0x%h", 32'hAABBCCDD);

        // 测试2: 读操作
        $display("Test 2: Read operation");
        send_read(0, 10'h000, 4'b1111, read_data);
        if (read_data !== 32'hAABBCCDD) begin
            $display("ERROR: Read 0x%h, expected 0xAABBCCDD", read_data);
            $finish;
        end else begin
            $display("Read completed: Address 0x000 = 0x%h", read_data);
        end

        // 测试3: 字节写操作
        $display("Test 3: Byte write operation");
        send_write(0, 10'h004, 32'h000000FF, 4'b0001);
        $display("Byte write completed: Address 0x004[7:0] = 0xFF");

        // 测试4: 字节读操作
        $display("Test 4: Byte read operation");
        send_read(0, 10'h004, 4'b0001, read_data);
        if (read_data[7:0] !== 8'hFF) begin
            $display("ERROR: Read 0x%h, expected 0x000000FF", read_data);
            $finish;
        end else begin
            $display("Byte read completed: Address 0x004[7:0] = 0x%h", read_data[7:0]);
        end

        // 测试5: 半字写操作
        $display("Test 5: Half-word write operation");
        send_write(0, 10'h008, 32'h0000ABCD, 4'b0011);
        $display("Half-word write completed: Address 0x008[15:0] = 0xABCD");

        // 测试6: 半字读操作
        $display("Test 6: Half-word read operation");
        send_read(0, 10'h008, 4'b0011, read_data);
        if (read_data[15:0] !== 16'hABCD) begin
            $display("ERROR: Read 0x%h, expected 0x0000ABCD", read_data);
            $finish;
        end else begin
            $display("Half-word read completed: Address 0x008[15:0] = 0x%h", read_data[15:0]);
        end

        // 测试7: 多个地址读写
        $display("Test 7: Multiple address read/write");
        send_write(0, 10'h010, 32'h11223344, 4'b1111);
        send_write(0, 10'h014, 32'h55667788, 4'b1111);
        send_write(0, 10'h018, 32'h99AABBCC, 4'b1111);

        send_read(0, 10'h010, 4'b1111, read_data);
        if (read_data !== 32'h11223344) begin
            $display("ERROR: Address 0x010: Read 0x%h, expected 0x11223344", read_data);
            $finish;
        end

        send_read(0, 10'h014, 4'b1111, read_data);
        if (read_data !== 32'h55667788) begin
            $display("ERROR: Address 0x014: Read 0x%h, expected 0x55667788", read_data);
            $finish;
        end

        send_read(0, 10'h018, 4'b1111, read_data);
        if (read_data !== 32'h99AABBCC) begin
            $display("ERROR: Address 0x018: Read 0x%h, expected 0x99AABBCC", read_data);
            $finish;
        end

        $display("Multiple address test completed successfully");

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
        $dumpfile("ram_node.vcd");
        $dumpvars(0, tb_ram_node);
    end

endmodule
