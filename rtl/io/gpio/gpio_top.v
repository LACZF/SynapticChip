
`include "stddef.v"
`include "global_config.v"

`include "gpio.v"

module gpio_top #(
    parameter GPIO_IN_CH           = 1,
    parameter GPIO_OUT_CH          = 1,
    parameter GPIO_IO_CH           = 1
) (
    input  wire                        clk,
    input  wire                        rst_n,

    /********** 总线接口 **********/
    input  wire                        cs_n_i,    // 片选信号
    input  wire                        as_n_i,    // 地址选通信号
    input  wire                        rw_i,      // Read / Write
    input  wire [`GpioAddrBus]         addr_i,    // 地址
    input  wire [`WordDataBus]         wr_data_i, // 写入的数据
    output reg  [`WordDataBus]         rd_data_o, // 读取的数据
    output reg                         rdy_n_o,   // 就绪信号
    /********** 通用输入输出接口 **********/
    input wire [GPIO_IN_CH-1:0]        gpio_in,   // 输入端口（控制寄存器0）
    output reg [GPIO_OUT_CH-1:0]       gpio_out,  // 输出端口（控制寄存器1）
    inout wire [GPIO_IO_CH-1:0]        gpio_io    // I/O端口（控制寄存器2）
);

    /********** 输入输出信号 **********/
    wire    [GPIO_IO_CH-1:0]            io_in;      // 输入的数据
    reg     [GPIO_IO_CH-1:0]            io_out;     // 输出的数据
    reg     [GPIO_IO_CH-1:0]            io_dir;     // 输入输出方向（控制寄存器3）
    reg     [GPIO_IO_CH-1:0]            io;         // 输入输出
    integer                              i;          // 迭代器

    /********** 输入输出信号的连续赋值 **********/
    assign io_in         = gpio_io;             // 输入的数据
    assign gpio_io       = io;                  // 输入输出

    /********** 输入输出方向的控制 **********/
    always @(*) begin
        for (i = 0; i < GPIO_IO_CH; i = i + 1) begin : IO_DIR
            io[i] = (io_dir[i] == `GPIO_DIR_IN) ? 1'bz : io_out[i];
        end
    end

    /********** GPIO的控制 **********/
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            /* 异步复位 */
            rd_data_o     <= `WORD_DATA_W'h0;
            rdy_n_o       <= `DISABLE_N;
            gpio_out <= {GPIO_OUT_CH{`LOW}};
            io_out     <= {GPIO_IO_CH{`LOW}};
            io_dir     <= {GPIO_IO_CH{`GPIO_DIR_IN}};
        end else begin
            /* 就绪信号的生成 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N)) begin
                rdy_n_o     <= `ENABLE_N;
            end else begin
                rdy_n_o     <= `DISABLE_N;
            end
            /* 读取访问 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) && (rw_i == `READ)) begin
                case (addr_i)
                    `GPIO_ADDR_IN_DATA    : begin // 控制寄存器 0
                        rd_data_o     <= {{`WORD_DATA_W-GPIO_IN_CH{1'b0}}, gpio_in};
                    end
                    `GPIO_ADDR_OUT_DATA : begin // 控制寄存器 1
                        rd_data_o     <= {{`WORD_DATA_W-GPIO_OUT_CH{1'b0}}, gpio_out};
                    end
                    `GPIO_ADDR_IO_DATA    : begin // 控制寄存器 2
                        rd_data_o     <= {{`WORD_DATA_W-GPIO_IO_CH{1'b0}}, io_in};
                     end
                    `GPIO_ADDR_IO_DIR    : begin // 控制寄存器 3
                        rd_data_o     <= {{`WORD_DATA_W-GPIO_IO_CH{1'b0}}, io_dir};
                    end
                endcase
            end else begin
                rd_data_o     <= `WORD_DATA_W'h0;
            end
            /* 写入访问 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) && (rw_i == `WRITE)) begin
                case (addr_i)
                    `GPIO_ADDR_OUT_DATA : begin // 控制寄存器 1
                        gpio_out <= wr_data_i[GPIO_OUT_CH-1:0];
                    end
                    `GPIO_ADDR_IO_DATA    : begin // 控制寄存器 2
                        io_out <= wr_data_i[GPIO_IO_CH-1:0];
                     end
                    `GPIO_ADDR_IO_DIR    : begin // 控制寄存器 3
                        io_dir <= wr_data_i[GPIO_IO_CH-1:0];
                    end
                endcase
            end
        end
    end

endmodule
