
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
    cpu u_cpu (
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

    /* 暂未使用 */
    assign m2_addr       = `WORD_ADDR_W'h0;
    assign m2_as_n       = `DISABLE_N;
    assign m2_rw         = `READ;
    assign m2_wr_data    = `WORD_DATA_W'h0;
    assign m2_req_n      = `DISABLE_N;

    /* 暂未使用 */
    assign m3_addr       = `WORD_ADDR_W'h0;
    assign m3_as_n       = `DISABLE_N;
    assign m3_rw         = `READ;
    assign m3_wr_data    = `WORD_DATA_W'h0;
    assign m3_req_n      = `DISABLE_N;

    /********** ROM **********/
    rom u_rom (
        .clk           (clk),
        .reset         (reset),

        .cs_n_i        (s_cs_n[0]),
        .as_n_i        (s_as_n),
        .addr_i        (s_addr[`RomAddrLoc]),
        .rd_data_o     (s_rd_data[0]),
        .rdy_n_o       (s_rdy_n[0])
    );

    /* 1 occupied by spm */

`ifdef IMPLEMENT_TIMER
    /********** TIMER **********/
    timer u_timer (
        .clk             (clk),
        .reset           (reset),

        .cs_n_i          (s_cs_n[2]),
        .as_n_i          (s_as_n),
        .rw_i            (s_rw),
        .addr_i          (s_addr[`TimerAddrLoc]),
        .wr_data_i       (s_wr_data),
        .rd_data_o       (s_rd_data[2]),
        .rdy_n_o         (s_rdy_n[2]),

        .irq_o           (irq_timer)
     );
`else
    assign s_rd_data[2] = `WORD_DATA_W'h0;
    assign s_rdy_n[2]   = `DISABLE_N;
    assign irq_timer    = `DISABLE;
`endif

`ifdef IMPLEMENT_UART
    /********** UART **********/
    uart u_uart (
        .clk               (clk),
        .reset             (reset),

        .cs_n_i            (s_cs_n[3]),
        .as_n_i            (s_as_n),
        .rw_i              (s_rw),
        .addr_i            (s_addr[`UartAddrLoc]),
        .wr_data_i         (s_wr_data),
        .rd_data_o         (s_rd_data[3]),
        .rdy_n_o           (s_rdy_n[3]),

        .irq_rx_o          (irq_uart_rx),
        .irq_tx_o          (irq_uart_tx),

        .rx_i              (uart_rx),
        .tx_o              (uart_tx)
    );
`else
    assign s_rd_data[3]  = `WORD_DATA_W'h0;
    assign s_rdy_n[3]    = `DISABLE_N;
    assign irq_uart_rx   = `DISABLE;
    assign irq_uart_tx   = `DISABLE;
`endif

`ifdef IMPLEMENT_GPIO
    /********** GPIO **********/
    gpio u_gpio (
        .clk             (clk),
        .reset           (reset),

        .cs_n_i          (s_cs_n[4]),
        .as_n_i          (s_as_n),
        .rw_i            (s_rw),
        .addr_i          (s_addr[`GpioAddrLoc]),
        .wr_data_i       (s_wr_data),
        .rd_data_i       (s_rd_data[4]),
        .rdy_n_o         (s_rdy_n[4])

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
    assign s_rd_data[4]   = `WORD_DATA_W'h0;
    assign s_rdy_n[4]     = `DISABLE_N;
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

        .req_i         (s_cs_n[5]),
        .we_i          (s_rw),
        .addr_i        ({{(32-`WORD_ADDR_W){1'b0}}, s_addr}),
        .data_in_i     (s_wr_data),
        .data_out_o    (s_rd_data[5]),
        .ack_o         (s_rdy_n[5]),

        .spi_cs_n_o    (spi_cs_n),
        .spi_clk_o     (spi_clk),
        .spi_mosi_o    (spi_mosi),
        .spi_miso_i    (spi_miso)
    );
`else
    /* 暂未使用 */
    assign s_rd_data[5]   = `WORD_DATA_W'h0;
    assign s_rdy_n[5]     = `DISABLE_N;
    assign spi_cs_n       = 1'b1;
    assign spi_clk        = 1'b0;
    assign spi_mosi       = 1'b0;
`endif

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

`ifdef IMPLEMENT_JTAG
    /********** JTAG **********/
    jtag #(
        .ADDR_WIDTH      (64),
        .DATA_WIDTH      (32),
        .INST_WIDTH      (4)
    ) u_jtag (
        .clk             (clk),
        .rst_n           (reset == `RESET_DISABLE ? 1'b1 : 1'b0),

        .tck_i           (tck),
        .tms_i           (tms),
        .tdi_i           (tdi),
        .tdo_o           (tdo),
        .tdo_en_o        (tdo_en),

        .req_i           (s_cs_n[7]),
        .we_i            (s_rw),
        .addr_i          ({{(64-`WORD_ADDR_W){1'b0}}, s_addr}),
        .data_in_i       (s_wr_data),
        .data_out_o      (s_rd_data[7][`WORD_DATA_W-1:0]),
        .ack_o           (s_rdy_n[7]),

        .debug_data_o    (),
        .debug_valid_o   ()
    );
`else
    assign s_rd_data[7]  = `WORD_DATA_W'h0;
    assign s_rdy_n[7]    = `DISABLE_N;
    assign tdo           = `LOW;
    assign tdo_en        = `LOW;
`endif

    /********** BUS **********/
    bus u_bus (
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