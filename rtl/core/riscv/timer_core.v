// timer_core.v
module timer_core (
    input wire clk,
    input wire rst_n,

    // 配置接口
    input wire [63:0] timecmp_i,        // 定时器比较值
    input wire timecmp_we,              // 比较值写使能
    input wire [63:0] mtime_i,          // 定时器当前值（写）
    input wire mtime_we,                // 定时器写使能
    input wire [1:0] timer_mode,        // 定时器模式

    // 输出
    output reg [63:0] mtime_o,          // 定时器当前值（读）
    output reg [63:0] timecmp_o,        // 定时器比较值（读）
    output reg timer_interrupt          // 定时器中断信号
);

    // 定时器模式定义
    localparam MODE_ONESHOT = 2'b00;    // 单次模式
    localparam MODE_PERIODIC = 2'b01;   // 周期模式
    localparam MODE_FREERUN = 2'b10;    // 自由运行模式

    // 内部寄存器
    reg [63:0] mtime_reg;               // 64位定时器计数器
    reg [63:0] timecmp_reg;             // 64位比较寄存器
    reg timer_active;                   // 定时器激活标志
    reg interrupt_pending;              // 中断等待标志

    // 输出连接
    assign mtime_o = mtime_reg;
    assign timecmp_o = timecmp_reg;

    // 定时器计数器逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime_reg <= 64'h0;
            timecmp_reg <= 64'hFFFFFFFF_FFFFFFFF;
            timer_active <= 1'b0;
            interrupt_pending <= 1'b0;
            timer_interrupt <= 1'b0;
        end else begin
            // 定时器计数器递增（自由运行或激活状态下）
            if (timer_mode == MODE_FREERUN || timer_active) begin
                mtime_reg <= mtime_reg + 64'h1;
            end

            // 写操作处理
            if (mtime_we) begin
                mtime_reg <= mtime_i;
            end

            if (timecmp_we) begin
                timecmp_reg <= timecmp_i;
                // 写入新的比较值时重新激活定时器
                if (timer_mode != MODE_FREERUN) begin
                    timer_active <= 1'b1;
                    interrupt_pending <= 1'b0;
                    timer_interrupt <= 1'b0;
                end
            end

            // 定时器比较逻辑
            if (timer_active && (mtime_reg >= timecmp_reg)) begin
                case (timer_mode)
                    MODE_ONESHOT: begin
                        timer_active <= 1'b0;
                        interrupt_pending <= 1'b1;
                        timer_interrupt <= 1'b1;
                    end
                    MODE_PERIODIC: begin
                        // 重新加载比较值（简单实现：timecmp_reg保持不变）
                        interrupt_pending <= 1'b1;
                        timer_interrupt <= 1'b1;
                        // 在实际实现中，这里可能需要重新加载周期值
                    end
                    default: begin
                        interrupt_pending <= 1'b1;
                        timer_interrupt <= 1'b1;
                    end
                endcase
            end

            // 中断清除逻辑（当软件读取或写入某些寄存器时清除）
            if (interrupt_pending && (mtime_we || timecmp_we)) begin
                interrupt_pending <= 1'b0;
                timer_interrupt <= 1'b0;
            end
        end
    end

    // 定时器状态输出（用于调试）
    wire [2:0] timer_state = {timer_active, interrupt_pending, timer_interrupt};

endmodule
