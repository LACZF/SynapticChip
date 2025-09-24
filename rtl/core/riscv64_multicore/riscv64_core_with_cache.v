// riscv64_core_with_cache.v
`include "cache_params.v"

module riscv64_core_with_cache #(
    parameter CORE_ID = 0
) (
    input wire clk,
    input wire rst_n,

    // L2缓存接口
    output wire l2_icache_req,
    output wire [63:0] l2_icache_addr,
    input wire [511:0] l2_icache_data,
    input wire l2_icache_ready,

    output wire l2_dcache_req,
    output wire [63:0] l2_dcache_addr,
    output wire [511:0] l2_dcache_wdata,
    input wire [511:0] l2_dcache_data,
    output wire l2_dcache_we,
    input wire l2_dcache_ready,

    // 核间一致性接口
    output wire snoop_valid,
    output wire [63:0] snoop_addr,
    output wire snoop_we,
    input wire snoop_hit,
    input wire [511:0] snoop_data,

    // 中断和调试
    input wire ipi_interrupt,
    input wire timer_interrupt,
    input wire external_interrupt,
    output wire halted
);

    // CPU内部信号
    wire [63:0] if_pc;
    wire [31:0] if_instr;
    wire if_req;
    wire if_ready;

    wire [63:0] mem_addr;
    wire [63:0] mem_wdata;
    wire [63:0] mem_rdata;
    wire mem_req;
    wire mem_we;
    wire [7:0] mem_byte_en;
    wire mem_ready;

    // 指令缓存实例
    l1_icache u_icache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(if_pc),
        .cpu_req(if_req),
        .cpu_data(if_instr),
        .cpu_ready(if_ready),
        .cache_hit(),
        .l2_req(l2_icache_req),
        .l2_addr(l2_icache_addr),
        .l2_data(l2_icache_data),
        .l2_ready(l2_icache_ready),
        .l2_read(),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_hit()
    );

    // 数据缓存实例
    l1_dcache u_dcache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(mem_addr),
        .cpu_wdata(mem_wdata),
        .cpu_req(mem_req),
        .cpu_we(mem_we),
        .cpu_byte_en(mem_byte_en),
        .cpu_rdata(mem_rdata),
        .cpu_ready(mem_ready),
        .cache_hit(),
        .l2_req(l2_dcache_req),
        .l2_addr(l2_dcache_addr),
        .l2_wdata(l2_dcache_wdata),
        .l2_rdata(l2_dcache_data),
        .l2_we(l2_dcache_we),
        .l2_ready(l2_dcache_ready),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_we(snoop_we),
        .snoop_hit(snoop_hit),
        .snoop_data(snoop_data)
    );

    // 修改后的取指阶段
    instruction_fetch_with_cache u_if (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_if),
        .flush(flush_if),
        .branch_target(branch_target),
        .branch_taken(branch_taken),
        .pc(if_pc),
        .instr(if_instr),
        .cache_req(if_req),
        .cache_ready(if_ready)
    );

    // 修改后的内存访问阶段
    memory_access_with_cache u_mem (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_mem),
        .flush(flush_mem),
        .pc_in(pc_ex),
        .instr_in(instr_ex),
        .alu_result(alu_result),
        .rs2_data(rs2_data),
        .ctrl_in(ctrl_ex),
        .cache_addr(mem_addr),
        .cache_wdata(mem_wdata),
        .cache_rdata(mem_rdata),
        .cache_req(mem_req),
        .cache_we(mem_we),
        .cache_byte_en(mem_byte_en),
        .cache_ready(mem_ready),
        .pc_out(pc_mem),
        .instr_out(instr_mem),
        .mem_result(mem_result),
        .ctrl_out(ctrl_mem)
    );

    // 其他阶段保持不变（ID, EX, WB）
    instruction_decode u_id (
        // ... 保持不变
    );

    execution u_ex (
        // ... 保持不变
    );

    write_back u_wb (
        // ... 保持不变
    );

    register_file u_regfile (
        // ... 保持不变
    );

    hazard_detection u_hazard (
        // ... 保持不变
    );

endmodule
