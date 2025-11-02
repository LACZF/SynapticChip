`include "common.v"

module io_top #(
    parameter ADDR_WIDTH           = 32,
    parameter DATA_WIDTH           = 32,
    parameter IO_SLAVES            = 8,
    parameter IO_ADDR_BASE         = 32'h40000000,
    parameter IO_ADDR_MASK         = ~32'hFFFFFFF,
    parameter IMPLEMENT_UART       = 1,
    parameter IMPLEMENT_GPIO       = 1,
    parameter IMPLEMENT_SPI        = 0,
    parameter IMPLEMENT_TIMER      = 1,
    parameter IMPLEMENT_FLASH      = 1,
    parameter SPI_NUM              = 1,
    parameter GPIO_IN_CH           = 1,
    parameter GPIO_OUT_CH          = 1,
    parameter GPIO_IO_CH           = 1
) (
    input  wire                               clk,
    input  wire                               rst_n,

    // 总线接口
    input  wire [IO_SLAVES-1:0]               slave_req,
    input  wire [IO_SLAVES-1:0][31:0]         slave_addr,
    input  wire [IO_SLAVES-1:0]               slave_we,
    input  wire [IO_SLAVES-1:0][ 3:0]         slave_be,
    input  wire [IO_SLAVES-1:0][31:0]         slave_wdata,
    output wire [IO_SLAVES-1:0]               slave_gnt,
    output wire [IO_SLAVES-1:0]               slave_rvalid,
    output wire [IO_SLAVES-1:0][31:0]         slave_rdata,

    output wire [IO_SLAVES-1:0][31:0]         slave_addr_mask,
    output wire [IO_SLAVES-1:0][31:0]         slave_addr_base,

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
    output wire [SPI_NUM-1:0]                 spi_cs_n,
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
    localparam int SLAVE_TIMER_INDEX   = 0;
    localparam int SLAVE_GPIO_INDEX    = 1;
    localparam int SLAVE_UART_INDEX    = 2;
    localparam int SLAVE_SPI_INDEX     = 3;
    localparam int SLAVE_FLASH_INDEX   = 4;

    localparam int TIMER_ADDR_BASE     = IO_ADDR_BASE + 32'h00010000;
    localparam int TIMER_ADDR_MASK     = `CALC_ADDR_MASK_BY_LENGTH(TIMER_ADDR_BASE, 4096);

    localparam int UART_ADDR_BASE      = IO_ADDR_BASE + 32'h00020000;
    localparam int UART_ADDR_MASK      = `CALC_ADDR_MASK_BY_LENGTH(UART_ADDR_BASE, 4096);

    localparam int GPIO_ADDR_BASE      = IO_ADDR_BASE + 32'h00030000;
    localparam int GPIO_ADDR_MASK      = `CALC_ADDR_MASK_BY_LENGTH(GPIO_ADDR_BASE, 4096);

    localparam int SPI_ADDR_BASE       = IO_ADDR_BASE + 32'h00040000;
    localparam int SPI_ADDR_MASK       = `CALC_ADDR_MASK_BY_LENGTH(SPI_ADDR_BASE, 4096);

    localparam int XIP_ADDR_BASE       = IO_ADDR_BASE + 32'h00050000;
    localparam int XIP_ADDR_MASK       = `CALC_ADDR_MASK_BY_LENGTH(XIP_ADDR_BASE, 4096);

    /********** TIMER **********/
    generate
        if (IMPLEMENT_TIMER) begin : timer_gen
            assign slave_addr_base[SLAVE_TIMER_INDEX] = TIMER_ADDR_BASE;
            assign slave_addr_mask[SLAVE_TIMER_INDEX] = TIMER_ADDR_MASK;
            timer_top u_timer (
                .clk             (clk),
                .rst_n           (rst_n),

                .req_i           (slave_req[SLAVE_TIMER_INDEX]),
                .we_i            (slave_we[SLAVE_TIMER_INDEX]),
                .addr_i          (slave_addr[SLAVE_TIMER_INDEX]),
                .wr_data_i       (slave_wdata[SLAVE_TIMER_INDEX]),
                .data_out_o      (slave_rdata[SLAVE_TIMER_INDEX]),
                .gnt_o           (slave_gnt[SLAVE_TIMER_INDEX]),
                .rvalid_o        (slave_rvalid[SLAVE_TIMER_INDEX]),

                .irq_o           (irq_timer)
             );
        end else begin
            assign slave_rdata[SLAVE_TIMER_INDEX]    = 32'h0;
            assign slave_rvalid[SLAVE_TIMER_INDEX]   = 1'b0;
            assign slave_gnt[SLAVE_TIMER_INDEX]      = 1'b0;
            assign irq_timer                         = 1'b0;
        end
    endgenerate

    /********** UART **********/
    generate
        if (IMPLEMENT_UART) begin : uart_gen
            assign slave_addr_base[SLAVE_UART_INDEX]  = UART_ADDR_BASE;
            assign slave_addr_mask[SLAVE_UART_INDEX]  = UART_ADDR_MASK;
            uart_top u_uart (
                .clk             (clk),
                .rst_n           (rst_n),

                .req_i           (slave_req[SLAVE_UART_INDEX]),
                .we_i            (slave_we[SLAVE_UART_INDEX]),
                .addr_i          (slave_addr[SLAVE_UART_INDEX]),
                .wr_data_i       (slave_wdata[SLAVE_UART_INDEX]),
                .data_out_o      (slave_rdata[SLAVE_UART_INDEX]),
                .gnt_o           (slave_gnt[SLAVE_UART_INDEX]),
                .rvalid_o        (slave_rvalid[SLAVE_UART_INDEX]),

                .uart_rx         (uart_rx),
                .uart_tx         (uart_tx),

                .irq_o           (irq_uart_rx)
             );
        end else begin
            assign slave_rdata[SLAVE_UART_INDEX]    = 32'h0;
            assign slave_rvalid[SLAVE_UART_INDEX]   = 1'b0;
            assign slave_gnt[SLAVE_UART_INDEX]      = 1'b0;
            assign irq_uart_rx                      = 1'b0;
            assign irq_uart_tx                      = 1'b0;
        end
    endgenerate

    /********** GPIO **********/
    generate
        if (IMPLEMENT_GPIO) begin : gpio_gen
            assign slave_addr_base[SLAVE_GPIO_INDEX]  = GPIO_ADDR_BASE;
            assign slave_addr_mask[SLAVE_GPIO_INDEX]  = GPIO_ADDR_MASK;
            gpio_top #(
                .GPIO_IN_CH    (GPIO_IN_CH),
                .GPIO_OUT_CH   (GPIO_OUT_CH),
                .GPIO_IO_CH    (GPIO_IO_CH)
            ) u_gpio (
                .clk             (clk),
                .rst_n           (rst_n),

                .req_i           (slave_req[SLAVE_GPIO_INDEX]),
                .we_i            (slave_we[SLAVE_GPIO_INDEX]),
                .addr_i          (slave_addr[SLAVE_GPIO_INDEX]),
                .wr_data_i       (slave_wdata[SLAVE_GPIO_INDEX]),
                .data_out_o      (slave_rdata[SLAVE_GPIO_INDEX]),
                .gnt_o           (slave_gnt[SLAVE_GPIO_INDEX]),
                .rvalid_o        (slave_rvalid[SLAVE_GPIO_INDEX]),

                .gpio_in         (gpio_in),
                .gpio_out        (gpio_out),
                .gpio_io         (gpio_io)
             );
        end else begin
            assign slave_rdata[SLAVE_GPIO_INDEX]     = 32'h0;
            assign slave_rvalid[SLAVE_GPIO_INDEX]    = 1'b0;
            assign slave_gnt[SLAVE_GPIO_INDEX]       = 1'b0;
            assign gpio_out                          = {GPIO_OUT_CH{1'b0}};
            // GPIO_IO需要保持三态，不做赋值
        end
    endgenerate

    /********** SPI **********/
    generate
        if (IMPLEMENT_SPI) begin : spi_gen
            assign slave_addr_base[SLAVE_SPI_INDEX]   = SPI_ADDR_BASE;
            assign slave_addr_mask[SLAVE_SPI_INDEX]   = SPI_ADDR_MASK;
            spi_top #(
                .ADDR_WIDTH    (ADDR_WIDTH),
                .DATA_WIDTH    (DATA_WIDTH),
                .SPI_NUM       (SPI_NUM)
            ) u_spi (
                .clk           (clk),
                .rst_n         (rst_n),

                .req_i         (slave_req[SLAVE_SPI_INDEX]),
                .we_i          (slave_we[SLAVE_SPI_INDEX]),
                .addr_i        (slave_addr[SLAVE_SPI_INDEX]),
                .data_in_i     (slave_wdata[SLAVE_SPI_INDEX]),
                .data_out_o    (slave_rdata[SLAVE_SPI_INDEX]),
                .gnt_o         (slave_gnt[SLAVE_SPI_INDEX]),
                .rvalid_o      (slave_rvalid[SLAVE_SPI_INDEX]),

                .spi_cs_n_o    (spi_cs_n),
                .spi_clk_o     (spi_clk),
                .spi_mosi_o    (spi_mosi),
                .spi_miso_i    (spi_miso)
            );
            // SPI已更新为完整OBI接口，gnt_o和rvalid_o由spi_top内部逻辑控制
        end else begin
            /* 暂未使用 */
            assign slave_rdata[SLAVE_SPI_INDEX]      = 32'h0;
            assign slave_rvalid[SLAVE_SPI_INDEX]     = 1'b0;
            assign slave_gnt[SLAVE_SPI_INDEX]        = 1'b0;
            assign spi_cs_n                          = 1'b1;
            assign spi_clk                           = 1'b0;
            assign spi_mosi                          = 1'b0;
        end
    endgenerate

`ifdef SUPPORT_XIP_FOR_CHIP
    /********** FLASH/XIP **********/
    generate
        if (IMPLEMENT_FLASH) begin : flash_gen
            assign slave_addr_base[SLAVE_FLASH_INDEX]  = XIP_ADDR_BASE;
            assign slave_addr_mask[SLAVE_FLASH_INDEX]  = XIP_ADDR_MASK;
            xip_top u_flash (
                .clk_i          (clk),
                .rst_ni         (rst_n),
                .req_i          (slave_req[SLAVE_FLASH_INDEX]),
                .we_i           (slave_we[SLAVE_FLASH_INDEX]),
                .be_i           (slave_be[SLAVE_FLASH_INDEX]),
                .addr_i         (slave_addr[SLAVE_FLASH_INDEX]),
                .data_i         (slave_wdata[SLAVE_FLASH_INDEX]),
                .gnt_o          (slave_gnt[SLAVE_FLASH_INDEX]),
                .rvalid_o       (slave_rvalid[SLAVE_FLASH_INDEX]),
                .data_o         (slave_rdata[SLAVE_FLASH_INDEX]),

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
            assign slave_rdata[SLAVE_FLASH_INDEX]      = 32'h0;
            assign slave_rvalid[SLAVE_FLASH_INDEX]     = 1'b0;
            assign slave_gnt[SLAVE_FLASH_INDEX]        = 1'b0;
            assign flash_spi_clk                       = 1'b0;
            assign flash_spi_ss                        = 1'b1;
            assign flash_spi_dq_out                    = 4'b0000;
            assign flash_spi_dq_oe                     = 4'b0000;
        end
    endgenerate
`endif

endmodule