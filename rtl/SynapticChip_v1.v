`ifndef BOOT_TYPE
`define BOOT_TYPE 2
`endif

`ifndef EXT_BUAD_SAMPLE_VALID
`define EXT_BUAD_SAMPLE_VALID 1'b0
`endif
`ifndef EXT_SAMPLE_REG
`define EXT_SAMPLE_REG        16
`endif
`ifndef EXT_BUAD_REG
`define EXT_BUAD_REG          (100_000_000 / 115_200 / 2 / `EXT_SAMPLE_REG)
`endif

module ip4_SynapticChip (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire                         uart_rx,
    output wire                         uart_tx,

    input  wire                         gpio_in0,
    input  wire                         gpio_in1,
    input  wire                         gpio_in2,
    input  wire                         gpio_in3,
    output wire                         gpio_out0,
    output wire                         gpio_out1,
    output wire                         gpio_out2,
    output wire                         gpio_out3,

    input  wire                         jtag_tck_pin,
    input  wire                         jtag_tms_pin,
    input  wire                         jtag_tdi_pin,
    output wire                         jtag_tdo_pin
);
    localparam TRACE_ENABLE              = 0;
    localparam CPU_NUM                   = 1;
    localparam ROM_DEPTH                 = 768;
    localparam RAM_DEPTH                 = 256;   // 修改RAM大小要修改program.s和uarta_boot.s中对应的sp基地值
    localparam ADDR_WIDTH                = 32;
    localparam DATA_WIDTH                = 32;
    localparam PE_ARRAY_X                = 3;
    localparam PE_ARRAY_Y                = 3;
    localparam BOOT_TYPE                 = `BOOT_TYPE;
    localparam IMPLEMENT_JTAG            = 1;
    localparam IMPLEMENT_UART            = 1;
    localparam IMPLEMENT_GPIO            = 1;
    localparam IMPLEMENT_SPI             = 0;
    localparam IMPLEMENT_XIP             = 0;
    localparam IMPLEMENT_SPI_FLASH       = 1;
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

    wire                                 obi_req;
    wire                                 obi_we;
    wire [31:0]                          obi_addr;
    wire [DATA_WIDTH-1:0]                obi_wdata;
    wire                                 obi_gnt;
    wire                                 obi_rvalid;
    wire [31:0]                          obi_rdata;

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

    wire [3:0]                           chip_gpio_in;
    wire [3:0]                           chip_gpio_out;

    /*
     * spi flash启动场景，将gpio到信号修改为spi flash使用：
     * 1. gpio_in[3]     -> spi_flash_miso
     * 2. spi_flash_cs_n -> gpio_out[3]
     * 3. spi_flash_clk  -> gpio_out[2]
     * 4. spi_flash_mosi -> gpio_out[1]
     */
    if (BOOT_TYPE == 2) begin
        assign gpio_out3          = spi_flash_cs_n;
        assign gpio_out2          = spi_flash_clk;
        assign gpio_out1          = spi_flash_mosi;
        assign gpio_out0          = chip_gpio_out[0];
        assign spi_flash_miso     = gpio_in3;
        assign chip_gpio_in       = {1'b0, gpio_in2, gpio_in1, gpio_in0};
    end else begin
        assign chip_gpio_in       = {gpio_in3, gpio_in2, gpio_in1, gpio_in0};
        assign gpio_out3          = chip_gpio_out[3];
        assign gpio_out2          = chip_gpio_out[2];
        assign gpio_out1          = chip_gpio_out[1];
        assign gpio_out0          = chip_gpio_out[0];
    end

    ip4_chip_top #(
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

        .obi_req_o    (obi_req),
        .obi_we_o     (obi_we),
        .obi_addr_o   (obi_addr),
        .obi_wdata_o  (obi_wdata),
        .obi_gnt_i    (obi_gnt),
        .obi_rvalid_i (obi_rvalid),
        .obi_rdata_i  (obi_rdata),

        .apb_psel_o   (apb_psel),
        .apb_penable_o(apb_penable),
        .apb_paddr_o  (apb_paddr),
        .apb_pwrite_o (apb_pwrite),
        .apb_pwdata_o (apb_pwdata),
        .apb_prdata_i (32'b0),
        .apb_pready_i (1'b0),

        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx),

        .ext_buad_sample_valid_i (1'(`EXT_BUAD_SAMPLE_VALID)),
        .ext_buad_reg_i          (8'(`EXT_BUAD_REG)),
        .ext_sample_reg_i        (8'(`EXT_SAMPLE_REG)),

        .gpio_in      (chip_gpio_in),
        .gpio_out     (chip_gpio_out),

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
