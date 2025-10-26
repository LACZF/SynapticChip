
`include "stddef.v"
`include "global_config.v"

`include "timer.v"

module timer (
    input  wire                    clk,
    input  wire                    reset,

    /********** 总线接口 **********/
    input  wire                    cs_n_i,       // 片选
    input  wire                    as_n_i,       // 地址选通
    input  wire                    rw_i,         // Read / Write
    input  wire [`TimerAddrBus]    addr_i,       // 地址
    input  wire [`WordDataBus]     wr_data_i,    // 数据写入
    output reg    [`WordDataBus]   rd_data_o,    // 数据读取
    output reg                     rdy_n_o,      // 就绪信号
    /********** 中断 **********/
    output reg                     irq_o         // 控制寄存器1：中断请求信号
);

    /********** 控制寄存器 **********/
    // 控制寄存器 0 : 控制
    reg                            mode;       // 模式位
    reg                            start;      // 起始位
    // 控制寄存器 2 : 最大值
    reg [`WordDataBus]             expr_val;   // 最大值
    // 控制寄存器 3 : 计数器
    reg [`WordDataBus]             counter;    // 计数器

    /********** 计时完成标志位 **********/
    wire expr_flag = ((start == `ENABLE) && (counter == expr_val)) ? `ENABLE : `DISABLE;

    /********** 定时器控制 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            rd_data_o   <= `WORD_DATA_W'h0;
            rdy_n_o     <= `DISABLE_N;
            start       <= `DISABLE;
            mode        <= `TIMER_MODE_ONE_SHOT;
            irq_o       <= `DISABLE;
            expr_val    <= `WORD_DATA_W'h0;
            counter     <= `WORD_DATA_W'h0;
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
                    `TIMER_ADDR_CTRL    : begin // 控制寄存器 0
                        rd_data_o     <= {{`WORD_DATA_W-2{1'b0}}, mode, start};
                    end
                    `TIMER_ADDR_INTR    : begin // 控制寄存器 1
                        rd_data_o     <= {{`WORD_DATA_W-1{1'b0}}, irq_o};
                    end
                    `TIMER_ADDR_EXPR    : begin // 控制寄存器 2
                        rd_data_o     <= expr_val;
                    end
                    `TIMER_ADDR_COUNTER : begin // 控制寄存器 3
                        rd_data_o     <= counter;
                    end
                endcase
            end else begin
                rd_data_o     <= `WORD_DATA_W'h0;
            end
            /* 写入访问 */
            // 控制寄存器 0
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                (rw_i == `WRITE) && (addr_i == `TIMER_ADDR_CTRL)) begin
                start     <= wr_data_i[`TimerStartLoc];
                mode      <= wr_data_i[`TimerModeLoc];
            end else if ((expr_flag == `ENABLE)     &&
                         (mode == `TIMER_MODE_ONE_SHOT)) begin
                start     <= `DISABLE;
            end
            // 控制寄存器 1
            if (expr_flag == `ENABLE) begin
                irq_o         <= `ENABLE;
            end else if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                         (rw_i == `WRITE) && (addr_i ==     `TIMER_ADDR_INTR)) begin
                irq_o         <= wr_data_i[`TimerIrqLoc];
            end
            // 控制寄存器 2
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                (rw_i == `WRITE) && (addr_i == `TIMER_ADDR_EXPR)) begin
                expr_val <= wr_data_i;
            end
            // 控制寄存器 3
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N) &&
                (rw_i == `WRITE) && (addr_i == `TIMER_ADDR_COUNTER)) begin
                counter     <= wr_data_i;
            end else if (expr_flag == `ENABLE) begin
                counter     <= `WORD_DATA_W'h0;
            end else if (start == `ENABLE) begin
                counter     <= counter + 1'd1;
            end
        end
    end

endmodule
