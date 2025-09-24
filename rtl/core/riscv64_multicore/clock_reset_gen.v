// clock_reset_gen.v
module clock_reset_gen (
    input wire clk,
    input wire rst_n,
    output reg soc_clk,
    output reg soc_rst_n,
    output reg soc_ready
);

    reg [7:0] reset_counter;
    reg [3:0] clock_divider;
    reg internal_rst_n;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reset_counter <= 8'h00;
            internal_rst_n <= 1'b0;
            soc_ready <= 1'b0;
            clock_divider <= 4'b0000;
            soc_clk <= 1'b0;
        end else begin
            // 复位序列
            if (reset_counter < 8'hFF) begin
                reset_counter <= reset_counter + 8'h01;
                internal_rst_n <= 1'b0;
            end else begin
                internal_rst_n <= 1'b1;
                soc_ready <= 1'b1;
            end

            // 时钟分频（从外部时钟生成SoC时钟）
            clock_divider <= clock_divider + 4'b0001;
            if (clock_divider == 4'b1111) begin
                soc_clk <= ~soc_clk;
            end
        end
    end

    assign soc_rst_n = internal_rst_n;

endmodule
