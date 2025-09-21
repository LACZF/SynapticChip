// uart_core.v
// UART核心模块实现

`include "uart_params.v"

module uart_core (
    input clk,
    input rst_n,

    // 控制接口
    input req,
    input we,
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] data_in,
    output reg [`DATA_WIDTH-1:0] data_out,
    output reg ack,

    // 串行接口
    output reg txd,        // 发送数据线
    input rxd,             // 接收数据线
    output reg rts,        // 请求发送 (可选)
    input cts,             // 清除发送 (可选)

    // 中断输出
    output reg int_out
);

    // 内部寄存器
    reg [7:0] rbr;         // 接收缓冲寄存器
    reg [7:0] thr;         // 发送保持寄存器
    reg [7:0] ier;         // 中断使能寄存器
    reg [7:0] iir;         // 中断标识寄存器
    reg [7:0] fcr;         // FIFO控制寄存器
    reg [7:0] lcr;         // 线控制寄存器
    reg [7:0] mcr;         // Modem控制寄存器
    reg [7:0] lsr;         // 线状态寄存器
    reg [7:0] msr;         // Modem状态寄存器
    reg [7:0] scr;         // Scratch寄存器
    reg [15:0] dll_dlm;    // 分频器锁存器

    // 波特率生成
    reg [15:0] baud_counter;
    reg baud_tick;

    // 发送状态机
    reg [3:0] tx_state;
    reg [7:0] tx_shift;
    reg [3:0] tx_bit_count;
    reg tx_parity;

    // 接收状态机
    reg [3:0] rx_state;
    reg [7:0] rx_shift;
    reg [3:0] rx_bit_count;
    reg rx_parity;
    reg rxd_sync;

    // FIFO缓冲区
    reg [7:0] rx_fifo [0:`FIFO_DEPTH-1];
    reg [7:0] tx_fifo [0:`FIFO_DEPTH-1];
    reg [`FIFO_ADDR_WIDTH-1:0] rx_head, rx_tail;
    reg [`FIFO_ADDR_WIDTH-1:0] tx_head, tx_tail;
    reg rx_full, rx_empty;
    reg tx_full, tx_empty;

    // 同步输入信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync <= 1'b1;
        end else begin
            rxd_sync <= rxd;
        end
    end

    // 波特率生成器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_counter == dll_dlm) begin
                baud_counter <= 0;
                baud_tick <= 1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 0;
            end
        end
    end

    // 发送状态机
    parameter TX_IDLE = 4'b0000;
    parameter TX_START = 4'b0001;
    parameter TX_DATA = 4'b0010;
    parameter TX_PARITY = 4'b0011;
    parameter TX_STOP = 4'b0100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= TX_IDLE;
            txd <= 1'b1;
            tx_shift <= 8'b0;
            tx_bit_count <= 0;
            tx_parity <= 0;
        end else if (baud_tick) begin
            case (tx_state)
                TX_IDLE: begin
                    if (!tx_empty) begin
                        // 从FIFO读取数据
                        tx_shift <= tx_fifo[tx_tail];
                        tx_tail <= tx_tail + 1;
                        tx_empty <= (tx_tail + 1 == tx_head);
                        tx_full <= 0;

                        tx_state <= TX_START;
                        txd <= 1'b0; // 起始位
                        tx_bit_count <= 0;
                        tx_parity <= 0;
                    end
                end

                TX_START: begin
                    tx_state <= TX_DATA;
                end

                TX_DATA: begin
                    txd <= tx_shift[0];
                    tx_shift <= {1'b0, tx_shift[7:1]};
                    tx_parity <= tx_parity ^ tx_shift[0];

                    if (tx_bit_count == (lcr[1:0] + 4'd5)) begin
                        tx_bit_count <= 0;
                        if (lcr[3]) begin
                            tx_state <= TX_PARITY; // 有奇偶校验
                        end else begin
                            tx_state <= TX_STOP; // 无奇偶校验
                        end
                    end else begin
                        tx_bit_count <= tx_bit_count + 1;
                    end
                end

                TX_PARITY: begin
                    txd <= (lcr[4] ? ~tx_parity : tx_parity); // 奇偶校验位
                    tx_state <= TX_STOP;
                end

                TX_STOP: begin
                    txd <= 1'b1; // 停止位
                    if (tx_bit_count == (lcr[2] ? 1'd1 : 1'd0)) begin
                        tx_state <= TX_IDLE;
                    end else begin
                        tx_bit_count <= tx_bit_count + 1;
                    end
                end
            endcase
        end
    end

    // 接收状态机
    parameter RX_IDLE = 4'b0000;
    parameter RX_START = 4'b0001;
    parameter RX_DATA = 4'b0010;
    parameter RX_PARITY = 4'b0011;
    parameter RX_STOP = 4'b0100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= RX_IDLE;
            rx_shift <= 8'b0;
            rx_bit_count <= 0;
            rx_parity <= 0;
            rx_head <= 0;
            rx_tail <= 0;
            rx_empty <= 1;
            rx_full <= 0;
        end else if (baud_tick) begin
            case (rx_state)
                RX_IDLE: begin
                    if (!rxd_sync) begin // 检测起始位
                        rx_state <= RX_START;
                        rx_bit_count <= 0;
                        rx_parity <= 0;
                    end
                end

                RX_START: begin
                    if (!rxd_sync) begin // 确认起始位
                        rx_state <= RX_DATA;
                    end else begin
                        rx_state <= RX_IDLE; // 假起始位
                    end
                end

                RX_DATA: begin
                    rx_shift <= {rxd_sync, rx_shift[7:1]};
                    rx_parity <= rx_parity ^ rxd_sync;

                    if (rx_bit_count == (lcr[1:0] + 4'd5)) begin
                        rx_bit_count <= 0;
                        if (lcr[3]) begin
                            rx_state <= RX_PARITY; // 有奇偶校验
                        end else begin
                            rx_state <= RX_STOP; // 无奇偶校验
                        end
                    end else begin
                        rx_bit_count <= rx_bit_count + 1;
                    end
                end

                RX_PARITY: begin
                    if (lcr[4] ? (rx_parity != rxd_sync) : (rx_parity == rxd_sync)) begin
                        // 奇偶校验错误
                        lsr[2] <= 1'b1;
                    end
                    rx_state <= RX_STOP;
                end

                RX_STOP: begin
                    if (!rxd_sync) begin
                        // 帧错误 (停止位不是1)
                        lsr[3] <= 1'b1;
                    end

                    // 将数据存入FIFO
                    if (!rx_full) begin
                        rx_fifo[rx_head] <= rx_shift;
                        rx_head <= rx_head + 1;
                        rx_empty <= 0;
                        rx_full <= (rx_head + 1 == rx_tail);

                        // 设置数据就绪标志
                        lsr[0] <= 1'b1;
                    end else begin
                        // FIFO溢出
                        lsr[1] <= 1'b1;
                    end

                    rx_state <= RX_IDLE;
                end
            endcase
        end
    end

    // 中断生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iir <= {4'b0, `INT_NONE};
            int_out <= 0;
        end else begin
            // 检查中断条件
            if ((ier[0] && !rx_empty) ||          // 接收数据可用
                (ier[1] && !tx_full) ||           // 发送保持寄存器空
                (ier[2] && (lsr[2] || lsr[3])) || // 接收线状态错误
                (ier[3] && msr[0])) begin         // Modem状态变化

                // 设置最高优先级中断
                if (ier[2] && (lsr[2] || lsr[3])) begin
                    iir <= {4'b0, `INT_LS};
                end else if (ier[0] && !rx_empty) begin
                    iir <= {4'b0, `INT_RX};
                end else if (ier[1] && !tx_full) begin
                    iir <= {4'b0, `INT_TX};
                end else if (ier[3] && msr[0]) begin
                    iir <= {4'b0, `INT_MS};
                end

                int_out <= 1;
            end else begin
                iir <= {4'b0, `INT_NONE};
                int_out <= 0;
            end
        end
    end

    // 寄存器读写
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thr <= 8'b0;
            ier <= 8'b0;
            fcr <= 8'b0;
            lcr <= 8'b0;
            mcr <= 8'b0;
            scr <= 8'b0;
            dll_dlm <= 16'd12; // 默认波特率 115200 @ 100MHz
            ack <= 1'b0;
            data_out <= {`DATA_WIDTH{1'b0}};
        end else begin
            ack <= 1'b0;

            if (req) begin
                if (we) begin
                    // 写操作
                    case (addr)
                        `REG_THR: begin
                            if (!tx_full) begin
                                tx_fifo[tx_head] <= data_in[7:0];
                                tx_head <= tx_head + 1;
                                tx_empty <= 0;
                                tx_full <= (tx_head + 1 == tx_tail);
                            end
                        end
                        `REG_IER: ier <= data_in[7:0];
                        `REG_FCR: fcr <= data_in[7:0];
                        `REG_LCR: lcr <= data_in[7:0];
                        `REG_MCR: mcr <= data_in[7:0];
                        `REG_SCR: scr <= data_in[7:0];
                        `REG_DLL: if (lcr[7]) dll_dlm[7:0] <= data_in[7:0];
                        `REG_DLM: if (lcr[7]) dll_dlm[15:8] <= data_in[7:0];
                    endcase
                end else begin
                    // 读操作
                    case (addr)
                        `REG_RBR: begin
                            if (!rx_empty) begin
                                data_out <= {24'b0, rx_fifo[rx_tail]};
                                rx_tail <= rx_tail + 1;
                                rx_full <= 0;
                                rx_empty <= (rx_tail + 1 == rx_head);

                                if (rx_empty) begin
                                    lsr[0] <= 1'b0; // 清除数据就绪标志
                                end
                            end
                        end
                        `REG_IER: data_out <= {24'b0, ier};
                        `REG_IIR: data_out <= {24'b0, iir};
                        `REG_LCR: data_out <= {24'b0, lcr};
                        `REG_MCR: data_out <= {24'b0, mcr};
                        `REG_LSR: data_out <= {24'b0, lsr};
                        `REG_MSR: data_out <= {24'b0, msr};
                        `REG_SCR: data_out <= {24'b0, scr};
                        `REG_DLL: if (lcr[7]) data_out <= {24'b0, dll_dlm[7:0]};
                        `REG_DLM: if (lcr[7]) data_out <= {24'b0, dll_dlm[15:8]};
                        default: data_out <= {`DATA_WIDTH{1'b0}};
                    endcase
                end

                ack <= 1'b1;
            end
        end
    end

endmodule
