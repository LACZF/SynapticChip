`include "stddef.v"
`include "global_config.v"

`include "rom.v"
`include "timer.v"
`include "uart.v"
`include "gpio.v"
`include "jtag_addr.v"
`include "spi_addr.v"
`include "spi.v"

module io_top #(
    parameter MASTER_NUM = 4,
    parameter SLAVE_NUM  = 8
) (
    input  wire                               clk,
    input  wire                               reset,

    // 总线接口
    input  wire [SLAVE_NUM-1:0]               s_cs_n,
    input  wire                               s_as_n,
    input  wire                               s_rw,
    input  wire [`WordAddrBus]                s_addr,
    input  wire [`WordDataBus]                s_wr_data,
    output wire [SLAVE_NUM-1:0][`WordDataBus] s_rd_data,
    output wire [SLAVE_NUM-1:0]               s_rdy_n,

    // 中断信号
    output wire                               irq_timer,
    output wire                               irq_uart_rx,
    output wire                               irq_uart_tx

`ifdef IMPLEMENT_JTAG
    // JTAG接口
    , input  wire                             tck
    , input  wire                             tms
    , input  wire                             tdi
    , output wire                             tdo
    , output wire                             tdo_en
`endif

`ifdef IMPLEMENT_UART
    // UART接口
    , input  wire                             uart_rx
    , output wire                             uart_tx
`endif

`ifdef IMPLEMENT_GPIO
    // GPIO接口
`ifdef GPIO_IN_CH     // 输入端口的实现
    , input wire [`GPIO_IN_CH-1:0]            gpio_in      // 输入端口
`endif
`ifdef GPIO_OUT_CH     // 输出端口实现
    , output wire [`GPIO_OUT_CH-1:0]          gpio_out     // 输出端口
`endif
`ifdef GPIO_IO_CH     // 输入/输出端口的实现
    , inout wire [`GPIO_IO_CH-1:0]            gpio_io      // 输入输出端口
`endif
`endif

`ifdef IMPLEMENT_SPI
    // SPI接口
    , output wire                             spi_cs_n
    , output wire                             spi_clk
    , output wire                             spi_mosi
    , input  wire                             spi_miso
`endif
);

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
        .rd_data_o       (s_rd_data[4]),
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

endmodule