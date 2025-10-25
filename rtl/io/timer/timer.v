
`include "stddef.v"
`include "global_config.v"

`include "timer.v"

module timer (
    input  wire                    clk,
    input  wire                    reset,
    /********** 总线接口 **********/
    input  wire                    cs_,        // 片选
    input  wire                    as_,        // 地址选通
    input  wire                    rw,         // Read / Write
    input  wire [`TimerAddrBus]    addr,       // 地址
    input  wire [`WordDataBus]     wr_data,    // 数据写入
    output reg    [`WordDataBus]   rd_data,    // 数据读取
    output reg                     rdy_,       // 就绪信号
    /********** 中断 **********/
    output reg                     irq         // 控制寄存器1：中断请求信号
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
            rd_data     <= `WORD_DATA_W'h0;
            rdy_        <= `DISABLE_N;
            start       <= `DISABLE;
            mode        <= `TIMER_MODE_ONE_SHOT;
            irq         <= `DISABLE;
            expr_val    <= `WORD_DATA_W'h0;
            counter     <= `WORD_DATA_W'h0;
        end else begin
            /* 就绪信号的生成 */
            if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N)) begin
                rdy_     <= `ENABLE_N;
            end else begin
                rdy_     <= `DISABLE_N;
            end
            /* 读取访问 */
            if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) && (rw == `READ)) begin
                case (addr)
                    `TIMER_ADDR_CTRL    : begin // 控制寄存器 0
                        rd_data     <= {{`WORD_DATA_W-2{1'b0}}, mode, start};
                    end
                    `TIMER_ADDR_INTR    : begin // 控制寄存器 1
                        rd_data     <= {{`WORD_DATA_W-1{1'b0}}, irq};
                    end
                    `TIMER_ADDR_EXPR    : begin // 控制寄存器 2
                        rd_data     <= expr_val;
                    end
                    `TIMER_ADDR_COUNTER : begin // 控制寄存器 3
                        rd_data     <= counter;
                    end
                endcase
            end else begin
                rd_data     <= `WORD_DATA_W'h0;
            end
            /* 写入访问 */
            // 控制寄存器 0
            if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
                (rw == `WRITE) && (addr == `TIMER_ADDR_CTRL)) begin
                start     <= wr_data[`TimerStartLoc];
                mode      <= wr_data[`TimerModeLoc];
            end else if ((expr_flag == `ENABLE)     &&
                         (mode == `TIMER_MODE_ONE_SHOT)) begin
                start     <= `DISABLE;
            end
            // 控制寄存器 1
            if (expr_flag == `ENABLE) begin
                irq         <= `ENABLE;
            end else if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
                         (rw == `WRITE) && (addr ==     `TIMER_ADDR_INTR)) begin
                irq         <= wr_data[`TimerIrqLoc];
            end
            // 控制寄存器 2
            if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
                (rw == `WRITE) && (addr == `TIMER_ADDR_EXPR)) begin
                expr_val <= wr_data;
            end
            // 控制寄存器 3
            if ((cs_ == `ENABLE_N) && (as_ == `ENABLE_N) &&
                (rw == `WRITE) && (addr == `TIMER_ADDR_COUNTER)) begin
                counter     <= wr_data;
            end else if (expr_flag == `ENABLE) begin
                counter     <= `WORD_DATA_W'h0;
            end else if (start == `ENABLE) begin
                counter     <= counter + 1'd1;
            end
        end
    end

endmodule
