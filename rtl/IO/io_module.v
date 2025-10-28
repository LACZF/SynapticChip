`include "stddef.v"
`include "global_config.v"

`include "defines.sv"

module io_module #(
    parameter GPIO_NUM        = 16,
    parameter IMPLEMENT_JTAG  = 0,
    parameter IMPLEMENT_UART  = 1,
    parameter IMPLEMENT_GPIO  = 1,
    parameter IMPLEMENT_SPI   = 0,
    parameter IMPLEMENT_TIMER = 1,
    parameter IMPLEMENT_I2C   = 1,
    parameter I2C_NUM         = 2,
    parameter UART_NUM        = 3,
    parameter SPI_NUM         = 1
)(
    input  wire            clk,
    input  wire            rst_ni,

    // 中断源信号
    output wire            timer0_irq,
    output wire            uart0_irq,
    output wire            gpio0_irq,
    output wire            gpio1_irq,
    output wire            i2c0_irq,
    output wire            spi0_irq,
    output wire            gpio2_4_irq,
    output wire            gpio5_7_irq,
    output wire            gpio8_irq,
    output wire            gpio9_irq,
    output wire            gpio10_12_irq,
    output wire            gpio13_15_irq,

    // GPIO相关信号
    inout  wire [GPIO_NUM-1:0] gpio_pins,

    // UART相关信号
    input  wire            uart_rx_int,
    output wire            uart_tx_int,

    // SPI相关信号
    input  wire            spi_clk_in_int,
    output wire            spi_clk_out_int,
    output wire            spi_clk_oe_int,
    input  wire            spi_ss_in_int,
    output wire            spi_ss_out_int,
    output wire            spi_ss_oe_int,
    input  wire [3:0]      spi_dq_in_int,
    output wire [3:0]      spi_dq_out_int,
    output wire [3:0]      spi_dq_oe_int,

    // I2C相关信号
    input  wire            i2c_scl_in_int,
    output wire            i2c_scl_out_int,
    output wire            i2c_scl_oe_int,
    input  wire            i2c_sda_in_int,
    output wire            i2c_sda_out_int,
    output wire            i2c_sda_oe_int,

    // XIP相关信号
    output wire            flash_spi_clk_pin,
    output wire            flash_spi_ss_pin,
    input  wire [3:0]      flash_spi_dq_in,
    output wire [3:0]      flash_spi_dq_out,
    output wire [3:0]      flash_spi_dq_oe,

    // 总线接口信号 - 使用数组表示多个从设备接口
    input  wire            slave_req[17:0],
    output wire            slave_gnt[17:0],
    output wire            slave_rvalid[17:0],
    input  wire [31:0]     slave_addr[17:0],
    input  wire            slave_we[17:0],
    input  wire [3:0]      slave_be[17:0],
    input  wire [31:0]     slave_wdata[17:0],
    output wire [31:0]     slave_rdata[17:0]
);
    // 定义从设备索引
    localparam int Timer0   = 0;
    localparam int Gpio     = 1;
    localparam int Uart0    = 2;
    localparam int Rvic     = 3;
    localparam int I2c0     = 4;
    localparam int Spi0     = 5;
    localparam int Pinmux   = 6;
    localparam int Xip      = 7;
    localparam int Bootrom  = 8;
    localparam int Reserved = 9;

    // 从设备地址掩码和基址
    wire [31:0] slave_addr_mask[9:0];
    wire [31:0] slave_addr_base[9:0];

    // 内部信号定义
    wire[GPIO_NUM-1:0] gpio_data_in;
    wire[GPIO_NUM-1:0] gpio_oe;
    wire[GPIO_NUM-1:0] gpio_data_out;

    wire[GPIO_NUM-1:0] io_data_in;
    wire[GPIO_NUM-1:0] io_oe;
    wire[GPIO_NUM-1:0] io_data_out;

    // I2C相关信号
    wire[I2C_NUM-1:0] i2c_scl_in;
    wire[I2C_NUM-1:0] i2c_scl_oe;
    wire[I2C_NUM-1:0] i2c_scl_out;
    wire[I2C_NUM-1:0] i2c_sda_in;
    wire[I2C_NUM-1:0] i2c_sda_oe;
    wire[I2C_NUM-1:0] i2c_sda_out;

    // SPI相关信号
    wire[SPI_NUM-1:0] spi_clk_in;
    wire[SPI_NUM-1:0] spi_clk_oe;
    wire[SPI_NUM-1:0] spi_clk_out;
    wire[SPI_NUM-1:0] spi_ss_in;
    wire[SPI_NUM-1:0] spi_ss_oe;
    wire[SPI_NUM-1:0] spi_ss_out;
    wire[3:0]         spi_dq_in[SPI_NUM-1:0];
    wire[3:0]         spi_dq_oe[SPI_NUM-1:0];
    wire[3:0]         spi_dq_out[SPI_NUM-1:0];

    // 中断相关信号
    wire [31:0] irq_src;
    wire        int_req;
    wire [7:0]  int_id;

    // 连接外部信号到内部信号
    assign i2c_scl_in[0] = i2c_scl_in_int;
    assign i2c_scl_out_int = i2c_scl_out[0];
    assign i2c_scl_oe_int = i2c_scl_oe[0];
    assign i2c_sda_in[0] = i2c_sda_in_int;
    assign i2c_sda_out_int = i2c_sda_out[0];
    assign i2c_sda_oe_int = i2c_sda_oe[0];

    assign spi_clk_in[0] = spi_clk_in_int;
    assign spi_clk_out_int = spi_clk_out[0];
    assign spi_clk_oe_int = spi_clk_oe[0];
    assign spi_ss_in[0] = spi_ss_in_int;
    assign spi_ss_out_int = spi_ss_out[0];
    assign spi_ss_oe_int = spi_ss_oe[0];
    assign spi_dq_in[0] = spi_dq_in_int;
    assign spi_dq_out_int = spi_dq_out[0];
    assign spi_dq_oe_int = spi_dq_oe[0];

    // GPIO引脚连接
    generate
        for (genvar i = 0; i < GPIO_NUM; i = i + 1) begin : g_io_data
            assign gpio_pins[i] = gpio_oe[i] ? gpio_data_out[i] : 1'bz;
            assign gpio_data_in[i] = gpio_pins[i];
        end
    endgenerate

`ifdef SUPPORT_IO_MODULE
    assign slave_addr_mask[Timer0] = `TIMER0_ADDR_MASK;
    assign slave_addr_base[Timer0] = `TIMER0_ADDR_BASE;
    timer_top u_timer(
        .clk_i   (clk),
        .rst_ni  (rst_ni),
        .irq_o   (timer0_irq),
        .req_i   (slave_req[Timer0]),
        .we_i    (slave_we[Timer0]),
        .be_i    (slave_be[Timer0]),
        .addr_i  (slave_addr[Timer0]),
        .data_i  (slave_wdata[Timer0]),
        .gnt_o   (slave_gnt[Timer0]),
        .rvalid_o(slave_rvalid[Timer0]),
        .data_o  (slave_rdata[Timer0])
    );

    // GPIO模块
    assign slave_addr_mask[Gpio] = `GPIO_ADDR_MASK;
    assign slave_addr_base[Gpio] = `GPIO_ADDR_BASE;
    gpio_top #(
        .GPIO_NUM(GPIO_NUM)
    ) u_gpio (
        .clk_i          (clk),
        .rst_ni         (rst_ni),
        .gpio_oe_o      (gpio_oe),
        .gpio_data_o    (gpio_data_out),
        .gpio_data_i    (gpio_data_in),
        .irq_gpio0_o    (gpio0_irq),
        .irq_gpio1_o    (gpio1_irq),
        .irq_gpio2_4_o  (gpio2_4_irq),
        .irq_gpio5_7_o  (gpio5_7_irq),
        .irq_gpio8_o    (gpio8_irq),
        .irq_gpio9_o    (gpio9_irq),
        .irq_gpio10_12_o(gpio10_12_irq),
        .irq_gpio13_15_o(gpio13_15_irq),
        .req_i          (slave_req[Gpio]),
        .we_i           (slave_we[Gpio]),
        .be_i           (slave_be[Gpio]),
        .addr_i         (slave_addr[Gpio]),
        .data_i         (slave_wdata[Gpio]),
        .gnt_o          (slave_gnt[Gpio]),
        .rvalid_o       (slave_rvalid[Gpio]),
        .data_o         (slave_rdata[Gpio])
    );

    assign slave_addr_mask[Uart0] = `UART0_ADDR_MASK;
    assign slave_addr_base[Uart0] = `UART0_ADDR_BASE;
    uart_top u_uart (
        .clk_i      (clk),
        .rst_ni     (rst_ni),
        .rx_i       (uart_rx_int),
        .tx_o       (uart_tx_int),
        .irq_o      (uart0_irq),
        .req_i      (slave_req[Uart0]),
        .we_i       (slave_we[Uart0]),
        .be_i       (slave_be[Uart0]),
        .addr_i     (slave_addr[Uart0]),
        .data_i     (slave_wdata[Uart0]),
        .gnt_o      (slave_gnt[Uart0]),
        .rvalid_o   (slave_rvalid[Uart0]),
        .data_o     (slave_rdata[Uart0])
    );

    // 中断控制器模块
    assign slave_addr_mask[Rvic] = `RVIC_ADDR_MASK;
    assign slave_addr_base[Rvic] = `RVIC_ADDR_BASE;
    rvic_top u_rvic(
        .clk_i      (clk),
        .rst_ni     (rst_ni),
        .src_i      (irq_src),
        .irq_o      (int_req),
        .irq_id_o   (int_id),
        .req_i      (slave_req[Rvic]),
        .we_i       (slave_we[Rvic]),
        .be_i       (slave_be[Rvic]),
        .addr_i     (slave_addr[Rvic]),
        .data_i     (slave_wdata[Rvic]),
        .gnt_o      (slave_gnt[Rvic]),
        .rvalid_o   (slave_rvalid[Rvic]),
        .data_o     (slave_rdata[Rvic])
    );

    assign slave_addr_mask[I2c0] = `I2C0_ADDR_MASK;
    assign slave_addr_base[I2c0] = `I2C0_ADDR_BASE;
    i2c_top u_i2c(
        .clk_i      (clk),
        .rst_ni     (rst_ni),
        .scl_o      (i2c_scl_out[0]),
        .scl_oe_o   (i2c_scl_oe[0]),
        .scl_i      (i2c_scl_in[0]),
        .sda_o      (i2c_sda_out[0]),
        .sda_oe_o   (i2c_sda_oe[0]),
        .sda_i      (i2c_sda_in[0]),
        .irq_o      (i2c0_irq),
        .req_i      (slave_req[I2c0]),
        .we_i       (slave_we[I2c0]),
        .be_i       (slave_be[I2c0]),
        .addr_i     (slave_addr[I2c0]),
        .data_i     (slave_wdata[I2c0]),
        .gnt_o      (slave_gnt[I2c0]),
        .rvalid_o   (slave_rvalid[I2c0]),
        .data_o     (slave_rdata[I2c0])
    );

    assign slave_addr_mask[Spi0] = `SPI0_ADDR_MASK;
    assign slave_addr_base[Spi0] = `SPI0_ADDR_BASE;
    spi_top u_spi(
        .clk_i      (clk),
        .rst_ni     (rst_ni),
        .spi_clk_i  (spi_clk_in[0]),
        .spi_clk_o  (spi_clk_out[0]),
        .spi_clk_oe_o(spi_clk_oe[0]),
        .spi_ss_i   (spi_ss_in[0]),
        .spi_ss_o   (spi_ss_out[0]),
        .spi_ss_oe_o(spi_ss_oe[0]),
        .spi_dq0_i  (spi_dq_in[0][0]),
        .spi_dq0_o  (spi_dq_out[0][0]),
        .spi_dq0_oe_o(spi_dq_oe[0][0]),
        .spi_dq1_i  (spi_dq_in[0][1]),
        .spi_dq1_o  (spi_dq_out[0][1]),
        .spi_dq1_oe_o(spi_dq_oe[0][1]),
        .spi_dq2_i  (spi_dq_in[0][2]),
        .spi_dq2_o  (spi_dq_out[0][2]),
        .spi_dq2_oe_o(spi_dq_oe[0][2]),
        .spi_dq3_i  (spi_dq_in[0][3]),
        .spi_dq3_o  (spi_dq_out[0][3]),
        .spi_dq3_oe_o(spi_dq_oe[0][3]),
        .irq_o      (spi0_irq),
        .req_i      (slave_req[Spi0]),
        .we_i       (slave_we[Spi0]),
        .be_i       (slave_be[Spi0]),
        .addr_i     (slave_addr[Spi0]),
        .data_i     (slave_wdata[Spi0]),
        .gnt_o      (slave_gnt[Spi0]),
        .rvalid_o   (slave_rvalid[Spi0]),
        .data_o     (slave_rdata[Spi0])
    );

    // PINMUX模块
    assign slave_addr_mask[Pinmux] = `PINMUX_ADDR_MASK;
    assign slave_addr_base[Pinmux] = `PINMUX_ADDR_BASE;
    pinmux_top #(
        .GPIO_NUM(GPIO_NUM),
        .I2C_NUM(I2C_NUM),
        .UART_NUM(1),
        .SPI_NUM(1)
    ) u_pinmux (
        .clk_i          (clk),
        .rst_ni         (rst_ni),
        .gpio_oe_i      (gpio_oe),
        .gpio_val_i     (gpio_data_out),
        .gpio_val_o     (gpio_data_in),
        .i2c_sda_oe_i   (i2c_sda_oe),
        .i2c_sda_val_i  (i2c_sda_out),
        .i2c_sda_val_o  (i2c_sda_in),
        .i2c_scl_oe_i   (i2c_scl_oe),
        .i2c_scl_val_i  (i2c_scl_out),
        .i2c_scl_val_o  (i2c_scl_in),
        .uart_tx_oe_i   ({1'b1}),
        .uart_tx_val_i  (uart_tx_int),
        .uart_tx_val_o  (),
        .uart_rx_oe_i   ({1'b0}),
        .uart_rx_val_i  (),
        .uart_rx_val_o  (uart_rx_int),
        .spi_clk_oe_i   (spi_clk_oe),
        .spi_clk_val_i  (spi_clk_out),
        .spi_clk_val_o  (spi_clk_in),
        .spi_ss_oe_i    (spi_ss_oe),
        .spi_ss_val_i   (spi_ss_out),
        .spi_ss_val_o   (spi_ss_in),
        .spi_dq_oe_i    (spi_dq_oe),
        .spi_dq_val_i   (spi_dq_out),
        .spi_dq_val_o   (spi_dq_in),
        .io_val_i       (io_data_in),
        .io_val_o       (io_data_out),
        .io_oe_o        (io_oe),
        .req_i          (slave_req[Pinmux]),
        .we_i           (slave_we[Pinmux]),
        .be_i           (slave_be[Pinmux]),
        .addr_i         (slave_addr[Pinmux]),
        .data_i         (slave_wdata[Pinmux]),
        .gnt_o          (slave_gnt[Pinmux]),
        .rvalid_o       (slave_rvalid[Pinmux]),
        .data_o         (slave_rdata[Pinmux])
    );

    // xip模块
    assign slave_addr_mask[Xip] = `XIP_ADDR_MASK;
    assign slave_addr_base[Xip] = `XIP_ADDR_BASE;
    xip_top u_xip (
        .clk_i          (clk),
        .rst_ni         (rst_ni),
        .spi_clk_o      (flash_spi_clk_pin),
        .spi_clk_oe_o   (),
        .spi_ss_o       (flash_spi_ss_pin),
        .spi_ss_oe_o    (),
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
        .spi_dq3_oe_o   (flash_spi_dq_oe[3]),
        .req_i          (slave_req[Xip]),
        .we_i           (slave_we[Xip]),
        .be_i           (slave_be[Xip]),
        .addr_i         (slave_addr[Xip]),
        .data_i         (slave_wdata[Xip]),
        .gnt_o          (slave_gnt[Xip]),
        .rvalid_o       (slave_rvalid[Xip]),
        .data_o         (slave_rdata[Xip])
    );

    // bootrom模块
    assign slave_addr_mask[Bootrom] = `BOOTROM_ADDR_MASK;
    assign slave_addr_base[Bootrom] = `BOOTROM_ADDR_BASE;
    bootrom_top u_bootrom(
        .clk_i   (clk),
        .rst_ni  (rst_ni),
        .req_i   (slave_req[Bootrom]),
        .we_i    (slave_we[Bootrom]),
        .be_i    (slave_be[Bootrom]),
        .addr_i  (slave_addr[Bootrom]),
        .data_i  (slave_wdata[Bootrom]),
        .gnt_o   (slave_gnt[Bootrom]),
        .rvalid_o(slave_rvalid[Bootrom]),
        .data_o  (slave_rdata[Bootrom])
    );

    // 保留端口
    assign slave_gnt[Reserved] = 0;
    assign slave_rvalid[Reserved] = 0;
    assign slave_rdata[Reserved] = 0;

    // 中断源
    always @ (*) begin
        irq_src     = 32'h0;
        irq_src[ 0] = timer0_irq;
        irq_src[ 1] = uart0_irq;
        irq_src[ 2] = gpio0_irq;
        irq_src[ 3] = gpio1_irq;
        irq_src[ 4] = i2c0_irq;
        irq_src[ 5] = spi0_irq;
        irq_src[ 6] = gpio2_4_irq;
        irq_src[ 7] = gpio5_7_irq;
        irq_src[ 8] = gpio8_irq;
        irq_src[ 9] = gpio9_irq;
        irq_src[10] = gpio10_12_irq;
        irq_src[11] = gpio13_15_irq;
    end
`endif

endmodule