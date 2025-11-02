
module uart16550 #(
    parameter SAMPLE_CYCLES = 16            // 每个位周期的采样次数
)(
    input  wire        clk,                // 时钟信号
    input  wire        rst_n,              // 复位信号，低电平有效
    input  wire        baud_clk_i,         // 波特率时钟

    // 寄存器接口
    input  wire        cs_n_i,             // 片选信号，低电平有效
    input  wire        rd_n_i,             // 读信号，低电平有效
    input  wire        wr_n_i,             // 写信号，低电平有效
    input  wire [7:0]  addr_i,             // 内部地址
    input  wire [7:0]  wr_data_i,          // 写入数据总线
    output wire [7:0]  rd_data_o,          // 读取数据总线

    // UART接口
    input  wire        uart_rx,            // UART接收信号
    output wire        uart_tx,            // UART发送信号

    // 中断信号
    output wire        irq_o               // 中断输出信号
);

    //--------------------------------------------------------------------
    // 寄存器定义
    //--------------------------------------------------------------------
    // 接收缓冲区寄存器 (0x00, 只读)
    reg [7:0]  rbr;
    // 发送保持寄存器 (0x00, 只写)
    reg [7:0]  thr;
    // 除数锁存低字节 (0x00, DLAB=1)
    reg [7:0]  dll;
    // 除数锁存高字节 (0x01, DLAB=1)
    reg [7:0]  dlm;
    // 中断使能寄存器 (0x01, DLAB=0)
    reg [3:0]  ier;
    // 中断识别寄存器 (0x02, 只读)
    wire [3:0] iir;
    // FIFO控制寄存器 (0x02, 只写)
    reg [2:0]  fcr;
    // 线路控制寄存器 (0x03)
    reg [7:0]  lcr;
    // 调制解调器控制寄存器 (0x04)
    reg [4:0]  mcr;
    // 线路状态寄存器 (0x05, 只读)
    wire [7:0] lsr;
    // 调制解调器状态寄存器 (0x06, 只读)
    wire [7:0] msr;
    // 暂存寄存器 (0x07, 只读)
    reg [7:0]  scr;

    //--------------------------------------------------------------------
    // 内部信号定义
    //--------------------------------------------------------------------
    // 寄存器选择信号
    wire       dlab;              // 除数锁存访问位 (LCR[7])
    wire       rbr_sel;           // 接收缓冲区寄存器选择
    wire       thr_sel;           // 发送保持寄存器选择
    wire       dll_sel;           // 除数锁存低字节选择
    wire       dlm_sel;           // 除数锁存高字节选择
    wire       ier_sel;           // 中断使能寄存器选择
    wire       iir_sel;           // 中断识别寄存器选择
    wire       fcr_sel;           // FIFO控制寄存器选择
    wire       lcr_sel;           // 线路控制寄存器选择
    wire       mcr_sel;           // 调制解调器控制寄存器选择
    wire       lsr_sel;           // 线路状态寄存器选择
    wire       msr_sel;           // 调制解调器状态寄存器选择
    wire       scr_sel;           // 暂存寄存器选择

    // 接收部分信号
    wire       rx_ready;          // 接收准备好
    wire [7:0] rx_data;           // 接收数据
    wire       rx_error;          // 接收错误
    reg        rx_available;      // 接收数据可用
    reg [7:0]  rx_buffer;         // 接收缓冲区

    // 发送部分信号
    wire       tx_busy;           // 发送忙
    reg        tx_start;          // 发送开始

    // 中断相关信号
    reg        rx_int;            // 接收中断
    reg        tx_int;            // 发送中断
    wire       modem_int;         // 调制解调器中断
    reg        fifo_int;          // FIFO中断

    // Data bits configuration
    wire [3:0] data_bits_config;  // 3-bit data bits configuration
    assign data_bits_config = lcr[1:0] + 3'd5;  // 5-8 data bits (3-bit port)

    //--------------------------------------------------------------------
    // 寄存器访问控制
    //--------------------------------------------------------------------
    assign dlab = lcr[7];

    assign rbr_sel = (addr_i == 8'h00) && !dlab && !cs_n_i && !rd_n_i;
    assign thr_sel = (addr_i == 8'h00) && !dlab && !cs_n_i && !wr_n_i;
    assign dll_sel = (addr_i == 8'h00) &&  dlab && !cs_n_i && !wr_n_i;
    assign dlm_sel = (addr_i == 8'h04) &&  dlab && !cs_n_i && !wr_n_i;
    assign ier_sel = (addr_i == 8'h04) && !dlab && !cs_n_i;
    assign iir_sel = (addr_i == 8'h08) && !cs_n_i && !rd_n_i;
    assign fcr_sel = (addr_i == 8'h0C) && !cs_n_i && !wr_n_i;
    assign lcr_sel = (addr_i == 8'h10) && !cs_n_i;
    assign mcr_sel = (addr_i == 8'h14) && !cs_n_i && !wr_n_i;
    assign lsr_sel = (addr_i == 8'h18) && !cs_n_i && !rd_n_i;
    assign msr_sel = (addr_i == 8'h1C) && !cs_n_i && !rd_n_i;
    assign scr_sel = (addr_i == 8'h20) && !cs_n_i;

    // 读取数据选择
    assign rd_data_o = rbr_sel ? rx_buffer :
                     iir_sel ? {4'b0000, iir} :
                     lsr_sel ? lsr :
                     msr_sel ? msr :
                     ier_sel && !rd_n_i ? {4'b0000, ier} :
                     lcr_sel && !rd_n_i ? lcr :
                     mcr_sel && !rd_n_i ? {3'b000, mcr} :
                     scr_sel && !rd_n_i ? scr :
                     8'h00;

    //--------------------------------------------------------------------
    // 线路控制寄存器 (LCR)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lcr <= 8'h03;  // 8个数据位，1个停止位，无奇偶校验
        end else if (lcr_sel && !wr_n_i) begin
            lcr <= wr_data_i;
        end
    end

    //--------------------------------------------------------------------
    // 除数锁存寄存器 (DLL/DLM)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dll <= 8'h00;
            dlm <= 8'h00;
        end else begin
            if (dll_sel) begin
                dll <= wr_data_i;
            end
            if (dlm_sel) begin
                dlm <= wr_data_i;
            end
        end
    end

    //--------------------------------------------------------------------
    // 中断使能寄存器 (IER)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ier <= 4'h0;
        end else if (ier_sel && !wr_n_i) begin
            ier <= wr_data_i[3:0];
        end
    end

    //--------------------------------------------------------------------
    // FIFO控制寄存器 (FCR)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fcr <= 3'h0;
        end else if (fcr_sel) begin
            fcr <= wr_data_i[2:0];
        end
    end

    //--------------------------------------------------------------------
    // 调制解调器控制寄存器 (MCR)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mcr <= 5'h0;
        end else if (mcr_sel) begin
            mcr <= wr_data_i[4:0];
        end
    end

    //--------------------------------------------------------------------
    // 暂存寄存器 (SCR)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scr <= 8'h00;
        end else if (scr_sel && !wr_n_i) begin
            scr <= wr_data_i;
        end
    end

    //--------------------------------------------------------------------
    // 发送部分
    //--------------------------------------------------------------------
    uart_tx #(
        .SAMPLE_CYCLES (SAMPLE_CYCLES)  // 配置每个位周期的采样次数
    ) tx_module (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_clk_i (baud_clk_i),
        .data_i     (thr),
        .start_i    (tx_start),
        .busy_o     (tx_busy),
        .tx_o       (uart_tx),
        .tx_end_o   (),  // 未使用的输出端口
        .data_bits_i(data_bits_config)  // 5-8 data bits (3-bit port)
    );

    // 发送保持寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thr <= 8'h00;
        end else if (thr_sel) begin
            thr <= wr_data_i;
        end
    end

    // 发送控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_start <= 1'b0;
        end else if (thr_sel) begin
            tx_start <= 1'b1;
        end else if (tx_busy) begin
            tx_start <= 1'b0;
        end
    end

    //--------------------------------------------------------------------
    // 接收部分
    //--------------------------------------------------------------------
    uart_rx #(
        .SAMPLE_CYCLES (SAMPLE_CYCLES)  // 配置每个位周期的采样次数
    ) rx_module (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_clk_i (baud_clk_i),
        .rx_i       (uart_rx),
        .data_o     (rx_data),
        .ready_o    (rx_ready),
        .error_o    (rx_error),
        .busy_o     (),  // 未使用的输出端口
        .data_bits_i(data_bits_config)  // 5-8 data bits (3-bit port)
    );

    // 接收数据处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_available <= 1'b0;
            rx_buffer <= 8'h00;
            rx_int <= 1'b0;
        end else begin
            if (rx_ready) begin
                rx_buffer <= rx_data;
                rx_available <= 1'b1;
                // 设置接收中断
                if (ier[0]) begin
                    rx_int <= 1'b1;
                end
            end else if (rbr_sel) begin
                rx_available <= 1'b0;
                rx_int <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------------
    // 线路状态寄存器 (LSR)
    //--------------------------------------------------------------------
    assign lsr = {
        1'b0,                   // bit 7: 保留
        1'b0,                   // bit 6: THR空
        tx_busy ? 1'b0 : 1'b1,  // bit 5: TX holding register空 (未使用)
        1'b0,                   // bit 4: 帧错误 (未使用)
        1'b0,                   // bit 3: 奇偶校验错误 (未使用)
        1'b0,                   // bit 2: 覆盖错误 (未使用)
        rx_error,               // bit 1: 接收数据错误
        rx_available            // bit 0: 接收数据准备好
    };

    //--------------------------------------------------------------------
    // 中断识别寄存器 (IIR)
    //--------------------------------------------------------------------
    assign iir = {
        1'b0,                 // bit 3: 保留
        1'b0,                 // bit 2: FIFO标志 (未使用)
        (rx_int) ? 2'b01 :    // 接收中断
        (tx_int) ? 2'b10 :    // 发送中断
        (modem_int) ? 2'b11 : // 调制解调器中断
        2'b00,                // 无中断
        1'b1                  // bit 0: 始终为1 (表示可读取)
    };

    // 调制解调器状态寄存器 (MSR) - 简化实现
    assign msr = 8'h00;
    assign modem_int = 1'b0;
    assign fifo_int = 1'b0;

    // 中断输出
    assign irq_o = (rx_int || tx_int || modem_int || fifo_int) && !cs_n_i;

endmodule

//======================================================================
// UART发送模块
//======================================================================
module uart_tx #(
    parameter SAMPLE_CYCLES = 16      // 每个位周期的采样次数
)(
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 复位信号
    input  wire        baud_clk_i,   // 波特率时钟
    input  wire [7:0]  data_i,       // 输入数据
    input  wire        start_i,      // 开始发送信号
    output reg         busy_o,       // 发送忙信号
    output reg         tx_o,         // UART发送信号
    output reg         tx_end_o,     // UART发送信号
    input  wire [3:0]  data_bits_i   // 数据位数量 (5-8)
);

    // 状态定义
    localparam IDLE = 2'b00;
    localparam START_BIT = 2'b01;
    localparam DATA_BITS = 2'b10;
    localparam STOP_BIT = 2'b11;

    // 计算采样计数器位宽
    localparam SAMPLE_CNT_WIDTH = $clog2(SAMPLE_CYCLES);
    // 定义中间采样位置
    localparam MIDDLE_SAMPLE = (SAMPLE_CYCLES / 2) - 1;
    // 定义结束采样位置
    localparam END_SAMPLE = SAMPLE_CYCLES - 1;

    reg [1:0] state;
    reg [7:0] tx_buffer;
    reg [2:0] bit_count;
    reg [SAMPLE_CNT_WIDTH-1:0] sample_count;  // 采样计数器
    reg       baud_clk_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            busy_o <= 1'b0;
            tx_end_o <= 1'b0;
            tx_o <= 1'b1;
            tx_buffer <= 8'h00;
            bit_count <= 3'd0;
            sample_count <= 0;
            baud_clk_prev <= 1'b0;
        end else begin
            baud_clk_prev <= baud_clk_i;
            tx_end_o <= 1'b0;

            // 仅在波特率时钟上升沿更新状态
            if (baud_clk_i && !baud_clk_prev) begin
                case (state)
                    IDLE: begin
                        tx_o <= 1'b1;  // 空闲状态为高电平
                        busy_o <= 1'b0;
                        sample_count <= 0;
                        if (start_i) begin
                            state <= START_BIT;
                            busy_o <= 1'b1;
                            tx_buffer <= data_i;
                        end
                    end

                    START_BIT: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == 0) begin
                            tx_o <= 1'b0;  // 起始位为低电平
                        end
                        if (sample_count == END_SAMPLE) begin
                            state <= DATA_BITS;
                            bit_count <= 3'd0;
                            sample_count <= 0;
                        end
                    end

                    DATA_BITS: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == 0) begin
                            tx_o <= tx_buffer[0];
                        end
                        if (sample_count == END_SAMPLE) begin
                            tx_buffer <= {1'b0, tx_buffer[7:1]};
                            bit_count <= bit_count + 3'd1;
                            sample_count <= 0;
                            if (bit_count == data_bits_i - 3'd1) begin
                                state <= STOP_BIT;
                            end
                        end
                    end

                    STOP_BIT: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == 0) begin
                            tx_o <= 1'b1;  // 停止位为高电平
                        end
                        if (sample_count == END_SAMPLE) begin
                            tx_end_o <= 1'b1;
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule

//======================================================================
// UART接收模块
//======================================================================
module uart_rx #(
    parameter SAMPLE_CYCLES = 16      // 每个位周期的采样次数
)(
    input  wire        clk,          // 系统时钟
    input  wire        rst_n,        // 复位信号
    input  wire        baud_clk_i,   // 波特率时钟
    input  wire        rx_i,         // UART接收信号
    output reg [7:0]   data_o,       // 输出数据
    output reg         busy_o,       // 接收准备好信号
    output reg         ready_o,      // 接收准备好信号
    output reg         error_o,      // 接收错误信号
    input  wire [3:0]  data_bits_i   // 数据位数量 (5-8)
);

    // 状态定义
    localparam IDLE = 3'b000;
    localparam START_BIT = 3'b001;
    localparam DATA_BITS = 3'b010;
    localparam STOP_BIT = 3'b011;

    // 计算采样计数器位宽
    localparam SAMPLE_CNT_WIDTH = $clog2(SAMPLE_CYCLES);
    // 定义中间采样位置
    localparam MIDDLE_SAMPLE = (SAMPLE_CYCLES / 2) - 1;
    // 定义结束采样位置
    localparam END_SAMPLE = SAMPLE_CYCLES - 1;

    reg [2:0] state;
    reg [7:0] rx_buffer;
    reg [2:0] bit_count;
    reg [SAMPLE_CNT_WIDTH-1:0] sample_count;  // 采样计数器
    reg       baud_clk_prev;
    reg       rx_sync1, rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready_o <= 1'b0;
            error_o <= 1'b0;
            data_o <= 8'h00;
            rx_buffer <= 8'h00;
            bit_count <= 3'd0;
            sample_count <= 0;
            baud_clk_prev <= 1'b0;
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            // 输入同步
            rx_sync1 <= rx_i;
            rx_sync2 <= rx_sync1;

            baud_clk_prev <= baud_clk_i;
            ready_o <= 1'b0;
            error_o <= 1'b0;

            // 仅在波特率时钟上升沿更新状态
            if (baud_clk_i && !baud_clk_prev) begin
                case (state)
                    IDLE: begin
                        busy_o <= 1'b0;
                        if (!rx_sync2) begin  // 检测到起始位
                            state <= START_BIT;
                            sample_count <= 1;
                        end
                    end

                    START_BIT: begin
                        busy_o <= 1'b1;
                        sample_count <= sample_count + 1;
                        if (sample_count == MIDDLE_SAMPLE) begin  // 在起始位中间采样
                            if (!rx_sync2) begin  // 如果仍然是低电平
                                state <= DATA_BITS;
                                bit_count <= 3'd0;
                                sample_count <= 0;
                            end else begin
                                state <= IDLE;  // 假起始位
                            end
                        end
                    end

                    DATA_BITS: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == END_SAMPLE) begin  // 在数据位中间采样
                            rx_buffer <= {rx_sync2, rx_buffer[7:1]};
                            bit_count <= bit_count + 3'd1;
                            sample_count <= 0;
                            if (bit_count == data_bits_i - 3'd1) begin
                                state <= STOP_BIT;
                            end
                        end
                    end

                    STOP_BIT: begin
                        sample_count <= sample_count + 1;
                        if (sample_count == END_SAMPLE) begin  // 在停止位中间采样
                            data_o <= rx_buffer;
                            ready_o <= 1'b1;
                            busy_o <= 1'b0;
                            if (!rx_sync2) begin
                                error_o <= 1'b1;
                            end
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule