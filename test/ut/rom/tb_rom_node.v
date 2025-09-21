// tb_rom_node.v
// ROM节点测试平台

`include "rom_params.v"
`timescale 1ns/1ps

module tb_rom_node;

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

    // Flash接口信号
    wire flash_ce_n;
    wire flash_oe_n;
    wire flash_we_n;
    wire [`FLASH_ADDR_WIDTH-1:0] flash_addr;
    wire [`FLASH_DATA_WIDTH-1:0] flash_data;

    // 模拟Flash存储器
    reg [`FLASH_DATA_WIDTH-1:0] flash_memory [0:(1<<`FLASH_ADDR_WIDTH)-1];
    reg [`FLASH_DATA_WIDTH-1:0] flash_data_out;
    reg flash_data_en;

    assign flash_data = flash_data_en ? flash_data_out : {`FLASH_DATA_WIDTH{1'bz}};

    // 实例化DUT
    rom_node dut (
        .clk(clk),
        .rst_n(rst_n),
        .node_id(2),  // 假设ROM节点ID为2
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
        .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n),
        .flash_we_n(flash_we_n),
        .flash_addr(flash_addr),
        .flash_data(flash_data)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // Flash模拟
    always @(negedge flash_oe_n) begin
        if (!flash_ce_n && !flash_oe_n) begin
            flash_data_en <= 1'b1;
            flash_data_out <= flash_memory[flash_addr];
        end else begin
            flash_data_en <= 1'b0;
        end
    end

    // 初始化Flash内容
    initial begin
        for (integer i = 0; i < (1<<`FLASH_ADDR_WIDTH); i = i + 1) begin
            // 填充一些测试数据
            flash_memory[i] = i % 256;
        end
    end

    // 测试任务：发送读请求
    task send_read;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        output [`DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 2;  // ROM节点ID
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

    // 测试任务：发送写请求（应该被忽略）
    task send_write;
        input [`NODE_ID_WIDTH-1:0] src;
        input [`ADDR_WIDTH-1:0] addr;
        input [`DATA_WIDTH-1:0] data;
        input [3:0] be;
        begin
            @(posedge clk);
            ring_in_valid <= 1'b1;
            ring_in_src <= src;
            ring_in_dest <= 2;  // ROM节点ID
            ring_in_addr <= addr;
            ring_in_data <= data;
            ring_in_we <= 1'b1;
            ring_in_be <= be;

            // 等待确认（ROM应该忽略写请求）
            wait(ring_out_ack);
            @(posedge clk);
            ring_in_valid <= 1'b0;
            ring_in_we <= 1'b0;
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
        flash_data_en = 0;

        // 复位
        #20 rst_n = 1;

        $display("Starting ROM Node Test");

        // 等待初始化完成
        $display("Waiting for ROM initialization from Flash...");
        wait(dut.ring_node_inst.init_done);
        $display("ROM initialization completed");

        // 测试1: 读操作
        $display("Test 1: Read operation");
        send_read(0, 10'h000, read_data);
        // 预期值：根据Flash内容计算
        // Flash地址 0: 0x00, 1: 0x01, 2: 0x02, 3: 0x03 -> 数据应该是 0x03020100
        if (read_data !== 32'h03020100) begin
            $display("ERROR: Address 0x000: Read 0x%h, expected 0x03020100", read_data);
            $finish;
        end else begin
            $display("Read completed: Address 0x000 = 0x%h", read_data);
        end

        // 测试2: 读取不同地址
        $display("Test 2: Read from different address");
        send_read(0, 10'h001, read_data);
        // Flash地址 4: 0x04, 5: 0x05, 6: 0x06, 7: 0x07 -> 数据应该是 0x07060504
        if (read_data !== 32'h07060504) begin
            $display("ERROR: Address 0x001: Read 0x%h, expected 0x07060504", read_data);
            $finish;
        end else begin
            $display("Read completed: Address 0x001 = 0x%h", read_data);
        end

        // 测试3: 写操作（应该被忽略）
        $display("Test 3: Write operation (should be ignored)");
        send_write(0, 10'h000, 32'hAABBCCDD, 4'b1111);
        $display("Write operation completed (ignored by ROM)");

        // 测试4: 验证写操作确实被忽略
        $display("Test 4: Verify write was ignored");
        send_read(0, 10'h000, read_data);
        if (read_data !== 32'h03020100) begin
            $display("ERROR: Address 0x000: Read 0x%h, expected 0x03020100 (write was not ignored)", read_data);
            $finish;
        end else begin
            $display("Write was correctly ignored: Address 0x000 = 0x%h", read_data);
        end

        // 测试5: 多个地址读取
        $display("Test 5: Multiple address read");
        send_read(0, 10'h002, read_data);
        if (read_data !== 32'h0B0A0908) begin
            $display("ERROR: Address 0x002: Read 0x%h, expected 0x0B0A0908", read_data);
            $finish;
        end

        send_read(0, 10'h003, read_data);
        if (read_data !== 32'h0F0E0D0C) begin
            $display("ERROR: Address 0x003: Read 0x%h, expected 0x0F0E0D0C", read_data);
            $finish;
        end

        send_read(0, 10'h004, read_data);
        if (read_data !== 32'h13121110) begin
            $display("ERROR: Address 0x004: Read 0x%h, expected 0x13121110", read_data);
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
        $dumpfile("rom_node.vcd");
        $dumpvars(0, tb_rom_node);
    end

endmodule
