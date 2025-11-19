`timescale 1ns/1ps

module tb_spi_flash_controller;
    // 时钟和复位
    reg         clk;
    reg         rst_n;

    // OBI总线接口
    reg         req_i;
    wire        gnt_o;
    wire        rvalid_o;
    reg  [31:0] addr_i;
    reg         we_i;
    reg  [3:0]  be_i;
    reg  [31:0] wdata_i;
    wire [31:0] rdata_o;

    // SPI接口
    wire        spi_cs_n_o;
    wire        spi_sck_o;
    wire        spi_mosi_o;
    wire        spi_miso_i;

    // Flash模型inout端口连接
    wire        wpn_wire;
    wire        holdn_wire;

    // 测试控制信号
    reg  [31:0] test_addr;
    reg  [31:0] test_data;
    reg  [31:0] expected_data;
    integer     test_pass_count;
    integer     test_fail_count;
    integer     test_total_count;

    // 时钟生成
    always #5 clk = ~clk;  // 100MHz时钟

    // 实例化SPI Flash控制器
    spi_flash_ctrl u_spi_flash_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(req_i),
        .gnt_o(gnt_o),
        .rvalid_o(rvalid_o),
        .addr_i(addr_i),
        .we_i(we_i),
        .be_i(be_i),
        .wdata_i(wdata_i),
        .rdata_o(rdata_o),
        .spi_cs_n_o(spi_cs_n_o),
        .spi_sck_o(spi_sck_o),
        .spi_mosi_o(spi_mosi_o),
        .spi_miso_i(spi_miso_i)
    );

    // 声明Flash模型的控制信号
    wire flash_wpn;
    wire flash_holdn;

    // 实例化W25Q128JVxIM Flash模型
    W25Q128JVxIM u_flash (
        .CSn(spi_cs_n_o),
        .CLK(spi_sck_o),
        .DIO(spi_mosi_o),     // 标准SPI模式：DIO作为MOSI输入
        .DO(spi_miso_i),      // 标准SPI模式：DO作为MISO输出
        .WPn(flash_wpn),      // 写保护
        .HOLDn(flash_holdn)   // 保持
    );

    // 连接Flash模型的控制信号
    assign flash_wpn = 1'b1;    // 写保护禁用
    assign flash_holdn = 1'b1;  // 保持禁用

    // 测试任务：等待授权
    task wait_for_grant;
        integer timeout_counter;
        begin
            // 等待至少一个时钟周期，让SPI控制器有时间响应
            @(posedge clk);
            timeout_counter = 0;
            while (!gnt_o) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
                if (timeout_counter > 1000) begin
                    $display("[ERROR] wait_for_grant超时！req_i=%b, gnt_o=%b", req_i, gnt_o);
                    $finish;
                end
            end
        `ifdef DEBUG
            $display("[DEBUG] 获得授权: gnt_o=%b", gnt_o);
        `endif
        end
    endtask

    // 测试任务：等待读完成
    task wait_for_read_complete;
        begin
            while (!rvalid_o) @(posedge clk);
        end
    endtask

    // 测试任务：等待写完成
    task wait_for_write_complete;
        begin
            while (!rvalid_o) @(posedge clk);
        end
    endtask

    // 测试任务：执行读操作
    task read_flash;
        input [31:0] addr;
        output [31:0] data;
        begin
            req_i = 1'b1;
            addr_i = addr;
            we_i = 1'b0;
            wait_for_grant();
            req_i = 1'b0;
            wait_for_read_complete();
            data = rdata_o;
            #20;  // 等待一段时间
        end
    endtask

    // 测试任务：执行写操作
    task write_flash;
        input [31:0] addr;
        input [31:0] data;
        begin
            req_i = 1'b1;
            addr_i = addr;
            we_i = 1'b1;
            wdata_i = data;
            wait_for_grant();
            req_i = 1'b0;
            wait_for_write_complete();
            #1000000;  // 等待写操作完成（Flash需要时间，页编程时间tPP=700us）
        end
    endtask

    // 测试任务：验证数据
    task verify_data;
        input [31:0] addr;
        input [31:0] expected;
        input string test_name;
        reg [31:0] read_data;
        begin
            read_flash(addr, read_data);
            if (read_data === expected) begin
                $display("[PASS] %s: Addr=0x%08X, Expected=0x%08X, Read=0x%08X",
                         test_name, addr, expected, read_data);
                test_pass_count = test_pass_count + 1;
            end else begin
                $display("[FAIL] %s: Addr=0x%08X, Expected=0x%08X, Read=0x%08X",
                         test_name, addr, expected, read_data);
                test_fail_count = test_fail_count + 1;
            end
            test_total_count = test_total_count + 1;
        end
    endtask

    // 主测试流程
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        req_i = 0;
        addr_i = 32'h0;
        we_i = 0;
        be_i = 4'hF;
        wdata_i = 32'h0;
        test_pass_count = 0;
        test_fail_count = 0;
        test_total_count = 0;

        // 复位
        #20;
        rst_n = 1;
        #100;  // 等待控制器初始化完成

        // 等待Flash初始化完成
        $display("等待控制器初始化...");
        #20000;  // 延长等待时间，确保控制器有足够时间初始化

        // 测试1：读取初始数据
        $display("测试1：读取初始数据（地址0）");
        // verify_data(32'h00000000, 32'h11111111, "初始数据读取");
        verify_data(32'h00000040, 32'hA0A0A0A0, "地址64读取验证");

        // 暂时注释掉写操作测试，专注于验证读功能
        // 测试2：写操作测试 - 写入测试数据
        /*$display("\n测试2：执行写操作");
        begin
            reg [31:0] write_data = 32'hA5A5A5A5;
            $display("写入数据: 0x%08X 到地址: 0x%08X", write_data, 32'h00000000);
            write_flash(32'h00000000, write_data);
            $display("写操作完成");
        end

        // 测试3：验证写入后的数据
        $display("\n测试3：验证写入后的数据");
        verify_data(32'h00000000, 32'hA5A5A5A5, "写后读验证");*/

    `ifdef TEST_MORE
        // 测试4：读取另一个地址（地址16）");
        $display("\n测试4：读取另一个地址（地址16）");
        verify_data(32'h00000010, 32'h22222222, "不同地址读取");

        // 测试5：读取更多地址以验证正确性
        $display("\n测试5：读取更多地址以验证正确性");
        verify_data(32'h00000020, 32'h88888888, "地址32读取验证");
        verify_data(32'h00000040, 32'hA0A0A0A0, "地址64读取验证");
        verify_data(32'h00000080, 32'h33333333, "默认地址读取验证");
    `endif

        $display("\n=== 测试结果统计 ===");
        $display("总测试数: %d", test_total_count);
        $display("通过测试: %d", test_pass_count);
        $display("失败测试: %d", test_fail_count);
        if (test_fail_count == 0) begin
            $display("[PASS] 所有测试通过！");
        end else begin
            $display("[FAIL] 部分测试失败，请检查SPI Flash控制器实现。");
        end
        #1000;
        $finish;
    end

`ifdef DEBUG
    // 监控OBI总线
    initial begin
        forever begin
            @(posedge clk);
            if (req_i) begin
                $display("[OBI] Time=%0t, REQ=%b, GNT=%b, ADDR=0x%08X, WE=%b, WDATA=0x%08X",
                         $time, req_i, gnt_o, addr_i, we_i, wdata_i);
            end
            if (rvalid_o) begin
                $display("[OBI] Time=%0t, RVALID=%b, RDATA=0x%08X",
                         $time, rvalid_o, rdata_o);
            end
        end
    end
`endif

    // 仿真超时保护
    initial begin
        #50000000;  // 50ms超时
        $display("仿真超时！");
        $finish;
    end

    // 生成波形文件
    initial begin
        $dumpfile("tb_spi_flash_controller.vcd");
        $dumpvars(0, tb_spi_flash_controller);
    end
endmodule