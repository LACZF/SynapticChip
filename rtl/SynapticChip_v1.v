module SynapticChip (
    input  wire                         clk,
    input  wire                         rst_n,

    output wire                         obi_req_o,
    output wire [31:0]                  obi_addr_o,
    input  wire                         obi_gnt_i,
    input  wire                         obi_rvalid_i,
    input  wire [31:0]                  obi_rdata_i,

    input  wire                         uart_rx,
    output wire                         uart_tx,

    inout  wire [7:0]                   gpio_io,

    input  wire                         jtag_tck_pin,
    input  wire                         jtag_tms_pin,
    input  wire                         jtag_tdi_pin,
    output wire                         jtag_tdo_pin
);
    localparam TRACE_ENABLE              = 0;
    localparam CPU_NUM                   = 1;
    localparam ROM_DEPTH                 = 1024;
    localparam RAM_DEPTH                 = 512;
    localparam ADDR_WIDTH                = 32;
    localparam DATA_WIDTH                = 32;
    localparam PE_ARRAY_X                = 16;
    localparam PE_ARRAY_Y                = 16;
    localparam BOOT_TYPE                 = 4;
    localparam IMPLEMENT_JTAG            = 1;
    localparam IMPLEMENT_UART            = 1;
    localparam IMPLEMENT_GPIO            = 1;
    localparam IMPLEMENT_SPI             = 0;
    localparam IMPLEMENT_XIP             = 0;
    localparam IMPLEMENT_SPI_FLASH       = 0;
    localparam IMPLEMENT_TIMER           = 1;
    localparam IMPLEMENT_I2C             = 0;
    localparam IMPLEMENT_EXT_OBI         = 1;
    localparam IMPLEMENT_EXT_APB         = 0;
    localparam GPIO_IN_NUM               = 1;
    localparam GPIO_OUT_NUM              = 1;
    localparam GPIO_INOUT_NUM            = 8;
    localparam I2C_NUM                   = 2;
    localparam UART_NUM                  = 3;
    localparam SPI_NUM                   = 1;

    chip_top #(
        .TRACE_ENABLE(TRACE_ENABLE),
        .CPU_NUM(CPU_NUM),
        .ROM_DEPTH(ROM_DEPTH),
        .RAM_DEPTH(RAM_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PE_ARRAY_X(PE_ARRAY_X),
        .PE_ARRAY_Y(PE_ARRAY_Y),
        .BOOT_TYPE(BOOT_TYPE),
        .IMPLEMENT_JTAG(IMPLEMENT_JTAG),
        .IMPLEMENT_UART(IMPLEMENT_UART),
        .IMPLEMENT_GPIO(IMPLEMENT_GPIO),
        .IMPLEMENT_SPI(IMPLEMENT_SPI),
        .IMPLEMENT_XIP(IMPLEMENT_XIP),
        .IMPLEMENT_SPI_FLASH(IMPLEMENT_SPI_FLASH),
        .IMPLEMENT_TIMER(IMPLEMENT_TIMER),
        .IMPLEMENT_I2C(IMPLEMENT_I2C),
        .IMPLEMENT_EXT_OBI(IMPLEMENT_EXT_OBI),
        .GPIO_IN_NUM(GPIO_IN_NUM),
        .GPIO_OUT_NUM(GPIO_OUT_NUM),
        .GPIO_INOUT_NUM(GPIO_INOUT_NUM),
        .I2C_NUM(I2C_NUM),
        .UART_NUM(UART_NUM),
        .SPI_NUM(SPI_NUM)
    ) u_chip_top (
        .clk         (clk),
        .rst_n       (rst_n),

        .obi_req_o    (obi_req_o),
        .obi_we_o     (),
        .obi_addr_o   (obi_addr_o),
        .obi_wdata_o  (),
        .obi_gnt_i    (obi_gnt_i),
        .obi_rvalid_i (obi_rvalid_i),
        .obi_rdata_i  (obi_rdata_i),

        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx),

        .gpio_in      ({GPIO_IN_NUM{1'b0}}),
        .gpio_out     (),
        .gpio_io      (gpio_io),

        .jtag_tck_pin (jtag_tck_pin),
        .jtag_tms_pin (jtag_tms_pin),
        .jtag_tdi_pin (jtag_tdi_pin),
        .jtag_tdo_pin (jtag_tdo_pin)
    );
endmodule
