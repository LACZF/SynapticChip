
`include "stddef.v"
`include "global_config.v"

module chip_top #(
    parameter MASTER_NUM                = 4,
    parameter SLAVE_NUM                 = 8,
    parameter IMPLEMENT_ROM             = 1,
    parameter IMPLEMENT_JTAG            = 0,
    parameter IMPLEMENT_UART            = 1,
    parameter IMPLEMENT_GPIO            = 1,
    parameter IMPLEMENT_SPI             = 0,
    parameter IMPLEMENT_TIMER           = 1,
    parameter GPIO_IN_CH                = 1,
    parameter GPIO_OUT_CH               = 1,
    parameter GPIO_IO_CH                = 1
) (
    input  wire                         clk,
    input  wire                         reset,

    /********** JTAG  **********/
    input  wire                         tck,
    input  wire                         tms,
    input  wire                         tdi,
    output wire                         tdo,
    output wire                         tdo_en,

    /********** UART  **********/
    input  wire                         uart_rx,
    output wire                         uart_tx,

    /********** GPIO  **********/
    input  wire [GPIO_IN_CH-1:0]        gpio_in,      // 输入端口
    output wire [GPIO_OUT_CH-1:0]       gpio_out,     // 输出端口
    inout  wire [GPIO_IO_CH-1:0]        gpio_io,      // 输入输出端口

    /********** SPI **********/
    output wire                         spi_cs_n,
    output wire                         spi_clk,
    output wire                         spi_mosi,
    input  wire                         spi_miso
);

    wire [`WordDataBus]                 m_rd_data;
    wire                                m_rdy_n;

    /********** 总线信号数组 **********/
    wire [MASTER_NUM-1:0]               m_req_n;
    wire [MASTER_NUM-1:0][`WordAddrBus] m_addr;
    wire [MASTER_NUM-1:0]               m_as_n;
    wire [MASTER_NUM-1:0]               m_rw;
    wire [MASTER_NUM-1:0][`WordDataBus] m_wr_data;
    wire [MASTER_NUM-1:0]               m_grnt_n;

    wire [SLAVE_NUM-1:0][`WordDataBus]  s_rd_data;
    wire [SLAVE_NUM-1:0]                s_rdy_n;
    wire [SLAVE_NUM-1:0]                s_cs_n;

    wire [`WordAddrBus]                 s_addr;
    wire                                s_as_n;
    wire                                s_rw;
    wire [`WordDataBus]                 s_wr_data;

    wire                                irq_timer;
    wire                                irq_uart_rx;
    wire                                irq_uart_tx;
    wire [`CPU_IRQ_CH-1:0]              cpu_irq;

    assign cpu_irq = {{`CPU_IRQ_CH-3{`LOW}}, irq_uart_rx, irq_uart_tx, irq_timer};

    /********** CPU **********/
    cpu_top u_cpu (
        .clk                   (clk),
        .reset                 (reset),

        // IF Stage
        .if_bus_rd_data_i      (m_rd_data),
        .if_bus_rdy_n_i        (m_rdy_n),
        .if_bus_grnt_n_i       (m_grnt_n[0]),
        .if_bus_req_n_o        (m_req_n[0]),
        .if_bus_addr_o         (m_addr[0]),
        .if_bus_as_n_o         (m_as_n[0]),
        .if_bus_rw_o           (m_rw[0]),
        .if_bus_wr_data_o      (m_wr_data[0]),
        // MEM Stage
        .mem_bus_rd_data_i     (m_rd_data),
        .mem_bus_rdy_n_i       (m_rdy_n),
        .mem_bus_grnt_n_i      (m_grnt_n[1]),
        .mem_bus_req_n_o       (m_req_n[1]),
        .mem_bus_addr_o        (m_addr[1]),
        .mem_bus_as_n_o        (m_as_n[1]),
        .mem_bus_rw_o          (m_rw[1]),
        .mem_bus_wr_data_o     (m_wr_data[1]),

        .cpu_irq_i             (cpu_irq)
    );

    /********** IO模块 **********/
    io_top #(
        .MASTER_NUM             (MASTER_NUM),
        .SLAVE_NUM              (SLAVE_NUM),
        .IMPLEMENT_ROM          (IMPLEMENT_ROM),
        .IMPLEMENT_JTAG         (IMPLEMENT_JTAG),
        .IMPLEMENT_UART         (IMPLEMENT_UART),
        .IMPLEMENT_GPIO         (IMPLEMENT_GPIO),
        .IMPLEMENT_SPI          (IMPLEMENT_SPI),
        .IMPLEMENT_TIMER        (IMPLEMENT_TIMER),
        .GPIO_IN_CH             (GPIO_IN_CH),
        .GPIO_OUT_CH            (GPIO_OUT_CH),
        .GPIO_IO_CH             (GPIO_IO_CH)
    ) u_io (
        .clk           (clk),
        .reset         (reset),

        // 总线接口
        .s_cs_n        (s_cs_n),
        .s_as_n        (s_as_n),
        .s_rw          (s_rw),
        .s_addr        (s_addr),
        .s_wr_data     (s_wr_data),
        .s_rd_data     (s_rd_data),
        .s_rdy_n       (s_rdy_n),

        // 中断信号
        .irq_timer     (irq_timer),
        .irq_uart_rx   (irq_uart_rx),
        .irq_uart_tx   (irq_uart_tx),

        // JTAG接口
        .tck           (tck),
        .tms           (tms),
        .tdi           (tdi),
        .tdo           (tdo),
        .tdo_en        (tdo_en),

        // UART接口
        .uart_rx       (uart_rx),
        .uart_tx       (uart_tx),

        // GPIO接口
        .gpio_in       (gpio_in),      // 输入端口
        .gpio_out      (gpio_out),     // 输出端口
        .gpio_io       (gpio_io),      // 输入输出端口

        // SPI接口
        .spi_cs_n      (spi_cs_n),
        .spi_clk       (spi_clk),
        .spi_mosi      (spi_mosi),
        .spi_miso      (spi_miso)
    );

    /********** Integrated PE Module **********/
    pe_top #(
        .ADDR_WIDTH(`WORD_ADDR_W),
        .DATA_WIDTH(`WORD_DATA_W),
        .NUM_PES(4),
        .INST_WIDTH(32),
        .PE_ID_WIDTH(4),
        .NUM_RINGS(2),
        .PE_ARRAY_ROWS(2),
        .PE_ARRAY_COLS(2)
    ) u_pe (
        .clk(clk),
        .reset(reset),

        .cs_n_i(s_cs_n[6]),
        .as_n_i(s_as_n),
        .rw_i(s_rw),
        .addr_i(s_addr),
        .wr_data_i(s_wr_data),
        .rd_data_o(s_rd_data[6]),
        .rdy_n_o(s_rdy_n[6])
    );

    /********** BUS **********/
    bus_top #(
        .MASTER_NUM        (MASTER_NUM),
        .SLAVE_NUM         (SLAVE_NUM)
    ) u_bus (
        .clk               (clk),
        .reset             (reset),

        .m_rd_data_o       (m_rd_data),
        .m_rdy_n_o         (m_rdy_n),

        .m_req_n_i         (m_req_n),
        .m_addr_i          (m_addr),
        .m_as_n_i          (m_as_n),
        .m_rw_i            (m_rw),
        .m_wr_data_i       (m_wr_data),
        .m_grnt_n_o        (m_grnt_n),
        .s_addr_o          (s_addr),
        .s_as_n_o          (s_as_n),
        .s_rw_o            (s_rw),
        .s_wr_data_o       (s_wr_data),
        .s_rd_data_i       (s_rd_data),
        .s_rdy_n_i         (s_rdy_n),
        .s_cs_n_o          (s_cs_n)
    );

endmodule