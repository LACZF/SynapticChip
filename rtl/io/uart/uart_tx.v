
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart_tx (
    input  wire                   clk,
    input  wire                   reset,

    /********** 控制信号 **********/
    input  wire                   tx_start,    // 发送开始信号
    input  wire [`ByteDataBus]    tx_data,     // 发送的数据
    output wire                   tx_busy,     // 发送中标志信号
    output reg                    tx_end,      // 发送完成信号
    /********** UART发送信号 **********/
    output reg                    tx           // UART发送信号
);

    /********** 内部信号 **********/
    reg [`UartStateBus]           state;       // 发送模块的状态
    reg [`UartDivCntBus]          div_cnt;     // 分频计数器
    reg [`UartBitCntBus]          bit_cnt;     // 比特计数器
    reg [`ByteDataBus]            sh_reg;      // 发送用移位寄存器

    /********** 发送中标志信号的生成 **********/
    assign tx_busy = (state == `UART_STATE_TX) ? `ENABLE : `DISABLE;

    /********** 发送逻辑电路 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            state     <= `UART_STATE_IDLE;
            div_cnt   <= `UART_DIV_RATE;
            bit_cnt   <= `UART_BIT_CNT_START;
            sh_reg    <= `BYTE_DATA_W'h0;
            tx_end    <= `DISABLE;
            tx        <= `UART_STOP_BIT;
        end else begin
            /* 发送状态 */
            case (state)
                `UART_STATE_IDLE : begin // 空闲状态
                    if (tx_start == `ENABLE) begin // 发送开始
                        state     <= `UART_STATE_TX;
                        sh_reg    <= tx_data;
                        tx        <= `UART_START_BIT;
                    end
                    tx_end    <= `DISABLE;
                end
                `UART_STATE_TX     : begin // 发送中
                    /* 通过时钟分频调整波特率 */
                    if (div_cnt == {`UART_DIV_CNT_W{1'b0}}) begin // 计数满
                        /* 发送下一个数据 */
                        case (bit_cnt)
                            `UART_BIT_CNT_MSB  : begin // 发送停止位
                                bit_cnt   <= `UART_BIT_CNT_STOP;
                                tx        <= `UART_STOP_BIT;
                            end
                            `UART_BIT_CNT_STOP : begin // 发送完成
                                state     <= `UART_STATE_IDLE;
                                bit_cnt   <= `UART_BIT_CNT_START;
                                tx_end    <= `ENABLE;
                            end
                            default               : begin // 数据的发送
                                bit_cnt   <= bit_cnt + 1'b1;
                                sh_reg    <= sh_reg >> 1'b1;
                                tx        <= sh_reg[`LSB];
                            end
                        endcase
                        div_cnt <= `UART_DIV_RATE;
                    end else begin // 倒数计数
                        div_cnt <= div_cnt - 1'b1 ;
                    end
                end
            endcase
        end
    end

endmodule
