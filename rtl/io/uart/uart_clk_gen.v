
module uart_clk_gen #(
    parameter SYS_CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE      = 115_200,
    parameter SAMPLE_CYCLES  = 16
)(
    input  wire                     clk,
    input  wire                     rst_n,

    output wire                     baud_clk_o
);
    parameter BAUD_DIV       = SYS_CLK_FREQ / BAUD_RATE / SAMPLE_CYCLES / 27;

    // 确保BAUD_DIV至少为1
    parameter BAUD_DIV_VAL   = (BAUD_DIV > 0) ? BAUD_DIV : 1;

    // 计算计数器位宽 - 确保能容纳BAUD_DIV_VAL的值
    parameter CNT_WIDTH      = $clog2(BAUD_DIV_VAL);

    // 波特率分频计数器
    reg [CNT_WIDTH-1:0] baud_div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_div_cnt <= {CNT_WIDTH{1'b0}};
        end else if (baud_div_cnt == BAUD_DIV_VAL - 1) begin
            baud_div_cnt <= {CNT_WIDTH{1'b0}};
        end else begin
            baud_div_cnt <= baud_div_cnt + 1'b1;
        end
    end

    // 在计数器归零时产生时钟脉冲
    assign baud_clk_o = (baud_div_cnt == {CNT_WIDTH{1'b0}});

endmodule
