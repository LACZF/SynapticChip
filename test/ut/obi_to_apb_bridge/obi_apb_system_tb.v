module obi_apb_system_tb;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // OBI接口信号
    reg        obi_req_i;
    reg [31:0] obi_addr_i;
    reg        obi_we_i;
    reg [31:0] obi_wdata_i;
    reg [3:0]  obi_be_i;
    wire       obi_gnt_o;
    wire       obi_rvalid_o;
    wire [31:0] obi_rdata_o;

    // APB接口信号
    wire        apb_psel_o;
    wire        apb_penable_o;
    wire [31:0] apb_paddr_o;
    wire        apb_pwrite_o;
    wire [31:0] apb_pwdata_o;
    wire [31:0] apb_prdata_i;
    wire        apb_pready_i;
    wire        apb_pslverr_i;

    // 测试统计
    integer test_pass_count = 0;
    integer test_fail_count = 0;
    integer total_tests = 0;

    // 时钟生成
    always #5 clk = ~clk;

    // DUT实例化
    obi_to_apb_bridge bridge (
        .clk(clk),
        .rst_n(rst_n),
        .obi_req_i(obi_req_i),
        .obi_addr_i(obi_addr_i),
        .obi_we_i(obi_we_i),
        .obi_wdata_i(obi_wdata_i),
        .obi_be_i(obi_be_i),
        .obi_gnt_o(obi_gnt_o),
        .obi_rvalid_o(obi_rvalid_o),
        .obi_rdata_o(obi_rdata_o),
        .apb_psel_o(apb_psel_o),
        .apb_penable_o(apb_penable_o),
        .apb_paddr_o(apb_paddr_o),
        .apb_pwrite_o(apb_pwrite_o),
        .apb_pwdata_o(apb_pwdata_o),
        .apb_prdata_i(apb_prdata_i),
        .apb_pready_i(apb_pready_i)
    );

    apb_ram #(
        .MEM_SIZE(1024),
        .ADDR_WIDTH(10),
        .INIT_FILE("memory_init.hex")
    ) memory (
        .clk(clk),
        .rst_n(rst_n),
        .apb_psel_i(apb_psel_o),
        .apb_penable_i(apb_penable_o),
        .apb_paddr_i(apb_paddr_o),
        .apb_pwrite_i(apb_pwrite_o),
        .apb_pwdata_i(apb_pwdata_o),
        .apb_pready_o(apb_pready_i),
        .apb_prdata_o(apb_prdata_i),
        .apb_pslverr_o(apb_pslverr_i)
    );

    // 测试任务：写操作
    task write_transaction;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            obi_req_i <= 1'b1;
            obi_addr_i <= addr;
            obi_we_i <= 1'b1;
            obi_wdata_i <= data;
            obi_be_i <= 4'b1111;

            wait(obi_gnt_o);
            @(posedge clk);
            obi_req_i <= 1'b0;

            wait(obi_rvalid_o);
            $display("OBI Write: Addr=0x%h, Data=0x%h", addr, data);
        end
    endtask

    // 测试任务：读操作（带校验）
    task read_transaction_with_check;
        input [31:0] addr;
        input [31:0] expected_data;
        input string test_name;
        begin
            reg [31:0] read_data;

            @(posedge clk);
            obi_req_i <= 1'b1;
            obi_addr_i <= addr;
            obi_we_i <= 1'b0;
            obi_be_i <= 4'b1111;

            wait(obi_gnt_o);
            @(posedge clk);
            obi_req_i <= 1'b0;

            wait(obi_rvalid_o);
            read_data = obi_rdata_o;

            total_tests = total_tests + 1;

            if (read_data === expected_data) begin
                test_pass_count = test_pass_count + 1;
                $display("PASS: %s - Addr=0x%h, Expected=0x%h, Read=0x%h",
                         test_name, addr, expected_data, read_data);
            end else begin
                test_fail_count = test_fail_count + 1;
                $display("FAIL: %s - Addr=0x%h, Expected=0x%h, Read=0x%h",
                         test_name, addr, expected_data, read_data);
            end
        end
    endtask

    // 测试任务：写后读校验
    task write_read_verify;
        input [31:0] addr;
        input [31:0] write_data;
        input string test_name;
        begin
            // 写入数据
            write_transaction(addr, write_data);

            // 读取并校验数据
            read_transaction_with_check(addr, write_data, test_name);
        end
    endtask

    // 打印测试统计
    task print_test_stats;
        begin
            $display("\n==========================================");
            $display("TEST SUMMARY");
            $display("==========================================");
            $display("Total Tests:  %0d", total_tests);
            $display("Tests Passed: %0d", test_pass_count);
            $display("Tests Failed: %0d", test_fail_count);
            if (total_tests > 0) begin
                $display("Pass Rate:    %0.2f%%", (real'(test_pass_count) / real'(total_tests)) * 100.0);
            end
            $display("==========================================");

            if (test_fail_count == 0) begin
                $display("ALL TESTS PASSED!");
            end else begin
                $display("SOME TESTS FAILED!");
            end
            $display("==========================================\n");
        end
    endtask

    // 主测试程序
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        obi_req_i = 0;
        obi_addr_i = 0;
        obi_we_i = 0;
        obi_wdata_i = 0;
        obi_be_i = 0;

        // 复位
        #20 rst_n = 1;

        // 等待内存初始化完成
        #50;

        // 测试序列
        $display("Starting OBI to APB Bridge Test...");

        // 测试1：基础写后读测试（不依赖文件初始化）
        $display("\n=== Test 1: Basic Write-Read Tests ===");
        write_read_verify(32'h0000_0000, 32'h12345678, "Basic Test 0");
        write_read_verify(32'h0000_0004, 32'h9ABCDEF0, "Basic Test 4");
        write_read_verify(32'h0000_0008, 32'hDEADBEEF, "Basic Test 8");
        write_read_verify(32'h0000_000C, 32'hCAFEBABE, "Basic Test C");

        // 测试2：验证写入的数据保持性
        $display("\n=== Test 2: Data Retention Tests ===");
        read_transaction_with_check(32'h0000_0000, 32'h12345678, "Retention Test 0");
        read_transaction_with_check(32'h0000_0004, 32'h9ABCDEF0, "Retention Test 4");
        read_transaction_with_check(32'h0000_0008, 32'hDEADBEEF, "Retention Test 8");
        read_transaction_with_check(32'h0000_000C, 32'hCAFEBABE, "Retention Test C");

        // 测试3：覆盖写入测试
        $display("\n=== Test 3: Overwrite Tests ===");
        write_read_verify(32'h0000_0000, 32'h11111111, "Overwrite Test 0");
        write_read_verify(32'h0000_0004, 32'h22222222, "Overwrite Test 4");
        write_read_verify(32'h0000_0010, 32'h33333333, "Overwrite Test 10");
        write_read_verify(32'h0000_0014, 32'h44444444, "Overwrite Test 14");

        // 测试4：边界测试
        $display("\n=== Test 4: Boundary Tests ===");
        write_read_verify(32'h0000_03FC, 32'h55555555, "Boundary Test"); // 1020 = 1024-4

        // 完成测试
        #100;
        print_test_stats();

        if (test_fail_count == 0) begin
            $display("SUCCESS: All tests passed!");
        end else begin
            $display("FAILURE: %0d tests failed!", test_fail_count);
        end

        $finish;
    end

    // 监控关键信号
    always @(posedge clk) begin
        if (obi_req_i && obi_gnt_o) begin
            $display("Transaction Started: Addr=0x%h, WE=%b", obi_addr_i, obi_we_i);
        end

        if (obi_rvalid_o) begin
            $display("Transaction Completed: Data=0x%h", obi_rdata_o);
        end
    end

    // 波形dump
    initial begin
        $dumpfile("obi_apb_system.vcd");
        $dumpvars(0, obi_apb_system_tb);
    end

endmodule