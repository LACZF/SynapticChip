module cgra_tb;

parameter CLK_PERIOD = 10;
parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 16;

reg clk;
reg rst_n;
reg obi_req;
reg obi_we;
reg [ADDR_WIDTH-1:0] obi_addr;
reg [DATA_WIDTH-1:0] obi_wdata;
wire obi_gnt;
wire obi_rvalid;
wire [DATA_WIDTH-1:0] obi_rdata;
wire ready;

// 调试信号
wire [DATA_WIDTH-1:0] debug_pe00_config;
wire [DATA_WIDTH-1:0] debug_pe00_out;
wire debug_pe00_valid;
wire [DATA_WIDTH-1:0] debug_data_mem0;
wire debug_data_mem0_valid;

// Clock generation
always #(CLK_PERIOD/2) clk = ~clk;

// DUT instantiation
cgra_top #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .PE_ARRAY_X(2),
    .PE_ARRAY_Y(2),
    .CONFIG_WIDTH(64),
    .NUM_CONTEXTS(4)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .obi_req(obi_req),
    .obi_we(obi_we),
    .obi_addr(obi_addr),
    .obi_wdata(obi_wdata),
    .obi_gnt(obi_gnt),
    .obi_rvalid(obi_rvalid),
    .obi_rdata(obi_rdata),
    .ready(ready)
);

// 连接调试信号
assign debug_pe00_config = dut.debug_pe00_config;
assign debug_pe00_out = dut.debug_pe00_out;
assign debug_pe00_valid = dut.debug_pe00_valid;
assign debug_data_mem0 = dut.debug_data_mem0;
assign debug_data_mem0_valid = dut.debug_data_mem0_valid;

// Test task for OBI write
task obi_write;
    input [ADDR_WIDTH-1:0] addr;
    input [DATA_WIDTH-1:0] data;
    begin
        @(posedge clk);
        obi_req = 1'b1;
        obi_we = 1'b1;
        obi_addr = addr;
        obi_wdata = data;

        wait (obi_gnt);
        @(posedge clk);
        obi_req = 1'b0;

        wait (obi_rvalid);
        @(posedge clk);
    end
endtask

// Test task for OBI read
task obi_read;
    input [ADDR_WIDTH-1:0] addr;
    output [DATA_WIDTH-1:0] data;
    begin
        @(posedge clk);
        obi_req = 1'b1;
        obi_we = 1'b0;
        obi_addr = addr;

        wait (obi_gnt);
        @(posedge clk);
        obi_req = 1'b0;

        wait (obi_rvalid);
        data = obi_rdata;
        @(posedge clk);
    end
endtask

// Test verification task
task verify_test;
    input [DATA_WIDTH-1:0] actual;
    input [DATA_WIDTH-1:0] expected;
    input string test_name;
    begin
        if (actual === expected) begin
            $display("PASS: %s - Expected: 0x%h, Got: 0x%h", test_name, expected, actual);
        end else begin
            $display("FAIL: %s - Expected: 0x%h, Got: 0x%h", test_name, expected, actual);
        end
    end
endtask

reg [31:0] read_data;
integer test_count = 0;
integer pass_count = 0;

initial begin
    // Initialize waveform dump
    $dumpfile("cgra_dataflow.vcd");
    $dumpvars(0, cgra_tb);

    // Initialize
    clk = 0;
    rst_n = 0;
    obi_req = 0;
    obi_we = 0;
    obi_addr = 0;
    obi_wdata = 0;

    $display("=== Starting CGRA Dataflow Simulation ===");

    // Reset
    #100;
    rst_n = 1;

    // Wait for ready
    wait (ready);
    $display("Time %0t: CGRA is ready", $time);

    // Test 1: 基本数据流测试 - PASS操作
    $display("\n=== Test 1: Basic Dataflow - PASS Operation ===");
    test_count = test_count + 1;

    // 配置PE(0,0)为PASS操作（从北输入传递数据）
    obi_write(16'h0000, 32'h00000A00); // PASS from NORTH
    obi_write(16'h0004, 32'h00000000); // No immediate
    obi_write(16'h0008, 32'h00000010); // Enable output

    // 加载配置到PE
    obi_write(16'h1010, 32'h00000001);

    #50;

    // 写入输入数据到PE(0,0)的北输入
    obi_write(16'h8000, 32'h00000042);

    // 启动计算
    obi_write(16'hC0FC, 32'h00000001); // 全局启动信号

    // 等待计算完成
    #200;

    // 读取PE(0,0)的输出
    obi_read(16'h8080, read_data);

    if (read_data === 32'h00000042) begin
        $display("PASS: PE PASS operation with dataflow control");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL: PE PASS operation - Expected 0x42, got 0x%h", read_data);
        $display("Debug: PE00_out=0x%h, PE00_valid=%b, DataMem0=0x%h, DataMem0_valid=%b",
                 debug_pe00_out, debug_pe00_valid, debug_data_mem0, debug_data_mem0_valid);
    end

    // Test 2: PE加法操作测试
    $display("\n=== Test 2: PE ADD Operation with Dataflow ===");
    test_count = test_count + 1;

    // 重新配置PE(0,0)为ADD操作
    obi_write(16'h0000, 32'h00000001); // ADD, use_immediate=1
    obi_write(16'h0004, 32'h00000005); // Immediate value = 5
    obi_write(16'h0008, 32'h00000010); // Enable output

    obi_write(16'h1010, 32'h00000001);
    #50;

    // 提供输入并启动
    obi_write(16'h8000, 32'h0000000A); // North input = 10
    obi_write(16'hC0FC, 32'h00000001); // 启动

    #200;

    obi_read(16'h8080, read_data);

    if (read_data === 32'h0000000F) begin
        $display("PASS: PE ADD operation with dataflow (10 + 5 = 15)");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL: PE ADD operation - Expected 0xF, got 0x%h", read_data);
    end

    // Test 3: 多PE数据流测试
    $display("\n=== Test 3: Multi-PE Dataflow Communication ===");
    test_count = test_count + 1;

    // 配置PE(0,1)从西输入传递数据
    obi_write(16'h0010, 32'h00000A02); // PASS from WEST
    obi_write(16'h0014, 32'h00000000);
    obi_write(16'h0018, 32'h00000004); // Enable EAST output

    obi_write(16'h1010, 32'h00000001);
    #50;

    // 写入输入数据并启动
    obi_write(16'h8000, 32'h00000033); // PE(0,0)输入
    obi_write(16'hC0FC, 32'h00000001); // 启动

    #300; // 需要更多时间让数据流过多个PE

    obi_read(16'h8081, read_data); // PE(0,1)输出

    if (read_data === 32'h00000033) begin
        $display("PASS: Multi-PE dataflow communication test");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL: Multi-PE dataflow communication - Expected 0x33, got 0x%h", read_data);
    end

    // Test 4: 无效数据测试
    $display("\n=== Test 4: Invalid Data Handling ===");
    test_count = test_count + 1;

    // 配置PE(0,0)为ADD，但只提供一个输入
    obi_write(16'h0000, 32'h00000000); // ADD, use_immediate=0, 需要两个输入
    obi_write(16'h0004, 32'h00000000);
    obi_write(16'h0008, 32'h00000010);

    obi_write(16'h1010, 32'h00000001);
    #50;

    // 只提供一个输入（北输入），西输入无效
    obi_write(16'h8000, 32'h00000011); // 北输入有效
    // 西输入保持无效（不写入数据）
    obi_write(16'hC0FC, 32'h00000001); // 启动

    #100;

    obi_read(16'h8080, read_data);
    // 由于缺少一个输入，PE输出应该保持之前的值或0
    $display("Invalid data test: PE output with missing input = 0x%h", read_data);

    // 现在提供两个有效输入
    obi_write(16'h8020, 32'h00000022); // 西输入也有效
    #100;

    obi_read(16'h8080, read_data);
    if (read_data === 32'h00000033) begin // 11 + 22 = 33
        $display("PASS: Invalid data handling test");
        pass_count = pass_count + 1;
    end else begin
        $display("FAIL: Invalid data handling - Expected 0x33, got 0x%h", read_data);
    end

    // 测试总结
    $display("\n=== TEST SUMMARY ===");
    $display("Total Tests: %0d", test_count);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", test_count - pass_count);

    if (pass_count == test_count) begin
        $display("ALL TESTS PASSED!");
    end else begin
        $display("SOME TESTS FAILED!");
    end

    $finish;
end

// 监控关键信号
initial begin
    #5; // 等待初始化
    $display("\nTime\tOperation\tAddress\tData\tPE00_Out\tPE00_Valid\tDataMem0\tDataMem0_Valid");
    forever begin
        @(posedge clk);
        if (obi_req && obi_gnt) begin
            if (obi_we) begin
                $display("%0t\tWRITE\t0x%h\t0x%h\t0x%h\t%b\t0x%h\t%b",
                         $time, obi_addr, obi_wdata, debug_pe00_out, debug_pe00_valid,
                         debug_data_mem0, debug_data_mem0_valid);
            end else begin
                $display("%0t\tREAD\t0x%h\t----\t0x%h\t%b\t0x%h\t%b",
                         $time, obi_addr, debug_pe00_out, debug_pe00_valid,
                         debug_data_mem0, debug_data_mem0_valid);
            end
        end
    end
end

endmodule