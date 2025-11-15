
`timescale 1ns/1ps

// 当所有测试宏都未定义时，自动定义所有测试宏
`ifndef PE_TEST_FOR_CHIP_TOP
    `ifndef GPIO_TEST_FOR_CHIP_TOP
        `ifndef TIMER_TEST_FOR_CHIP_TOP
            `ifndef SPI_TEST_FOR_CHIP_TOP
                `define PE_TEST_FOR_CHIP_TOP
                `define GPIO_TEST_FOR_CHIP_TOP
                `define TIMER_TEST_FOR_CHIP_TOP
                `define SPI_TEST_FOR_CHIP_TOP
            `endif
        `endif
    `endif
`endif

module chip_top_test;
    /********** 输入/输出信号 **********/
    reg                       clk;
    reg                       rst_n;

    localparam TEST_CMD_PE    = 8'h70; // 'p'
    localparam TEST_CMD_GPIO  = 8'h67; // 'g'
    localparam TEST_CMD_SPI   = 8'h73; // 's'
    localparam TEST_CMD_TIMER = 8'h74; // 't'
    localparam TEST_CMD_END   = 8'h04;
    localparam CPU_NUM        = 1;
    localparam GPIO_IN_NUM    = 14;
    localparam GPIO_OUT_NUM   = 8;
    localparam GPIO_INOUT_NUM = 66;
    localparam SPI_NUM        = 2;
    localparam SAMPLE_CYCLES  = 4;
    localparam UART_DIV_RATE  = 2;
    localparam IMPLEMENT_ROM  = 1;

    // UART
    reg                       uart_rx;       // UART接收信号
    wire                      uart_tx;       // UART发送信号

    // SPI
    wire [SPI_NUM-1:0]        spi_cs_n;      // SPI片选信号
    wire                      spi_clk;       // SPI时钟信号
    wire                      spi_mosi;      // SPI主机输出从机输入
    wire                      spi_miso;      // SPI主机输入从机输出

    // QSPI Flash接口
    wire [3:0]                flash_spi_dq_in;   // QSPI Flash数据输入
    wire [3:0]                flash_spi_dq_out;  // QSPI Flash数据输出
    wire [3:0]                flash_spi_dq_oe;    // QSPI Flash数据输出使能
    wire                      flash_spi_clk_pin; // QSPI Flash时钟
    wire                      flash_spi_ss_pin;  // QSPI Flash片选

    // SPI从机MISO信号数组（用于多个从机）
    wire [SPI_NUM-1:0] spi_slave_miso;

    // SPI模式选择信号（每个从机一个）
    reg [1:0] [SPI_NUM-1:0] spi_slave_mode;

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
    wire [GPIO_INOUT_NUM-1:0]    gpio_io = {GPIO_INOUT_NUM{1'bz}};

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
    assign flash_spi_dq_in[0] = flash_spi_dq_oe[0] ? flash_spi_dq_out[0] : 1'bz;
    assign flash_spi_dq_in[1] = flash_spi_dq_oe[1] ? flash_spi_dq_out[1] : 1'bz;
    assign flash_spi_dq_in[2] = flash_spi_dq_oe[2] ? flash_spi_dq_out[2] : 1'bz;
    assign flash_spi_dq_in[3] = flash_spi_dq_oe[3] ? flash_spi_dq_out[3] : 1'bz;

    /********** 时钟生成 **********/
    always #2 clk = ~clk;

    /********** 实例化chip_top **********/
    chip_top #(
        .TRACE_ENABLE(0),
        .CPU_NUM(1),
        .ROM_DEPTH(8192),
        .RAM_DEPTH(8192),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .NUM_PES(16),
        .INST_WIDTH(32),
        .PE_ID_WIDTH(4),
        .PE_ARRAY_X(4),
        .PE_ARRAY_Y(4),
        .IMPLEMENT_ROM(IMPLEMENT_ROM),
        .IMPLEMENT_JTAG(1),
        .IMPLEMENT_UART(1),
        .IMPLEMENT_GPIO(1),
        .IMPLEMENT_SPI(1),
        .IMPLEMENT_FLASH(1),
        .IMPLEMENT_TIMER(1),
        .IMPLEMENT_I2C(1),
        .GPIO_IN_NUM(GPIO_IN_NUM),
        .GPIO_OUT_NUM(GPIO_OUT_NUM),
        .GPIO_INOUT_NUM(GPIO_INOUT_NUM),
        .I2C_NUM(1),
        .UART_NUM(1),
        .SPI_NUM(SPI_NUM)
    ) u_chip_top (
        .clk         (clk),
        .rst_n       (rst_n),

        /********** UART **********/
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),

        /********** 通用输入/输出端口 **********/
        .gpio_in     (gpio_in),
        .gpio_out    (gpio_out),
        .gpio_io     (gpio_io),

        /********** SPI **********/
        .spi_cs_n    (spi_cs_n),
        .spi_clk     (spi_clk),
        .spi_mosi    (spi_mosi),
        .spi_miso    (spi_miso),

        /********** QSPI Flash **********/
        .flash_spi_dq_in   (flash_spi_dq_in),
        .flash_spi_dq_out  (flash_spi_dq_out),
        .flash_spi_dq_oe   (flash_spi_dq_oe),
        .flash_spi_clk_pin (flash_spi_clk_pin),
        .flash_spi_ss_pin  (flash_spi_ss_pin)
    );

    /********** 实例化QSPI Flash模拟模块 **********/
    qspi_flash_model #(
        .FLASH_SIZE  (64*1024),
        .PROGRAM_FILE(`ROM_PRG)
    ) u_qspi_flash (
        .clk            (clk),
        .rst_n          (rst_n),
        .cs_n           (flash_spi_ss_pin),
        .sck            (flash_spi_clk_pin),
        .io_in          (flash_spi_dq_in),
        .io_out         (flash_spi_dq_out),
        .io_oe          (flash_spi_dq_oe[0])
    );

    /********** UART发送相关信号 **********/
    reg                       tx_start;     // 发送开始信号
    reg  [7:0]                tx_data;      // 发送数据
    wire                      tx_busy;      // 发送中标志
    wire                      tx_end;       // 发送完成标志

    wire                      baud_clk;        // 波特率时钟

    clk_gen u_uart_clk_gen(
        .clk              (clk),
        .rst_n            (rst_n),
        .div_i            (16'(UART_DIV_RATE)),
        .clk_o            (baud_clk)
    );

    uart_rx u_uart_rx (
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

    uart_tx u_uart_tx (
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

    /********** 接收信号的监测 **********/
    always @(posedge clk) begin
        if (rx_end == 1'b1) begin // 输出接收到的文字
            if (rx_data !== TEST_CMD_END) begin
                $write("%c", rx_data);
                $fflush(); // 强制刷新输出缓冲区，实现实时显示
            end
        end
    end

    /********** 测试用例 **********/
    initial begin
        if (IMPLEMENT_ROM) begin
            $readmemh(`ROM_PRG, u_chip_top.rom_gen.u_rom.u_gen_ram.ram);
        end
        $readmemh(`RAM_PRG, u_chip_top.u_ram.u_gen_ram.ram);
        clk      <= 0;
        rst_n    <= 0;
        tx_start <= 1'b0;
        tx_data  <= 8'h00;

        @(posedge clk);
        rst_n <= 0;
        @(posedge clk);
        rst_n <= 1;

        // 等待系统初始化完成
        wait(rx_data == TEST_CMD_END);
        # 500;

        // 发送测试命令
        $display("\n----- Starting Module Tests -----");

`ifdef PE_TEST_FOR_CHIP_TOP
        // 发送PE模块测试命令
        send_test(TEST_CMD_PE);
`endif

`ifdef GPIO_TEST_FOR_CHIP_TOP
        // 发送GPIO模块测试命令
        send_test(TEST_CMD_GPIO);
        $display($time, " gpio_in  : %b", gpio_in);
        $display($time, " gpio_out : %b", gpio_out);
        $display($time, " gpio_io  : %b", gpio_io);
`endif

`ifdef SPI_TEST_FOR_CHIP_TOP
        // 发送SPI模块测试命令
        send_test(TEST_CMD_SPI);
`endif

`ifdef TIMER_TEST_FOR_CHIP_TOP
        // 发送Timer模块测试命令
        send_test(TEST_CMD_TIMER);
`endif
        // #`SIM_CYCLE;

        $display("\n----- All Tests Completed -----");

        $finish;
    end

    /********** 输出波形 **********/
    initial begin
        $dumpfile("chip_top_test.vcd");
        $dumpvars(0, chip_top_test);
    end

endmodule