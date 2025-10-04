// mmio_subsystem.v
`include "soc_params.v"

module mmio_subsystem (
    input wire clk,
    input wire rst_n,

    // 系统接口
    input wire sys_req,
    input wire [63:0] sys_addr,
    input wire [63:0] sys_wdata,
    output reg [63:0] sys_rdata,
    input wire sys_we,
    input wire [7:0] sys_byte_en,
    output reg sys_ready,

    // 外设接口
    output wire uart_txd,
    input wire uart_rxd,
    input wire [15:0] gpio_in,
    output wire [15:0] gpio_out,
    input wire [3:0] dip_switch,
    output wire [3:0] led,

    // 中断接口
    output wire [(`NUM_CORES*16)-1:0] core_irq,
    output wire [`NUM_CORES-1:0] timer_irq,
    output wire [`NUM_CORES-1:0] external_irq,
    output wire [`NUM_CORES-1:0] software_irq
);

    // UART寄存器
    reg [7:0] uart_tx_data;
    reg [7:0] uart_rx_data;
    reg uart_tx_busy;
    reg uart_rx_ready;
    reg [15:0] uart_baud_div;
    reg uart_tx_start_pulse;

    // GPIO寄存器
    reg [15:0] gpio_out_reg;
    reg [15:0] gpio_dir; // 0=input, 1=output
    reg [15:0] gpio_pullup;

    // 定时器寄存器
    reg [63:0] timer_counter [`NUM_CORES-1:0];
    reg [63:0] timer_compare [`NUM_CORES-1:0];
    reg [`NUM_CORES-1:0] timer_enable;

    // 中断控制器寄存器
    reg [31:0] plic_priority [0:31]; // 中断优先级
    reg [31:0] plic_pending;         // 挂起中断
    reg [31:0] plic_enable [`NUM_CORES-1:0]; // 每个核的中断使能
    reg [4:0] plic_threshold [`NUM_CORES-1:0]; // 中断阈值

    // 局部变量声明（移到模块级别以避免静态变量初始化警告）
    integer core_id;
    integer irq_id;

    // 定时器中断临时寄存器
    reg [`NUM_CORES-1:0] timer_irq_reg;

    // 内部信号
    wire uart_tx_start;
    wire uart_rx_done_internal;

    // UART模块实例化
    uart #(
        .CLK_FREQ(`SOC_CLK_FREQ),
        .BAUD_RATE(115200)
    ) u_uart (
        .clk(clk),
        .rst_n(rst_n),
        .txd(uart_txd),
        .rxd(uart_rxd),
        .tx_data(uart_tx_data),
        .tx_start(uart_tx_start_pulse),
        .tx_busy(uart_tx_busy),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done_internal),
        .rx_error()
    );

    // 内部信号连接
    assign uart_tx_start = uart_tx_start_pulse;
    assign timer_irq = timer_irq_reg;

    // 地址解码 - 使用范围检查避免位提取错误
    wire is_uart0 = (sys_addr >= `UART0_BASE && sys_addr < (`UART0_BASE + 64'h100));
    wire is_gpio0 = (sys_addr >= `GPIO0_BASE && sys_addr < (`GPIO0_BASE + 64'h100));
    wire is_timer0 = (sys_addr >= `TIMER0_BASE && sys_addr < (`TIMER0_BASE + 64'h100));
    wire is_plic = (sys_addr >= `PLIC_BASE && sys_addr < (`PLIC_BASE + 64'h1000));

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sys_ready <= 1'b0;
            sys_rdata <= 64'b0;
            uart_tx_start_pulse <= 1'b0;

            // 初始化寄存器
            uart_baud_div <= `SOC_CLK_FREQ / 115200;
            gpio_out_reg <= 16'b0;
            gpio_dir <= 16'b0;
            gpio_pullup <= 16'b0;

            for (integer i = 0; i < `NUM_CORES; i = i + 1) begin
                timer_counter[i] <= 64'b0;
                timer_compare[i] <= 64'hFFFF_FFFF_FFFF_FFFF;
                timer_enable[i] <= 1'b0;
                timer_irq_reg[i] <= 1'b0;
                plic_enable[i] <= 32'b0;
                plic_threshold[i] <= 5'b0;
            end

            for (integer i = 0; i < 32; i = i + 1) begin
                plic_priority[i] <= 32'b0;
            end

            plic_pending <= 32'b0;

        end else begin
            sys_ready <= 1'b0;
            uart_tx_start_pulse <= 1'b0;

            // 处理UART接收
            if (uart_rx_done_internal) begin
                uart_rx_ready <= 1'b1;
                // 设置UART接收中断
                plic_pending[1] <= 1'b1;
            end

            // 更新定时器
            for (integer i = 0; i < `NUM_CORES; i = i + 1) begin
                if (timer_enable[i]) begin
                    timer_counter[i] <= timer_counter[i] + 64'h1;
                    if (timer_counter[i] >= timer_compare[i]) begin
                        timer_irq_reg[i] <= 1'b1;
                        timer_counter[i] <= 64'b0;
                    end
                end
            end

            // 处理系统请求
            if (sys_req && !sys_ready) begin
                sys_ready <= 1'b1;

                if (is_uart0) begin
                    case (sys_addr[3:0])
                        4'h0: begin // UART数据寄存器
                            if (sys_we) begin
                                uart_tx_data <= sys_wdata[7:0];
                                uart_tx_start_pulse <= 1'b1;
                            end else begin
                                sys_rdata <= {56'b0, uart_rx_data};
                                uart_rx_ready <= 1'b0;
                                plic_pending[1] <= 1'b0;
                            end
                        end
                        4'h4: begin // UART状态寄存器
                            sys_rdata <= {62'b0, uart_tx_busy, uart_rx_ready};
                        end
                        4'h8: begin // UART波特率寄存器
                            if (sys_we) begin
                                uart_baud_div <= sys_wdata[15:0];
                            end else begin
                                sys_rdata <= {48'b0, uart_baud_div};
                            end
                        end
                    endcase
                end else if (is_gpio0) begin
                    case (sys_addr[3:0])
                        4'h0: begin // GPIO数据寄存器
                            if (sys_we) begin
                                gpio_out_reg <= sys_wdata[15:0] & gpio_dir;
                            end else begin
                                sys_rdata <= {48'b0, (gpio_in & ~gpio_dir) | (gpio_out_reg & gpio_dir)};
                            end
                        end
                        4'h4: begin // GPIO方向寄存器
                            if (sys_we) begin
                                gpio_dir <= sys_wdata[15:0];
                            end else begin
                                sys_rdata <= {48'b0, gpio_dir};
                            end
                        end
                    endcase
                end else if (is_timer0) begin
                    core_id = sys_addr[7:4];
                    if (core_id < `NUM_CORES) begin
                        case (sys_addr[3:0])
                            4'h0: begin // 定时器计数器
                                if (sys_we) begin
                                    timer_counter[core_id] <= sys_wdata;
                                    timer_irq_reg[core_id] <= 1'b0;
                                end else begin
                                    sys_rdata <= timer_counter[core_id];
                                end
                            end
                            4'h8: begin // 定时器比较值
                                if (sys_we) begin
                                    timer_compare[core_id] <= sys_wdata;
                                end else begin
                                    sys_rdata <= timer_compare[core_id];
                                end
                            end
                            4'hC: begin // 定时器控制
                                if (sys_we) begin
                                    timer_enable[core_id] <= sys_wdata[0];
                                end else begin
                                    sys_rdata <= {63'b0, timer_enable[core_id]};
                                end
                            end
                        endcase
                    end
                end else if (is_plic) begin
                    // 中断控制器寄存器处理
                    core_id = sys_addr[11:8];
                    irq_id = sys_addr[7:2];

                    if (core_id < `NUM_CORES) begin
                        if (sys_we) begin
                            case (sys_addr[1:0])
                                2'b00: plic_priority[irq_id] <= sys_wdata;
                                2'b01: plic_enable[core_id] <= sys_wdata;
                                2'b10: plic_threshold[core_id] <= sys_wdata[4:0];
                            endcase
                        end else begin
                            case (sys_addr[1:0])
                                2'b00: sys_rdata <= plic_priority[irq_id];
                                2'b01: sys_rdata <= plic_enable[core_id];
                                2'b10: sys_rdata <= {59'b0, plic_threshold[core_id]};
                            endcase
                        end
                    end
                end
            end
        end
    end

    // GPIO输出
    assign gpio_out = gpio_out_reg;
    assign led = gpio_out_reg[3:0];

    // 中断生成（简化版本）
    assign software_irq = plic_pending[0] ? 4'b1111 : 4'b0000;
    assign external_irq = gpio_in[0] ? 4'b1111 : 4'b0000;

    // 核心中断（简化版本）
    assign core_irq[15:0] = {15'b0, timer_irq[0] | external_irq[0] | software_irq[0]};
    assign core_irq[31:16] = {15'b0, timer_irq[1] | external_irq[1] | software_irq[1]};
    assign core_irq[47:32] = {15'b0, timer_irq[2] | external_irq[2] | software_irq[2]};
    assign core_irq[63:48] = {15'b0, timer_irq[3] | external_irq[3] | software_irq[3]};

endmodule