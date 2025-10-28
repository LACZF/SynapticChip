`include "stddef.v"
`include "global_config.v"

`include "defines.sv"
`include "jtag_def.sv"

module chip_top #(
    parameter TRACE_ENABLE              = 0,
    parameter CPU_NUM                   = 1,
    parameter IMPLEMENT_ROM             = 1,
    parameter IMPLEMENT_JTAG            = 0,
    parameter IMPLEMENT_UART            = 1,
    parameter IMPLEMENT_GPIO            = 1,
    parameter IMPLEMENT_SPI             = 0,
    parameter IMPLEMENT_TIMER           = 1,
    parameter IMPLEMENT_I2C             = 1,
    parameter GPIO_NUM                  = 16,
    parameter I2C_NUM                   = 2,
    parameter UART_NUM                  = 3,
    parameter SPI_NUM                   = 1
)(
    input  wire                         clk,
    input  wire                         rst_n,

    /********** UART  **********/
    input  wire                         uart_rx,
    output wire                         uart_tx,

    /********** GPIO  **********/
    input  wire [GPIO_NUM-1:0]          gpio_in,
    output wire [GPIO_NUM-1:0]          gpio_out,
    inout  wire [GPIO_NUM-1:0]          gpio_io,

    /********** SPI **********/
    output wire                         spi_cs_n,
    output wire                         spi_clk,
    output wire                         spi_mosi,
    input  wire                         spi_miso,

    /********** JTAG **********/
    input  wire                         jtag_tck_pin,
    input  wire                         jtag_tms_pin,
    input  wire                         jtag_tdi_pin,
    output wire                         jtag_tdo_pin
);
    /* (instruction + data) * CPU_NUM + jtag */
    localparam int MASTERS      = CPU_NUM * 2 + 1;
    localparam int SLAVES       = 18; // Number of slave ports

    // masters
    localparam int JtagHost     = 0;

    // slaves
    localparam int Rom          = 0;
    localparam int Ram          = 1;
    localparam int JtagDevice   = 2;

    wire           master_req       [MASTERS];
    wire           master_gnt       [MASTERS];
    wire           master_rvalid    [MASTERS];
    wire [31:0]    master_addr      [MASTERS];
    wire           master_we        [MASTERS];
    wire [ 3:0]    master_be        [MASTERS];
    wire [31:0]    master_rdata     [MASTERS];
    wire [31:0]    master_wdata     [MASTERS];

    wire           slave_req        [SLAVES];
    wire           slave_gnt        [SLAVES];
    wire           slave_rvalid     [SLAVES];
    wire [31:0]    slave_addr       [SLAVES];
    wire           slave_we         [SLAVES];
    wire [ 3:0]    slave_be         [SLAVES];
    wire [31:0]    slave_rdata      [SLAVES];
    wire [31:0]    slave_wdata      [SLAVES];

    wire [31:0]    slave_addr_mask  [SLAVES];
    wire [31:0]    slave_addr_base  [SLAVES];

    wire ndmreset;
    wire ndmreset_n;
    wire debug_req;
    wire core_halted;

    wire[3:0]         flash_spi_dq_in;
    wire[3:0]         flash_spi_dq_oe;
    wire[3:0]         flash_spi_dq_out;
    wire              flash_spi_clk_pin;
    wire              flash_spi_ss_pin;

    // 中断相关信号
    wire timer0_irq;
    wire uart0_irq;
    wire gpio0_irq;
    wire gpio1_irq;
    wire i2c0_irq;
    wire spi0_irq;
    wire gpio2_4_irq;
    wire gpio5_7_irq;
    wire gpio8_irq;
    wire gpio9_irq;
    wire gpio10_12_irq;
    wire gpio13_15_irq;
    reg [31:0] irq_src;
    wire int_req;
    wire[7:0] int_id;

    // CPU实例化
    generate
        genvar i;
        for (i = 0; i < CPU_NUM; i = i + 1) begin : cpu_gen
            assign master_we[2*i + 1] = '0;
            assign master_be[2*i + 1] = '0;
            tinyriscv_core #(
                .DEBUG_HALT_ADDR(`DEBUG_ADDR_BASE + `HaltAddress),
                .DEBUG_EXCEPTION_ADDR(`DEBUG_ADDR_BASE + `ExceptionAddress),
                .BranchPredictor(1'b1),
                .TRACE_ENABLE(TRACE_ENABLE)
            ) u_tinyriscv_core (
                .clk            (clk),
                .rst_n          (ndmreset_n),

                .instr_req_o    (master_req[2*i + 1]),
                .instr_gnt_i    (master_gnt[2*i + 1]),
                .instr_rvalid_i (master_rvalid[2*i + 1]),
                .instr_addr_o   (master_addr[2*i + 1]),
                .instr_rdata_i  (master_rdata[2*i + 1]),
                .instr_err_i    (1'b0),

                .data_req_o     (master_req[2*i]),
                .data_gnt_i     (master_gnt[2*i]),
                .data_rvalid_i  (master_rvalid[2*i]),
                .data_we_o      (master_we[2*i]),
                .data_be_o      (master_be[2*i]),
                .data_addr_o    (master_addr[2*i]),
                .data_wdata_o   (master_wdata[2*i]),
                .data_rdata_i   (master_rdata[2*i]),
                .data_err_i     (1'b0),

                .int_req_i      (int_req),
                .int_id_i       (int_id),

                .debug_req_i    (debug_req)
            );
        end

        // 将未使用的总线主控信号接地
        for (i = CPU_NUM * 2 + 1; i < MASTERS; i = i + 1) begin : unused_master_gen
            assign master_req[i]    = 0;
            assign master_gnt[i]    = 0;
            assign master_rvalid[i] = 0;
            assign master_addr[i]   = 0;
            assign master_we[i]     = 0;
            assign master_be[i]     = 0;
            assign master_rdata[i]  = 0;
            assign master_wdata[i]  = 0;
        end
    endgenerate

`ifdef SUPPORT_ROM
    assign slave_addr_mask[Rom] = `ROM_ADDR_MASK;
    assign slave_addr_base[Rom] = `ROM_ADDR_BASE;
    // 指令存储器
    rom #(
        .DP(`ROM_DEPTH)
    ) u_rom (
        .clk_i      (clk),
        .rst_ni     (ndmreset_n),
        .req_i      (slave_req[Rom]),
        .addr_i     (slave_addr[Rom]),
        .data_i     (slave_wdata[Rom]),
        .be_i       (slave_be[Rom]),
        .we_i       (slave_we[Rom]),
        .gnt_o      (slave_gnt[Rom]),
        .rvalid_o   (slave_rvalid[Rom]),
        .data_o     (slave_rdata[Rom])
    );

    assign slave_addr_mask[Ram] = `RAM_ADDR_MASK;
    assign slave_addr_base[Ram] = `RAM_ADDR_BASE;
`else
    `define ALL_ADDR_MASK       ~32'hfffff
    `define ALL_ADDR_BASE       32'h00000000
    assign slave_addr_mask[Ram] = `ALL_ADDR_MASK;
    assign slave_addr_base[Ram] = `ALL_ADDR_BASE;
`endif

    // 数据存储器
    ram #(
        .DP(`RAM_DEPTH)
    ) u_ram (
        .clk_i      (clk),
        .rst_ni     (ndmreset_n),
        .req_i      (slave_req[Ram]),
        .addr_i     (slave_addr[Ram]),
        .data_i     (slave_wdata[Ram]),
        .be_i       (slave_be[Ram]),
        .we_i       (slave_we[Ram]),
        .gnt_o      (slave_gnt[Ram]),
        .rvalid_o   (slave_rvalid[Ram]),
        .data_o     (slave_rdata[Ram])
    );

    io_module #(
        .GPIO_NUM(GPIO_NUM),
        .IMPLEMENT_JTAG(IMPLEMENT_JTAG),
        .IMPLEMENT_UART(IMPLEMENT_UART),
        .IMPLEMENT_GPIO(IMPLEMENT_GPIO),
        .IMPLEMENT_SPI(IMPLEMENT_SPI),
        .IMPLEMENT_TIMER(IMPLEMENT_TIMER),
        .IMPLEMENT_I2C(IMPLEMENT_I2C),
        .I2C_NUM(I2C_NUM),
        .UART_NUM(UART_NUM),
        .SPI_NUM(SPI_NUM)
    ) u_io_module (
        .clk                (clk),
        .rst_ni             (ndmreset_n),

        // 中断源信号
        .timer0_irq         (timer0_irq),
        .uart0_irq          (uart0_irq),
        .gpio0_irq          (gpio0_irq),
        .gpio1_irq          (gpio1_irq),
        .i2c0_irq           (i2c0_irq),
        .spi0_irq           (spi0_irq),
        .gpio2_4_irq        (gpio2_4_irq),
        .gpio5_7_irq        (gpio5_7_irq),
        .gpio8_irq          (gpio8_irq),
        .gpio9_irq          (gpio9_irq),
        .gpio10_12_irq      (gpio10_12_irq),
        .gpio13_15_irq      (gpio13_15_irq),

        // GPIO相关信号
        .gpio_pins          (gpio_io),

        // UART相关信号
        .uart_rx_int        (uart_rx),
        .uart_tx_int        (uart_tx),

        // SPI相关信号
        .spi_clk_in_int     (spi_clk),
        .spi_clk_out_int    (spi_clk),
        .spi_clk_oe_int     (),
        .spi_ss_in_int      (spi_cs_n),
        .spi_ss_out_int     (spi_cs_n),
        .spi_ss_oe_int      (),
        .spi_dq_in_int      ({3'b0, spi_miso}),
        .spi_dq_out_int     (),
        .spi_dq_oe_int      (),

        // I2C相关信号
        .i2c_scl_in_int     (),
        .i2c_scl_out_int    (),
        .i2c_scl_oe_int     (),
        .i2c_sda_in_int     (),
        .i2c_sda_out_int    (),
        .i2c_sda_oe_int     (),

        // XIP相关信号
        .flash_spi_clk_pin  (flash_spi_clk_pin),
        .flash_spi_ss_pin   (flash_spi_ss_pin),
        .flash_spi_dq_in    (flash_spi_dq_in),
        .flash_spi_dq_out   (flash_spi_dq_out),
        .flash_spi_dq_oe    (flash_spi_dq_oe),

        // 将所有slave信号传递给IO模块
        .slave_req          (slave_req),
        .slave_gnt          (slave_gnt),
        .slave_rvalid       (slave_rvalid),
        .slave_addr         (slave_addr),
        .slave_we           (slave_we),
        .slave_be           (slave_be),
        .slave_wdata        (slave_wdata),
        .slave_rdata        (slave_rdata)
    );

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

    // 内部总线
    obi_interconnect #(
        .MASTERS(MASTERS),
        .SLAVES(SLAVES)
    ) bus (
        .clk_i              (clk),
        .rst_ni             (ndmreset_n),
        .master_req_i       (master_req),
        .master_gnt_o       (master_gnt),
        .master_rvalid_o    (master_rvalid),
        .master_we_i        (master_we),
        .master_be_i        (master_be),
        .master_addr_i      (master_addr),
        .master_wdata_i     (master_wdata),
        .master_rdata_o     (master_rdata),
        .slave_addr_mask_i  (slave_addr_mask),
        .slave_addr_base_i  (slave_addr_base),
        .slave_req_o        (slave_req),
        .slave_gnt_i        (slave_gnt),
        .slave_rvalid_i     (slave_rvalid),
        .slave_we_o         (slave_we),
        .slave_be_o         (slave_be),
        .slave_addr_o       (slave_addr),
        .slave_wdata_o      (slave_wdata),
        .slave_rdata_i      (slave_rdata)
    );

    // 复位信号产生
    rst_gen #(
        .RESET_FIFO_DEPTH(5)
    ) u_rst (
        .clk    (clk),
        .rst_ni (rst_n & (~ndmreset)),
        .rst_no (ndmreset_n)
    );

`ifdef IMPLEMENT_JTAG
    assign slave_addr_mask[JtagDevice] = `DEBUG_ADDR_MASK;
    assign slave_addr_base[JtagDevice] = `DEBUG_ADDR_BASE;
    // JTAG模块
    jtag_top #(

    ) u_jtag (
        .clk_i              (clk),
        .rst_ni             (rst_n),
        .debug_req_o        (debug_req),
        .ndmreset_o         (ndmreset),
        .halted_o           (core_halted),
        .jtag_tck_i         (jtag_TCK_pin),
        .jtag_tdi_i         (jtag_TDI_pin),
        .jtag_tms_i         (jtag_TMS_pin),
        .jtag_trst_ni       (rst_n),
        .jtag_tdo_o         (jtag_TDO_pin),
        .master_req_o       (master_req[JtagHost]),
        .master_gnt_i       (master_gnt[JtagHost]),
        .master_rvalid_i    (master_rvalid[JtagHost]),
        .master_we_o        (master_we[JtagHost]),
        .master_be_o        (master_be[JtagHost]),
        .master_addr_o      (master_addr[JtagHost]),
        .master_wdata_o     (master_wdata[JtagHost]),
        .master_rdata_i     (master_rdata[JtagHost]),
        .master_err_i       (1'b0),
        .slave_req_i        (slave_req[JtagDevice]),
        .slave_we_i         (slave_we[JtagDevice]),
        .slave_addr_i       (slave_addr[JtagDevice]),
        .slave_be_i         (slave_be[JtagDevice]),
        .slave_wdata_i      (slave_wdata[JtagDevice]),
        .slave_gnt_o        (slave_gnt[JtagDevice]),
        .slave_rvalid_o     (slave_rvalid[JtagDevice]),
        .slave_rdata_o      (slave_rdata[JtagDevice])
    );
`endif

endmodule