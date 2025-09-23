// tb_memory_system.v
module tb_memory_system;

    reg clk;
    reg rst_n;

    // CPU接口信号
    reg [31:0] imem_addr;
    wire [31:0] imem_data;
    reg imem_req;
    wire imem_ack;

    reg [31:0] dmem_addr;
    reg [31:0] dmem_data_out;
    wire [31:0] dmem_data_in;
    reg dmem_we;
    reg [3:0] dmem_sel;
    reg dmem_req;
    wire dmem_ack;

    // 调试信号
    wire [2:0] mem_state;

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化存储器系统
    memory_system uut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_req(imem_req),
        .imem_ack(imem_ack),
        .dmem_addr(dmem_addr),
        .dmem_data_out(dmem_data_out),
        .dmem_data_in(dmem_data_in),
        .dmem_we(dmem_we),
        .dmem_sel(dmem_sel),
        .dmem_req(dmem_req),
        .dmem_ack(dmem_ack),
        .mem_state(mem_state)
    );

    // 测试任务：指令读取
    task read_instruction;
        input [31:0] address;
        begin
            @(posedge clk);
            imem_addr = address;
            imem_req = 1'b1;
            @(posedge clk);
            wait(imem_ack);
            imem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 测试任务：数据读取
    task read_data;
        input [31:0] address;
        begin
            @(posedge clk);
            dmem_addr = address;
            dmem_we = 1'b0;
            dmem_req = 1'b1;
            @(posedge clk);
            wait(dmem_ack);
            dmem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 测试任务：数据写入
    task write_data;
        input [31:0] address;
        input [31:0] data;
        begin
            @(posedge clk);
            dmem_addr = address;
            dmem_data_out = data;
            dmem_we = 1'b1;
            dmem_sel = 4'b1111;
            dmem_req = 1'b1;
            @(posedge clk);
            wait(dmem_ack);
            dmem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        imem_addr = 32'h0;
        imem_req = 1'b0;
        dmem_addr = 32'h0;
        dmem_data_out = 32'h0;
        dmem_we = 1'b0;
        dmem_sel = 4'h0;
        dmem_req = 1'b0;

        // 复位
        #20;
        rst_n = 1;

        $display("=== 开始存储器系统测试 ===");
        $display("时间: %t - 系统复位完成", $time);

        // 测试1: RAM指令读取
        $display("测试1: RAM指令读取");
        read_instruction(32'h00000000);
        $display("地址 0x00000000 数据: 0x%h", imem_data);

        read_instruction(32'h00000004);
        $display("地址 0x00000004 数据: 0x%h", imem_data);

        // 测试2: ROM指令读取（缓存未命中）
        $display("测试2: ROM指令读取");
        read_instruction(32'h10000000);
        $display("地址 0x10000000 数据: 0x%h", imem_data);

        read_instruction(32'h10000004);
        $display("地址 0x10000004 数据: 0x%h", imem_data);

        // 测试3: Flash数据读取
        $display("测试3: Flash数据读取");
        read_data(32'h20000000);
        $display("地址 0x20000000 数据: 0x%h", dmem_data_in);

        // 测试4: RAM数据写入和读取
        $display("测试4: RAM数据写入和读取");
        write_data(32'h00001000, 32'h12345678);
        read_data(32'h00001000);
        $display("写入数据: 0x12345678, 读取数据: 0x%h", dmem_data_in);

        // 测试5: Flash数据写入（需要时间）
        $display("测试5: Flash数据写入");
        write_data(32'h20000100, 32'hdeadbeef);
        $display("Flash写入完成");

        // 测试6: 缓存命中测试
        $display("测试6: 缓存命中测试");
        read_instruction(32'h10000000);  // 应该命中缓存
        $display("缓存命中测试完成");

        // 测试7: 边界测试
        $display("测试7: 边界测试");
        read_instruction(32'h0000FFFC);  // RAM边界
        read_instruction(32'h100FFFFC);  // ROM边界

        $display("=== 存储器系统测试完成 ===");
        $finish;
    end

    // 监控存储器状态
    always @(posedge clk) begin
        if (imem_req || dmem_req) begin
            $display("时间: %t - 存储器状态: %d, 地址: 0x%h",
                    $time, mem_state, imem_req ? imem_addr : dmem_addr);
        end

        if (imem_ack) begin
            $display("时间: %t - 指令读取完成: 0x%h -> 0x%h",
                    $time, imem_addr, imem_data);
        end

        if (dmem_ack) begin
            if (dmem_we) begin
                $display("时间: %t - 数据写入完成: 0x%h -> 0x%h",
                        $time, dmem_addr, dmem_data_out);
            end else begin
                $display("时间: %t - 数据读取完成: 0x%h -> 0x%h",
                        $time, dmem_addr, dmem_data_in);
            end
        end
    end

endmodule
