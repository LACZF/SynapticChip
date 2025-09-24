// riscv64_cpu_with_cache.v
module riscv64_cpu_with_cache (
    input wire clk,
    input wire rst_n,

    // 主存接口（连接到外部存储器控制器）
    output wire [63:0] mem_addr,
    output wire [63:0] mem_data_out,
    input wire [63:0] mem_data_in,
    output wire mem_we,
    output wire [7:0] mem_sel,
    output wire mem_req,
    input wire mem_ack,

    // 中断输入
    input wire ext_interrupt,
    input wire timer_interrupt,
    input wire soft_interrupt,

    // 调试接口
    output wire [63:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire [4:0] debug_state,
    /* TODO */
    // output wire [63:0] debug_registers [0:31],

    // 缓存性能统计
    output wire [31:0] perf_icache_hits,
    output wire [31:0] perf_icache_misses,
    output wire [31:0] perf_dcache_hits,
    output wire [31:0] perf_dcache_misses,
    output wire [31:0] perf_l2cache_hits,
    output wire [31:0] perf_l2cache_misses
);

    // ==================== CPU与缓存接口信号 ====================

    // CPU核心接口
    wire [63:0] cpu_imem_addr;
    wire [63:0] cpu_imem_data;
    wire cpu_imem_req;
    wire cpu_imem_ack;

    wire [63:0] cpu_dmem_addr;
    wire [63:0] cpu_dmem_data_out;
    wire [63:0] cpu_dmem_data_in;
    wire cpu_dmem_we;
    wire [7:0] cpu_dmem_sel;
    wire cpu_dmem_req;
    wire cpu_dmem_ack;

    // 缓存系统接口
    wire [63:0] cache_imem_addr;
    wire [63:0] cache_imem_data;
    wire cache_imem_req;
    wire cache_imem_ack;

    wire [63:0] cache_dmem_addr;
    wire [63:0] cache_dmem_data_out;
    wire [63:0] cache_dmem_data_in;
    wire cache_dmem_we;
    wire [7:0] cache_dmem_sel;
    wire cache_dmem_req;
    wire cache_dmem_ack;

    // 缓存系统内部信号
    wire [63:0] l2_mem_addr;
    wire [63:0] l2_mem_data_out;
    wire [63:0] l2_mem_data_in;
    wire l2_mem_we;
    wire [7:0] l2_mem_sel;
    wire l2_mem_req;
    wire l2_mem_ack;

    // ==================== 模块实例化 ====================

    // 64位RISC-V CPU核心
    riscv64_cpu cpu_core (
        .clk(clk),
        .rst_n(rst_n),

        // 指令存储器接口（连接到缓存）
        .imem_addr(cpu_imem_addr),
        .imem_data(cpu_imem_data),
        .imem_req(cpu_imem_req),
        .imem_ack(cpu_imem_ack),

        // 数据存储器接口（连接到缓存）
        .dmem_addr(cpu_dmem_addr),
        .dmem_data_out(cpu_dmem_data_out),
        .dmem_data_in(cpu_dmem_data_in),
        .dmem_we(cpu_dmem_we),
        .dmem_sel(cpu_dmem_sel),
        .dmem_req(cpu_dmem_req),
        .dmem_ack(cpu_dmem_ack),

        // 中断输入
        .ext_interrupt(ext_interrupt),
        .timer_interrupt(timer_interrupt),
        .soft_interrupt(soft_interrupt),

        // 调试输出
        .debug_pc(debug_pc),
        .debug_instruction(debug_instruction),
        .debug_state(debug_state)
    );

    // 64位缓存系统
    cache_system_64bit cache_system (
        .clk(clk),
        .rst_n(rst_n),

        // CPU接口
        .cpu_imem_addr(cpu_imem_addr),
        .cpu_imem_data(cpu_imem_data),
        .cpu_imem_req(cpu_imem_req),
        .cpu_imem_ack(cpu_imem_ack),

        .cpu_dmem_addr(cpu_dmem_addr),
        .cpu_dmem_data_out(cpu_dmem_data_out),
        .cpu_dmem_data_in(cpu_dmem_data_in),
        .cpu_dmem_we(cpu_dmem_we),
        .cpu_dmem_sel(cpu_dmem_sel),
        .cpu_dmem_req(cpu_dmem_req),
        .cpu_dmem_ack(cpu_dmem_ack),

        // 主存接口
        .mem_addr(l2_mem_addr),
        .mem_data_out(l2_mem_data_out),
        .mem_data_in(l2_mem_data_in),
        .mem_we(l2_mem_we),
        .mem_sel(l2_mem_sel),
        .mem_req(l2_mem_req),
        .mem_ack(l2_mem_ack),

        // 性能统计
        .perf_icache_hits(perf_icache_hits),
        .perf_icache_misses(perf_icache_misses),
        .perf_dcache_hits(perf_dcache_hits),
        .perf_dcache_misses(perf_dcache_misses),
        .perf_l2cache_hits(perf_l2cache_hits),
        .perf_l2cache_misses(perf_l2cache_misses)
    );

    // 存储器接口适配器（处理缓存未命中的主存访问）
    memory_interface_adapter mem_adapter (
        .clk(clk),
        .rst_n(rst_n),

        // 缓存系统接口
        .cache_addr(l2_mem_addr),
        .cache_data_out(l2_mem_data_out),
        .cache_data_in(l2_mem_data_in),
        .cache_we(l2_mem_we),
        .cache_sel(l2_mem_sel),
        .cache_req(l2_mem_req),
        .cache_ack(l2_mem_ack),

        // 外部存储器接口
        .ext_mem_addr(mem_addr),
        .ext_mem_data_out(mem_data_out),
        .ext_mem_data_in(mem_data_in),
        .ext_mem_we(mem_we),
        .ext_mem_sel(mem_sel),
        .ext_mem_req(mem_req),
        .ext_mem_ack(mem_ack)
    );

    // 寄存器调试接口（连接到CPU内部寄存器文件）
    // assign debug_registers = cpu_core.reg_file.registers;

endmodule