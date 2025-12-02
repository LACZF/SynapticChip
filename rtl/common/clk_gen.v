
module ip4_clk_gen (
    input  wire                     clk,
    input  wire                     rst_n,

    input  wire [15:0]              div_i,

    output wire                     clk_o
);
    parameter CNT_WIDTH      = 16;

    reg [CNT_WIDTH-1:0] div_cnt;
    reg                 div_clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= {CNT_WIDTH{1'b0}};
            div_clk <= 1'b0;
        end else begin
            div_cnt <= (div_cnt >= (div_i - 1)) ? 0 : div_cnt + 1'b1;
            div_clk <= (div_cnt >= (div_i - 1)) ? ~div_clk : div_clk;
        end
    end

    assign clk_o = div_clk;

endmodule
