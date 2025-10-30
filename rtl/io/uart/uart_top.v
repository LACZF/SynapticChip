`include "global_config.v"
`include "stddef.v"

module uart_top (
    // 时钟和复位信号
    input  wire                     clk,             // 系统时钟
    input  wire                     rst_n,           // 复位信号，低电平有效

    // OBI总线接口
    input  wire                     req_i,           // 请求信号
    input  wire                     we_i,            // 写使能信号
    input  wire [31:0]              addr_i,          // 地址总线
    input  wire [31:0]              wr_data_i,       // 写入数据总线
    output wire [31:0]              data_out_o,      // 读出数据总线
    output wire                     gnt_o,           // 授权信号
    output wire                     rvalid_o,        // 读有效信号

    // UART外部接口
    input  wire                     uart_rx,         // UART接收信号
    output wire                     uart_tx,         // UART发送信号

    // 中断信号
    output wire                     irq_o            // 中断输出信号
);

    //--------------------------------------------------------------------
    // 内部信号定义
    //--------------------------------------------------------------------
    // 寄存器访问控制信号
    wire                            cs_n;            // 片选信号，低电平有效
    wire                            rd_n;            // 读信号，低电平有效
    wire                            wr_n;            // 写信号，低电平有效
    wire [2:0]                      reg_addr;        // 寄存器地址

    // 数据信号
    wire [7:0]                      uart_wr_data;    // UART写入数据
    wire [7:0]                      uart_rd_data;    // UART读取数据
    reg  [31:0]                     data_out;        // 输出数据寄存器

    // 状态控制信号
    reg                             rvalid_q;        // 读有效信号寄存器
    wire                            baud_clk;        // 波特率时钟

    //--------------------------------------------------------------------
    // 波特率时钟生成
    //--------------------------------------------------------------------
    // 这里使用简化的波特率时钟生成，实际应用中应根据系统时钟和期望波特率调整
    parameter BAUD_DIV = 100;  // 假设系统时钟为100MHz，生成1MHz的波特率时钟
    reg [6:0] baud_div_cnt;    // 波特率分频计数器

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_cnt <= 7'h00;
        end else if (baud_div_cnt == BAUD_DIV - 1) begin
            baud_div_cnt <= 7'h00;
        end else begin
            baud_div_cnt <= baud_div_cnt + 7'h01;
        end
    end

    assign baud_clk = (baud_div_cnt == 7'h00);  // 在计数器归零时产生时钟脉冲

    //--------------------------------------------------------------------
    // OBI总线接口转换
    //--------------------------------------------------------------------
    // 地址和数据信号转换
    assign reg_addr = addr_i[4:2];  // 假设寄存器地址在地址总线的[4:2]位
    assign uart_wr_data = wr_data_i[7:0];  // 只使用低8位数据

    // 控制信号转换
    assign cs_n = ~req_i;
    assign rd_n = we_i;
    assign wr_n = ~we_i;

    // 输出数据处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= `WORD_DATA_W'h0;
        end else if (!cs_n && !rd_n) begin
            // 读操作时，将UART读取的数据扩展为32位
            data_out <= {24'h000000, uart_rd_data};
        end
    end

    assign data_out_o = data_out;

    assign gnt_o = req_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_q <= 1'b0;
        end else begin
            rvalid_q <= req_i;
        end
    end

    assign rvalid_o = rvalid_q;

    //--------------------------------------------------------------------
    // 16550 UART 实例化
    //--------------------------------------------------------------------
    uart16550 u_uart16550 (
        .clk        (clk),
        .rst_n      (rst_n),
        .baud_clk   (baud_clk),

        .cs_n       (cs_n),
        .rd_n       (rd_n),
        .wr_n       (wr_n),
        .addr       (reg_addr),
        .wr_data    (uart_wr_data),
        .rd_data    (uart_rd_data),

        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),

        .irq        (irq_o)
    );

endmodule