// tb_riscv64_l2_cache_system.v
module tb_riscv64_l2_cache_system;

    reg clk;
    reg rst_n;

    // 系统参数
    parameter NUM_CORES = 4;

    // 内存接口
    wire mem_req;
    wire [63:0] mem_addr;
    wire [511:0] mem_wdata;
    reg [511:0] mem_rdata;
    wire mem_we;
    reg mem_ready;

    // 中断信号
    reg [NUM_CORES-1:0] ipi_interrupt;

    // 调试信号
    wire [NUM_CORES-1:0] core_halted;

    // 时钟生成
    always #5 clk = ~clk;

    // 完整系统实例
    riscv64_multicore_with_l2_cache #(
        .NUM_CORES(NUM_CORES),
        .CORE_ID_WIDTH(2)
    ) u_system (
        .clk(clk),
        .rst_n(rst_n),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(mem_we),
        .mem_ready(mem_ready),
        .ipi_interrupt(ipi_interrupt),
        .core_halted(core_halted)
    );

    // 主内存模型（DRAM模拟）
    reg [511:0] main_memory [0:65535]; // 4MB内存
    reg [15:0] memory_latency_counter;
    reg memory_access_pending;
    reg [63:0] pending_mem_addr;
    reg pending_mem_we;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        mem_ready = 0;
        ipi_interrupt = {NUM_CORES{1'b0}};
        memory_access_pending = 0;

        // 初始化内存内容
        for (integer j = 0; j < 65536; j = j + 1) begin
            main_memory[j] = 512'b0;
        end

        // 加载测试程序到内存
        initialize_test_program();

        #100 rst_n = 1;

        // 内存访问处理
        forever begin
            @(posedge clk);

            if (mem_req && !memory_access_pending) begin
                memory_access_pending = 1'b1;
                pending_mem_addr = mem_addr;
                pending_mem_we = mem_we;
                memory_latency_counter = 10; // 10周期内存延迟
            end

            if (memory_access_pending) begin
                if (memory_latency_counter > 0) begin
                    memory_latency_counter = memory_latency_counter - 1;
                end else begin
                    // 内存访问完成
                    memory_access_pending = 1'b0;
                    mem_ready = 1'b1;

                    if (pending_mem_we) begin
                        main_memory[pending_mem_addr[23:6]] <= mem_wdata;
                        $display("Time %0t: Memory Write to address %h", $time, pending_mem_addr);
                    end else begin
                        mem_rdata <= main_memory[pending_mem_addr[23:6]];
                        $display("Time %0t: Memory Read from address %h", $time, pending_mem_addr);
                    end

                    @(posedge clk);
                    mem_ready = 1'b0;
                end
            end
        end
    end

    // 测试程序初始化
    task initialize_test_program;
        begin
            // 核心0：写入测试模式
            main_memory[0] = {
                32'h00000013, 32'h00100093, 32'h00200113, 32'h00300193, // NOP, ADDI x1, x0, 1, ADDI x2, x0, 2, ADDI x3, x0, 3
                32'h00400213, 32'h00500293, 32'h00600313, 32'h00700393  // ADDI x4, x0, 4, ADDI x5, x0, 5, ADDI x6, x0, 6, ADDI x7, x0, 7
            };

            // 核心1：读取并验证
            main_memory[1] = {
                32'h00000013, 32'h00002083, 32'h00402103, 32'h00802183, // NOP, LW x1, 0(x0), LW x2, 4(x0), LW x3, 8(x0)
                32'h00c02203, 32'h01002283, 32'h01402303, 32'h01802383  // LW x4, 12(x0), LW x5, 16(x0), LW x6, 20(x0), LW x7, 24(x0)
            };

            // 数据区域
            main_memory[256] = 512'h0123456789ABCDEF_FEDCBA9876543210_0011223344556677_8899AABBCCDDEEFF;
        end
    endtask

    // 监控系统行为
    integer cycle_count;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;

            // 监控L2缓存活动
            if (mem_req) begin
                $display("Time %0t: L2 Cache accessing memory", $time);
            end

            // 每1000周期显示进度
            if (cycle_count % 1000 == 0) begin
                $display("Cycle %0d: Simulation running...", cycle_count);
            end

            // 结束条件
            if (cycle_count > 10000) begin
                $display("Simulation completed after %0d cycles", cycle_count);
                $finish;
            end
        end
    end

    // 性能统计
    reg [31:0] l2_cache_hits;
    reg [31:0] l2_cache_misses;
    reg [31:0] memory_accesses;

    always @(posedge clk) begin
        if (mem_req) begin
            memory_accesses = memory_accesses + 1;
            if (mem_ready) begin
                l2_cache_misses = l2_cache_misses + 1;
            end
        end
    end

    initial begin
        cycle_count = 0;
        l2_cache_hits = 0;
        l2_cache_misses = 0;
        memory_accesses = 0;

        #10000;
        $display("=== L2 Cache Performance Statistics ===");
        $display("Total Cycles: %0d", cycle_count);
        $display("Memory Accesses: %0d", memory_accesses);
        $display("L2 Cache Misses: %0d", l2_cache_misses);
        $display("L2 Cache Hit Rate: %.2f%%", (memory_accesses - l2_cache_misses) * 100.0 / memory_accesses);
        $display("Average Memory Latency: %.2f cycles", cycle_count * 1.0 / memory_accesses);
        $finish;
    end

endmodule
