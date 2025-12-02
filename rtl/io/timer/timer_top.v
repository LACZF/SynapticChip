


module ip0_timer_top(
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

    localparam TIMER_ADDR_CTRL      = 8'h00;  //  控制寄存器0 :控制
    localparam TIMER_ADDR_INTR      = 8'h04;  //  控制寄存器1 :中断
    localparam TIMER_ADDR_EXPR      = 8'h08;  //  控制寄存器2 :最大值
    localparam TIMER_ADDR_COUNTER   = 8'h0c;  //  控制寄存器3 :计数器

    localparam TIMER_START_LOC      = 0;     // 起始位的位置
    localparam TIMER_MODE_LOC       = 1;     // 模式位的位置
    localparam TIMER_MODE_ONE_SHOT  = 1'b0;  // 模式 :单次定时器
    localparam TIMER_MODE_PERIODIC  = 1'b1;  // 模式 :循环定时器

    localparam TIMER_IRQ_LOC        = 0;     // 中断位的位置

    /********** 控制寄存器 **********/
    // 控制寄存器 0 : 控制
    reg                            mode;       // 模式位
    reg                            start;      // 起始位
    // 控制寄存器 2 : 最大值
    reg [31:0]                     expr_val;   // 最大值
    // 控制寄存器 3 : 计数器
    reg [31:0]                     counter;    // 计数器
    // OBI协议控制信号
    reg                            req_accepted; // 请求已接受

    wire [7:0]     addr            = addr_i[7:0];

    /********** 计时完成标志位 **********/
    wire expr_flag = ((start == 1'b1) && (counter == expr_val)) ? 1'b1 : 1'b0;

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

            rvalid_o <= req_i;

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
            data_out_o  <= 32'b0;
            start       <= 1'b0;
            mode        <= TIMER_MODE_ONE_SHOT;
            irq_o       <= 1'b0;
            expr_val    <= 32'b0;
            counter     <= 32'b0;
        end else begin
            /* 读取访问 */
            if (req_accepted && !we_i) begin
                case (addr)
                    TIMER_ADDR_CTRL    : begin // 控制寄存器 0
                        data_out_o     <= {{32-2{1'b0}}, mode, start};
                    end
                    TIMER_ADDR_INTR    : begin // 控制寄存器 1
                        data_out_o     <= {{32-1{1'b0}}, irq_o};
                    end
                    TIMER_ADDR_EXPR    : begin // 控制寄存器 2
                        data_out_o     <= expr_val;
                    end
                    TIMER_ADDR_COUNTER : begin // 控制寄存器 3
                        data_out_o     <= counter;
                    end
                endcase
            end else begin
                data_out_o     <= 32'b0;
            end
            /* 写入访问 */
            // 控制寄存器 0
            if (req_accepted && we_i && (addr == TIMER_ADDR_CTRL)) begin
                start     <= wr_data_i[TIMER_START_LOC];
                mode      <= wr_data_i[TIMER_MODE_LOC];
            end else if ((expr_flag == 1'b1) && (mode == TIMER_MODE_ONE_SHOT)) begin
                start     <= 1'b0;
            end
            // 控制寄存器 1
            if (expr_flag == 1'b1) begin
                irq_o         <= 1'b1;
            end else if (req_accepted && we_i && (addr == TIMER_ADDR_INTR)) begin
                irq_o         <= wr_data_i[TIMER_IRQ_LOC];
            end
            // 控制寄存器 2
            if (req_accepted && we_i && (addr == TIMER_ADDR_EXPR)) begin
                expr_val <= wr_data_i;
            end
            // 控制寄存器 3
            if (req_accepted && we_i && (addr == TIMER_ADDR_COUNTER)) begin
                counter     <= wr_data_i;
            end else if (expr_flag == 1'b1) begin
                counter     <= 32'b0;
            end else if (start == 1'b1) begin
                counter     <= counter + 1'd1;
            end
        end
    end

endmodule