
`timescale 1ns/1ps

// 当所有测试宏都未定义时，自动定义所有测试宏
`ifndef PE_TEST_FOR_CHIP_TOP
    `ifndef GPIO_TEST_FOR_CHIP_TOP
        `ifndef TIMER_TEST_FOR_CHIP_TOP
            `ifndef SPI_TEST_FOR_CHIP_TOP
                `define PE_TEST_FOR_CHIP_TOP
                `define GPIO_TEST_FOR_CHIP_TOP
                `define TIMER_TEST_FOR_CHIP_TOP
                // `define SPI_TEST_FOR_CHIP_TOP
            `endif
        `endif
    `endif
`endif

`ifndef BOOT_TYPE
`define BOOT_TYPE 4
`endif

module chip_top_test;
    /********** 输入/输出信号 **********/
    reg                       clk;
    reg                       rst_n;

    localparam TEST_CMD_PE          = 8'h70; // 'p'
    localparam TEST_CMD_GPIO_IN     = 8'h67; // 'g' - GPIO输入测试
    localparam TEST_CMD_GPIO_OUT    = 8'h47; // 'G' - GPIO输出测试
    localparam TEST_CMD_GPIO_IO     = 8'h69; // 'i' - GPIO双向测试
    localparam TEST_CMD_SPI         = 8'h73; // 's'
    localparam TEST_CMD_TIMER       = 8'h74; // 't'
    localparam TEST_CMD_END         = 8'h04;
    localparam CPU_NUM              = 1;
    localparam SPI_NUM              = 1;
    localparam GPIO_IN_NUM          = 8;
    localparam GPIO_OUT_NUM         = 8;
    localparam GPIO_INOUT_NUM       = 8;
    localparam I2C_NUM              = 1;
    localparam UART_NUM             = 1;
    localparam BOOT_TYPE            = `BOOT_TYPE;     // 0 : ROM, 1 : QSPI FLASH, 2 : SPI FLASH, 3 : APB, 4 : ext rom(OBI bus)
    localparam IMPLEMENT_JTAG       = 1;
    localparam IMPLEMENT_UART       = 1;
    localparam IMPLEMENT_GPIO       = 1;
    localparam IMPLEMENT_SPI        = SPI_NUM > 0 ? 1 : 0;
    localparam IMPLEMENT_XIP        = 0;
    localparam IMPLEMENT_SPI_FLASH  = 0;
    localparam IMPLEMENT_TIMER      = 1;
    localparam IMPLEMENT_I2C        = 0;
    localparam IMPLEMENT_EXT_OBI    = 1;
    localparam IMPLEMENT_EXT_APB    = 0;
    localparam TRACE_ENABLE         = 0;
    localparam ROM_DEPTH            = 8192;
    localparam RAM_DEPTH            = 8192;
    localparam ADDR_WIDTH           = 32;
    localparam DATA_WIDTH           = 32;
    localparam PE_ARRAY_X           = 16;
    localparam PE_ARRAY_Y           = 16;
    localparam SYS_CLK_FREQ         = 100_000_000;
    localparam BAUD_RATE            = 115_200;

`ifdef ASIC_VERSION
    /*
     * ASIC版本直接通过代码配置，外部波特率分频寄存器和采样率不可用，此时时需要与program.s和uart_boot.s中定义的一致
     */
    localparam BUAD_SAMPLE_VALID    = 1'b0;
    localparam SAMPLE_CYCLES        = 16;
    localparam UART_DIV_RATE        = (SYS_CLK_FREQ / BAUD_RATE / 2 / SAMPLE_CYCLES);
    localparam TIMEOUT_CYCLES       = 1000000;
`else
    localparam BUAD_SAMPLE_VALID    = 1'b1;
    localparam SAMPLE_CYCLES        = 4;
    localparam UART_DIV_RATE        = 2;
    localparam TIMEOUT_CYCLES       = 10000;
`endif

    wire                      obi_req;
    wire                      obi_we;
    wire [31:0]               obi_addr;
    wire [DATA_WIDTH-1:0]     obi_wdata;
    wire                      obi_gnt;
    wire                      obi_rvalid;
    wire [DATA_WIDTH-1:0]     obi_rdata;

    wire                      apb_psel;
    wire                      apb_penable;
    wire [31:0]               apb_paddr;
    wire                      apb_pwrite;
    wire [31:0]               apb_pwdata;
    wire [31:0]               apb_prdata;
    wire                      apb_pready;
    wire                      apb_pslverr;

    // UART
    reg                       uart_rx;       // UART接收信号
    wire                      uart_tx;       // UART发送信号

    // SPI
    wire [SPI_NUM-1:0]        spi_cs_n;      // SPI片选信号
    wire                      spi_clk;       // SPI时钟信号
    wire                      spi_mosi;      // SPI主机输出从机输入
    wire                      spi_miso;      // SPI主机输入从机输出

    // QSPI Flash接口
    wire [3:0]                qspi_flash_dq_in;   // QSPI Flash数据输入
    wire [3:0]                qspi_flash_dq_out;  // QSPI Flash数据输出
    wire [3:0]                qspi_flash_dq_oe;   // QSPI Flash数据输出使能
    wire                      qspi_flash_clk_pin; // QSPI Flash时钟
    wire                      qspi_flash_ss_pin;  // QSPI Flash片选

    // SPI Flash接口
    wire                      spi_flash_cs_n;    // SPI Flash片选信号
    wire                      spi_flash_clk;     // SPI Flash时钟信号
    wire                      spi_flash_mosi;    // SPI Flash主机输出从机输入
    wire                      spi_flash_miso;    // SPI Flash主机输入从机输出

    // MX25L6436F专用接口
    wire                      spi_flash_wp;      // MX25L6436F写保护引脚
    wire                      spi_flash_sio3;    // MX25L6436F SIO3引脚

    // MX25L6436F引脚赋值
    assign spi_flash_wp       = 1'b1;   // 写保护引脚，设置为高电平（不保护）
    assign spi_flash_sio3     = 1'b1;   // 保留引脚，设置为高电平

    if (IMPLEMENT_SPI_FLASH == 1) begin : spi_flash_gen
        /********** 实例化MX25L6436F SPI Flash模拟模块 **********/
        MX25L6436F #(
            .TOP_Add(23'hffff),
            .Init_File(`ROM_PRG)
        ) u_spi_flash (
            .SCLK           (spi_flash_clk),
            .CS             (spi_flash_cs_n),
            .SI             (spi_flash_mosi),
            .SO             (spi_flash_miso),
            .WP             (spi_flash_wp),   // 写保护引脚
            .SIO3           (spi_flash_sio3)  // 保留引脚
        );
    end

    // SPI从机MISO信号数组（用于多个从机）
    wire [SPI_NUM-1:0] spi_slave_miso;

    // SPI模式选择信号（每个从机一个）
    reg [SPI_NUM-1:0][1:0] spi_slave_mode;

    // 为每个从机分配默认模式（初始为模式0）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer j = 0; j < SPI_NUM; j = j + 1) begin
                spi_slave_mode[j] <= 2'b00; // 默认模式0
            end
        end
        // 这里可以根据需要动态调整不同从机的SPI模式
    end

    // 通用输入/输出端口
    wire [GPIO_IN_NUM-1:0]       gpio_in = {GPIO_IN_NUM{1'b1}};
    wire [GPIO_OUT_NUM-1:0]      gpio_out;

    /********** UART模型 **********/
    wire                      rx_busy;          // 接收中标志
    wire                      rx_end;           // 接收完成标志
    wire [7:0]                rx_data;          // 接收的数据

    /********** SPI从机模型 **********/
    // 使用generate语句根据SPI_NUM动态例化SPI从机
    generate
        genvar i;
        for (i = 0; i < SPI_NUM; i = i + 1) begin : spi_slave_gen
            test_spi_slave #(
                .SLAVE_ID(i)  // 设置从机ID
            ) u_spi_slave (
                .clk        (clk),
                .rst_n      (rst_n),
                .mode       (spi_slave_mode[i]), // 传入SPI模式
                .spi_cs_n   (spi_cs_n[i]),
                .spi_clk    (spi_clk),
                .spi_mosi   (spi_mosi),
                .spi_miso   (spi_slave_miso[i])
            );
        end
    endgenerate

    // SPI MISO信号的线或连接
    generate
        if (SPI_NUM == 1) begin
            assign spi_miso = (spi_cs_n[0] == 1'b0) ? spi_slave_miso[0] : 1'bz;
        end else begin
            reg [SPI_NUM-1:0] cs_n_active;
            wire [SPI_NUM-1:0] cs_n_active_vec;
            wire               any_cs_n_active;
            integer            active_index;

            always @(*) begin
                cs_n_active = 0;
                active_index = SPI_NUM;
                for (integer j = 0; j < SPI_NUM; j = j + 1) begin
                    if (spi_cs_n[j] == 1'b0) begin
                        cs_n_active[j] = 1'b1;
                        active_index = j;
                    end
                end
            end
            assign cs_n_active_vec = cs_n_active;
            assign any_cs_n_active = |cs_n_active_vec;
            assign spi_miso = any_cs_n_active ? spi_slave_miso[active_index] : 1'bz;
        end
    endgenerate

    // QSPI Flash数据线连接
    // 当输出使能有效时，使用chip_top的输出数据，否则为高阻态
    assign qspi_flash_dq_in[0] = qspi_flash_dq_oe[0] ? qspi_flash_dq_out[0] : 1'bz;
    assign qspi_flash_dq_in[1] = qspi_flash_dq_oe[1] ? qspi_flash_dq_out[1] : 1'bz;
    assign qspi_flash_dq_in[2] = qspi_flash_dq_oe[2] ? qspi_flash_dq_out[2] : 1'bz;
    assign qspi_flash_dq_in[3] = qspi_flash_dq_oe[3] ? qspi_flash_dq_out[3] : 1'bz;

    /********** 时钟生成 **********/
    always #5 clk = ~clk;

    /********** 实例化chip_top **********/
    ip0_chip_top #(
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
        .apb_prdata_i (apb_prdata),
        .apb_pready_i (apb_pready),

        /********** UART **********/
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),

        .ext_buad_sample_valid_i (1'(BUAD_SAMPLE_VALID)),
        .ext_buad_reg_i          (8'(UART_DIV_RATE)),
        .ext_sample_reg_i        (8'(SAMPLE_CYCLES)),

        /********** 通用输入/输出端口 **********/
        .gpio_in     (gpio_in),
        .gpio_out    (gpio_out),

        /********** SPI **********/
        .spi_cs_n    (spi_cs_n),
        .spi_clk     (spi_clk),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),

        /********** QSPI Flash **********/
        .qspi_flash_dq_in   (qspi_flash_dq_in),
        .qspi_flash_dq_out  (qspi_flash_dq_out),
        .qspi_flash_dq_oe   (qspi_flash_dq_oe),
        .qspi_flash_clk_pin (qspi_flash_clk_pin),
        .qspi_flash_ss_pin  (qspi_flash_ss_pin),

        /********** SPI Flash **********/
        .spi_flash_cs_n     (spi_flash_cs_n),
        .spi_flash_clk      (spi_flash_clk),
        .spi_flash_mosi     (spi_flash_mosi),
        .spi_flash_miso     (spi_flash_miso)
    );

    if (IMPLEMENT_XIP == 1) begin : xip_gen
        /********** 实例化QSPI Flash模拟模块 **********/
        qspi_flash_model #(
            .FLASH_SIZE  (64*1024),
            .PROGRAM_FILE(`ROM_PRG)
        ) u_qspi_flash (
            .clk            (clk),
            .rst_n          (rst_n),
            .cs_n           (qspi_flash_ss_pin),
            .sck            (qspi_flash_clk_pin),
            .io_in          (qspi_flash_dq_in),
            .io_out         (qspi_flash_dq_out),
            .io_oe          (qspi_flash_dq_oe[0])
        );
    end

    if (BOOT_TYPE == 3) begin : apb_ram_gen
        apb_ram #(
            .MEM_SIZE(8192),
            .ADDR_WIDTH(32),
            .INIT_FILE(`ROM_PRG)
        ) u_apb_ram (
            .clk(clk),
            .rst_n(rst_n),
            .apb_psel_i(apb_psel),
            .apb_penable_i(apb_penable),
            .apb_paddr_i(apb_paddr),
            .apb_pwrite_i(apb_pwrite),
            .apb_pwdata_i(apb_pwdata),
            .apb_pready_o(apb_pready),
            .apb_prdata_o(apb_prdata),
            .apb_pslverr_o(apb_pslverr)
        );
    end

    ip0_rom #(
        .DP(ROM_DEPTH)
    ) u_ext_rom (
        .clk_i      (clk),
        .rst_ni     (ndmreset_n),
        .req_i      (obi_req),
        .addr_i     (obi_addr),
        .data_i     (obi_wdata),
        .be_i       (4'b1),
        .we_i       (obi_we),
        .gnt_o      (obi_gnt),
        .rvalid_o   (obi_rvalid),
        .data_o     (obi_rdata)
    );

    /********** UART发送相关信号 **********/
    reg                       tx_start;     // 发送开始信号
    reg  [7:0]                tx_data;      // 发送数据
    wire                      tx_busy;      // 发送中标志
    wire                      tx_end;       // 发送完成标志

    wire                      baud_clk;        // 波特率时钟

    ip0_clk_gen u_uart_clk_gen(
        .clk              (clk),
        .rst_n            (rst_n),
        .div_i            (16'(UART_DIV_RATE)),
        .clk_o            (baud_clk)
    );

    ip0_uart_rx u_uart_rx (
        .clk              (clk),
        .rst_n            (rst_n),
        .baud_clk_i       (baud_clk),
        .rx_i             (uart_tx),
        .busy_o           (rx_busy),
        .data_o           (rx_data),
        .ready_o          (rx_end),
        .error_o          (),
        .sample_cycles_i  (8'(SAMPLE_CYCLES)),
        .data_bits_i      (4'h8)  // 5-8 data bits (3-bit port)
    );

    ip0_uart_tx u_uart_tx (
        .clk              (clk),
        .rst_n            (rst_n),
        .baud_clk_i       (baud_clk),
        .data_i           (tx_data),
        .start_i          (tx_start),
        .busy_o           (tx_busy),
        .tx_o             (uart_rx),
        .tx_end_o         (tx_end),
        .sample_cycles_i  (8'(SAMPLE_CYCLES)),
        .data_bits_i      (4'h8)  // 5-8 data bits (3-bit port)
    );

    /********** UART发送字符任务 **********/
    task send_char;
        input [7:0] char;
        input       display;
        begin
            if (display) begin
                $display($time, " Sending character: %c", char);
            end
            // 等待发送空闲
            wait(tx_busy == 1'b0);
            @(posedge clk);
            tx_data  <= char;
            tx_start <= 1'b1;
            @(posedge clk);
            tx_start <= 1'b0;
            // 等待发送完成
            wait(tx_end == 1'b1);
            @(posedge clk);
        end
    endtask;

    /********** UART发送CR和LF任务 **********/
    task send_test;
        input [7:0] char;
        begin
            send_char(char,  1'b1);
            # 500;
            send_char(TEST_CMD_END, 1'b0);
            wait(rx_data == TEST_CMD_END);
            # 500;
        end
    endtask;

    reg init_done = 1'b0;
    /********** 接收信号的监测 **********/
    always @(posedge clk) begin
        if (rx_end == 1'b1) begin // 输出接收到的文字
            if (rx_data !== TEST_CMD_END) begin
                $write("%c", rx_data);
                $fflush(); // 强制刷新输出缓冲区，实现实时显示
            end else begin
                init_done <= 1'b1;
            end
        end
    end

    /********** 测试用例 **********/
    initial begin
        integer timeout;

        $readmemh(`ROM_PRG, u_ext_rom.u_gen_ram.ram);
        $readmemh(`RAM_PRG, u_chip_top.u_ram.u_gen_ram.ram);
        clk      <= 0;
        rst_n    <= 0;
        tx_start <= 1'b0;
        tx_data  <= 8'h00;

        @(posedge clk);
        rst_n <= 0;
        @(posedge clk);
        rst_n <= 1;

        timeout = 0;

        while (!init_done && timeout < TIMEOUT_CYCLES) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (timeout >= TIMEOUT_CYCLES) begin
            $display("Init timeout.");
            $finish;
        end
        # 500;

        // 发送测试命令
        $display("\n----- Starting Module Tests -----");

`ifdef PE_TEST_FOR_CHIP_TOP
        // 发送PE模块测试命令
        send_test(TEST_CMD_PE);
`endif

`ifdef GPIO_TEST_FOR_CHIP_TOP
        // 发送GPIO输入测试命令
        send_test(TEST_CMD_GPIO_IN);
        $display($time, " gpio_in  : %b", gpio_in);

`ifdef ASIC_VERSION
        # (5000 * 30);
`else
        # 20000;
`endif

        // 发送GPIO输出测试命令
        send_test(TEST_CMD_GPIO_OUT);
        # 20000;
        $display($time, " gpio_out : %b", gpio_out);
`endif

`ifdef SPI_TEST_FOR_CHIP_TOP
        // 发送SPI模块测试命令
        send_test(TEST_CMD_SPI);
`endif

`ifdef TIMER_TEST_FOR_CHIP_TOP
        // 发送Timer模块测试命令
        send_test(TEST_CMD_TIMER);
`endif

`ifdef ASIC_VERSION
        #(`SIM_CYCLE * 30);
`else
        #`SIM_CYCLE;
`endif

        $display("\n----- All Tests Completed -----");

        $finish;
    end

`ifndef ASIC_VERSION
    /********** 输出波形 **********/
    initial begin
        $dumpfile("chip_top_test.vcd");
        $dumpvars(0, chip_top_test);
    end
`endif

endmodule