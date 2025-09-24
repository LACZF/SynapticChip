// riscv64_multicore.v
module riscv64_multicore #(
    parameter NUM_CORES = 2,
    parameter CORE_ID_WIDTH = 4
) (
    input wire clk,
    input wire rst_n,

    // 内存接口
    output wire [63:0] mem_addr,
    output wire [63:0] mem_wdata,
    input wire [63:0] mem_rdata,
    output wire mem_we,
    output wire [7:0] mem_byte_en,
    output wire mem_req,
    input wire mem_ready,

    // 核间中断
    input wire [NUM_CORES-1:0] ipi_interrupt,

    // 调试接口
    output wire [NUM_CORES-1:0] core_halted
);

    // 核间连接信号
    wire [NUM_CORES-1:0] bus_req;
    wire [NUM_CORES*64-1:0] bus_addr;
    wire [NUM_CORES*64-1:0] bus_wdata;
    wire [NUM_CORES-1:0] bus_we;
    wire [NUM_CORES*8-1:0] bus_byte_en;
    wire [NUM_CORES-1:0] bus_grant;

    // 内存仲裁器
    memory_arbiter #(
        .NUM_MASTERS(NUM_CORES),
        .ADDR_WIDTH(64),
        .DATA_WIDTH(64)
    ) u_arbiter (
        .clk(clk),
        .rst_n(rst_n),

        .master_req(bus_req),
        .master_addr(bus_addr),
        .master_wdata(bus_wdata),
        .master_we(bus_we),
        .master_byte_en(bus_byte_en),
        .master_grant(bus_grant),

        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(mem_we),
        .mem_byte_en(mem_byte_en),
        .mem_req(mem_req),
        .mem_ready(mem_ready)
    );

    // 生成多个CPU核
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : core_gen
            riscv64_core #(
                .CORE_ID(i[CORE_ID_WIDTH-1:0])
            ) u_core (
                .clk(clk),
                .rst_n(rst_n),

                // 内存接口
                .mem_req(bus_req[i]),
                .mem_addr(bus_addr[i*64 +: 64]),
                .mem_wdata(bus_wdata[i*64 +: 64]),
                .mem_rdata(mem_rdata),
                .mem_we(bus_we[i]),
                .mem_byte_en(bus_byte_en[i*8 +: 8]),
                .mem_grant(bus_grant[i]),
                .mem_ready(mem_ready),

                // 中断
                .ipi_interrupt(ipi_interrupt[i]),
                .timer_interrupt(1'b0), // 可连接定时器
                .external_interrupt(1'b0), // 可连接外部中断

                // 调试
                .halted(core_halted[i])
            );
        end
    endgenerate

endmodule
