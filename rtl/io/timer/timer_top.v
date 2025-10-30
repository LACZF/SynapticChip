
`include "stddef.v"
`include "global_config.v"

`include "timer.v"

module timer_top(
    input  wire                    clk,
    input  wire                    rst_n,

    /********** OBI总线接口 **********/
    input  wire                    req_i,      // 请求信号
    input  wire                    we_i,       // 写使能
    input  wire [31:0]             addr_i,     // 地址
    input  wire [31:0]             wr_data_i,  // 写入的数据
    output reg  [31:0]             data_out_o, // 读取的数据
    output reg                     gnt_o,      // 授权信号
    output reg                     rvalid_o,   // 读有效信号
    /********** 中断信号 **********/
    output reg                     irq_o       // 中断信号
);

    /********** 控制寄存器 **********/
    // 控制寄存器 0 : 控制
    reg                            mode;       // 模式位
    reg                            start;      // 起始位
    // 控制寄存器 2 : 最大值
    reg [`WordDataBus]             expr_val;   // 最大值
    // 控制寄存器 3 : 计数器
    reg [`WordDataBus]             counter;    // 计数器
    // OBI协议控制信号
    reg                            req_accepted; // 请求已接受

    wire addr                      = addr_i[`TimerAddrBus];

    /********** 计时完成标志位 **********/
    wire expr_flag = ((start == `ENABLE) && (counter == expr_val)) ? `ENABLE : `DISABLE;

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

    /********** 定时器控制 **********/
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            /* 异步复位 */
            data_out_o  <= `WORD_DATA_W'h0;
            start       <= `DISABLE;
            mode        <= `TIMER_MODE_ONE_SHOT;
            irq_o       <= `DISABLE;
            expr_val    <= `WORD_DATA_W'h0;
            counter     <= `WORD_DATA_W'h0;
        end else begin
            /* 读取访问 */
            if (req_accepted && !we_i) begin
                case (addr)
                    `TIMER_ADDR_CTRL    : begin // 控制寄存器 0
                        data_out_o     <= {{`WORD_DATA_W-2{1'b0}}, mode, start};
                    end
                    `TIMER_ADDR_INTR    : begin // 控制寄存器 1
                        data_out_o     <= {{`WORD_DATA_W-1{1'b0}}, irq_o};
                    end
                    `TIMER_ADDR_EXPR    : begin // 控制寄存器 2
                        data_out_o     <= expr_val;
                    end
                    `TIMER_ADDR_COUNTER : begin // 控制寄存器 3
                        data_out_o     <= counter;
                    end
                endcase
            end else begin
                data_out_o     <= `WORD_DATA_W'h0;
            end
            /* 写入访问 */
            // 控制寄存器 0
            if (req_accepted && we_i && (addr == `TIMER_ADDR_CTRL)) begin
                start     <= wr_data_i[`TimerStartLoc];
                mode      <= wr_data_i[`TimerModeLoc];
            end else if ((expr_flag == `ENABLE) && (mode == `TIMER_MODE_ONE_SHOT)) begin
                start     <= `DISABLE;
            end
            // 控制寄存器 1
            if (expr_flag == `ENABLE) begin
                irq_o         <= `ENABLE;
            end else if (req_accepted && we_i && (addr == `TIMER_ADDR_INTR)) begin
                irq_o         <= wr_data_i[`TimerIrqLoc];
            end
            // 控制寄存器 2
            if (req_accepted && we_i && (addr == `TIMER_ADDR_EXPR)) begin
                expr_val <= wr_data_i;
            end
            // 控制寄存器 3
            if (req_accepted && we_i && (addr == `TIMER_ADDR_COUNTER)) begin
                counter     <= wr_data_i;
            end else if (expr_flag == `ENABLE) begin
                counter     <= `WORD_DATA_W'h0;
            end else if (start == `ENABLE) begin
                counter     <= counter + 1'd1;
            end
        end
    end

endmodule