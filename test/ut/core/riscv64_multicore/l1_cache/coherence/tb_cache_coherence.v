// tb_cache_coherence.v
module tb_cache_coherence;

    reg clk;
    reg rst_n;

    // 测试多核缓存一致性
    // 简化版本，重点测试监听协议

    // ... 类似的测试框架，但专注于缓存一致性场景

    initial begin
        clk = 0;
        rst_n = 0;

        #20 rst_n = 1;

        // 测试场景：两个核同时读写同一地址
        #100;
        $display("Testing cache coherence protocol...");

        // 监控监听活动
        forever begin
            @(posedge clk);
            if (snoop_valid[0] || snoop_valid[1]) begin
                $display("Time %0t: Snoop activity detected", $time);
            end
        end
    end

    initial begin
        #500;
        $display("Cache Coherence Test Completed");
        $finish;
    end

endmodule
