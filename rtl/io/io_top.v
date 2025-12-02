`include "common.v"

module ip0_io_top #(
    parameter ADDR_WIDTH           = 32,
    parameter DATA_WIDTH           = 32,
    parameter IO_SLAVES            = 9,
    parameter IO_ADDR_BASE         = 32'h40000000,
    parameter IO_ADDR_MASK         = ~32'hFFFFFFF,
    parameter BOOT_TYPE            = 2,
    parameter IMPLEMENT_UART       = 1,
    parameter IMPLEMENT_GPIO       = 1,
    parameter IMPLEMENT_SPI        = 1,
    parameter IMPLEMENT_TIMER      = 1,
    parameter IMPLEMENT_XIP        = 1,
    parameter IMPLEMENT_SPI_FLASH  = 1,
    parameter IMPLEMENT_EXT_APB    = 1,
    parameter SPI_NUM              = 1,
    parameter NUM_IRQ_SOURCES      = 32,
    parameter GPIO_IN_NUM          = 1,
    parameter GPIO_OUT_NUM         = 1,
    parameter GPIO_INOUT_NUM       = 1,
    parameter NUM_PES              = 4
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

    output wire                               apb_psel_o,
    output wire                               apb_penable_o,
    output wire [31:0]                        apb_paddr_o,
    output wire                               apb_pwrite_o,
    output wire [31:0]                        apb_pwdata_o,
    input  wire [31:0]                        apb_prdata_i,
    input  wire                               apb_pready_i,

    // 中断信号（新增中断控制器输出）
    output wire                               int_req_o,        // 中断请求信号
    output wire [7:0]                         int_id_o,         // 中断号

    // PE IRQ输入信号
    input  wire [NUM_PES-1:0]                 pe_irq_i,         // PE IRQ输入信号
    input  wire [(NUM_PES*8)-1:0]             pe_irq_id_i,      // PE IRQ ID输入

    // UART接口
    input  wire                               uart_rx,
    output wire                               uart_tx,

    input  wire                               ext_buad_sample_valid_i,
    input  wire [7:0]                         ext_buad_reg_i,
    input  wire [7:0]                         ext_sample_reg_i,

    // GPIO接口
    input  wire [GPIO_IN_NUM-1:0]             gpio_in,
    output wire [GPIO_OUT_NUM-1:0]            gpio_out,

    // SPI接口
    output wire [SPI_NUM-1:0]                 spi_cs_n,
    output wire                               spi_clk,
    output wire                               spi_mosi,
    input  wire                               spi_miso,

    // Flash接口
    output wire                               qspi_flash_clk,
    output wire                               qspi_flash_ss,
    output wire [3:0]                         qspi_flash_dq_out,
    output wire [3:0]                         qspi_flash_dq_oe,
    input  wire [3:0]                         qspi_flash_dq_in,

    // SPI Flash接口（用于直接SPI Flash控制器）
    output wire                               spi_flash_cs_n,
    output wire                               spi_flash_clk,
    output wire                               spi_flash_mosi,
    input  wire                               spi_flash_miso
);
    localparam int SLAVE_TIMER_INDEX     = 0;
    localparam int SLAVE_GPIO_INDEX      = 1;
    localparam int SLAVE_UART_INDEX      = 2;
    localparam int SLAVE_SPI_INDEX       = 3;
    localparam int SLAVE_FLASH_INDEX     = 4;
    localparam int SLAVE_SPI_FLASH_INDEX = 5;
    localparam int SLAVE_IRQ_INDEX       = 6;
    localparam int SLAVE_APB_BRIDGE_INDEX = 7;

    // 中断源定义
    localparam int IRQ_TIMER_ID        = 18 - 8;  // 定时器中断
    localparam int IRQ_UART_RX_ID      = 21 - 8;  // UART接收中断
    localparam int IRQ_UART_TX_ID      = 22 - 8;  // UART发送中断
    localparam int IRQ_SPI_ID          = 23 - 8;  // SPI中断
    localparam int IRQ_GPIO_ID         = 24 - 8;  // GPIO中断
    localparam int IRQ_PE_ID           = 25 - 8;  // PE中断

    // 中断源信号
    wire [NUM_IRQ_SOURCES-1:0]         irq_sources;
    wire                               irq_timer;
    wire                               irq_uart_rx;
    wire                               irq_uart_tx;

    localparam int TIMER_ADDR_BASE     = IO_ADDR_BASE + 32'h00010000;
    localparam int TIMER_ADDR_MASK     = `CALC_ADDR_MASK_BY_LENGTH(TIMER_ADDR_BASE, 4096);

    localparam int UART_ADDR_BASE      = IO_ADDR_BASE + 32'h00020000;
    localparam int UART_ADDR_MASK      = `CALC_ADDR_MASK_BY_LENGTH(UART_ADDR_BASE, 4096);

    localparam int GPIO_ADDR_BASE      = IO_ADDR_BASE + 32'h00030000;
    localparam int GPIO_ADDR_MASK      = `CALC_ADDR_MASK_BY_LENGTH(GPIO_ADDR_BASE, 4096);

    localparam int SPI_ADDR_BASE       = IO_ADDR_BASE + 32'h00040000;
    localparam int SPI_ADDR_MASK       = `CALC_ADDR_MASK_BY_LENGTH(SPI_ADDR_BASE, 4096);

    localparam int IRQ_CTRL_ADDR_BASE  = IO_ADDR_BASE + 32'h00060000;
    localparam int IRQ_CTRL_ADDR_MASK  = `CALC_ADDR_MASK_BY_LENGTH(IRQ_CTRL_ADDR_BASE, 4096);

    localparam int XIP_ADDR_BASE       = (BOOT_TYPE != 1) ? IO_ADDR_BASE + 32'h01000000 : 32'h0;
    localparam int XIP_ADDR_MASK       = `CALC_ADDR_MASK_BY_LENGTH(XIP_ADDR_BASE, 128 * 1024 * 1024);

    localparam int SPI_FLASH_ADDR_BASE = (BOOT_TYPE != 2) ? IO_ADDR_BASE + 32'h02000000 : 32'h0;
    localparam int SPI_FLASH_ADDR_MASK = `CALC_ADDR_MASK_BY_LENGTH(SPI_FLASH_ADDR_BASE, 128 * 1024 * 1024);

    localparam int APB_BRIDGE_ADDR_BASE = (BOOT_TYPE == 3) ? 32'h0 : IO_ADDR_BASE + 32'h03000000;
    localparam int APB_BRIDGE_ADDR_MASK = `CALC_ADDR_MASK_BY_LENGTH(APB_BRIDGE_ADDR_BASE, 128 * 1024 * 1024);

    /********** TIMER **********/
    generate
        if (IMPLEMENT_TIMER) begin : timer_gen
            assign slave_addr_base[SLAVE_TIMER_INDEX] = TIMER_ADDR_BASE;
            assign slave_addr_mask[SLAVE_TIMER_INDEX] = TIMER_ADDR_MASK;
            ip0_timer_top u_timer (
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
            ip0_uart_top u_uart (
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

                .ext_buad_sample_valid_i (ext_buad_sample_valid_i),
                .ext_buad_reg_i          (ext_buad_reg_i),
                .ext_sample_reg_i        (ext_sample_reg_i),

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
            ip0_gpio_top #(
                .GPIO_IN_NUM     (GPIO_IN_NUM),
                .GPIO_OUT_NUM    (GPIO_OUT_NUM),
                .GPIO_INOUT_NUM  (GPIO_INOUT_NUM)
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
                .gpio_out        (gpio_out)
             );
        end else begin
            assign slave_rdata[SLAVE_GPIO_INDEX]     = 32'h0;
            assign slave_rvalid[SLAVE_GPIO_INDEX]    = 1'b0;
            assign slave_gnt[SLAVE_GPIO_INDEX]       = 1'b0;
            assign gpio_out                          = {GPIO_OUT_NUM{1'b0}};
        end
    endgenerate

    /********** SPI **********/
    generate
        if (IMPLEMENT_SPI) begin : spi_gen
            assign slave_addr_base[SLAVE_SPI_INDEX]   = SPI_ADDR_BASE;
            assign slave_addr_mask[SLAVE_SPI_INDEX]   = SPI_ADDR_MASK;
            ip0_spi_top #(
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

    /********** SPI Flash控制器 **********/
    generate
        if (IMPLEMENT_SPI_FLASH) begin : spi_flash_gen
            assign slave_addr_base[SLAVE_SPI_FLASH_INDEX]  = SPI_FLASH_ADDR_BASE;
            assign slave_addr_mask[SLAVE_SPI_FLASH_INDEX]  = SPI_FLASH_ADDR_MASK;
            ip0_spi_flash_controller u_spi_flash_ctrl (
                .clk           (clk),
                .rst_n         (rst_n),

                .req_i         (slave_req[SLAVE_SPI_FLASH_INDEX]),
                .we_i          (slave_we[SLAVE_SPI_FLASH_INDEX]),
                .addr_i        (slave_addr[SLAVE_SPI_FLASH_INDEX]),
                .wdata_i       (slave_wdata[SLAVE_SPI_FLASH_INDEX]),
                .rdata_o       (slave_rdata[SLAVE_SPI_FLASH_INDEX]),
                .gnt_o         (slave_gnt[SLAVE_SPI_FLASH_INDEX]),
                .rvalid_o      (slave_rvalid[SLAVE_SPI_FLASH_INDEX]),

                .spi_cs_n_o    (spi_flash_cs_n),
                .spi_sck_o     (spi_flash_clk),
                .spi_mosi_o    (spi_flash_mosi),
                .spi_miso_i    (spi_flash_miso)
            );
        end else begin
            assign slave_rdata[SLAVE_SPI_FLASH_INDEX]      = 32'h0;
            assign slave_rvalid[SLAVE_SPI_FLASH_INDEX]     = 1'b0;
            assign slave_gnt[SLAVE_SPI_FLASH_INDEX]        = 1'b0;
            assign spi_flash_cs_n                          = 1'b1;
            assign spi_flash_clk                           = 1'b0;
            assign spi_flash_mosi                           = 1'b0;
        end
    endgenerate

    /********** FLASH/XIP **********/
    generate
        if (IMPLEMENT_XIP) begin : flash_gen
            assign slave_addr_base[SLAVE_FLASH_INDEX]  = XIP_ADDR_BASE;
            assign slave_addr_mask[SLAVE_FLASH_INDEX]  = XIP_ADDR_MASK;
            ip0_xip_top u_xip (
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

                .spi_clk_o      (qspi_flash_clk),
                .spi_clk_oe_o   (), // 不使用
                .spi_ss_o       (qspi_flash_ss),
                .spi_ss_oe_o    (), // 不使用
                .spi_dq0_i      (qspi_flash_dq_in[0]),
                .spi_dq0_o      (qspi_flash_dq_out[0]),
                .spi_dq0_oe_o   (qspi_flash_dq_oe[0]),
                .spi_dq1_i      (qspi_flash_dq_in[1]),
                .spi_dq1_o      (qspi_flash_dq_out[1]),
                .spi_dq1_oe_o   (qspi_flash_dq_oe[1]),
                .spi_dq2_i      (qspi_flash_dq_in[2]),
                .spi_dq2_o      (qspi_flash_dq_out[2]),
                .spi_dq2_oe_o   (qspi_flash_dq_oe[2]),
                .spi_dq3_i      (qspi_flash_dq_in[3]),
                .spi_dq3_o      (qspi_flash_dq_out[3]),
                .spi_dq3_oe_o   (qspi_flash_dq_oe[3])
            );
        end else begin
            assign slave_rdata[SLAVE_FLASH_INDEX]      = 32'h0;
            assign slave_rvalid[SLAVE_FLASH_INDEX]     = 1'b0;
            assign slave_gnt[SLAVE_FLASH_INDEX]        = 1'b0;
            assign qspi_flash_clk                      = 1'b0;
            assign qspi_flash_ss                       = 1'b1;
            assign qspi_flash_dq_out                   = 4'b0000;
            assign qspi_flash_dq_oe                    = 4'b0000;
        end
    endgenerate

    genvar i;
    generate
        for (i = 0; i < NUM_IRQ_SOURCES; i = i + 1) begin : all_irq_sources
            if (i == IRQ_TIMER_ID) begin
                assign irq_sources[i] = irq_timer;
            end else if (i == IRQ_UART_RX_ID) begin
                assign irq_sources[i] = irq_uart_rx;
            end else if (i == IRQ_UART_TX_ID) begin
                assign irq_sources[i] = irq_uart_tx;
            end else if (i == IRQ_PE_ID) begin
                // PE IRQ: 当任意一个PE产生IRQ时触发
                assign irq_sources[i] = |pe_irq_i;
            end else begin
                assign irq_sources[i] = 1'b0;
            end
        end
    endgenerate

    // 中断控制器实例化
    assign slave_addr_base[SLAVE_IRQ_INDEX] = IRQ_CTRL_ADDR_BASE;
    assign slave_addr_mask[SLAVE_IRQ_INDEX] = IRQ_CTRL_ADDR_MASK;
    ip0_irq_controller #(
        .NUM_IRQ_SOURCES(NUM_IRQ_SOURCES)
    ) u_irq_controller (
        .clk           (clk),
        .rst_n         (rst_n),

        // 中断源输入
        .irq_sources_i (irq_sources),

        // CPU中断接口
        .int_req_o     (int_req_o),
        .int_id_o      (int_id_o),

        // OBI总线接口
        .req_i         (slave_req[SLAVE_IRQ_INDEX]),
        .we_i          (slave_we[SLAVE_IRQ_INDEX]),
        .addr_i        (slave_addr[SLAVE_IRQ_INDEX]),
        .wr_data_i     (slave_wdata[SLAVE_IRQ_INDEX]),
        .data_out_o    (slave_rdata[SLAVE_IRQ_INDEX]),
        .gnt_o         (slave_gnt[SLAVE_IRQ_INDEX]),
        .rvalid_o      (slave_rvalid[SLAVE_IRQ_INDEX])
    );

    /********** OBI到APB桥接器 **********/
    generate
        if (IMPLEMENT_EXT_APB) begin : apb_bridge_gen
            assign slave_addr_base[SLAVE_APB_BRIDGE_INDEX] = APB_BRIDGE_ADDR_BASE;
            assign slave_addr_mask[SLAVE_APB_BRIDGE_INDEX] = APB_BRIDGE_ADDR_MASK;
            ip0_obi_to_apb_bridge u_obi_to_apb_bridge (
                .clk(clk),
                .rst_n(rst_n),

                .obi_req_i(slave_req[SLAVE_APB_BRIDGE_INDEX]),
                .obi_addr_i(slave_addr[SLAVE_APB_BRIDGE_INDEX]),
                .obi_we_i(slave_we[SLAVE_APB_BRIDGE_INDEX]),
                .obi_wdata_i(slave_wdata[SLAVE_APB_BRIDGE_INDEX]),
                .obi_be_i(slave_be[SLAVE_APB_BRIDGE_INDEX]),
                .obi_gnt_o(slave_gnt[SLAVE_APB_BRIDGE_INDEX]),
                .obi_rvalid_o(slave_rvalid[SLAVE_APB_BRIDGE_INDEX]),
                .obi_rdata_o(slave_rdata[SLAVE_APB_BRIDGE_INDEX]),

                .apb_psel_o(apb_psel_o),
                .apb_penable_o(apb_penable_o),
                .apb_paddr_o(apb_paddr_o),
                .apb_pwrite_o(apb_pwrite_o),
                .apb_pwdata_o(apb_pwdata_o),
                .apb_prdata_i(apb_prdata_i),
                .apb_pready_i(apb_pready_i)
            );
        end else begin
            assign slave_rdata[SLAVE_APB_BRIDGE_INDEX]      = 32'h0;
            assign slave_rvalid[SLAVE_APB_BRIDGE_INDEX]     = 1'b0;
            assign slave_gnt[SLAVE_APB_BRIDGE_INDEX]        = 1'b0;
        end
    endgenerate

endmodule