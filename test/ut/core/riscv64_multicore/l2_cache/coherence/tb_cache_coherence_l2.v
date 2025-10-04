// tb_cache_coherence_l2.v
module tb_cache_coherence_l2;

    reg clk;
    reg rst_n;

    parameter NUM_CORES = 4;

    // 系统实例
    riscv64_multicore u_system (
        // ... 端口连接
    );

    // 测试缓存一致性的特定场景
    initial begin
        clk = 0;
        rst_n = 0;

        #100 rst_n = 1;

        $display("Starting L2 Cache Coherence Test...");

        // 测试场景1：多核同时读取同一地址
        #200;
        $display("Test 1: Multiple cores reading same address");

        // 测试场景2：一个核写入，其他核读取
        #500;
        $display("Test 2: One core writing, others reading");

        // 测试场景3：多核同时写入同一地址
        #800;
        $display("Test 3: Multiple cores writing same address");

        // 监控缓存一致性协议
        forever begin
            @(posedge clk);
            // 检测监听活动
            if (|u_system.snoop_valid) begin
                $display("Time %0t: Snoop activity detected", $time);
            end

            // 检测状态转换
            for (integer i = 0; i < NUM_CORES; i = i + 1) begin
                if (u_system.snoop_state[i*2 +: 2] != 2'b00) begin
                    $display("Time %0t: Core %0d cache state changed", $time, i);
                end
            end
        end
    end

    initial begin
        #5000;
        $display("L2 Cache Coherence Test Completed");
        $finish;
    end

endmodule
