// riscv64_multicore.v
`include "l2_cache_params.v"

module riscv64_multicore #(
    parameter NUM_CORES = 4,
    parameter CORE_ID_WIDTH = 2
) (
    input wire clk,
    input wire rst_n,

    // 内存接口
    output wire mem_req,
    output wire [63:0] mem_addr,
    output wire [511:0] mem_wdata,
    input wire [511:0] mem_rdata,
    output wire mem_we,
    input wire mem_ready,

    // 核间中断
    input wire [NUM_CORES-1:0] ipi_interrupt,

    // 调试接口
    output wire [NUM_CORES-1:0] core_halted
);

    // L1缓存接口信号
    wire [NUM_CORES-1:0] l1_icache_req;
    wire [NUM_CORES*64-1:0] l1_icache_addr;
    wire [NUM_CORES*512-1:0] l1_icache_data;
    wire [NUM_CORES-1:0] l1_icache_ready;

    wire [NUM_CORES-1:0] l1_dcache_req;
    wire [NUM_CORES*64-1:0] l1_dcache_addr;
    wire [NUM_CORES*512-1:0] l1_dcache_wdata;
    wire [NUM_CORES*512-1:0] l1_dcache_data;
    wire [NUM_CORES-1:0] l1_dcache_we;
    wire [NUM_CORES*2-1:0] l1_dcache_req_type;
    wire [NUM_CORES-1:0] l1_dcache_ready;

    // 监听接口信号
    wire [NUM_CORES-1:0] snoop_valid;
    wire [NUM_CORES*64-1:0] snoop_addr;
    wire [NUM_CORES*2-1:0] snoop_req_type;
    wire [NUM_CORES-1:0] snoop_ready;
    wire [NUM_CORES-1:0] snoop_hit;
    wire [NUM_CORES*2-1:0] snoop_state;
    wire [NUM_CORES*512-1:0] snoop_data;

    // 共享L2缓存实例
    shared_l2_cache #(
        .NUM_CORES(NUM_CORES),
        .CORE_ID_WIDTH(CORE_ID_WIDTH)
    ) u_l2_cache (
        .clk(clk),
        .rst_n(rst_n),

        // L1指令缓存接口
        .l1_icache_req(l1_icache_req),
        .l1_icache_addr(l1_icache_addr),
        .l1_icache_data(l1_icache_data),
        .l1_icache_ready(l1_icache_ready),

        // L1数据缓存接口
        .l1_dcache_req(l1_dcache_req),
        .l1_dcache_addr(l1_dcache_addr),
        .l1_dcache_wdata(l1_dcache_wdata),
        .l1_dcache_data(l1_dcache_data),
        .l1_dcache_we(l1_dcache_we),
        .l1_dcache_req_type(l1_dcache_req_type),
        .l1_dcache_ready(l1_dcache_ready),

        // 内存接口
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(mem_we),
        .mem_ready(mem_ready),

        // 监听接口
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_req_type(snoop_req_type),
        .snoop_ready(snoop_ready),
        .snoop_hit(snoop_hit),
        .snoop_state(snoop_state),
        .snoop_data(snoop_data)
    );

    // 生成多个带L1缓存的CPU核
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : core_gen
            riscv64_core #(
                .CORE_ID(i[CORE_ID_WIDTH-1:0])
            ) u_core (
                .clk(clk),
                .rst_n(rst_n),

                /* TODO */
                // // L2指令缓存接口
                // .l2_icache_req(l1_icache_req[i]),
                // .l2_icache_addr(l1_icache_addr[i*64 +: 64]),
                // .l2_icache_data(l1_icache_data[i*512 +: 512]),
                // .l2_icache_ready(l1_icache_ready[i]),

                // // L2数据缓存接口
                // .l2_dcache_req(l1_dcache_req[i]),
                // .l2_dcache_addr(l1_dcache_addr[i*64 +: 64]),
                // .l2_dcache_wdata(l1_dcache_wdata[i*512 +: 512]),
                // .l2_dcache_data(l1_dcache_data[i*512 +: 512]),
                // .l2_dcache_we(l1_dcache_we[i]),
                // .l2_dcache_req_type(l1_dcache_req_type[i*2 +: 2]),
                // .l2_dcache_ready(l1_dcache_ready[i]),

                // 监听接口
                // .snoop_valid(snoop_valid[i]),
                // .snoop_addr(snoop_addr[i*64 +: 64]),
                // .snoop_req_type(snoop_req_type[i*2 +: 2]),
                // .snoop_ready(snoop_ready[i]),
                // .snoop_hit(snoop_hit[i]),
                // .snoop_state(snoop_state[i*2 +: 2]),
                // .snoop_data(snoop_data[i*512 +: 512]),

                // 中断和调试
                // .ipi_interrupt(ipi_interrupt[i]),
                .timer_interrupt(1'b0),
                .external_interrupt(1'b0)
                // .halted(core_halted[i])
            );
        end
    endgenerate

endmodule
