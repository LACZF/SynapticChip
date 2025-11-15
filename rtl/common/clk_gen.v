
module clk_gen (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [15:0]              div_i,

    output wire                     clk_o
);
    parameter CNT_WIDTH      = 16;

    reg [CNT_WIDTH-1:0] div_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= {CNT_WIDTH{1'b0}};
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

    assign clk_o = ((div_i > 1) ? div_cnt[div_i-1] : clk);

endmodule
