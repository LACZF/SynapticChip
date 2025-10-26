
`timescale 1ns/1ps

`include "stddef.v"
`include "global_config.v"

`include "bus.v"
`include "cpu.v"
`include "gpio.v"

module chip_top_test;
    /********** 输入/输出信号 **********/
    reg                       clk;
    reg                       reset;

    localparam CPU_NUM        = 1;

    // UART
    wire                      uart_rx;       // UART接收信号
    wire                      uart_tx;       // UART发送信号

    // 通用输入/输出端口
    wire [`GPIO_IN_CH-1:0]    gpio_in = {`GPIO_IN_CH{1'b0}}; // 输入端口
    wire [`GPIO_OUT_CH-1:0]   gpio_out;                      // 输出端口
    wire [`GPIO_IO_CH-1:0]    gpio_io = {`GPIO_IO_CH{1'bz}}; // 输入输出端口

    /********** UART模型 **********/
    wire                      rx_busy;          // 接收中标志
    wire                      rx_end;           // 接收完成标志
    wire [`ByteDataBus]       rx_data;          // 接收的数据

    /********** 时钟生成 **********/
    always #5 clk = ~clk;

    /********** 实例化chip_top **********/
    chip_top #(
        .CPU_NUM         (CPU_NUM),
        .SLAVE_NUM       (8),
        .IMPLEMENT_ROM   (1),
        .IMPLEMENT_JTAG  (1),
        .IMPLEMENT_UART  (1),
        .IMPLEMENT_GPIO  (1),
        .IMPLEMENT_SPI   (1),
        .IMPLEMENT_TIMER (1),
        .GPIO_IN_CH      (`GPIO_IN_CH),
        .GPIO_OUT_CH     (`GPIO_OUT_CH),
        .GPIO_IO_CH      (`GPIO_IO_CH)
    ) u_chip_top (
        .clk         (clk),
        .reset       (reset),

        /********** UART **********/
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),

        /********** 通用输入/输出端口 **********/
        .gpio_in     (gpio_in),
        .gpio_out    (gpio_out),
        .gpio_io     (gpio_io)
);

    /********** GPIO的监测 **********/
    always @(gpio_in) begin     // gpio_in值变化后打印输出
        $display($time, " gpio_in changed  : %b", gpio_in);
    end
    always @(gpio_out) begin    // gpio_out值变化后打印输出
        $display($time, " gpio_out changed : %b", gpio_out);
    end
    always @(gpio_io) begin     // gpio_io值变化后打印输出
        $display($time, " gpio_io changed  : %b", gpio_io);
    end

    /********** 接收信号 **********/
    assign uart_rx = `HIGH;        // 空闲

    /********** UART模型 **********/
    uart_rx u_uart_model (
        .clk        (clk),
        .reset      (reset),
        /********** 控制信号 **********/
        .rx_busy_o  (rx_busy),
        .rx_end_o   (rx_end),
        .rx_data_o  (rx_data),
        /********** Receive Signal **********/
        .rx_i       (uart_tx)
    );

    /********** 发送信号的监测 **********/
    always @(posedge clk) begin
        if (rx_end == `ENABLE) begin // 输出接收到的文字
            $write("%c", rx_data);
        end
    end

    /********** 测试用例 **********/
    initial begin
        $readmemh(`ROM_PRG, u_chip_top.u_io.rom_gen.u_rom.u_x_s3e_sprom.mem);
        clk   <= `LOW;
        reset <= `RESET_ENABLE;

        @(posedge clk);
        reset <= `RESET_DISABLE;

        # `SIM_CYCLE $finish;
    end

    generate
        genvar i;
        for (i = 0; i < CPU_NUM; i = i + 1) begin : spm_init_gen
            initial begin
                $readmemh(`SPM_PRG, u_chip_top.cpu_gen[i].u_cpu.u_spm.u_x_s3e_dpram.mem);
            end
        end
    endgenerate

    /********** 输出波形 **********/
    initial begin
        $dumpfile("chip_top_test.vcd");
        $dumpvars(0, chip_top_test);
    end

endmodule