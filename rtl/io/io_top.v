`include "stddef.v"
`include "global_config.v"

`include "timer.v"
`include "uart.v"
`include "gpio.v"
`include "spi_addr.v"
`include "spi.v"

module io_top #(
    parameter SLAVES               = 8,
    parameter START_SLAVE          = 2,
    parameter IMPLEMENT_UART       = 1,
    parameter IMPLEMENT_GPIO       = 1,
    parameter IMPLEMENT_SPI        = 0,
    parameter IMPLEMENT_TIMER      = 1,
    parameter IMPLEMENT_FLASH      = 1,
    parameter GPIO_IN_CH           = 1,
    parameter GPIO_OUT_CH          = 1,
    parameter GPIO_IO_CH           = 1
) (
    input  wire                               clk,
    input  wire                               rst_n,

    // 总线接口
    input  wire                               slave_req        [SLAVES],
    input  wire [31:0]                        slave_addr       [SLAVES],
    input  wire                               slave_we         [SLAVES],
    input  wire [ 3:0]                        slave_be         [SLAVES],
    input  wire [31:0]                        slave_wdata      [SLAVES],
    output wire                               slave_gnt        [SLAVES],
    output wire                               slave_rvalid     [SLAVES],
    output wire [31:0]                        slave_rdata      [SLAVES],

    input  wire [31:0]                        slave_addr_mask  [SLAVES],
    input  wire [31:0]                        slave_addr_base  [SLAVES],

    // 中断信号
    output wire                               irq_timer,
    output wire                               irq_uart_rx,
    output wire                               irq_uart_tx,

    // UART接口
    input  wire                               uart_rx,
    output wire                               uart_tx,

    // GPIO接口
    input  wire [GPIO_IN_CH-1:0]              gpio_in,
    output wire [GPIO_OUT_CH-1:0]             gpio_out,
    inout  wire [GPIO_IO_CH-1:0]              gpio_io,

    // SPI接口
    output wire                               spi_cs_n,
    output wire                               spi_clk,
    output wire                               spi_mosi,
    input  wire                               spi_miso,

    // Flash接口
    output wire                               flash_spi_clk,
    output wire                               flash_spi_ss,
    output wire [3:0]                         flash_spi_dq_out,
    output wire [3:0]                         flash_spi_dq_oe,
    input  wire [3:0]                         flash_spi_dq_in
);
    localparam int slave_timer_index   = START_SLAVE + 0;
    localparam int slave_gpio_index    = START_SLAVE + 1;
    localparam int slave_uart_index    = START_SLAVE + 2;
    localparam int slave_spi_index     = START_SLAVE + 3;
    localparam int slave_flash_index   = START_SLAVE + 4;

    /********** TIMER **********/
    generate
        if (IMPLEMENT_TIMER) begin : timer_gen
            assign slave_addr_mask[slave_timer_index] = `TIMER0_ADDR_MASK;
            assign slave_addr_base[slave_timer_index] = `TIMER0_ADDR_BASE;
            timer_top u_timer (
                .clk             (clk),
                .rst_n           (rst_n),

                .req_i           (slave_req[slave_timer_index]),
                .we_i            (slave_we[slave_timer_index]),
                .addr_i          (slave_addr[slave_timer_index][`TimerAddrLoc]),
                .wr_data_i       (slave_wdata[slave_timer_index]),
                .data_out_o      (slave_rdata[slave_timer_index]),
                .gnt_o           (slave_gnt[slave_timer_index]),
                .rvalid_o        (slave_rvalid[slave_timer_index]),

                .irq_o           (irq_timer)
             );
        end else begin
            assign slave_rdata[slave_timer_index]    = `WORD_DATA_W'h0;
            assign slave_rvalid[slave_timer_index]   = `DISABLE_N;
            assign slave_gnt[slave_timer_index]      = `DISABLE_N;
            assign irq_timer                         = `DISABLE;
        end
    endgenerate

    /********** UART **********/
    generate
        if (IMPLEMENT_UART) begin : uart_gen
            assign slave_addr_mask[slave_uart_index] = `UART0_ADDR_MASK;
            assign slave_addr_base[slave_uart_index] = `UART0_ADDR_BASE;
            uart_top u_uart (
                .clk               (clk),
                .rst_n             (rst_n),

                .req_i             (slave_req[slave_uart_index]),
                .we_i              (slave_we[slave_uart_index]),
                .addr_i            (slave_addr[slave_uart_index][`UartAddrLoc]),
                .wr_data_i         (slave_wdata[slave_uart_index]),
                .data_out_o        (slave_rdata[slave_uart_index]),
                .gnt_o             (slave_gnt[slave_uart_index]),
                .rvalid_o          (slave_rvalid[slave_uart_index]),

                .irq_o             (irq_uart_rx),

                .uart_rx_i         (uart_rx),
                .uart_tx_o         (uart_tx)
            );
            // 合并RX和TX中断信号
            assign irq_uart_tx = `DISABLE;
        end else begin
            assign slave_rdata[slave_uart_index]   = `WORD_DATA_W'h0;
            assign slave_rvalid[slave_uart_index]  = `DISABLE_N;
            assign slave_gnt[slave_uart_index]     = `DISABLE_N;
            assign irq_uart_rx                     = `DISABLE;
            assign irq_uart_tx                     = `DISABLE;
            assign uart_tx                         = `LOW;
        end
    endgenerate

    /********** GPIO **********/
    generate
        if (IMPLEMENT_GPIO) begin : gpio_gen
            assign slave_addr_mask[slave_gpio_index] = `GPIO_ADDR_MASK;
            assign slave_addr_base[slave_gpio_index] = `GPIO_ADDR_BASE;
            gpio_top #(
                .GPIO_IN_CH      (GPIO_IN_CH),
                .GPIO_OUT_CH     (GPIO_OUT_CH),
                .GPIO_IO_CH      (GPIO_IO_CH)
            ) u_gpio (
                .clk             (clk),
                .rst_n           (rst_n),

                .req_i           (slave_req[slave_gpio_index]),
                .we_i            (slave_we[slave_gpio_index]),
                .addr_i          (slave_addr[slave_gpio_index][`GpioAddrLoc]),
                .wr_data_i       (slave_wdata[slave_gpio_index]),
                .data_out_o      (slave_rdata[slave_gpio_index]),
                .gnt_o           (slave_gnt[slave_gpio_index]),
                .rvalid_o        (slave_rvalid[slave_gpio_index]),

                // 根据参数条件连接GPIO端口
                .gpio_in         (gpio_in),
                .gpio_out        (gpio_out),
                .gpio_io         (gpio_io)
            );
        end else begin
            assign slave_rdata[slave_gpio_index]      = `WORD_DATA_W'h0;
            assign slave_rvalid[slave_gpio_index]     = `DISABLE_N;
            assign slave_gnt[slave_gpio_index]        = `DISABLE_N;
        end
    endgenerate

    /********** SPI **********/
    generate
        if (IMPLEMENT_SPI) begin : spi_gen
            assign slave_addr_mask[slave_spi_index] = `SPI0_ADDR_MASK;
            assign slave_addr_base[slave_spi_index] = `SPI0_ADDR_BASE;
            spi_top #(
                .DATA_WIDTH    (32),
                .ADDR_WIDTH    (32),
                .CS_NUM        (1)
            ) u_spi (
                .clk           (clk),
                .rst_n         (rst_n == `RESET_DISABLE ? 1'b1 : 1'b0),

                .req_i         (slave_req[slave_spi_index]),
                .we_i          (slave_we[slave_spi_index]),
                .addr_i        (slave_addr[slave_spi_index]),
                .data_in_i     (slave_wdata[slave_spi_index]),
                .data_out_o    (slave_rdata[slave_spi_index]),
                .gnt_o         (slave_gnt[slave_spi_index]),
                .rvalid_o      (slave_rvalid[slave_spi_index]),

                .spi_cs_n_o    (spi_cs_n),
                .spi_clk_o     (spi_clk),
                .spi_mosi_o    (spi_mosi),
                .spi_miso_i    (spi_miso)
            );
            // SPI已更新为完整OBI接口，gnt_o和rvalid_o由spi_top内部逻辑控制
        end else begin
            /* 暂未使用 */
            assign slave_rdata[slave_spi_index]      = `WORD_DATA_W'h0;
            assign slave_rvalid[slave_spi_index]     = `DISABLE_N;
            assign slave_gnt[slave_spi_index]        = `DISABLE_N;
            assign spi_cs_n                          = 1'b1;
            assign spi_clk                           = 1'b0;
            assign spi_mosi                          = 1'b0;
        end
    endgenerate

    /********** FLASH/XIP **********/
    generate
        if (IMPLEMENT_FLASH) begin : flash_gen
            assign slave_addr_mask[slave_flash_index] = `XIP_ADDR_MASK;
            assign slave_addr_base[slave_flash_index] = `XIP_ADDR_BASE;
            xip_top u_flash (
                .clk_i          (clk),
                .rst_ni         (rst_n),
                .req_i          (slave_req[slave_flash_index]),
                .we_i           (slave_we[slave_flash_index]),
                .be_i           (slave_be[slave_flash_index]),
                .addr_i         (slave_addr[slave_flash_index]),
                .data_i         (slave_wdata[slave_flash_index]),
                .gnt_o          (slave_gnt[slave_flash_index]),
                .rvalid_o       (slave_rvalid[slave_flash_index]),
                .data_o         (slave_rdata[slave_flash_index]),

                .spi_clk_o      (flash_spi_clk),
                .spi_clk_oe_o   (), // 不使用
                .spi_ss_o       (flash_spi_ss),
                .spi_ss_oe_o    (), // 不使用
                .spi_dq0_i      (flash_spi_dq_in[0]),
                .spi_dq0_o      (flash_spi_dq_out[0]),
                .spi_dq0_oe_o   (flash_spi_dq_oe[0]),
                .spi_dq1_i      (flash_spi_dq_in[1]),
                .spi_dq1_o      (flash_spi_dq_out[1]),
                .spi_dq1_oe_o   (flash_spi_dq_oe[1]),
                .spi_dq2_i      (flash_spi_dq_in[2]),
                .spi_dq2_o      (flash_spi_dq_out[2]),
                .spi_dq2_oe_o   (flash_spi_dq_oe[2]),
                .spi_dq3_i      (flash_spi_dq_in[3]),
                .spi_dq3_o      (flash_spi_dq_out[3]),
                .spi_dq3_oe_o   (flash_spi_dq_oe[3])
            );
        end else begin
            assign slave_rdata[slave_flash_index]      = `WORD_DATA_W'h0;
            assign slave_rvalid[slave_flash_index]     = `DISABLE_N;
            assign slave_gnt[slave_flash_index]        = `DISABLE_N;
            assign flash_spi_clk                       = 1'b0;
            assign flash_spi_ss                        = 1'b1;
            assign flash_spi_dq_out                    = 4'b0000;
            assign flash_spi_dq_oe                     = 4'b0000;
        end
    endgenerate

endmodule