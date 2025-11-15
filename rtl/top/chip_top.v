
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
    parameter NUM_PES                   = 16,
    parameter INST_WIDTH                = 32,
    parameter PE_ID_WIDTH               = 4,
    parameter PE_ARRAY_X                = 4,
    parameter PE_ARRAY_Y                = 4,
    parameter BOOT_TYPE                 = 2,           // 0 : ROM, 1 : QSPI FLASH, 2 : SPI FLASH
    parameter IMPLEMENT_JTAG            = 1,
    parameter IMPLEMENT_UART            = 1,
    parameter IMPLEMENT_GPIO            = 1,
    parameter IMPLEMENT_SPI             = 1,
    parameter IMPLEMENT_XIP             = 1,
    parameter IMPLEMENT_SPI_FLASH       = 1,
    parameter IMPLEMENT_TIMER           = 1,
    parameter IMPLEMENT_I2C             = 1,
    parameter IMPLEMENT_DMA             = 1,           // DMA控制器使能
    parameter GPIO_IN_NUM               = 14,
    parameter GPIO_OUT_NUM              = 8,
    parameter GPIO_INOUT_NUM            = 66,
    parameter I2C_NUM                   = 2,
    parameter UART_NUM                  = 3,
    parameter SPI_NUM                   = 1,
    parameter DMA_FIFO_DEPTH            = 16,          // DMA FIFO深度
    parameter DMA_BURST_LENGTH          = 8            // DMA突发传输长度
)(
    input  wire                         clk,
    input  wire                         rst_n,

    /********** UART  **********/
    input  wire                         uart_rx,
    output wire                         uart_tx,

    /********** GPIO  **********/
    input  wire [GPIO_IN_NUM-1:0]       gpio_in,
    output wire [GPIO_OUT_NUM-1:0]      gpio_out,
    inout  wire [GPIO_INOUT_NUM-1:0]    gpio_io,

    /********** SPI **********/
    output wire [SPI_NUM-1:0]           spi_cs_n,
    output wire                         spi_clk,
    output wire                         spi_mosi,
    input  wire                         spi_miso,

    /********** FLASH **********/
    input  wire[3:0]                    qspi_flash_dq_in,
    output wire[3:0]                    qspi_flash_dq_oe,
    output wire[3:0]                    qspi_flash_dq_out,
    output wire                         qspi_flash_clk_pin,
    output wire                         qspi_flash_ss_pin,

    /********** SPI FLASH **********/
    output wire                         spi_flash_cs_n,
    output wire                         spi_flash_clk,
    output wire                         spi_flash_mosi,
    input  wire                         spi_flash_miso,

    /********** JTAG **********/
    input  wire                         jtag_tck_pin,
    input  wire                         jtag_tms_pin,
    input  wire                         jtag_tdi_pin,
    output wire                         jtag_tdo_pin
);
    /* (instruction + data) * CPU_NUM + jtag */
    localparam int MASTERS                  = (IMPLEMENT_JTAG ? (CPU_NUM * 2 + 1) : (CPU_NUM * 2));
    localparam int SLAVES                   = 16; // Number of slave ports

    // masters
    localparam int MASTER_JTAG_INDEX        = CPU_NUM * 2;

    // slaves
    localparam int SLAVE_ROM_INDEX          = 0;
    localparam int SLAVE_RAM_INDEX          = 1;
    localparam int SLAVE_JTAG_INDEX         = 2;
    localparam int SLAVE_PE_TOP_INDEX       = 3;
    localparam int SLAVE_PE_MEM_INDEX       = 4;  // PE直接内存控制器
    localparam int IO_SLAVES                = 8;
    localparam int SLAVE_IO_START_INDEX     = 8;
    localparam int SLAVE_IO_END_INDEX       = SLAVE_IO_START_INDEX + IO_SLAVES - 1;

    localparam int ROM_ADDR_BASE            = 32'h00000000;
    localparam int ROM_ADDR_MASK            = `CALC_ADDR_MASK_BY_LENGTH(ROM_ADDR_BASE, ROM_DEPTH * 4);

    localparam int DEBUG_ADDR_BASE          = 32'h10000000;
    localparam int DEBUG_ADDR_MASK          = `CALC_ADDR_MASK_BY_LENGTH(DEBUG_ADDR_BASE, 8*1024);

    localparam int RAM_ADDR_BASE            = 32'h20000000;
    localparam int RAM_ADDR_MASK            = `CALC_ADDR_MASK_BY_LENGTH(RAM_ADDR_BASE, RAM_DEPTH * 4);

    localparam int PE_ADDR_BASE             = 32'h30000000;
    localparam int PE_ADDR_MASK             = `CALC_ADDR_MASK_BY_LENGTH(PE_ADDR_BASE, 128 * 1024 * 1024);

    localparam int IO_ADDR_BASE             = 32'h40000000;
    localparam int IO_ADDR_MASK             = `CALC_ADDR_MASK_BY_END_ADDR(IO_ADDR_BASE, 32'h4FFFFFFF);

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

    // 修复信号位选择顺序，避免信号反转
    wire [IO_SLAVES-1:0]                    io_slave_req;
    wire [IO_SLAVES-1:0]                    io_slave_gnt;
    wire [IO_SLAVES-1:0]                    io_slave_rvalid;
    wire [IO_SLAVES-1:0][31:0]              io_slave_addr;
    wire [IO_SLAVES-1:0]                    io_slave_we;
    wire [IO_SLAVES-1:0][ 3:0]              io_slave_be;
    wire [IO_SLAVES-1:0][31:0]              io_slave_rdata;
    wire [IO_SLAVES-1:0][31:0]              io_slave_wdata;
    wire [IO_SLAVES-1:0][31:0]              io_slave_addr_mask;
    wire [IO_SLAVES-1:0][31:0]              io_slave_addr_base;

    wire                                                  ndmreset;
    wire                                                  ndmreset_n;
    wire                                                  debug_req;
    wire                                                  core_halted;

    // 中断相关信号
    wire                                                  int_req;
    wire[7:0]                                             int_id;

    // PE IRQ信号
    wire [NUM_PES-1:0]                                    pe_irq;
    wire [(NUM_PES*8)-1:0]                                pe_irq_id;

    // DMA相关信号
    wire                                                  dma_irq;                    // DMA中断信号
    wire [7:0]                                            dma_irq_id;                 // DMA中断ID
    wire                                                  dma_pe_req;                 // DMA到PE的请求信号
    wire                                                  dma_pe_we;                  // DMA到PE的写使能
    wire [ADDR_WIDTH-1:0]                                 dma_pe_addr;                // DMA到PE的地址
    wire [DATA_WIDTH-1:0]                                 dma_pe_data;                // DMA到PE的数据（32位）
    wire                                                  dma_pe_ack;                 // DMA到PE的应答信号
    wire [DATA_WIDTH-1:0]                                 dma_pe_rdata;               // DMA从PE读取的数据（32位）

    // 高带宽内存接口信号（用于PE直接内存访问）
    wire                                                  pe_mem_req;                 // 高带宽内存请求信号
    wire                                                  pe_mem_we;                  // 高带宽内存写使能
    wire [ADDR_WIDTH-1:0]                                 pe_mem_addr;                // 高带宽内存地址
    wire [(PE_ARRAY_X+3)*PE_ARRAY_Y*DATA_WIDTH-1:0]       pe_mem_data_o;              // 高带宽内存写入数据
    wire                                                  pe_mem_ack;                 // 高带宽内存应答信号
    wire [(PE_ARRAY_X+3)*PE_ARRAY_Y*DATA_WIDTH-1:0]       pe_mem_data_i;              // 高带宽内存读取数据

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

    // ROM实例化 - 条件编译
    generate
        if (BOOT_TYPE == 0) begin : rom_gen
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
        end else begin
            assign slave_addr_mask[SLAVE_ROM_INDEX] = 32'h0;
            assign slave_addr_base[SLAVE_ROM_INDEX] = 32'h0;
            assign slave_gnt[SLAVE_ROM_INDEX]       = 1'b0;
            assign slave_rvalid[SLAVE_ROM_INDEX]    = 1'b0;
            assign slave_rdata[SLAVE_ROM_INDEX]     = 32'h0;
        end
    endgenerate

    assign slave_addr_mask[SLAVE_RAM_INDEX] = RAM_ADDR_MASK;
    assign slave_addr_base[SLAVE_RAM_INDEX] = RAM_ADDR_BASE;
    // 数据存储器
    ram #(
        .DP(RAM_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .HIGH_BW_DW((PE_ARRAY_X+3)*PE_ARRAY_Y*DATA_WIDTH),
        .HIGH_BW_MW(((PE_ARRAY_X+3)*PE_ARRAY_Y*DATA_WIDTH)/32)
    ) u_ram (
        .clk_i          (clk),
        .rst_ni         (ndmreset_n),
        .req_i          (slave_req[SLAVE_RAM_INDEX]),
        .addr_i         (slave_addr[SLAVE_RAM_INDEX]),
        .data_i         (slave_wdata[SLAVE_RAM_INDEX]),
        .be_i           (slave_be[SLAVE_RAM_INDEX]),
        .we_i           (slave_we[SLAVE_RAM_INDEX]),
        .gnt_o          (slave_gnt[SLAVE_RAM_INDEX]),
        .rvalid_o       (slave_rvalid[SLAVE_RAM_INDEX]),
        .data_o         (slave_rdata[SLAVE_RAM_INDEX]),
        // 高带宽内存接口 - 连接到PE_TOP的宽位宽接口
        .high_bw_req_i  (pe_mem_req),
        .high_bw_we_i   (pe_mem_we),
        .high_bw_addr_i (pe_mem_addr),
        .high_bw_data_i (pe_mem_data_o),
        .high_bw_ack_o  (pe_mem_ack),
        .high_bw_data_o (pe_mem_data_i)
    );


    assign slave_addr_mask[SLAVE_PE_TOP_INDEX] = PE_ADDR_MASK;
    assign slave_addr_base[SLAVE_PE_TOP_INDEX] = PE_ADDR_BASE;
    // PE_TOP实例化
    pe_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PE_ARRAY_X(PE_ARRAY_X),
        .PE_ARRAY_Y(PE_ARRAY_Y),
        .HIGH_BW_DW((PE_ARRAY_X+3)*PE_ARRAY_Y*DATA_WIDTH)
    ) u_pe_top (
        .clk        (clk),
        .rst_n      (rst_n),
        .req_i      (slave_req[SLAVE_PE_TOP_INDEX]),
        .we_i       (slave_we[SLAVE_PE_TOP_INDEX]),
        .addr_i     (slave_addr[SLAVE_PE_TOP_INDEX]),
        .wdata_i    (slave_wdata[SLAVE_PE_TOP_INDEX]),
        .rdata_o    (slave_rdata[SLAVE_PE_TOP_INDEX]),
        .gnt_o      (slave_gnt[SLAVE_PE_TOP_INDEX]),
        .rvalid_o   (slave_rvalid[SLAVE_PE_TOP_INDEX]),
        // 直接内存接口 - 连接到高带宽内存接口信号
        .mem_req_o  (pe_mem_req),
        .mem_we_o   (pe_mem_we),
        .mem_addr_o (pe_mem_addr),
        .mem_data_o (pe_mem_data_o),
        .mem_ack_i  (pe_mem_ack),
        .mem_data_i (pe_mem_data_i)
    );

    generate
        genvar j;
        for (j = 0; j < IO_SLAVES; j = j + 1) begin : io_slave_conn
            // 从交叉开关到IO模块的信号（输入到IO模块）
            assign io_slave_req[j]                            = slave_req[SLAVE_IO_START_INDEX + j];
            assign io_slave_addr[j]                           = slave_addr[SLAVE_IO_START_INDEX + j];
            assign io_slave_we[j]                             = slave_we[SLAVE_IO_START_INDEX + j];
            assign io_slave_be[j]                             = slave_be[SLAVE_IO_START_INDEX + j];
            assign io_slave_wdata[j]                          = slave_wdata[SLAVE_IO_START_INDEX + j];

            // 从IO模块到交叉开关的信号（输出从IO模块）
            assign slave_gnt[SLAVE_IO_START_INDEX + j]        = io_slave_gnt[j];
            assign slave_rvalid[SLAVE_IO_START_INDEX + j]     = io_slave_rvalid[j];
            assign slave_rdata[SLAVE_IO_START_INDEX + j]      = io_slave_rdata[j];
            assign slave_addr_mask[SLAVE_IO_START_INDEX + j]  = io_slave_addr_mask[j];
            assign slave_addr_base[SLAVE_IO_START_INDEX + j]  = io_slave_addr_base[j];
        end
    endgenerate

    io_top #(
        .ADDR_WIDTH             (ADDR_WIDTH),
        .DATA_WIDTH             (DATA_WIDTH),
        .IO_SLAVES              (IO_SLAVES),
        .IO_ADDR_BASE           (IO_ADDR_BASE),
        .IO_ADDR_MASK           (IO_ADDR_MASK),
        .BOOT_TYPE              (BOOT_TYPE),
        .IMPLEMENT_UART         (IMPLEMENT_UART),
        .IMPLEMENT_GPIO         (IMPLEMENT_GPIO),
        .IMPLEMENT_SPI          (IMPLEMENT_SPI),
        .IMPLEMENT_TIMER        (IMPLEMENT_TIMER),
        .IMPLEMENT_XIP          (IMPLEMENT_XIP),
        .IMPLEMENT_SPI_FLASH    (IMPLEMENT_SPI_FLASH),
        .IMPLEMENT_DMA          (IMPLEMENT_DMA),
        .DMA_FIFO_DEPTH         (DMA_FIFO_DEPTH),
        .SPI_NUM                (SPI_NUM),
        .GPIO_IN_NUM            (GPIO_IN_NUM),
        .GPIO_OUT_NUM           (GPIO_OUT_NUM),
        .GPIO_INOUT_NUM         (GPIO_INOUT_NUM),
        .NUM_PES                (NUM_PES)
    ) u_io (
        .clk              (clk),
        .rst_n            (rst_n),

        // 总线接口
        .slave_req        (io_slave_req),
        .slave_gnt        (io_slave_gnt),
        .slave_rvalid     (io_slave_rvalid),
        .slave_addr       (io_slave_addr),
        .slave_we         (io_slave_we),
        .slave_be         (io_slave_be),
        .slave_rdata      (io_slave_rdata),
        .slave_wdata      (io_slave_wdata),

        .slave_addr_mask  (io_slave_addr_mask),
        .slave_addr_base  (io_slave_addr_base),

        // 中断控制器输出信号
        .int_req_o        (int_req),
        .int_id_o         (int_id),

        // PE IRQ输入信号
        .pe_irq_i         (pe_irq),
        .pe_irq_id_i      (pe_irq_id),

        // DMA到PE接口信号（32位）
        .dma_pe_req_o     (dma_pe_req),
        .dma_pe_we_o      (dma_pe_we),
        .dma_pe_addr_o    (dma_pe_addr),
        .dma_pe_data_o    (dma_pe_data),
        .dma_pe_ack_i     (dma_pe_ack),
        .dma_pe_data_i    (dma_pe_rdata),

        // UART接口
        .uart_rx          (uart_rx),
        .uart_tx          (uart_tx),

        // GPIO接口
        .gpio_in          (gpio_in),
        .gpio_out         (gpio_out),
        .gpio_io          (gpio_io),

        // SPI接口
        .spi_cs_n         (spi_cs_n),
        .spi_clk          (spi_clk),
        .spi_mosi         (spi_mosi),
        .spi_miso         (spi_miso),

        // Flash接口
        .qspi_flash_clk    (qspi_flash_clk_pin),
        .qspi_flash_ss     (qspi_flash_ss_pin),
        .qspi_flash_dq_out (qspi_flash_dq_out),
        .qspi_flash_dq_oe  (qspi_flash_dq_oe),
        .qspi_flash_dq_in  (qspi_flash_dq_in),

        // SPI Flash接口
        .spi_flash_cs_n    (spi_flash_cs_n),
        .spi_flash_clk     (spi_flash_clk),
        .spi_flash_mosi    (spi_flash_mosi),
        .spi_flash_miso    (spi_flash_miso)
    );

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
                .jtag_tdo_o         (jtag_tdo_pin),
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