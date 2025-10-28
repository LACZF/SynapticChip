
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart_ctrl (
    input  wire                   clk,
    input  wire                   rst_n,

    /********** 总线接口 **********/
    input  wire                   cs_n_i,        // 片选信号
    input  wire                   as_n_i,        // 地址选通信号
    input  wire                   rw_i,          // Read / Write
    input  wire [`UartAddrBus]    addr_i,        // 地址
    input  wire [`WordDataBus]    wr_data_i,     // 写入的数据
    output reg  [`WordDataBus]    rd_data_o,     // 读取的数据
    output reg                    rdy_n_o,       // 就绪信号
    /********** 中断 **********/
    output reg                    irq_rx_o,      // 接收中断请求信号
    output reg                    irq_tx_o,      // 发送中断请求信号
    /********** 控制信号 **********/
    // 接收控制
    input  wire                   rx_busy_i,     // 接收中标志信号
    input  wire                   rx_end_i,      // 接收完成信号
    input  wire [`ByteDataBus]    rx_data_i,     // 接收的数据
    // 发送控制
    input  wire                   tx_busy_i,     // 发送中标志信号
    input  wire                   tx_end_i,      // 发送完成信号
    output reg                    tx_start_o,    // 发送开始信号
    output reg  [`ByteDataBus]    tx_data_o      // 发送的数据
);

    /********** 标准UART 16550寄存器 **********/
    reg [`ByteDataBus]            rbr;            // 接收缓冲寄存器
    reg [`ByteDataBus]            ier;            // 中断使能寄存器
    reg [`ByteDataBus]            iir;            // 中断识别寄存器
    reg [`ByteDataBus]            fcr;            // FIFO控制寄存器
    reg [`ByteDataBus]            lcr;            // 线路控制寄存器
    reg [`ByteDataBus]            mcr;            // 调制解调器控制寄存器
    reg [`ByteDataBus]            lsr;            // 线路状态寄存器
    reg [`ByteDataBus]            msr;            // 调制解调器状态寄存器
    reg [`ByteDataBus]            scr;            // 暂存寄存器
    reg [`ByteDataBus]            dll;            // 除数锁存低字节
    reg [`ByteDataBus]            dlh;            // 除数锁存高字节

    /********** 内部信号 **********/
    reg                           dlab;           // 除数锁存访问位
    reg                           rx_data_ready;  // 接收数据就绪标志
    reg                           overrun_error;  // 溢出错误标志

    /********** UART控制逻辑电路 **********/
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            /* 异步复位 */
            rd_data_o     <= `WORD_DATA_W'h0;
            rdy_n_o       <= `DISABLE_N;
            irq_rx_o      <= `DISABLE;
            irq_tx_o      <= `DISABLE;
            tx_start_o    <= `DISABLE;
            tx_data_o     <= `BYTE_DATA_W'h0;

            // 初始化寄存器
            rbr           <= `BYTE_DATA_W'h0;
            ier           <= `BYTE_DATA_W'h0;
            iir           <= `BYTE_DATA_W'h1; // 无中断
            fcr           <= `BYTE_DATA_W'h0;
            lcr           <= `BYTE_DATA_W'h0;
            mcr           <= `BYTE_DATA_W'h0;
            lsr           <= 8'b00110000; // THRE=1, TEMT=1
            msr           <= `BYTE_DATA_W'h0;
            scr           <= `BYTE_DATA_W'h0;
            dll           <= `BYTE_DATA_W'h0;
            dlh           <= `BYTE_DATA_W'h0;

            dlab          <= `DISABLE;
            rx_data_ready <= `DISABLE;
            overrun_error <= `DISABLE;
        end else begin
            /* 就绪信号的生成 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N)) begin
                rdy_n_o     <= `ENABLE_N;
            end else begin
                rdy_n_o     <= `DISABLE_N;
            end

            /* 更新dlab标志 */
            dlab <= lcr[`UART_LCR_DLAB];

            /* 更新线路状态寄存器 */
            lsr[`UART_LSR_THRE]     <= ~tx_busy_i;
            lsr[`UART_LSR_TEMT]     <= ~tx_busy_i;
            lsr[`UART_LSR_DR]       <= rx_data_ready;
            lsr[`UART_LSR_OE]       <= overrun_error;
            lsr[`UART_LSR_PE]       <= `DISABLE;
            lsr[`UART_LSR_FE]       <= `DISABLE;
            lsr[`UART_LSR_BI]       <= `DISABLE;
            lsr[`UART_LSR_FIFO_ERR] <= `DISABLE;

            /* 更新中断状态 */
            if (tx_end_i == `ENABLE) begin
                if (ier[`UART_IER_ETBEI] == `ENABLE) begin
                    irq_tx_o <= `ENABLE;
                end
            end

            if (rx_end_i == `ENABLE) begin
                if (rx_data_ready == `ENABLE) begin
                    overrun_error <= `ENABLE;
                end else begin
                    rbr <= rx_data_i;
                    rx_data_ready <= `ENABLE;
                    if (ier[`UART_IER_ERBFI] == `ENABLE) begin
                        irq_rx_o <= `ENABLE;
                    end
                end
            end

            /* 读取访问 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) && (rw_i == `READ)) begin
                if (dlab == `ENABLE) begin
                    // 访问除数锁存寄存器
                    case (addr_i)
                        `UART_ADDR_DLL: rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, dll};
                        `UART_ADDR_DLH: rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, dlh};
                        default:        rd_data_o <= `WORD_DATA_W'h0;
                    endcase
                end else begin
                    // 访问标准寄存器
                    case (addr_i)
                        `UART_ADDR_RBR: begin
                            rd_data_o     <= {{`BYTE_DATA_W*2{1'b0}}, rbr};
                            rx_data_ready <= `DISABLE;
                            irq_rx_o      <= `DISABLE;
                        end
                        `UART_ADDR_IER: rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, ier};
                        `UART_ADDR_IIR: begin
                            // 模拟中断识别，按优先级顺序
                            if (rx_data_ready == `ENABLE) begin
                                rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, 8'b00000101}; // 接收数据可用
                            end else if (~tx_busy_i) begin
                                rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, 8'b00000010}; // 发送保持寄存器空
                            end else begin
                                rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, 8'b00000001}; // 无中断
                            end
                        end
                        `UART_ADDR_LCR:    rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, lcr};
                        `UART_ADDR_MCR:    rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, mcr};
                        `UART_ADDR_LSR:    rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, lsr};
                        `UART_ADDR_MSR:    rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, msr};
                        `UART_ADDR_SCR:    rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, scr};
                        // 向后兼容的地址
                        `UART_ADDR_STATUS: rd_data_o <= {{`BYTE_DATA_W*2{1'b0}}, lsr};
                        `UART_ADDR_DATA: begin
                            rd_data_o     <= {{`BYTE_DATA_W*2{1'b0}}, rbr};
                            rx_data_ready <= `DISABLE;
                            irq_rx_o      <= `DISABLE;
                        end
                        default: rd_data_o <= `WORD_DATA_W'h0;
                    endcase
                end
            end else begin
                rd_data_o <= `WORD_DATA_W'h0;
            end

            /* 写入访问 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) && (rw_i == `WRITE)) begin
                if (dlab == `ENABLE) begin
                    // 写入除数锁存寄存器
                    case (addr_i)
                        `UART_ADDR_DLL: dll <= wr_data_i[`BYTE_MSB:`LSB];
                        `UART_ADDR_DLH: dlh <= wr_data_i[`BYTE_MSB:`LSB];
                    endcase
                end else begin
                    // 写入标准寄存器
                    case (addr_i)
                        `UART_ADDR_THR: begin
                            tx_start_o          <= `ENABLE;
                            tx_data_o           <= wr_data_i[`BYTE_MSB:`LSB];
                            lsr[`UART_LSR_THRE] <= `DISABLE;
                        end
                        `UART_ADDR_IER: ier <= wr_data_i[`BYTE_MSB:`LSB];
                        `UART_ADDR_FCR: fcr <= wr_data_i[`BYTE_MSB:`LSB];
                        `UART_ADDR_LCR: lcr <= wr_data_i[`BYTE_MSB:`LSB];
                        `UART_ADDR_MCR: mcr <= wr_data_i[`BYTE_MSB:`LSB];
                        `UART_ADDR_SCR: scr <= wr_data_i[`BYTE_MSB:`LSB];
                        // 向后兼容的地址
                        `UART_ADDR_DATA: begin
                            tx_start_o          <= `ENABLE;
                            tx_data_o           <= wr_data_i[`BYTE_MSB:`LSB];
                            lsr[`UART_LSR_THRE] <= `DISABLE;
                        end
                        // 写入中断状态寄存器（向后兼容）
                        `UART_ADDR_STATUS: begin
                            if (wr_data_i[`UartCtrlIrqTx] == `DISABLE) begin
                                irq_tx_o <= `DISABLE;
                            end
                            if (wr_data_i[`UartCtrlIrqRx] == `DISABLE) begin
                                irq_rx_o <= `DISABLE;
                            end
                        end
                    endcase
                end
            end else begin
                tx_start_o <= `DISABLE;
            end
        end
    end

endmodule