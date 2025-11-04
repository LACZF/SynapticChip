
module uart_clk_gen (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [7:0]               sample_cycles_i,
    input  wire [15:0]              baud_div_i,

    output wire                     baud_clk_o
);
    // 计算计数器位宽 - 确保能容纳最大可能的baud_div值
    parameter CNT_WIDTH      = 16;

    // 波特率分频计数器
    reg [CNT_WIDTH-1:0] baud_div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_cnt <= {CNT_WIDTH{1'b0}};
        end else if (baud_div_cnt >= (|baud_div_i ? baud_div_i : 16'd1) - 1) begin
            baud_div_cnt <= {CNT_WIDTH{1'b0}};
        end else begin
            baud_div_cnt <= baud_div_cnt + 1'b1;
        end
    end

    // 在计数器归零时产生时钟脉冲
    assign baud_clk_o = (baud_div_i <= 1 ? clk : (baud_div_cnt == {CNT_WIDTH{1'b0}}));

endmodule
