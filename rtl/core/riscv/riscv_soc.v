// riscv_soc.v
module riscv_soc (
    input wire clk,
    input wire rst_n,

    // 外部中断输入
    input wire ext_int,

    // 调试接口
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire [4:0] debug_state,
    // output wire [31:0] debug_registers [0:31],

    // 外部存储器接口（可选）
    output wire [31:0] ext_mem_addr,
    output wire [31:0] ext_mem_data_out,
    input wire [31:0] ext_mem_data_in,
    output wire ext_mem_we,
    output wire ext_mem_re,
    input wire ext_mem_ack
);

    // ==================== 内部信号定义 ====================

    // CPU与存储器接口
    wire [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_data;
    wire cpu_imem_req;
    wire cpu_imem_ack;

    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_data_out;
    wire [31:0] cpu_dmem_data_in;
    wire cpu_dmem_we;
    wire [3:0] cpu_dmem_sel;
    wire cpu_dmem_req;
    wire cpu_dmem_ack;

    // 存储器系统内部接口
    wire [31:0] ram_addr;
    wire [31:0] ram_data_out;
    wire [31:0] ram_data_in;
    wire ram_we;
    wire [3:0] ram_sel;
    wire ram_req;
    wire ram_ack;

    wire [31:0] rom_addr;
    wire [31:0] rom_data;
    wire rom_req;
    wire rom_ack;

    wire [31:0] flash_addr;
    wire [31:0] flash_data;
    wire flash_req;
    wire flash_ack;
    wire flash_we;
    wire [31:0] flash_data_out;

    // 中断信号
    wire timer_int;
    wire soft_int;
    wire interrupt_controller_timer_int;

    // 定时器接口
    wire [31:0] timer_csr_addr;
    wire [31:0] timer_csr_data_in;
    wire timer_csr_we;
    wire [2:0] timer_csr_op;
    wire [31:0] timer_csr_data_out;
    wire timer_csr_ack;

    // 调试信号
    wire [31:0] cpu_debug_pc;
    wire [31:0] cpu_debug_instruction;
    wire [4:0] cpu_debug_state;
    wire [31:0] cpu_debug_registers [0:31];

    wire [31:0] perf_icache_hits;
    wire [31:0] perf_icache_misses;
    wire [31:0] perf_dcache_hits;
    wire [31:0] perf_dcache_misses;
    wire [31:0] perf_l2cache_hits;
    wire [31:0] perf_l2cache_misses;

    // ==================== 模块实例化 ====================

    // RISC-V CPU核心
    riscv_cpu cpu_core (
        .clk(clk),
        .rst_n(rst_n),

        // 指令存储器接口
        .imem_addr(cpu_imem_addr),
        .imem_data(cpu_imem_data),
        .imem_req(cpu_imem_req),
        .imem_ack(cpu_imem_ack),

        // 数据存储器接口
        .dmem_addr(cpu_dmem_addr),
        .dmem_data_out(cpu_dmem_data_out),
        .dmem_data_in(cpu_dmem_data_in),
        .dmem_we(cpu_dmem_we),
        .dmem_sel(cpu_dmem_sel),
        .dmem_req(cpu_dmem_req),
        .dmem_ack(cpu_dmem_ack),

        // 中断输入
        .ext_interrupt(ext_int),
        .timer_interrupt(timer_int),
        .soft_interrupt(soft_int),

        // 调试输出
        .debug_pc(cpu_debug_pc),
        .debug_instruction(cpu_debug_instruction),
        // .debug_registers(cpu_debug_registers),
        .debug_state(cpu_debug_state)
    );

    // 缓存系统
    cache_system cache_sys (
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

        // 性能统计
        .perf_icache_hits(perf_icache_hits),
        .perf_icache_misses(perf_icache_misses),
        .perf_dcache_hits(perf_dcache_hits),
        .perf_dcache_misses(perf_dcache_misses),
        .perf_l2cache_hits(perf_l2cache_hits),
        .perf_l2cache_misses(perf_l2cache_misses)
    );

    // 存储器系统
    memory_system mem_system (
        .clk(clk),
        .rst_n(rst_n),

        // CPU接口
        .imem_addr(cpu_imem_addr),
        .imem_data(cpu_imem_data),
        .imem_req(cpu_imem_req),
        .imem_ack(cpu_imem_ack),

        .dmem_addr(cpu_dmem_addr),
        .dmem_data_out(cpu_dmem_data_out),
        .dmem_data_in(cpu_dmem_data_in),
        .dmem_we(cpu_dmem_we),
        .dmem_sel(cpu_dmem_sel),
        .dmem_req(cpu_dmem_req),
        .dmem_ack(cpu_dmem_ack),

/*
        // TODO
        // 内部存储器接口（连接到具体存储器）
        .ram_addr(ram_addr),
        .ram_data_out(ram_data_out),
        .ram_data_in(ram_data_in),
        .ram_we(ram_we),
        .ram_sel(ram_sel),
        .ram_req(ram_req),
        .ram_ack(ram_ack),

        .rom_addr(rom_addr),
        .rom_data(rom_data),
        .rom_req(rom_req),
        .rom_ack(rom_ack),

        .flash_addr(flash_addr),
        .flash_data(flash_data),
        .flash_req(flash_req),
        .flash_ack(flash_ack),
        .flash_we(flash_we),
        .flash_data_out(flash_data_out),
*/

        // 状态输出
        .mem_state(debug_state[2:0])
    );

    // RAM模块（64KB）
    ram #(
        .SIZE(65536)
    ) system_ram (
        .clk(clk),
        .rst_n(rst_n),
        .addr(ram_addr),
        .data_in(ram_data_out),
        .data_out(ram_data_in),
        .we(ram_we),
        .sel(ram_sel),
        .req(ram_req),
        .ack(ram_ack)
    );

    // ROM模块（1MB - 存放启动代码）
    rom #(
        .SIZE(1048576)
    ) system_rom (
        .clk(clk),
        .rst_n(rst_n),
        .addr(rom_addr),
        .data_out(rom_data),
        .req(rom_req),
        .ack(rom_ack)
    );

    // Flash模块（16MB - 存放应用程序）
    flash #(
        .SIZE(16777216)
    ) system_flash (
        .clk(clk),
        .rst_n(rst_n),
        .addr(flash_addr),
        .data_in(flash_data_out),
        .data_out(flash_data),
        .we(flash_we),
        .req(flash_req),
        .ack(flash_ack)
    );

    // 定时器模块（CSR接口）
    csr_timer system_timer (
        .clk(clk),
        .rst_n(rst_n),

        // CSR接口
        .csr_addr_i(timer_csr_addr),
        .csr_data_i(timer_csr_data_in),
        .csr_we_i(timer_csr_we),
        .csr_op_i(timer_csr_op),
        .csr_data_o(timer_csr_data_out),
        .csr_ack_o(timer_csr_ack),

        // 中断输出
        .timer_int_o(interrupt_controller_timer_int)
    );

    // 中断控制器（集成在CPU内部，这里简化连接）
    // 注意：实际中断控制器在CPU的exception_handler模块中

    // ==================== 中断连接逻辑 ====================

    // 定时器中断连接
    assign timer_int = interrupt_controller_timer_int;

    // 软件中断暂时设为0（可通过CSR触发）
    assign soft_int = 1'b0;

    // ==================== CSR接口连接（简化） ====================

    // 定时器CSR接口连接到CPU的CSR总线（简化实现）
    // 在实际系统中，这些信号应该来自CPU的CSR解码逻辑
    assign timer_csr_addr = 12'h0;
    assign timer_csr_data_in = 32'h0;
    assign timer_csr_we = 1'b0;
    assign timer_csr_op = 3'b0;

    // ==================== 调试接口连接 ====================

    assign debug_pc = cpu_debug_pc;
    assign debug_instruction = cpu_debug_instruction;
    assign debug_state = {2'b00, cpu_debug_state[2:0]};

    // 寄存器文件调试输出
    // genvar i;
    // generate
    //     for (i = 0; i < 32; i = i + 1) begin : reg_debug
    //         assign debug_registers[i] = cpu_debug_registers[i];
    //     end
    // endgenerate

    // ==================== 外部存储器接口（可选） ====================

    // 如果需要扩展外部存储器，可以在这里添加多路选择逻辑
    assign ext_mem_addr = 32'h0;
    assign ext_mem_data_out = 32'h0;
    assign ext_mem_we = 1'b0;
    assign ext_mem_re = 1'b0;

endmodule
