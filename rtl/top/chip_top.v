
`include "common.v"

`include "jtag_def.sv"

`include "defines.sv"

module chip_top #(
    parameter TRACE_ENABLE              = 0,
    parameter CPU_NUM                   = 1,
    parameter ROM_DEPTH                 = 1024,
    parameter RAM_DEPTH                 = 1024,
    parameter ADDR_WIDTH                = 32,
    parameter DATA_WIDTH                = 32,
    parameter NUM_PES                   = 4,
    parameter INST_WIDTH                = 32,
    parameter PE_ID_WIDTH               = 4,
    parameter PE_ARRAY_ROWS             = 2,
    parameter PE_ARRAY_COLS             = 2,
    parameter IMPLEMENT_ROM             = 1,
    parameter IMPLEMENT_UART            = 1,
    parameter IMPLEMENT_GPIO            = 1,
    parameter IMPLEMENT_SPI             = 0,
    parameter IMPLEMENT_FLASH           = 0,
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
    output wire [SPI_NUM-1:0]           spi_cs_n,
    output wire                         spi_clk,
    output wire                         spi_mosi,
    input  wire                         spi_miso,

    /********** FLASH **********/
    input  wire[3:0]                    flash_spi_dq_in,
    output wire[3:0]                    flash_spi_dq_oe,
    output wire[3:0]                    flash_spi_dq_out,
    output wire                         flash_spi_clk_pin,
    output wire                         flash_spi_ss_pin,

    /********** JTAG **********/
    input  wire                         jtag_tck_pin,
    input  wire                         jtag_tms_pin,
    input  wire                         jtag_tdi_pin,
    output wire                         jtag_tdo_pin
);
    /* (instruction + data) * CPU_NUM + jtag */
    localparam int MASTERS                  = (CPU_NUM * 2 + 1);
    localparam int SLAVES                   = 18; // Number of slave ports

    // slaves
    localparam int SLAVE_ROM_INDEX          = 0;
    localparam int SLAVE_RAM_INDEX          = 1;
    localparam int SLAVE_JTAG_INDEX         = 2;
    localparam int SLAVE_PE_TOP_INDEX       = 3;
    localparam int SLAVE_IO_START_INDEX     = SLAVE_PE_TOP_INDEX + 1;

    localparam int ROM_ADDR_BASE            = 32'h00000000;
    localparam int ROM_ADDR_MASK            = `CALC_ADDR_MASK_BY_LENGTH(ROM_ADDR_BASE, ROM_DEPTH * 4);

    localparam int DEBUG_ADDR_BASE          = 32'h10000000;
    localparam int DEBUG_ADDR_MASK          = `CALC_ADDR_MASK_BY_LENGTH(DEBUG_ADDR_BASE, 8*1024);

    localparam int RAM_ADDR_BASE            = 32'h20000000;
    localparam int RAM_ADDR_MASK            = `CALC_ADDR_MASK_BY_LENGTH(RAM_ADDR_BASE, RAM_DEPTH * 4);

    localparam int PE_ADDR_BASE             = 32'h30000000;
    localparam int PE_ADDR_MASK             = `CALC_ADDR_MASK_BY_LENGTH(PE_ADDR_BASE, 1 * 1024 * 1024);

    localparam int IO_ADDR_BASE             = 32'h40000000;
    localparam int IO_ADDR_MASK             = `CALC_ADDR_MASK_BY_END_ADDR(IO_ADDR_BASE, 32'h4FFFFFFF);

    localparam int SLAVE_TIMER_INDEX        = SLAVE_IO_START_INDEX + 0;
    localparam int SLAVE_GPIO_INDEX         = SLAVE_IO_START_INDEX + 1;
    localparam int SLAVE_UART_INDEX         = SLAVE_IO_START_INDEX + 2;
    localparam int SLAVE_SPI_INDEX          = SLAVE_IO_START_INDEX + 3;
    localparam int SLAVE_FLASH_INDEX        = SLAVE_IO_START_INDEX + 4;

    localparam int TIMER_ADDR_BASE          = IO_ADDR_BASE + 32'h00010000;
    localparam int TIMER_ADDR_MASK          = `CALC_ADDR_MASK_BY_LENGTH(TIMER_ADDR_BASE, 4096);

    localparam int UART_ADDR_BASE           = IO_ADDR_BASE + 32'h00020000;
    localparam int UART_ADDR_MASK           = `CALC_ADDR_MASK_BY_LENGTH(UART_ADDR_BASE, 4096);

    localparam int GPIO_ADDR_BASE           = IO_ADDR_BASE + 32'h00030000;
    localparam int GPIO_ADDR_MASK           = `CALC_ADDR_MASK_BY_LENGTH(GPIO_ADDR_BASE, 4096);

    localparam int SPI_ADDR_BASE            = IO_ADDR_BASE + 32'h00040000;
    localparam int SPI_ADDR_MASK            = `CALC_ADDR_MASK_BY_LENGTH(SPI_ADDR_BASE, 4096);

    localparam int XIP_ADDR_BASE            = IO_ADDR_BASE + 32'h00050000;
    localparam int XIP_ADDR_MASK            = `CALC_ADDR_MASK_BY_LENGTH(XIP_ADDR_BASE, 4096);

    wire [MASTERS-1:0]                      master_req;
    wire [MASTERS-1:0]                      master_gnt;
    wire [MASTERS-1:0]                      master_rvalid;
    wire [MASTERS-1:0][31:0]                master_addr;
    wire [MASTERS-1:0]                      master_we;
    wire [MASTERS-1:0][ 3:0]                master_be;
    wire [MASTERS-1:0][31:0]                master_rdata;
    wire [MASTERS-1:0][31:0]                master_wdata;

    wire [SLAVES-1:0]                       slave_req;
    wire [SLAVES-1:0]                       slave_gnt;
    wire [SLAVES-1:0]                       slave_rvalid;
    wire [SLAVES-1:0][31:0]                 slave_addr;
    wire [SLAVES-1:0]                       slave_we;
    wire [SLAVES-1:0][ 3:0]                 slave_be;
    wire [SLAVES-1:0][31:0]                 slave_rdata;
    wire [SLAVES-1:0][31:0]                 slave_wdata;

    wire [SLAVES-1:0][31:0]                 slave_addr_mask;
    wire [SLAVES-1:0][31:0]                 slave_addr_base;

    wire ndmreset;
    wire ndmreset_n;
    wire debug_req;
    wire core_halted;

    // 中断相关信号
    wire int_req;
    wire[7:0] int_id;
    reg [31:0] irq_src;

    // CPU实例化
    generate
        genvar i;
        for (i = 0; i < CPU_NUM; i = i + 1) begin : cpu_gen
            assign master_we[2*i + 1] = '0;
            assign master_be[2*i + 1] = '0;
            tinyriscv_core #(
                .DEBUG_HALT_ADDR(DEBUG_ADDR_BASE + `HaltAddress),
                .DEBUG_EXCEPTION_ADDR(DEBUG_ADDR_BASE + `ExceptionAddress),
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
    endgenerate

    assign slave_addr_mask[SLAVE_ROM_INDEX] = ROM_ADDR_MASK;
    assign slave_addr_base[SLAVE_ROM_INDEX] = ROM_ADDR_BASE;
    // 指令存储器
    rom #(
        .DP(ROM_DEPTH)
    ) u_rom (
        .clk_i      (clk),
        .rst_ni     (ndmreset_n),
        .req_i      (slave_req[SLAVE_ROM_INDEX]),
        .addr_i     (slave_addr[SLAVE_ROM_INDEX]),
        .data_i     (slave_wdata[SLAVE_ROM_INDEX]),
        .be_i       (slave_be[SLAVE_ROM_INDEX]),
        .we_i       (slave_we[SLAVE_ROM_INDEX]),
        .gnt_o      (slave_gnt[SLAVE_ROM_INDEX]),
        .rvalid_o   (slave_rvalid[SLAVE_ROM_INDEX]),
        .data_o     (slave_rdata[SLAVE_ROM_INDEX])
    );

    assign slave_addr_mask[SLAVE_RAM_INDEX] = RAM_ADDR_MASK;
    assign slave_addr_base[SLAVE_RAM_INDEX] = RAM_ADDR_BASE;
    // 数据存储器
    ram #(
        .DP(RAM_DEPTH)
    ) u_ram (
        .clk_i      (clk),
        .rst_ni     (ndmreset_n),
        .req_i      (slave_req[SLAVE_RAM_INDEX]),
        .addr_i     (slave_addr[SLAVE_RAM_INDEX]),
        .data_i     (slave_wdata[SLAVE_RAM_INDEX]),
        .be_i       (slave_be[SLAVE_RAM_INDEX]),
        .we_i       (slave_we[SLAVE_RAM_INDEX]),
        .gnt_o      (slave_gnt[SLAVE_RAM_INDEX]),
        .rvalid_o   (slave_rvalid[SLAVE_RAM_INDEX]),
        .data_o     (slave_rdata[SLAVE_RAM_INDEX])
    );


    assign slave_addr_mask[SLAVE_PE_TOP_INDEX] = PE_ADDR_MASK;
    assign slave_addr_base[SLAVE_PE_TOP_INDEX] = PE_ADDR_BASE;
    // PE_TOP实例化
    pe_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PES(NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS)
    ) u_pe_top (
        .clk        (clk),
        .rst_n      (rst_n),
        .req_i      (slave_req[SLAVE_PE_TOP_INDEX]),
        .we_i       (slave_we[SLAVE_PE_TOP_INDEX]),
        .addr_i     (slave_addr[SLAVE_PE_TOP_INDEX]),
        .wr_data_i  (slave_wdata[SLAVE_PE_TOP_INDEX]),
        .rd_data_o  (slave_rdata[SLAVE_PE_TOP_INDEX]),
        .gnt_o      (slave_gnt[SLAVE_PE_TOP_INDEX]),
        .rvalid_o   (slave_rvalid[SLAVE_PE_TOP_INDEX])
    );

    generate
        if (IMPLEMENT_TIMER) begin
            assign slave_addr_base[SLAVE_TIMER_INDEX] = TIMER_ADDR_BASE;
            assign slave_addr_mask[SLAVE_TIMER_INDEX] = TIMER_ADDR_MASK;
        end
        if (IMPLEMENT_UART) begin
            assign slave_addr_base[SLAVE_UART_INDEX]  = UART_ADDR_BASE;
            assign slave_addr_mask[SLAVE_UART_INDEX]  = UART_ADDR_MASK;
        end
        if (IMPLEMENT_GPIO) begin
            assign slave_addr_base[SLAVE_GPIO_INDEX]  = GPIO_ADDR_BASE;
            assign slave_addr_mask[SLAVE_GPIO_INDEX]  = GPIO_ADDR_MASK;
        end
        if (IMPLEMENT_SPI) begin
            assign slave_addr_base[SLAVE_SPI_INDEX]   = SPI_ADDR_BASE;
            assign slave_addr_mask[SLAVE_SPI_INDEX]   = SPI_ADDR_MASK;
        end
        if (IMPLEMENT_FLASH) begin
            assign slave_addr_base[SLAVE_FLASH_INDEX]  = XIP_ADDR_BASE;
            assign slave_addr_mask[SLAVE_FLASH_INDEX]  = XIP_ADDR_MASK;
        end
    endgenerate

    io_top #(
        .ADDR_WIDTH             (ADDR_WIDTH),
        .DATA_WIDTH             (DATA_WIDTH),
        .SLAVES                 (SLAVES),
        .START_SLAVE            (SLAVE_IO_START_INDEX),
        .IO_ADDR_BASE           (IO_ADDR_BASE),
        .IO_ADDR_MASK           (IO_ADDR_MASK),
        .IMPLEMENT_UART         (IMPLEMENT_UART),
        .IMPLEMENT_GPIO         (IMPLEMENT_GPIO),
        .IMPLEMENT_SPI          (IMPLEMENT_SPI),
        .IMPLEMENT_TIMER        (IMPLEMENT_TIMER),
        .IMPLEMENT_FLASH        (IMPLEMENT_FLASH),
        .SPI_NUM                (SPI_NUM),
        .GPIO_IN_CH             (GPIO_NUM),
        .GPIO_OUT_CH            (GPIO_NUM),
        .GPIO_IO_CH             (GPIO_NUM)
    ) u_io (
        .clk           (clk),
        .rst_n         (rst_n),

        // 总线接口
        .slave_req       (slave_req),
        .slave_gnt       (slave_gnt),
        .slave_rvalid    (slave_rvalid),
        .slave_addr      (slave_addr),
        .slave_we        (slave_we),
        .slave_be        (slave_be),
        .slave_rdata     (slave_rdata),
        .slave_wdata     (slave_wdata),

        .slave_addr_mask (slave_addr_mask),
        .slave_addr_base (slave_addr_base),

        // 中断信号
        .irq_timer     (irq_timer),
        .irq_uart_rx   (irq_uart_rx),
        .irq_uart_tx   (irq_uart_tx),

        // UART接口
        .uart_rx       (uart_rx),
        .uart_tx       (uart_tx),

        // GPIO接口
        .gpio_in       (gpio_in),
        .gpio_out      (gpio_out),
        .gpio_io       (gpio_io),

        // SPI接口
        .spi_cs_n      (spi_cs_n),
        .spi_clk       (spi_clk),
        .spi_mosi      (spi_mosi),
        .spi_miso      (spi_miso),

        // Flash接口
        .flash_spi_clk    (flash_spi_clk_pin),
        .flash_spi_ss     (flash_spi_ss_pin),
        .flash_spi_dq_out (flash_spi_dq_out),
        .flash_spi_dq_oe  (flash_spi_dq_oe),
        .flash_spi_dq_in  (flash_spi_dq_in)
    );

    // 中断源
    always @ (*) begin
        irq_src     = 32'h0;
        // 从io_top获取的中断信号
        irq_src[ 0] = irq_timer;     // 定时器中断
        irq_src[ 1] = irq_uart_rx;   // UART接收中断
        irq_src[ 2] = irq_uart_tx;   // UART发送中断
        // 其他未实现的中断信号保持为0
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

endmodule