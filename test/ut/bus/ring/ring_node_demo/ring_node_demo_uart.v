
// 简单的UART设备模型
module uart_device #(
    parameter DATA_WIDTH = 64
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 设备接口
    input  wire                         dev_req_valid,
    input  wire                         dev_req_type,       // 0:读, 1:写
    input  wire [31:0]                  dev_req_addr,
    input  wire [DATA_WIDTH-1:0]        dev_req_data,
    output wire                         dev_req_ready,

    output wire                         dev_rsp_valid,
    output wire [DATA_WIDTH-1:0]        dev_rsp_data,
    output wire                         dev_rsp_error,
    input  wire                         dev_rsp_ready,

    // UART物理接口
    output wire                         uart_tx,
    input  wire                         uart_rx,

    // 状态输出
    output wire                         uart_busy
);

    // 内部信号
    reg                         processing;
    reg [7:0]                   tx_data;
    reg [7:0]                   rx_data;
    reg                         tx_active;
    reg                         rx_active;

    // UART模拟逻辑（简化版）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing <= 1'b0;
            tx_data <= 8'h00;
            rx_data <= 8'h00;
            tx_active <= 1'b0;
            rx_active <= 1'b0;
        end else begin
            if (dev_req_valid && dev_req_ready && !processing) begin
                processing <= 1'b1;

                if (dev_req_type) begin
                    // UART发送
                    tx_data <= dev_req_data[7:0];
                    tx_active <= 1'b1;
                    // 模拟发送延迟
                    #10;
                    tx_active <= 1'b0;
                end else begin
                    // UART接收
                    // 模拟接收数据
                    rx_data <= 8'hA5; // 模拟接收到的数据
                end
            end else if (processing && dev_rsp_valid && dev_rsp_ready) begin
                processing <= 1'b0;
            end
        end
    end

    // 接口控制
    assign dev_req_ready = !processing;
    assign dev_rsp_valid = processing;
    assign dev_rsp_data = dev_req_type ? {56'h0, tx_data} : {56'h0, rx_data};
    assign dev_rsp_error = 1'b0;

    assign uart_tx = tx_active ? 1'b0 : 1'b1; // 简化TX信号
    assign uart_busy = processing;

endmodule
