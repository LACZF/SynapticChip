// tb_cache_system.v
module tb_cache_system;

    reg clk;
    reg rst_n;

    // CPU接口信号
    reg [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_data;
    reg cpu_imem_req;
    wire cpu_imem_ack;

    reg [31:0] cpu_dmem_addr;
    reg [31:0] cpu_dmem_data_out;
    wire [31:0] cpu_dmem_data_in;
    reg cpu_dmem_we;
    reg [3:0] cpu_dmem_sel;
    reg cpu_dmem_req;
    wire cpu_dmem_ack;

    // 性能统计
    wire [31:0] perf_icache_hits;
    wire [31:0] perf_icache_misses;
    wire [31:0] perf_dcache_hits;
    wire [31:0] perf_dcache_misses;
    wire [31:0] perf_l2cache_hits;
    wire [31:0] perf_l2cache_misses;

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化带缓存的CPU
    riscv_cpu_with_cache uut (
        .clk(clk),
        .rst_n(rst_n),
        // .imem_addr(cpu_imem_addr),
        .imem_data(cpu_imem_data),
        // .imem_req(cpu_imem_req),
        .imem_ack(cpu_imem_ack),
        // .dmem_addr(cpu_dmem_addr),
        // .dmem_data_out(cpu_dmem_data_out),
        .dmem_data_in(cpu_dmem_data_in),
        // .dmem_we(cpu_dmem_we),
        // .dmem_sel(cpu_dmem_sel),
        // .dmem_req(cpu_dmem_req),
        .dmem_ack(cpu_dmem_ack),
        .perf_icache_hits(perf_icache_hits),
        .perf_icache_misses(perf_icache_misses),
        .perf_dcache_hits(perf_dcache_hits),
        .perf_dcache_misses(perf_dcache_misses),
        .perf_l2cache_hits(perf_l2cache_hits),
        .perf_l2cache_misses(perf_l2cache_misses)
    );

    // 测试任务：指令读取
    task read_instruction;
        input [31:0] address;
        begin
            @(posedge clk);
            cpu_imem_addr = address;
            cpu_imem_req = 1'b1;
            @(posedge clk);
            wait(cpu_imem_ack);
            cpu_imem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 测试任务：数据读取
    task read_data;
        input [31:0] address;
        begin
            @(posedge clk);
            cpu_dmem_addr = address;
            cpu_dmem_we = 1'b0;
            cpu_dmem_req = 1'b1;
            @(posedge clk);
            wait(cpu_dmem_ack);
            cpu_dmem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 测试任务：数据写入
    task write_data;
        input [31:0] address;
        input [31:0] data;
        begin
            @(posedge clk);
            cpu_dmem_addr = address;
            cpu_dmem_data_out = data;
            cpu_dmem_we = 1'b1;
            cpu_dmem_sel = 4'b1111;
            cpu_dmem_req = 1'b1;
            @(posedge clk);
            wait(cpu_dmem_ack);
            cpu_dmem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        cpu_imem_addr = 32'h0;
        cpu_imem_req = 1'b0;
        cpu_dmem_addr = 32'h0;
        cpu_dmem_data_out = 32'h0;
        cpu_dmem_we = 1'b0;
        cpu_dmem_sel = 4'h0;
        cpu_dmem_req = 1'b0;

        // 创建VCD文件
        $dumpfile("cache_system.vcd");
        $dumpvars(0, tb_cache_system);

        // 复位
        #20;
        rst_n = 1;

        $display("=== 缓存系统测试开始 ===");

        // 测试1: 指令缓存测试
        $display("测试1: 指令缓存命中测试");
        read_instruction(32'h00000000);
        read_instruction(32'h00000004);
        read_instruction(32'h00000000);  // 应该命中
        read_instruction(32'h00000004);  // 应该命中

        // 测试2: 数据缓存测试
        $display("测试2: 数据缓存读写测试");
        write_data(32'h00001000, 32'h12345678);
        read_data(32'h00001000);  // 应该命中

        // 测试3: 缓存行填充测试
        $display("测试3: 缓存行填充测试");
        read_instruction(32'h00010000);  // 新地址，应该未命中
        read_instruction(32'h00010004);  // 同一缓存行，应该命中

        // 测试4: 写分配测试
        $display("测试4: 写分配测试");
        write_data(32'h00002000, 32'hdeadbeef);  // 写未命中
        read_data(32'h00002000);  // 应该命中

        // 测试5: 性能统计验证
        $display("测试5: 性能统计验证");
        repeat (10) @(posedge clk);

        $display("指令缓存命中率: %0d/%0d (%.1f%%)",
                perf_icache_hits, perf_icache_hits + perf_icache_misses,
                (perf_icache_hits * 100.0) / (perf_icache_hits + perf_icache_misses));

        $display("数据缓存命中率: %0d/%0d (%.1f%%)",
                perf_dcache_hits, perf_dcache_hits + perf_dcache_misses,
                (perf_dcache_hits * 100.0) / (perf_dcache_hits + perf_dcache_misses));

        $display("L2缓存命中率: %0d/%0d (%.1f%%)",
                perf_l2cache_hits, perf_l2cache_hits + perf_l2cache_misses,
                (perf_l2cache_hits * 100.0) / (perf_l2cache_hits + perf_l2cache_misses));

        $display("=== 缓存系统测试完成 ===");
        $finish;
    end

    // 监控缓存行为
    always @(posedge clk) begin
        if (cpu_imem_ack) begin
            $display("时间: %t - 指令读取: 地址=0x%h, 数据=0x%h, 命中=%s",
                    $time, cpu_imem_addr, cpu_imem_data,
                    uut.cache_sys.l1_icache_inst.cache_hit ? "是" : "否");
        end

        if (cpu_dmem_ack) begin
            if (cpu_dmem_we) begin
                $display("时间: %t - 数据写入: 地址=0x%h, 数据=0x%h, 命中=%s",
                        $time, cpu_dmem_addr, cpu_dmem_data_out,
                        uut.cache_sys.l1_dcache_inst.cache_hit ? "是" : "否");
            end else begin
                $display("时间: %t - 数据读取: 地址=0x%h, 数据=0x%h, 命中=%s",
                        $time, cpu_dmem_addr, cpu_dmem_data_in,
                        uut.cache_sys.l1_dcache_inst.cache_hit ? "是" : "否");
            end
        end
    end

endmodule
