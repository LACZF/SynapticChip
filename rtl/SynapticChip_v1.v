`ifndef BOOT_TYPE
`define BOOT_TYPE 0
`endif

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

    input  wire                         ext_buad_sample_valid_i,
    input  wire [7:0]                   ext_buad_reg_i,
    input  wire [7:0]                   ext_sample_reg_i,

    input  wire [3:0]                   gpio_in,
    output wire [3:0]                   gpio_out,

    input  wire                         jtag_tck_pin,
    input  wire                         jtag_tms_pin,
    input  wire                         jtag_tdi_pin,
    output wire                         jtag_tdo_pin
);
    localparam TRACE_ENABLE              = 0;
    localparam CPU_NUM                   = 1;
    localparam ROM_DEPTH                 = 1024;
    localparam RAM_DEPTH                 = 256;   // 修改RAM大小要修改program.s和uarta_boot.s中对应的sp基地值
    localparam ADDR_WIDTH                = 32;
    localparam DATA_WIDTH                = 32;
    localparam PE_ARRAY_X                = 16;
    localparam PE_ARRAY_Y                = 16;
    localparam BOOT_TYPE                 = `BOOT_TYPE;
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
    localparam GPIO_IN_NUM               = 4;
    localparam GPIO_OUT_NUM              = 4;
    localparam GPIO_INOUT_NUM            = 1;
    localparam I2C_NUM                   = 2;
    localparam UART_NUM                  = 3;
    localparam SPI_NUM                   = 1;

    wire                                 apb_psel;
    wire                                 apb_penable;
    wire [31:0]                          apb_paddr;
    wire                                 apb_pwrite;
    wire [31:0]                          apb_pwdata;
    wire [31:0]                          apb_prdata;
    wire                                 apb_pready;
    wire                                 apb_pslverr;

    wire                                 obi_we;
    wire [DATA_WIDTH-1:0]                obi_wdata;

    wire [SPI_NUM-1:0]                   spi_cs_n;
    wire                                 spi_clk;
    wire                                 spi_mosi;
    wire                                 spi_miso;

    wire [3:0]                           qspi_flash_dq_in;
    wire [3:0]                           qspi_flash_dq_out;
    wire [3:0]                           qspi_flash_dq_oe;
    wire                                 qspi_flash_clk_pin;
    wire                                 qspi_flash_ss_pin;

    wire                                 spi_flash_cs_n;
    wire                                 spi_flash_clk;
    wire                                 spi_flash_mosi;
    wire                                 spi_flash_miso;

    wire                                 spi_flash_wp;
    wire                                 spi_flash_sio3;

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
        .obi_we_o     (obi_we),
        .obi_addr_o   (obi_addr_o),
        .obi_wdata_o  (obi_wdata),
        .obi_gnt_i    (obi_gnt_i),
        .obi_rvalid_i (obi_rvalid_i),
        .obi_rdata_i  (obi_rdata_i),

        .apb_psel_o   (apb_psel),
        .apb_penable_o(apb_penable),
        .apb_paddr_o  (apb_paddr),
        .apb_pwrite_o (apb_pwrite),
        .apb_pwdata_o (apb_pwdata),
        .apb_prdata_i (32'b0),
        .apb_pready_i (1'b0),

        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx),

        .ext_buad_sample_valid_i (ext_buad_sample_valid_i),
        .ext_buad_reg_i          (ext_buad_reg_i),
        .ext_sample_reg_i        (ext_sample_reg_i),

        .gpio_in      (gpio_in),
        .gpio_out     (gpio_out),

        .spi_cs_n    (spi_cs_n),
        .spi_clk     (spi_clk),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),

        .qspi_flash_dq_in   (qspi_flash_dq_in),
        .qspi_flash_dq_out  (qspi_flash_dq_out),
        .qspi_flash_dq_oe   (qspi_flash_dq_oe),
        .qspi_flash_clk_pin (qspi_flash_clk_pin),
        .qspi_flash_ss_pin  (qspi_flash_ss_pin),

        .spi_flash_cs_n     (spi_flash_cs_n),
        .spi_flash_clk      (spi_flash_clk),
        .spi_flash_mosi     (spi_flash_mosi),
        .spi_flash_miso     (spi_flash_miso),

        .jtag_tck_pin (jtag_tck_pin),
        .jtag_tms_pin (jtag_tms_pin),
        .jtag_tdi_pin (jtag_tdi_pin),
        .jtag_tdo_pin (jtag_tdo_pin)
    );
endmodule
