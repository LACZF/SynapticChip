
`timescale 1ns/1ps

`define PE_TEST_FOR_CHIP_TOP
`define GPIO_TEST_FOR_CHIP_TOP
`define TIMER_TEST_FOR_CHIP_TOP
`define SPI_TEST_FOR_CHIP_TOP

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
    localparam GPIO_NUM       = 32;
    localparam BAUD_RATE      = 115200;
    localparam CLK_FREQ       = 50000000;
    localparam UART_DIV_RATE  = CLK_FREQ / BAUD_RATE;

    // UART
    reg                       uart_rx;       // UART接收信号
    wire                      uart_tx;       // UART发送信号

    // 通用输入/输出端口
    wire [GPIO_NUM-1:0]       gpio_in = {GPIO_NUM{1'b1}}; // 输入端口
    wire [GPIO_NUM-1:0]       gpio_out;                   // 输出端口
    wire [GPIO_NUM-1:0]       gpio_io = {GPIO_NUM{1'bz}}; // 输入输出端口

    /********** UART模型 **********/
    wire                      rx_busy;          // 接收中标志
    wire                      rx_end;           // 接收完成标志
    wire [7:0]                rx_data;          // 接收的数据

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
        .NUM_PES(4),
        .INST_WIDTH(32),
        .PE_ID_WIDTH(4),
        .PE_ARRAY_ROWS(2),
        .PE_ARRAY_COLS(2),
        .IMPLEMENT_ROM(1),
        .IMPLEMENT_JTAG(1),
        .IMPLEMENT_UART(1),
        .IMPLEMENT_GPIO(1),
        .IMPLEMENT_SPI(1),
        .IMPLEMENT_FLASH(0),
        .IMPLEMENT_TIMER(1),
        .IMPLEMENT_I2C(1),
        .GPIO_NUM(GPIO_NUM),
        .I2C_NUM(1),
        .UART_NUM(1),
        .SPI_NUM(2)
    ) u_chip_top (
        .clk         (clk),
        .rst_n       (rst_n),

        /********** UART **********/
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),

        /********** 通用输入/输出端口 **********/
        .gpio_in     (gpio_in),
        .gpio_out    (gpio_out),
        .gpio_io     (gpio_io)
    );

    /********** UART发送相关信号 **********/
    reg                       tx_start;     // 发送开始信号
    reg  [7:0]                tx_data;      // 发送数据
    wire                      tx_busy;      // 发送中标志
    wire                      tx_end;       // 发送完成标志

    /********** UART接收模型 **********/
    test_uart_rx u_uart_rx (
        .clk        (clk),
        .rst_n      (rst_n),
        /********** 控制信号 **********/
        .rx_busy_o  (rx_busy),
        .rx_end_o   (rx_end),
        .rx_data_o  (rx_data),
        /********** Receive Signal **********/
        .rx_i       (uart_tx)
    );

    /********** UART发送模型 **********/
    test_uart_tx u_uart_tx (
        .clk        (clk),
        .rst_n      (rst_n),
        /********** 控制信号 **********/
        .tx_start_i (tx_start),
        .tx_data_i  (tx_data),
        .tx_busy_o  (tx_busy),
        .tx_end_o   (tx_end),
        /********** UART发送信号 **********/
        .tx_o       (uart_rx)
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
            // 等待发送完成
            wait(tx_end == 1'b1);
            tx_start <= 1'b0;
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
            $write("%c", rx_data);
            $fflush(); // 强制刷新输出缓冲区，实现实时显示
        end
    end

    /********** 测试用例 **********/
    initial begin
        $readmemh(`ROM_PRG, u_chip_top.u_rom.u_gen_ram.ram);
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
        #1000;

        // 发送测试命令
        $display("\n----- Starting Module Tests -----");

        // 等待初始化完成
        wait(rx_data == TEST_CMD_END);
        # 500;

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