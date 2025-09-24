// tb_riscv64_cpu_with_cache.v
module tb_riscv64_cpu_with_cache;

    reg clk;
    reg rst_n;

    // 主存接口
    reg [63:0] mem_data_in;
    reg mem_ack;

    wire [63:0] mem_addr;
    wire [63:0] mem_data_out;
    wire mem_we;
    wire [7:0] mem_sel;
    wire mem_req;

    // 中断信号
    reg ext_int;
    reg timer_int;
    reg soft_int;

    // 调试信号
    wire [63:0] debug_pc;
    wire [31:0] debug_instruction;
    wire [4:0] debug_state;
    // wire [63:0] debug_registers [0:31];

    // 性能统计
    wire [31:0] perf_icache_hits;
    wire [31:0] perf_icache_misses;
    wire [31:0] perf_dcache_hits;
    wire [31:0] perf_dcache_misses;
    wire [31:0] perf_l2cache_hits;
    wire [31:0] perf_l2cache_misses;

    // 主存储器模拟
    reg [63:0] main_memory [0:1048575];  // 8MB主存

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化带缓存的64位CPU
    riscv64_cpu_with_cache uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_we(mem_we),
        .mem_sel(mem_sel),
        .mem_req(mem_req),
        .mem_ack(mem_ack),
        .ext_interrupt(ext_int),
        .timer_interrupt(timer_int),
        .soft_interrupt(soft_int),
        .debug_pc(debug_pc),
        .debug_instruction(debug_instruction),
        .debug_state(debug_state),
        // .debug_registers(debug_registers),
        .perf_icache_hits(perf_icache_hits),
        .perf_icache_misses(perf_icache_misses),
        .perf_dcache_hits(perf_dcache_hits),
        .perf_dcache_misses(perf_dcache_misses),
        .perf_l2cache_hits(perf_l2cache_hits),
        .perf_l2cache_misses(perf_l2cache_misses)
    );

    // 主存储器模拟
    always @(posedge clk) begin
        if (mem_req && mem_we) begin
            // 写操作
            if (mem_sel[0]) main_memory[mem_addr[23:3]][7:0]   <= mem_data_out[7:0];
            if (mem_sel[1]) main_memory[mem_addr[23:3]][15:8]  <= mem_data_out[15:8];
            if (mem_sel[2]) main_memory[mem_addr[23:3]][23:16] <= mem_data_out[23:16];
            if (mem_sel[3]) main_memory[mem_addr[23:3]][31:24] <= mem_data_out[31:24];
            if (mem_sel[4]) main_memory[mem_addr[23:3]][39:32] <= mem_data_out[39:32];
            if (mem_sel[5]) main_memory[mem_addr[23:3]][47:40] <= mem_data_out[47:40];
            if (mem_sel[6]) main_memory[mem_addr[23:3]][55:48] <= mem_data_out[55:48];
            if (mem_sel[7]) main_memory[mem_addr[23:3]][63:56] <= mem_data_out[63:56];
            mem_ack <= 1'b1;
        end else if (mem_req && !mem_we) begin
            // 读操作
            mem_data_in <= main_memory[mem_addr[23:3]];
            mem_ack <= 1'b1;
        end else begin
            mem_ack <= 1'b0;
        end
    end

    // 加载测试程序到主存
    integer i;
    initial begin
        // 简单的64位测试程序
        for (i = 0; i < 256; i = i + 1) begin
            main_memory[i] = 64'h0000000000000000;
        end

        // 测试程序：64位加法
        main_memory[0] = 64'h0000000000000093;  // addi x1, x0, 0
        main_memory[1] = 64'h0010013000000113;  // addi x2, x0, 1
        main_memory[2] = 64'h002081B300000193;  // addi x3, x1, 2
        main_memory[3] = 64'h0031023300000223;  // add x4, x2, x3
        main_memory[4] = 64'h000000730000006F;  // jal x0, 0 (循环)
    end

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        ext_int = 0;
        timer_int = 0;
        soft_int = 0;

        // 创建VCD文件
        $dumpfile("riscv64_cpu_with_cache.vcd");
        $dumpvars(0, tb_riscv64_cpu_with_cache);

        // 复位
        #20;
        rst_n = 1;

        $display("=== 64位RISC-V CPU带缓存系统测试开始 ===");

        // 运行测试
        #2000;

        // 显示性能统计
        $display("=== 缓存性能统计 ===");
        $display("L1指令缓存: 命中=%d, 未命中=%d, 命中率=%.1f%%",
                perf_icache_hits, perf_icache_misses,
                (perf_icache_hits * 100.0) / (perf_icache_hits + perf_icache_misses));

        $display("L1数据缓存: 命中=%d, 未命中=%d, 命中率=%.1f%%",
                perf_dcache_hits, perf_dcache_misses,
                (perf_dcache_hits * 100.0) / (perf_dcache_hits + perf_dcache_misses));

        $display("L2缓存: 命中=%d, 未命中=%d, 命中率=%.1f%%",
                perf_l2cache_hits, perf_l2cache_misses,
                (perf_l2cache_hits * 100.0) / (perf_l2cache_hits + perf_l2cache_misses));

        // 显示寄存器状态
        $display("=== 寄存器状态 ===");
        // $display("x1 = 0x%h", debug_registers[1]);
        // $display("x2 = 0x%h", debug_registers[2]);
        // $display("x3 = 0x%h", debug_registers[3]);
        // $display("x4 = 0x%h", debug_registers[4]);

        $display("=== 测试完成 ===");
        $finish;
    end

    // 监控系统行为
    always @(posedge clk) begin
        if (uut.cpu_core.if_id_valid) begin
            $display("时间: %t - IF: PC=0x%h, INST=0x%h",
                    $time, debug_pc, debug_instruction);
        end

        // 监控缓存未命中
        if (uut.cache_system.l1_icache_inst.cache_miss) begin
            $display("时间: %t - L1指令缓存未命中: 地址=0x%h",
                    $time, uut.cache_system.l1_icache_inst.saved_addr);
        end

        if (uut.cache_system.l1_dcache_inst.cache_miss) begin
            $display("时间: %t - L1数据缓存未命中: 地址=0x%h",
                    $time, uut.cache_system.l1_dcache_inst.saved_addr);
        end

        // 监控主存访问
        if (mem_req) begin
            if (mem_we) begin
                $display("时间: %t - 主存写入: 地址=0x%h, 数据=0x%h",
                        $time, mem_addr, mem_data_out);
            end else begin
                $display("时间: %t - 主存读取: 地址=0x%h", $time, mem_addr);
            end
        end
    end

endmodule
