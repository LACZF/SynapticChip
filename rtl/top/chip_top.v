
`include "stddef.v"
`include "global_config.v"

`include "gpio.v"

module chip_top (
    input  wire                        clk_ref,
    input  wire                        reset_sw

`ifdef IMPLEMENT_JTAG
    /********** JTAG **********/
    , input wire                       tck
    , input wire                       tms
    , input wire                       tdi
    , output wire                      tdo
    , output wire                      tdo_en
`endif
`ifdef IMPLEMENT_UART
    /********** UART **********/
    , input wire                       uart_rx
    , output wire                      uart_tx
`endif

`ifdef IMPLEMENT_GPIO
    /********** GPIO **********/
`ifdef GPIO_IN_CH     // 输入端口的实现
    , input wire [`GPIO_IN_CH-1:0]     gpio_in  // 输入端口
`endif
`ifdef GPIO_OUT_CH     // 输出端口实现
    , output wire [`GPIO_OUT_CH-1:0]   gpio_out // 输出端口
`endif
`ifdef GPIO_IO_CH     // 输入/输出端口的实现
    , inout wire [`GPIO_IO_CH-1:0]     gpio_io  // 输入输出端口
`endif
`endif
);

    /********** 时钟 & 复位 **********/
    wire                       clk;              // 时钟
    wire                       clk_;             // 反相时钟
    wire                       chip_reset;       // 复芯片位

    clk_gen u_clk_gen (
        /********** 时钟 & 复位 **********/
        .clk_ref      (clk_ref),                // 主时钟
        .reset_sw     (reset_sw),               // 复位按钮
        /********** 生成时钟 **********/
        .clk          (clk),                    // 时钟
        .clk_         (clk_),                   // 反相时钟
        /********** 复芯片位 **********/
        .chip_reset   (chip_reset)              // 复芯片位
    );

    chip u_chip (
        .clk          (clk),
        .clk_         (clk_),
        .reset        (chip_reset)

`ifdef IMPLEMENT_JTAG
        /********** JTAG **********/
        , .tck        (tck)
        , .tms        (tms)
        , .tdi        (tdi)
        , .tdo        (tdo)
        , .tdo_en     (tdo_en)
`endif

`ifdef IMPLEMENT_UART
        /********** UART **********/
        , .uart_rx    (uart_rx)
        , .uart_tx    (uart_tx)
`endif
`ifdef IMPLEMENT_GPIO
        /********** GPIO **********/
`ifdef GPIO_IN_CH  // 输入端口的实现
        , .gpio_in    (gpio_in)
`endif
`ifdef GPIO_OUT_CH // 输出端口实现
        , .gpio_out   (gpio_out)
`endif
`ifdef GPIO_IO_CH  // 输入/输出端口的实现
        , .gpio_io    (gpio_io)
`endif
`endif
    );

endmodule