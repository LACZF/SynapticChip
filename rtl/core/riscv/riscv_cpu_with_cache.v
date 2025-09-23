// riscv_cpu_with_cache.v
module riscv_cpu_with_cache (
    input wire clk,
    input wire rst_n,

    // 存储器接口（现在连接到缓存系统）
    output wire [31:0] imem_addr,
    input wire [31:0] imem_data,
    output wire imem_req,
    input wire imem_ack,

    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_data_out,
    input wire [31:0] dmem_data_in,
    output wire dmem_we,
    output wire [3:0] dmem_sel,
    output wire dmem_req,
    input wire dmem_ack,

    // 中断输入
    input wire ext_interrupt,
    input wire timer_interrupt,
    input wire soft_interrupt,

    // 缓存性能统计
    output wire [31:0] perf_icache_hits,
    output wire [31:0] perf_icache_misses,
    output wire [31:0] perf_dcache_hits,
    output wire [31:0] perf_dcache_misses,
    output wire [31:0] perf_l2cache_hits,
    output wire [31:0] perf_l2cache_misses
);

    // CPU核心（使用之前的RISC-V CPU实现）
    riscv_cpu cpu_core (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_req(imem_req),
        .imem_ack(imem_ack),
        .dmem_addr(dmem_addr),
        .dmem_data_out(dmem_data_out),
        .dmem_data_in(dmem_data_in),
        .dmem_we(dmem_we),
        .dmem_sel(dmem_sel),
        .dmem_req(dmem_req),
        .dmem_ack(dmem_ack),
        .ext_interrupt(ext_interrupt),
        .timer_interrupt(timer_interrupt),
        .soft_interrupt(soft_interrupt)
    );

    // 缓存系统
    cache_system cache_sys (
        .clk(clk),
        .rst_n(rst_n),

        // CPU接口
        .cpu_imem_addr(imem_addr),
        .cpu_imem_data(imem_data),
        .cpu_imem_req(imem_req),
        .cpu_imem_ack(imem_ack),

        .cpu_dmem_addr(dmem_addr),
        .cpu_dmem_data_out(dmem_data_out),
        .cpu_dmem_data_in(dmem_data_in),
        .cpu_dmem_we(dmem_we),
        .cpu_dmem_sel(dmem_sel),
        .cpu_dmem_req(dmem_req),
        .cpu_dmem_ack(dmem_ack),

        // 性能统计
        .perf_icache_hits(perf_icache_hits),
        .perf_icache_misses(perf_icache_misses),
        .perf_dcache_hits(perf_dcache_hits),
        .perf_dcache_misses(perf_dcache_misses),
        .perf_l2cache_hits(perf_l2cache_hits),
        .perf_l2cache_misses(perf_l2cache_misses)
    );

endmodule
