
`include "common.v"

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
    parameter IMPLEMENT_JTAG            = 0,
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
    localparam int MASTERS                  = (IMPLEMENT_JTAG ? (CPU_NUM * 2 + 1) : (CPU_NUM * 2));
    localparam int SLAVES                   = 18; // Number of slave ports

    // masters
    localparam int MASTER_JTAG_INDEX        = CPU_NUM * 2;

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

    generate
        if (IMPLEMENT_JTAG) begin : jtag_gen
            assign slave_addr_mask[SLAVE_JTAG_INDEX] = DEBUG_ADDR_MASK;
            assign slave_addr_base[SLAVE_JTAG_INDEX] = DEBUG_ADDR_BASE;
            // JTAG模块
            jtag_top #(

            ) u_jtag (
                .clk_i              (clk),
                .rst_ni             (rst_n),
                .debug_req_o        (debug_req),
                .ndmreset_o         (ndmreset),
                .halted_o           (core_halted),
                .jtag_tck_i         (jtag_tck_pin),
                .jtag_tdi_i         (jtag_tdi_pin),
                .jtag_tms_i         (jtag_tms_pin),
                .jtag_trst_ni       (rst_n),
                .jtag_tdo_o         (jtag_TDO_pin),
                .master_req_o       (master_req[MASTER_JTAG_INDEX]),
                .master_gnt_i       (master_gnt[MASTER_JTAG_INDEX]),
                .master_rvalid_i    (master_rvalid[MASTER_JTAG_INDEX]),
                .master_we_o        (master_we[MASTER_JTAG_INDEX]),
                .master_be_o        (master_be[MASTER_JTAG_INDEX]),
                .master_addr_o      (master_addr[MASTER_JTAG_INDEX]),
                .master_wdata_o     (master_wdata[MASTER_JTAG_INDEX]),
                .master_rdata_i     (master_rdata[MASTER_JTAG_INDEX]),
                .master_err_i       (1'b0),
                .slave_req_i        (slave_req[SLAVE_JTAG_INDEX]),
                .slave_we_i         (slave_we[SLAVE_JTAG_INDEX]),
                .slave_addr_i       (slave_addr[SLAVE_JTAG_INDEX]),
                .slave_be_i         (slave_be[SLAVE_JTAG_INDEX]),
                .slave_wdata_i      (slave_wdata[SLAVE_JTAG_INDEX]),
                .slave_gnt_o        (slave_gnt[SLAVE_JTAG_INDEX]),
                .slave_rvalid_o     (slave_rvalid[SLAVE_JTAG_INDEX]),
                .slave_rdata_o      (slave_rdata[SLAVE_JTAG_INDEX])
            );
        end else begin
            /* 暂未使用 */
            assign slave_rdata[SLAVE_JTAG_INDEX]      = 32'h0;
            assign slave_rvalid[SLAVE_JTAG_INDEX]     = 1'b0;
            assign slave_gnt[SLAVE_JTAG_INDEX]        = 1'b0;
        end
    endgenerate

endmodule