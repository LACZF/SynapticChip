
`include "stddef.v"
`include "global_config.v"

`include "cpu.v"
`include "bus.v"
`include "pe_addr.v"
`include "pe.v"

module chip_top #(
    parameter MASTER_NUM = `BUS_MASTER_CH,
    parameter SLAVE_NUM  = `BUS_SLAVE_CH
) (
    input  wire                         clk,
    input  wire                         reset

`ifdef IMPLEMENT_JTAG
    /********** JTAG  **********/
    , input  wire                       tck
    , input  wire                       tms
    , input  wire                       tdi
    , output wire                       tdo
    , output wire                       tdo_en
`endif

`ifdef IMPLEMENT_UART
    /********** UART  **********/
    , input     wire                    uart_rx
    , output wire                       uart_tx
`endif

`ifdef IMPLEMENT_GPIO // GPIO实现
    /********** GPIO  **********/
`ifdef GPIO_IN_CH     // 输入端口的实现
    , input wire [`GPIO_IN_CH-1:0]      gpio_in      // 输入端口
`endif
`ifdef GPIO_OUT_CH     // 输出端口实现
    , output wire [`GPIO_OUT_CH-1:0]    gpio_out     // 输出端口
`endif
`ifdef GPIO_IO_CH     // 输入/输出端口的实现
    , inout wire [`GPIO_IO_CH-1:0]      gpio_io      // 输入输出端口
`endif
`endif

`ifdef IMPLEMENT_SPI
    /********** SPI **********/
    , output wire                       spi_cs_n
    , output wire                       spi_clk
    , output wire                       spi_mosi
    , input  wire                       spi_miso
`endif
);

    wire [`WordDataBus]    m_rd_data;
    wire                   m_rdy_n;

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

    wire [`WordAddrBus]    s_addr;
    wire                   s_as_n;
    wire                   s_rw;
    wire [`WordDataBus]    s_wr_data;

    wire                   irq_timer;
    wire                   irq_uart_rx;
    wire                   irq_uart_tx;
    wire [`CPU_IRQ_CH-1:0] cpu_irq;

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
        .MASTER_NUM    (MASTER_NUM),
        .SLAVE_NUM     (SLAVE_NUM)
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
        .irq_uart_tx   (irq_uart_tx)

`ifdef IMPLEMENT_JTAG
        // JTAG接口
        , .tck          (tck)
        , .tms          (tms)
        , .tdi          (tdi)
        , .tdo          (tdo)
        , .tdo_en       (tdo_en)
`endif

`ifdef IMPLEMENT_UART
        // UART接口
        , .uart_rx      (uart_rx)
        , .uart_tx      (uart_tx)
`endif

`ifdef IMPLEMENT_GPIO
        // GPIO接口
`ifdef GPIO_IN_CH     // 输入端口的实现
        , .gpio_in      (gpio_in)      // 输入端口
`endif
`ifdef GPIO_OUT_CH     // 输出端口实现
        , .gpio_out     (gpio_out)     // 输出端口
`endif
`ifdef GPIO_IO_CH     // 输入/输出端口的实现
        , .gpio_io      (gpio_io)      // 输入输出端口
`endif
`endif

`ifdef IMPLEMENT_SPI
        // SPI接口
        , .spi_cs_n     (spi_cs_n)
        , .spi_clk      (spi_clk)
        , .spi_mosi     (spi_mosi)
        , .spi_miso     (spi_miso)
`endif
    );

`ifdef IMPLEMENT_PE
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
`else
    /* 暂未使用 */
    assign s_rd_data[6]    = `WORD_DATA_W'h0;
    assign s_rdy_n[6]      = `DISABLE_N;
`endif

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