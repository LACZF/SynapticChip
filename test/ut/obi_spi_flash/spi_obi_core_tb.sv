`timescale 1ns/1ps

module spi_obi_core_tb;

  // 时钟和复位
  reg clk;
  reg rst_n;

  // OBI总线接口信号
  reg        req_i;
  reg        we_i;
  reg [3:0]  be_i;
  reg [31:0] addr_i;
  reg [31:0] data_i;
  wire       gnt_o;
  wire       rvalid_o;
  wire [31:0] data_o;

  // SPI接口信号
  wire spi_clk;
  wire spi_csn0;
  wire spi_csn1;
  wire spi_csn2;
  wire spi_csn3;
  wire spi_sdo0;
  wire spi_sdo1;
  wire spi_sdo2;
  wire spi_sdo3;
  wire spi_oe0;
  wire spi_oe1;
  wire spi_oe2;
  wire spi_oe3;
  wire spi_sdi0;
  wire spi_sdi1;
  wire spi_sdi2;
  wire spi_sdi3;

  // Flash模型接口
  wire flash_cs;
  wire flash_clk;
  wire flash_dq0;
  wire flash_dq1;
  wire flash_dq2;
  wire flash_dq3;

  // 测试统计
  integer test_pass_count = 0;
  integer test_fail_count = 0;
  integer total_tests = 0;

  // 时钟生成
  always #5 clk = ~clk;

  // DUT实例化
  spi_obi_core #(
      .BUFFER_DEPTH(8)
  ) dut (
      .clk_i(clk),
      .rst_ni(rst_n),
      .req_i(req_i),
      .we_i(we_i),
      .be_i(be_i),
      .addr_i(addr_i),
      .data_i(data_i),
      .gnt_o(gnt_o),
      .rvalid_o(rvalid_o),
      .data_o(data_o),
      .spi_clk(spi_clk),
      .spi_csn0(spi_csn0),
      .spi_csn1(spi_csn1),
      .spi_csn2(spi_csn2),
      .spi_csn3(spi_csn3),
      .spi_sdo0(spi_sdo0),
      .spi_sdo1(spi_sdo1),
      .spi_sdo2(spi_sdo2),
      .spi_sdo3(spi_sdo3),
      .spi_oe0(spi_oe0),
      .spi_oe1(spi_oe1),
      .spi_oe2(spi_oe2),
      .spi_oe3(spi_oe3),
      .spi_sdi0(spi_sdi0),
      .spi_sdi1(spi_sdi1),
      .spi_sdi2(spi_sdi2),
      .spi_sdi3(spi_sdi3)
  );

  // Flash模型实例化
  W25Q128JVxIM flash_model (
      .CSn(flash_cs),
      .CLK(flash_clk),
      .DIO(flash_dq0),
      .DO(flash_dq1),
      .WPn(),  // 写保护禁用，悬空
      .HOLDn() // 保持禁用，悬空
  );

  // SPI信号连接
  assign flash_cs = spi_csn0;
  assign flash_clk = spi_clk;

  // 双向数据线连接
  // SPI控制器输出到Flash模型
  assign flash_dq0 = spi_oe0 ? spi_sdo0 : 1'bz;
  assign flash_dq1 = spi_oe1 ? spi_sdo1 : 1'bz;

  // Flash模型输出到SPI控制器
  assign spi_sdi0 = flash_dq0;
  assign spi_sdi1 = flash_dq1;

  // 寄存器地址定义
  localparam REG_STATUS = 32'h00;
  localparam REG_CLKDIV = 32'h04;
  localparam REG_SPICMD = 32'h08;
  localparam REG_SPIADR = 32'h0C;
  localparam REG_SPILEN = 32'h10;
  localparam REG_SPIDUM = 32'h14;
  localparam REG_TXFIFO = 32'h18;
  localparam REG_RXFIFO = 32'h20;
  localparam REG_INTCFG = 32'h24;
  localparam REG_INTSTA = 32'h28;

  // OBI读操作任务
  task obi_read;
    input [31:0] address;
    output [31:0] read_data;
    begin
      req_i = 1'b1;
      we_i = 1'b0;
      addr_i = address;
      data_i = 32'h0;
      be_i = 4'hF;

      // 等待授权
      @(posedge clk);
      while (!gnt_o) @(posedge clk);

      // 等待数据有效
      @(posedge clk);
      while (!rvalid_o) @(posedge clk);

      read_data = data_o;

      // 结束请求
      req_i = 1'b0;
      we_i = 1'b0;
      addr_i = 32'h0;
      data_i = 32'h0;
      be_i = 4'h0;

      @(posedge clk);
    end
  endtask

  // OBI写操作任务
  task obi_write;
    input [31:0] address;
    input [31:0] write_data;
    begin
      req_i = 1'b1;
      we_i = 1'b1;
      addr_i = address;
      data_i = write_data;
      be_i = 4'hF;

      // 等待授权
      @(posedge clk);
      while (!gnt_o) @(posedge clk);

      // 结束请求
      req_i = 1'b0;
      we_i = 1'b0;
      addr_i = 32'h0;
      data_i = 32'h0;
      be_i = 4'h0;

      @(posedge clk);
    end
  endtask

  // 验证任务
  task verify;
    input [31:0] expected;
    input [31:0] actual;
    input string test_name;
    begin
      total_tests = total_tests + 1;
      if (expected === actual) begin
        $display("[PASS] %s: Expected=0x%08X, Actual=0x%08X", test_name, expected, actual);
        test_pass_count = test_pass_count + 1;
      end else begin
        $display("[FAIL] %s: Expected=0x%08X, Actual=0x%08X", test_name, expected, actual);
        test_fail_count = test_fail_count + 1;
      end
    end
  endtask

  // 初始化任务
  task init;
    begin
      clk = 1'b0;
      rst_n = 1'b0;
      req_i = 1'b0;
      we_i = 1'b0;
      addr_i = 32'h0;
      data_i = 32'h0;
      be_i = 4'h0;
      // spi_sdi0, spi_sdi1, spi_sdi2, spi_sdi3 现在是wire类型，通过连续赋值连接

      // 复位
      #20;
      rst_n = 1'b1;
      #20;
    end
  endtask

  // 配置SPI控制器任务
  task configure_spi;
    begin
      // 设置CS寄存器
      obi_write(REG_STATUS, 32'h00000F13); // CS0使能

      // 设置时钟分频器 (分频系数=4)
      obi_write(REG_CLKDIV, 32'h00000001);

      // 设置SPI命令 (读命令=0x03)
      obi_write(REG_SPICMD, 32'h00000003);

      // 设置命令长度为8位
      obi_write(REG_SPILEN, 32'h00080000);

      // 设置地址长度为24位
      obi_write(REG_SPILEN, 32'h00180000);

      // 设置数据长度
      obi_write(REG_SPILEN, 32'h00000008);

      // 设置读dummy周期
      obi_write(REG_SPIDUM, 32'h00000000);
    end
  endtask

  // 测试用例1: Flash ID读取
  task test_flash_id;
    reg [31:0] read_data;
    begin
      $display("=== Test 1: Flash ID Read ===");

      // 配置SPI控制器
      configure_spi;

      // 设置地址为0x00000000 (JEDEC ID读取)
      obi_write(REG_SPIADR, 32'h00000000);

      // 启动读操作
      obi_write(REG_STATUS, 32'h00000001); // 设置读使能

      // 等待操作完成
      #1000;

      // 读取状态寄存器
      obi_read(REG_STATUS, read_data);

      // 验证状态
      verify(32'h00000000, read_data & 32'h000000FF, "Flash ID Read Status");

      $display("=== Test 1 Complete ===\n");
    end
  endtask

  // 测试用例2: 地址0x1000数据读取
  task test_read_address_1000;
    reg [31:0] read_data;
    begin
      $display("=== Test 2: Read Address 0x1000 ===");

      // 配置SPI控制器
      configure_spi;

      // 设置地址为0x00001000
      obi_write(REG_SPIADR, 32'h00001000);

      // 启动读操作
      obi_write(REG_STATUS, 32'h00000001); // 设置读使能

      // 等待操作完成
      #1000;

      // 读取状态寄存器
      obi_read(REG_STATUS, read_data);

      // 验证状态
      verify(32'h00000000, read_data & 32'h000000FF, "Address 0x1000 Read Status");

      $display("=== Test 2 Complete ===\n");
    end
  endtask

  // 测试用例3: 地址0x2000数据读取
  task test_read_address_2000;
    reg [31:0] read_data;
    begin
      $display("=== Test 3: Read Address 0x2000 ===");

      // 配置SPI控制器
      configure_spi;

      // 设置地址为0x00002000
      obi_write(REG_SPIADR, 32'h00002000);

      // 启动读操作
      obi_write(REG_STATUS, 32'h00000001); // 设置读使能

      // 等待操作完成
      #1000;

      // 读取状态寄存器
      obi_read(REG_STATUS, read_data);

      // 验证状态
      verify(32'h00000000, read_data & 32'h000000FF, "Address 0x2000 Read Status");

      $display("=== Test 3 Complete ===\n");
    end
  endtask

  // 测试用例4: 边界地址测试
  task test_boundary_address;
    reg [31:0] read_data;
    begin
      $display("=== Test 4: Boundary Address Test ===");

      // 配置SPI控制器
      configure_spi;

      // 测试边界地址0x00000000
      obi_write(REG_SPIADR, 32'h00000000);
      obi_write(REG_STATUS, 32'h00000001);
      #1000;
      obi_read(REG_STATUS, read_data);
      verify(32'h00000000, read_data & 32'h000000FF, "Boundary Address 0x00000000");

      // 测试边界地址0x00FFFFFF
      obi_write(REG_SPIADR, 32'h00FFFFFF);
      obi_write(REG_STATUS, 32'h00000001);
      #1000;
      obi_read(REG_STATUS, read_data);
      verify(32'h00000000, read_data & 32'h000000FF, "Boundary Address 0x00FFFFFF");

      $display("=== Test 4 Complete ===\n");
    end
  endtask

  // 测试用例5: 连续地址读取
  task test_sequential_read;
    reg [31:0] read_data;
    integer i;
    begin
      $display("=== Test 5: Sequential Address Read ===");

      // 配置SPI控制器
      configure_spi;

      for (i = 0; i < 4; i = i + 1) begin
        // 设置地址
        obi_write(REG_SPIADR, 32'h00001000 + (i * 4));

        // 启动读操作
        obi_write(REG_STATUS, 32'h00000001);

        // 等待操作完成
        #1000;

        // 读取状态寄存器
        obi_read(REG_STATUS, read_data);

        // 验证状态
        verify(32'h00000000, read_data & 32'h000000FF, $sformatf("Sequential Read Address 0x%08X", 32'h00001000 + (i * 4)));
      end

      $display("=== Test 5 Complete ===\n");
    end
  endtask

  // 主测试流程
  initial begin
    // 初始化
    init;

    // 运行测试用例
    test_flash_id;
    test_read_address_1000;
    test_read_address_2000;
    test_boundary_address;
    test_sequential_read;

    // 测试统计
    $display("=== Test Summary ===");
    $display("Total Tests: %0d", total_tests);
    $display("Passed: %0d", test_pass_count);
    $display("Failed: %0d", test_fail_count);

    if (test_fail_count == 0) begin
      $display("All tests PASSED!");
    end else begin
      $display("Some tests FAILED!");
    end

    // 结束仿真
    #100;
    $finish;
  end

  // 波形输出
  initial begin
    $dumpfile("spi_obi_core_tb.vcd");
    $dumpvars(0, spi_obi_core_tb);
  end

  // 超时保护
  initial begin
    #1000000; // 1ms超时
    $display("ERROR: Simulation timeout!");
    $finish;
  end

endmodule