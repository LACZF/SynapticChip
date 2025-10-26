
`include "stddef.v"
`include "global_config.v"

`include "cpu.v"
`include "bus.v"
`include "rom.v"
`include "timer.v"
`include "uart.v"
`include "gpio.v"
`include "jtag_addr.v"
`include "spi_addr.v"
`include "spi.v"
`include "pe_addr.v"
`include "pe.v"

module chip (
    input  wire                         clk,
    input  wire                         clk_,
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
    wire                   m_rdy_;

    wire                   m0_req_;
    wire [`WordAddrBus]    m0_addr;
    wire                   m0_as_;
    wire                   m0_rw;
    wire [`WordDataBus]    m0_wr_data;
    wire                   m0_grnt_;

    wire                   m1_req_;
    wire [`WordAddrBus]    m1_addr;
    wire                   m1_as_;
    wire                   m1_rw;
    wire [`WordDataBus]    m1_wr_data;
    wire                   m1_grnt_;

    wire                   m2_req_;
    wire [`WordAddrBus]    m2_addr;
    wire                   m2_as_;
    wire                   m2_rw;
    wire [`WordDataBus]    m2_wr_data;
    wire                   m2_grnt_;

    wire                   m3_req_;
    wire [`WordAddrBus]    m3_addr;
    wire                   m3_as_;
    wire                   m3_rw;
    wire [`WordDataBus]    m3_wr_data;
    wire                   m3_grnt_;

    wire [`WordAddrBus]    s_addr;
    wire                   s_as_;
    wire                   s_rw;
    wire [`WordDataBus]    s_wr_data;

    wire [`WordDataBus]    s0_rd_data;
    wire                   s0_rdy_;
    wire                   s0_cs_;

    wire [`WordDataBus]    s1_rd_data;
    wire                   s1_rdy_;
    wire                   s1_cs_;

    wire [`WordDataBus]    s2_rd_data;
    wire                   s2_rdy_;
    wire                   s2_cs_;

    wire [`WordDataBus]    s3_rd_data;
    wire                   s3_rdy_;
    wire                   s3_cs_;

    wire [`WordDataBus]    s4_rd_data;
    wire                   s4_rdy_;
    wire                   s4_cs_;

    wire [`WordDataBus]    s5_rd_data;
    wire                   s5_rdy_;
    wire                   s5_cs_;

    wire [`WordDataBus]    s6_rd_data;
    wire                   s6_rdy_;
    wire                   s6_cs_;

    wire [`WordDataBus]    s7_rd_data;
    wire                   s7_rdy_;
    wire                   s7_cs_;

    wire                   irq_timer;
    wire                   irq_uart_rx;
    wire                   irq_uart_tx;
    wire [`CPU_IRQ_CH-1:0] cpu_irq;

    assign cpu_irq = {{`CPU_IRQ_CH-3{`LOW}}, irq_uart_rx, irq_uart_tx, irq_timer};

    /********** CPU **********/
    cpu u_cpu (
        .clk                   (clk),
        .clk_n                 (clk_),
        .reset                 (reset),

        // IF Stage
        .if_bus_rd_data_i      (m_rd_data),
        .if_bus_rdy_n_i        (m_rdy_),
        .if_bus_grnt_n_i       (m0_grnt_),
        .if_bus_req_n_o        (m0_req_),
        .if_bus_addr_o         (m0_addr),
        .if_bus_as_n_o         (m0_as_),
        .if_bus_rw_o           (m0_rw),
        .if_bus_wr_data_o      (m0_wr_data),
        // MEM Stage
        .mem_bus_rd_data_i     (m_rd_data),
        .mem_bus_rdy_n_i       (m_rdy_),
        .mem_bus_grnt_n_i      (m1_grnt_),
        .mem_bus_req_n_o       (m1_req_),
        .mem_bus_addr_o        (m1_addr),
        .mem_bus_as_n_o        (m1_as_),
        .mem_bus_rw_o          (m1_rw),
        .mem_bus_wr_data_o     (m1_wr_data),

        .cpu_irq_i             (cpu_irq)
    );

    /* 暂未使用 */
    assign m2_addr      = `WORD_ADDR_W'h0;
    assign m2_as_       = `DISABLE_N;
    assign m2_rw        = `READ;
    assign m2_wr_data   = `WORD_DATA_W'h0;
    assign m2_req_      = `DISABLE_N;

    /* 暂未使用 */
    assign m3_addr      = `WORD_ADDR_W'h0;
    assign m3_as_       = `DISABLE_N;
    assign m3_rw        = `READ;
    assign m3_wr_data   = `WORD_DATA_W'h0;
    assign m3_req_      = `DISABLE_N;

    /********** ROM **********/
    rom u_rom (
        .clk           (clk),
        .reset         (reset),

        .cs_n_i        (s0_cs_),
        .as_n_i        (s_as_),
        .addr_i        (s_addr[`RomAddrLoc]),
        .rd_data_o     (s0_rd_data),
        .rdy_n_o       (s0_rdy_)
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

        .cs_(s1_cs_),
        .as_(s_as_),
        .rw(s_rw),
        .addr(s_addr),
        .wr_data(s_wr_data),
        .rd_data(s1_rd_data),
        .rdy_(s1_rdy_)
    );
`else
    /* 暂未使用 */
    assign s1_rd_data   = `WORD_DATA_W'h0;
    assign s1_rdy_      = `DISABLE_N;
`endif

`ifdef IMPLEMENT_TIMER
    /********** TIMER **********/
    timer u_timer (
        .clk             (clk),
        .reset           (reset),

        .cs_n_i          (s2_cs_),
        .as_n_i          (s_as_),
        .rw_i            (s_rw),
        .addr_i          (s_addr[`TimerAddrLoc]),
        .wr_data_i       (s_wr_data),
        .rd_data_o       (s2_rd_data),
        .rdy_n_o         (s2_rdy_),

        .irq_o           (irq_timer)
     );
`else
    assign s2_rd_data = `WORD_DATA_W'h0;
    assign s2_rdy_    = `DISABLE_N;
    assign irq_timer  = `DISABLE;
`endif

`ifdef IMPLEMENT_UART
    /********** UART **********/
    uart u_uart (
        .clk               (clk),
        .reset             (reset),

        .cs_n_i            (s3_cs_),
        .as_n_i            (s_as_),
        .rw_i              (s_rw),
        .addr_i            (s_addr[`UartAddrLoc]),
        .wr_data_i         (s_wr_data),
        .rd_data_o         (s3_rd_data),
        .rdy_n_o           (s3_rdy_),

        .irq_rx_o          (irq_uart_rx),
        .irq_tx_o          (irq_uart_tx),

        .rx_i              (uart_rx),
        .tx_o              (uart_tx)
    );
`else
    assign s3_rd_data  = `WORD_DATA_W'h0;
    assign s3_rdy_       = `DISABLE_N;
    assign irq_uart_rx = `DISABLE;
    assign irq_uart_tx = `DISABLE;
`endif

`ifdef IMPLEMENT_GPIO
    /********** GPIO **********/
    gpio u_gpio (
        .clk             (clk),
        .reset           (reset),

        .cs_n_i          (s4_cs_),
        .as_n_i          (s_as_),
        .rw_i            (s_rw),
        .addr_i          (s_addr[`GpioAddrLoc]),
        .wr_data_i       (s_wr_data),
        .rd_data_i       (s4_rd_data),
        .rdy_n_o         (s4_rdy_)

`ifdef GPIO_IN_CH
        , .gpio_in       (gpio_in)
`endif
`ifdef GPIO_OUT_CH
        , .gpio_out      (gpio_out)
`endif
`ifdef GPIO_IO_CH
        , .gpio_io       (gpio_io)
`endif
    );
`else
    assign s4_rd_data   = `WORD_DATA_W'h0;
    assign s4_rdy_      = `DISABLE_N;
`endif

`ifdef IMPLEMENT_SPI
    /********** SPI **********/
    spi #(
        .DATA_WIDTH    (32),
        .ADDR_WIDTH    (32),
        .CS_NUM        (1)
    ) u_spi (
        .clk           (clk),
        .rst_n         (reset == `RESET_DISABLE ? 1'b1 : 1'b0),

        .req_i         (s5_cs_),
        .we_i          (s_rw),
        .addr_i        ({{(32-`WORD_ADDR_W){1'b0}}, s_addr}),
        .data_in_i     (s_wr_data),
        .data_out_o    (s5_rd_data),
        .ack_o         (s5_rdy_),

        .spi_cs_n_o    (spi_cs_n),
        .spi_clk_o     (spi_clk),
        .spi_mosi_o    (spi_mosi),
        .spi_miso_i    (spi_miso)
    );
`else
    /* 暂未使用 */
    assign s5_rd_data   = `WORD_DATA_W'h0;
    assign s5_rdy_      = `DISABLE_N;
    assign spi_cs_n     = 1'b1;
    assign spi_clk      = 1'b0;
    assign spi_mosi     = 1'b0;
`endif

    /* 暂未使用 */
    assign s6_rd_data   = `WORD_DATA_W'h0;
    assign s6_rdy_      = `DISABLE_N;

`ifdef IMPLEMENT_JTAG
    /********** JTAG **********/
    jtag #(
        .ADDR_WIDTH    (64),
        .DATA_WIDTH    (32),
        .INST_WIDTH    (4)
    ) u_jtag (
        .clk             (clk),
        .rst_n           (reset == `RESET_DISABLE ? 1'b1 : 1'b0),

        .tck_i           (tck),
        .tms_i           (tms),
        .tdi_i           (tdi),
        .tdo_o           (tdo),
        .tdo_en_o        (tdo_en),

        .req_i           (s7_cs_),
        .we_i            (s_rw),
        .addr_i          ({{(64-`WORD_ADDR_W){1'b0}}, s_addr}),
        .data_in_i       (s_wr_data),
        .data_out_o      (s7_rd_data[`WORD_DATA_W-1:0]),
        .ack_o           (s7_rdy_),

        .debug_data_o    (),
        .debug_valid_o   ()
    );
`else
    assign s7_rd_data    = `WORD_DATA_W'h0;
    assign s7_rdy_       = `DISABLE_N;
    assign tdo           = `LOW;
    assign tdo_en        = `LOW;
`endif

    /********** BUS **********/
    bus u_bus (
        .clk               (clk),
        .reset             (reset),

        .m_rd_data_o       (m_rd_data),
        .m_rdy_n_o         (m_rdy_),

        .m0_req_n_i         (m0_req_),
        .m0_addr_i          (m0_addr),
        .m0_as_n_i          (m0_as_),
        .m0_rw_i            (m0_rw),
        .m0_wr_data_i       (m0_wr_data),
        .m0_grnt_n_o        (m0_grnt_),

        .m1_req_n_i         (m1_req_),
        .m1_addr_i          (m1_addr),
        .m1_as_n_i          (m1_as_),
        .m1_rw_i            (m1_rw),
        .m1_wr_data_i       (m1_wr_data),
        .m1_grnt_n_o        (m1_grnt_),

        .m2_req_n_i         (m2_req_),
        .m2_addr_i          (m2_addr),
        .m2_as_n_i          (m2_as_),
        .m2_rw_i            (m2_rw),
        .m2_wr_data_i       (m2_wr_data),
        .m2_grnt_n_o        (m2_grnt_),

        .m3_req_n_i         (m3_req_),
        .m3_addr_i          (m3_addr),
        .m3_as_n_i          (m3_as_),
        .m3_rw_i            (m3_rw),
        .m3_wr_data_i       (m3_wr_data),
        .m3_grnt_n_o        (m3_grnt_),

        .s_addr_o           (s_addr),
        .s_as_n_o           (s_as_),
        .s_rw_o             (s_rw),
        .s_wr_data_o        (s_wr_data),

        .s0_rd_data_i       (s0_rd_data),
        .s0_rdy_n_i         (s0_rdy_),
        .s0_cs_n_o          (s0_cs_),

        .s1_rd_data_i       (s1_rd_data),
        .s1_rdy_n_i         (s1_rdy_),
        .s1_cs_n_o          (s1_cs_),

        .s2_rd_data_i       (s2_rd_data),
        .s2_rdy_n_i         (s2_rdy_),
        .s2_cs_n_o          (s2_cs_),

        .s3_rd_data_i       (s3_rd_data),
        .s3_rdy_n_i         (s3_rdy_),
        .s3_cs_n_o          (s3_cs_),

        .s4_rd_data_i       (s4_rd_data),
        .s4_rdy_n_i         (s4_rdy_),
        .s4_cs_n_o          (s4_cs_),

        .s5_rd_data_i       (s5_rd_data),
        .s5_rdy_n_i         (s5_rdy_),
        .s5_cs_n_o          (s5_cs_),

        .s6_rd_data_i       (s6_rd_data),
        .s6_rdy_n_i         (s6_rdy_),
        .s6_cs_n_o          (s6_cs_),

        .s7_rd_data_i       (s7_rd_data),
        .s7_rdy_n_i         (s7_rdy_),
        .s7_cs_n_o          (s7_cs_)
    );

endmodule