
`include "stddef.v"
`include "global_config.v"

`include "uart.v"

module uart_top(
    input  wire                    clk,
    input  wire                    rst_n,

    /********** OBI总线接口 **********/
    input  wire                    req_i,
    input  wire                    we_i,
    input  wire [`UartAddrBus]     addr_i,
    input  wire [`WordDataBus]     wr_data_i,
    output reg  [`WordDataBus]     data_out_o,
    output reg                     gnt_o,
    output reg                     rvalid_o,
    /********** UART接口 **********/
    output wire                    uart_tx_o,
    input  wire                    uart_rx_i,
    /********** 中断信号 **********/
    output reg                     irq_o
);

    /********** 内部信号 **********/
    wire                           tx_start;
    wire                           tx_busy;
    wire                           rx_busy;
    wire                           rx_end;
    wire  [`WordDataBus]           rx_data;
    reg                            req_accepted;

    // 内部信号定义
    reg  [`WordDataBus]            rd_data_int;
    reg                            rdy_n_int;
    reg                            irq_rx_int;
    reg                            irq_tx_int;
    reg  [`ByteDataBus]            tx_data;  // uart_ctrl输出8位数据

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

    /********** UART控制器 **********/
    wire [7:0] rx_data_byte;  // uart_rx输出的是32位数据，但uart_ctrl只需要8位
    assign rx_data_byte = rx_data[7:0];

    uart_ctrl uart_ctrl(
        .clk        (clk),
        .rst_n      (rst_n),
        // 将OBI总线信号转换为uart_ctrl需要的信号
        .cs_n_i     (~req_accepted),      // req_accepted为高表示有效，cs_n_i低电平有效
        .as_n_i     (~req_accepted),      // 简化处理，as_n_i与cs_n_i一致
        .rw_i       (we_i),               // we_i为高表示写，rw_i为高也表示写
        .addr_i     (addr_i),
        .wr_data_i  (wr_data_i),
        .rd_data_o  (rd_data_int),        // 内部数据总线
        .rdy_n_o    (rdy_n_int),          // 内部就绪信号
        // 中断信号
        .irq_rx_o   (irq_rx_int),         // 接收中断
        .irq_tx_o   (irq_tx_int),         // 发送中断
        // 控制信号
        .rx_busy_i  (rx_busy),
        .rx_end_i   (rx_end),
        .rx_data_i  (rx_data_byte),       // 只取低8位
        .tx_busy_i  (tx_busy),
        .tx_end_i   (1'b0),               // 简化处理，暂不使用tx_end
        .tx_start_o (tx_start),
        .tx_data_o  (tx_data)             // 发送数据
    );



    /********** UART发送器 **********/
    // 将uart_ctrl的8位tx_data_o转换为uart_tx需要的格式
    wire [7:0] tx_data_8bit;  // uart_tx实际可能需要8位数据
    assign tx_data_8bit = tx_data;  // 直接传递8位数据

    uart_tx uart_tx(
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_start_i (tx_start),
        .tx_data_i  (tx_data_8bit),  // 传递完整的8位数据
        .tx_busy_o  (tx_busy),
        .tx_o       (uart_tx_o)
    );

    /********** UART接收器 **********/
    // 将uart_rx的8位rx_data_o转换为32位
    wire [`ByteDataBus] rx_data_8bit;
    assign rx_data = {24'h0, rx_data_8bit};  // 扩展为32位，高24位补0

    uart_rx uart_rx(
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_i       (uart_rx_i),
        .rx_busy_o  (rx_busy),
        .rx_end_o   (rx_end),
        .rx_data_o  (rx_data_8bit)  // 连接到8位信号
    );

    // 连接输出信号
    always @(posedge clk or negedge rst_n) begin
        if (rst_n == 0) begin
            data_out_o <= `WORD_DATA_W'h0;
            irq_o <= `DISABLE;
        end else begin
            // 连接读取数据
            data_out_o <= rd_data_int;

            // 合并中断信号
            irq_o <= irq_rx_int | irq_tx_int;
        end
    end

endmodule