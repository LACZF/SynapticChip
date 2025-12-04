`timescale 1ns/1ps

module tb_spi_flash;

    // 时钟参数
    parameter CLK_PERIOD = 10;  // 100MHz

    // 信号定义
    reg         clk;
    reg         rst_n;

    // OBI总线接口
    reg         obi_req_i;
    reg         obi_we_i;
    reg  [31:0] obi_addr_i;
    reg  [31:0] obi_wdata_i;
    reg  [3:0]  obi_be_i;
    wire        obi_gnt_o;
    wire        obi_rvalid_o;
    wire [31:0] obi_rdata_o;
    wire        obi_err_o;

    // SPI接口
    wire        spi_cs_n;
    wire        spi_sck;
    wire        spi_mosi;
    wire        spi_miso;

    // 测试控制
    reg  [31:0] read_data;
    integer     error_count;
    integer     test_count;

    // 时钟生成
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // 复位生成
    initial begin
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
    end

    // DUT实例化
    ip4_spi_flash_top u_spi_flash_top (
        .clk(clk),
        .rst_n(rst_n),

        .req_i(obi_req_i),
        .we_i(obi_we_i),
        .addr_i(obi_addr_i),
        .wdata_i(obi_wdata_i),
        .be_i(obi_be_i),

        .gnt_o(obi_gnt_o),
        .rvalid_o(obi_rvalid_o),
        .rdata_o(obi_rdata_o),

        .spi_cs_n_o(spi_cs_n),
        .spi_sck_o (spi_sck),
        .spi_mosi_o(spi_mosi),
        .spi_miso_i(spi_miso)
    );

    W25Q128JVxIM flash_model (
        .CSn(spi_cs_n),
        .CLK(spi_sck),
        .DIO(spi_mosi),
        .DO(spi_miso),
        .WPn(),  // 写保护禁用，悬空
        .HOLDn() // 保持禁用，悬空
    );

    // 测试任务：发送OBI读请求
    task send_obi_read;
        input [31:0] address;
        begin
            @(posedge clk);
            obi_req_i = 1'b1;
            obi_we_i = 1'b0;
            obi_addr_i = address;
            obi_be_i = 4'b1111;

            @(posedge clk);
            while (!obi_gnt_o) @(posedge clk);
            obi_req_i = 1'b0;

            @(posedge clk);
            while (!obi_rvalid_o) @(posedge clk);
            read_data = obi_rdata_o;
            test_count = test_count + 1;

            $display("[%0t] Read from address 0x%08h: 0x%08h",
                    $time, address, read_data);
        end
    endtask

    // 验证任务
    task verify_data;
        input [31:0] expected;
        input [31:0] actual;
        input string test_name;
        begin
            if (expected !== actual) begin
                $display("[ERROR] %s: Expected 0x%08h, Got 0x%08h",
                        test_name, expected, actual);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s: 0x%08h", test_name, actual);
            end
        end
    endtask

    // 主测试程序
    initial begin
        // 初始化
        error_count = 0;
        test_count = 0;
        obi_req_i = 1'b0;
        obi_we_i = 1'b0;
        obi_addr_i = 32'h0;
        obi_wdata_i = 32'h0;
        obi_be_i = 4'b0;

        // 等待复位完成
        #200;

        $display("\n=========================================");
        $display("Starting SPI Flash Controller Test");
        $display("=========================================\n");

        // 测试1：读取Flash ID
        $display("Test 1: Reading Flash ID");
        send_obi_read(32'h100_0004);  // 读ID命令地址（bit24=1表示读ID）
        verify_data(32'h001870ef, read_data, "Flash ID Read");

        // 测试2：读取状态寄存器
        $display("\nTest 2: Reading Status Register");
        send_obi_read(32'h100_0008);  // 读状态寄存器地址
        verify_data(32'h00000000, read_data, "Status Register Read");

        send_obi_read(32'h100_000C);  // 读状态2寄存器地址
        verify_data(32'h00000000, read_data, "Status2 Register Read");

        send_obi_read(32'h100_0010);  // 读状态3寄存器地址
        verify_data(32'h00000000, read_data, "Status3 Register Read");

        // 测试3：读取指令数据
        $display("\nTest 3: Reading Instructions from Flash");

        send_obi_read(32'h0000_0000);
        verify_data(32'h11111111, read_data, "Read 0x00 ");

        send_obi_read(32'h0000_0004);
        verify_data(32'hffffffff, read_data, "Read 0x04 ");

        send_obi_read(32'h0000_0010);
        verify_data(32'h22222222, read_data, "Read 0x10 ");

        send_obi_read(32'h0000_0020);
        verify_data(32'h88888888, read_data, "Read 0x20 ");

        send_obi_read(32'h0000_0040);
        verify_data(32'ha0a0a0a0, read_data, "Read 0x40 ");

    `ifdef TEST_SPI_FLASH_WRITE
        // 测试4：写使能和扇区擦除测试
        $display("\nTest 4: Write Enable and Sector Erase Test");

        // 先读一下要擦除的扇区
        send_obi_read(32'h0000_1000);
        $display("Before erase: 0x%08h", read_data);

        // 写使能
        obi_req_i = 1'b1;
        obi_we_i = 1'b1;
        obi_addr_i = 32'h8000_0008;  // WREN命令
        obi_wdata_i = 32'h0;
        obi_be_i = 4'b1111;
        @(posedge clk);
        while (!obi_gnt_o) @(posedge clk);
        obi_req_i = 1'b0;
        @(posedge clk);

        // 等待操作完成
        #1000;

        // 扇区擦除
        obi_req_i = 1'b1;
        obi_we_i = 1'b1;
        obi_addr_i = 32'h8000_1010;  // SE命令（bit24=1表示擦除）
        obi_wdata_i = 32'h0;
        obi_be_i = 4'b1111;
        @(posedge clk);
        while (!obi_gnt_o) @(posedge clk);
        obi_req_i = 1'b0;
        @(posedge clk);

        // 等待擦除完成
        #5000;

        // 验证擦除结果（应该是全FF）
        send_obi_read(32'h0000_1000);
        verify_data(32'hFFFFFFFF, read_data, "Sector Erase");

        // 测试5：页编程测试
        $display("\nTest 5: Page Program Test");

        // 写使能
        obi_req_i = 1'b1;
        obi_we_i = 1'b1;
        obi_addr_i = 32'h8000_0008;  // WREN命令
        obi_wdata_i = 32'h0;
        obi_be_i = 4'b1111;
        @(posedge clk);
        while (!obi_gnt_o) @(posedge clk);
        obi_req_i = 1'b0;
        @(posedge clk);

        // 等待操作完成
        #1000;

        // 页编程
        obi_req_i = 1'b1;
        obi_we_i = 1'b1;
        obi_addr_i = 32'h0000_1000;  // PP命令（写数据）
        obi_wdata_i = 32'h12345678;
        obi_be_i = 4'b1111;
        @(posedge clk);
        while (!obi_gnt_o) @(posedge clk);
        obi_req_i = 1'b0;
        @(posedge clk);

        // 等待编程完成
        #5000;

        // 验证编程数据
        send_obi_read(32'h0000_1000);
        verify_data(32'h12345678, read_data, "Page Program");
    `endif

        // 测试总结
        $display("\n=========================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_count);
        $display("  Errors: %0d", error_count);
        $display("=========================================\n");

        if (error_count == 0) begin
            $display("All tests PASSED!");
        end else begin
            $display("Some tests FAILED!");
        end

        #100;
        $finish;
    end

    // 监控SPI总线活动
    /*
    initial begin
        $timeformat(-9, 3, " ns", 10);
        forever begin
            @(negedge spi_cs_n);
            $display("[%0t] SPI CS asserted", $time);
            while (!spi_cs_n) begin
                @(posedge spi_sck);
                $display("[%0t] SCK posedge, MOSI=%b", $time, spi_mosi);
                @(negedge spi_sck);
                $display("[%0t] SCK negedge, MISO=%b", $time, spi_miso);
            end
            $display("[%0t] SPI CS deasserted", $time);
        end
    end
    */

    // 波形生成
    initial begin
        $dumpfile("spi_flash.vcd");
        $dumpvars(0, tb_spi_flash);
    end

endmodule