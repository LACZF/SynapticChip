
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

    /********** OBI总线接口 **********/
    input  wire                        req_i,     // 请求信号
    input  wire                        we_i,      // 写使能
    input  wire [`GpioAddrBus]         addr_i,    // 地址
    input  wire [`WordDataBus]         wr_data_i, // 写入的数据
    output reg  [`WordDataBus]         data_out_o, // 读取的数据
    output reg                         gnt_o,     // 授权信号
    output reg                         rvalid_o,  // 读有效信号
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
    reg                                 req_accepted; // 请求已接受

    /********** 输入输出信号的连续赋值 **********/
    assign io_in         = gpio_io;             // 输入的数据
    assign gpio_io       = io;                  // 输入输出

    /********** 输入输出方向的控制 **********/
    always @(*) begin
        for (i = 0; i < GPIO_IO_CH; i = i + 1) begin : IO_DIR
            io[i] = (io_dir[i] == `GPIO_DIR_IN) ? 1'bz : io_out[i];
        end
    end

    /********** OBI握手逻辑 **********/
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            gnt_o <= 1'b0;
            rvalid_o <= 1'b0;
            req_accepted <= 1'b0;
        end else begin
            // 授权信号：当没有挂起的请求时立即授权
            if (req_i && !req_accepted) begin
                gnt_o <= 1'b1;
                req_accepted <= 1'b1;
            end else begin
                gnt_o <= 1'b0;
            end

            // 读有效信号：在请求被接受后的下一个周期置位
            if (req_accepted && !we_i) begin
                rvalid_o <= 1'b1;
            end else begin
                rvalid_o <= 1'b0;
            end

            // 清除请求接受标志
            if (req_accepted) begin
                req_accepted <= 1'b0;
            end
        end
    end

    /********** GPIO的控制 **********/
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            /* 异步复位 */
            data_out_o     <= `WORD_DATA_W'h0;
            gpio_out <= {GPIO_OUT_CH{`LOW}};
            io_out     <= {GPIO_IO_CH{`LOW}};
            io_dir     <= {GPIO_IO_CH{`GPIO_DIR_IN}};
        end else begin
            /* 读取访问 */
            if (req_accepted && !we_i) begin
                case (addr_i)
                    `GPIO_ADDR_IN_DATA    : begin // 控制寄存器 0
                        data_out_o     <= {{`WORD_DATA_W-GPIO_IN_CH{1'b0}}, gpio_in};
                    end
                    `GPIO_ADDR_OUT_DATA : begin // 控制寄存器 1
                        data_out_o     <= {{`WORD_DATA_W-GPIO_OUT_CH{1'b0}}, gpio_out};
                    end
                    `GPIO_ADDR_IO_DATA    : begin // 控制寄存器 2
                        data_out_o     <= {{`WORD_DATA_W-GPIO_IO_CH{1'b0}}, io_in};
                     end
                    `GPIO_ADDR_IO_DIR    : begin // 控制寄存器 3
                        data_out_o     <= {{`WORD_DATA_W-GPIO_IO_CH{1'b0}}, io_dir};
                    end
                endcase
            end else begin
                data_out_o     <= `WORD_DATA_W'h0;
            end
            /* 写入访问 */
            if (req_accepted && we_i) begin
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