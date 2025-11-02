
module uart16550 #(
    parameter SYS_CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE      = 115_200,
    parameter SAMPLE_CYCLES  = 16            // 每个位周期的采样次数
)(
    input  wire        clk,                // 时钟信号
    input  wire        rst_n,              // 复位信号，低电平有效

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
    // 采样周期寄存器 (0x24, 可读写)
    reg [7:0]  sample_cycles_reg;
    // 波特率分频寄存器 (0x28, 可读写)
    reg [15:0] baud_div_reg;

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
    wire       sample_cycles_sel; // 采样周期寄存器选择
    wire       baud_div_sel;      // 波特率分频寄存器选择

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

    wire       baud_clk;        // 波特率时钟

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
    // 采样周期寄存器选择 (地址0x24)
    assign sample_cycles_sel = (addr_i == 8'h24) && !cs_n_i;
    // 波特率分频寄存器选择 (地址0x28 - 低字节, 0x2C - 高字节)
    assign baud_div_sel = ((addr_i == 8'h28) || (addr_i == 8'h2C)) && !cs_n_i;

    // 读取数据选择
    assign rd_data_o = rbr_sel ? rx_buffer :
                     iir_sel ? {4'b0000, iir} :
                     lsr_sel ? lsr :
                     msr_sel ? msr :
                     ier_sel && !rd_n_i ? {4'b0000, ier} :
                     lcr_sel && !rd_n_i ? lcr :
                     mcr_sel && !rd_n_i ? {3'b000, mcr} :
                     scr_sel && !rd_n_i ? scr :
                     sample_cycles_sel && !rd_n_i ? sample_cycles_reg :
                     baud_div_sel && !rd_n_i && (addr_i == 8'h28) ? baud_div_reg[7:0] :
                     baud_div_sel && !rd_n_i && (addr_i == 8'h2C) ? baud_div_reg[15:8] :
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
    // 采样周期寄存器 (SAMPLE_CYCLES_REG)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cycles_reg <= SAMPLE_CYCLES;
        end else if (sample_cycles_sel && !wr_n_i) begin
            sample_cycles_reg <= wr_data_i;
        end
    end

    //--------------------------------------------------------------------
    // 波特率分频寄存器 (BAUD_DIV_REG)
    //--------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_reg <= (SYS_CLK_FREQ / BAUD_RATE / SAMPLE_CYCLES);  // 默认值根据参数的系统时钟和波特率确定
        end else begin
            if (baud_div_sel && !wr_n_i && (addr_i == 8'h28)) begin
                baud_div_reg[7:0] <= wr_data_i;
            end
            if (baud_div_sel && !wr_n_i && (addr_i == 8'h2C)) begin
                baud_div_reg[15:8] <= wr_data_i;
            end
        end
    end

    uart_clk_gen u_uart_clk_gen(
        .clk            (clk),
        .rst_n          (rst_n),
        .sample_cycles_i(sample_cycles_reg),
        .baud_div_i     (baud_div_reg),
        .baud_clk_o     (baud_clk)
    );

    //--------------------------------------------------------------------
    // 发送部分
    //--------------------------------------------------------------------
    uart_tx #(
        .SAMPLE_CYCLES (SAMPLE_CYCLES)  // 配置每个位周期的采样次数
    ) tx_module (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_clk_i (baud_clk),
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
        .baud_clk_i (baud_clk),
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
