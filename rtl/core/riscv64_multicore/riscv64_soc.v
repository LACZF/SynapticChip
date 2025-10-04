// riscv64_soc.v
`include "soc_params.v"
`include "l2_cache_params.v"

module riscv64_soc (
    input wire clk,
    input wire rst_n,

    // Flash接口
    output wire [23:0] flash_addr,
    input wire [31:0] flash_data_in,
    output wire [31:0] flash_data_out,
    output wire flash_ce_n,
    output wire flash_oe_n,
    output wire flash_we_n,
    output wire flash_wp_n,
    input wire flash_ready,

    // UART接口
    output wire uart_txd,
    input wire uart_rxd,

    // GPIO接口
    input wire [15:0] gpio_in,
    output wire [15:0] gpio_out,

    // 系统控制
    input wire [3:0] dip_switch,
    output wire [3:0] led,
    output wire soc_ready
);

    // 时钟和复位
    wire soc_clk;
    wire soc_rst_n;

    // 系统总线
    wire [63:0] sys_addr;
    wire [63:0] sys_wdata;
    wire [63:0] sys_rdata;
    wire sys_we;
    wire [7:0] sys_byte_en;
    wire sys_req;
    wire sys_ready;
    wire [1:0] sys_req_type;
    wire [`CORE_ID_WIDTH-1:0] sys_master_id;

    // L2缓存接口
    wire l2_mem_req;
    wire [63:0] l2_mem_addr;
    wire [511:0] l2_mem_wdata;
    wire [511:0] l2_mem_rdata;
    wire l2_mem_we;
    wire l2_mem_ready;

    // Flash控制器接口
    wire flash_ctrl_req;
    wire [63:0] flash_ctrl_addr;
    wire [511:0] flash_ctrl_wdata;
    wire [511:0] flash_ctrl_rdata;
    wire flash_ctrl_we;
    wire flash_ctrl_ready;

    // SRAM控制器接口
    wire sram_ctrl_req;
    wire [63:0] sram_ctrl_addr;
    wire [511:0] sram_ctrl_wdata;
    wire [511:0] sram_ctrl_rdata;
    wire sram_ctrl_we;
    wire sram_ctrl_ready;

    // MMIO接口
    wire mmio_req;
    wire [63:0] mmio_addr;
    wire [63:0] mmio_wdata;
    wire [63:0] mmio_rdata;
    wire mmio_we;
    wire [7:0] mmio_byte_en;
    wire mmio_ready;

    // 中断信号
    wire [(`NUM_CORES*16)-1:0] core_irq;
    wire [`NUM_CORES-1:0] timer_irq;
    wire [`NUM_CORES-1:0] external_irq;
    wire [`NUM_CORES-1:0] software_irq;

    // 时钟和复位生成
    clock_reset_gen u_clk_rst_gen (
        .clk(clk),
        .rst_n(rst_n),
        .soc_clk(soc_clk),
        .soc_rst_n(soc_rst_n),
        .soc_ready(soc_ready)
    );

    // 多核CPU子系统
    riscv64_multicore #(
        .NUM_CORES(`NUM_CORES),
        .CORE_ID_WIDTH(`CORE_ID_WIDTH)
    ) u_multicore (
        .clk(soc_clk),
        .rst_n(soc_rst_n),

        // 系统内存接口
        .mem_req(l2_mem_req),
        .mem_addr(l2_mem_addr),
        .mem_wdata(l2_mem_wdata),
        .mem_rdata(l2_mem_rdata),
        .mem_we(l2_mem_we),
        .mem_ready(l2_mem_ready),

        // 中断接口
        .ipi_interrupt(software_irq),

        // 调试接口
        .core_halted()
    );

    // 系统总线仲裁器
    system_bus_arbiter #(
        .NUM_MASTERS(`NUM_CORES),
        .ADDR_WIDTH(64),
        .DATA_WIDTH(64)
    ) u_bus_arbiter (
        .clk(soc_clk),
        .rst_n(soc_rst_n),

        // CPU接口
        .cpu_req(l2_mem_req),
        .cpu_addr(l2_mem_addr),
        .cpu_wdata(l2_mem_wdata[63:0]), // 64位接口
        .cpu_rdata(l2_mem_rdata[63:0]),
        .cpu_we(l2_mem_we),
        .cpu_byte_en(8'hFF),
        .cpu_ready(l2_mem_ready),

        // 系统总线
        .sys_addr(sys_addr),
        .sys_wdata(sys_wdata),
        .sys_rdata(sys_rdata),
        .sys_we(sys_we),
        .sys_byte_en(sys_byte_en),
        .sys_req(sys_req),
        .sys_ready(sys_ready),
        .sys_master_id(sys_master_id)
    );

    // 地址解码器
    address_decoder u_addr_decoder (
        .clk(soc_clk),
        .rst_n(soc_rst_n),

        // 系统总线输入
        .sys_addr(sys_addr),
        .sys_wdata(sys_wdata),
        .sys_rdata(sys_rdata),
        .sys_we(sys_we),
        .sys_byte_en(sys_byte_en),
        .sys_req(sys_req),
        .sys_ready(sys_ready),

        // Flash控制器接口
        .flash_req(flash_ctrl_req),
        .flash_addr(flash_ctrl_addr),
        .flash_wdata(flash_ctrl_wdata[63:0]),
        .flash_rdata(flash_ctrl_rdata[63:0]),
        .flash_we(flash_ctrl_we),
        .flash_ready(flash_ctrl_ready),

        // SRAM控制器接口
        .sram_req(sram_ctrl_req),
        .sram_addr(sram_ctrl_addr),
        .sram_wdata(sram_ctrl_wdata[63:0]),
        .sram_rdata(sram_ctrl_rdata[63:0]),
        .sram_we(sram_ctrl_we),
        .sram_ready(sram_ctrl_ready),

        // MMIO接口
        .mmio_req(mmio_req),
        .mmio_addr(mmio_addr),
        .mmio_wdata(mmio_wdata),
        .mmio_rdata(mmio_rdata),
        .mmio_we(mmio_we),
        .mmio_byte_en(mmio_byte_en),
        .mmio_ready(mmio_ready)
    );

    // Flash控制器
    flash_controller u_flash_ctrl (
        .clk(soc_clk),
        .rst_n(soc_rst_n),

        // 系统接口
        .sys_req(flash_ctrl_req),
        .sys_addr(flash_ctrl_addr),
        .sys_wdata(flash_ctrl_wdata[63:0]),
        .sys_rdata(flash_ctrl_rdata[63:0]),
        .sys_we(flash_ctrl_we),
        .sys_ready(flash_ctrl_ready),

        // Flash物理接口
        .flash_addr(flash_addr),
        .flash_data_in(flash_data_in),
        .flash_data_out(flash_data_out),
        .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n),
        .flash_we_n(flash_we_n),
        .flash_wp_n(flash_wp_n),
        .flash_ready(flash_ready)
    );

    // MMIO子系统
    mmio_subsystem u_mmio (
        .clk(soc_clk),
        .rst_n(soc_rst_n),

        // 系统接口
        .sys_req(mmio_req),
        .sys_addr(mmio_addr),
        .sys_wdata(mmio_wdata),
        .sys_rdata(mmio_rdata),
        .sys_we(mmio_we),
        .sys_byte_en(mmio_byte_en),
        .sys_ready(mmio_ready),

        // 外设接口
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .dip_switch(dip_switch),
        .led(led),

        // 中断接口
        .core_irq(core_irq),
        .timer_irq(timer_irq),
        .external_irq(external_irq),
        .software_irq(software_irq)
    );

endmodule