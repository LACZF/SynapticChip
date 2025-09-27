module round_robin_arbiter #(
    parameter NUM_REQUESTS = 4
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [NUM_REQUESTS-1:0]  req_i,
    output reg  [$clog2(NUM_REQUESTS)-1:0] grant_o,
    output reg                      valid_o,
    input  wire                     ready_i
);

    reg [$clog2(NUM_REQUESTS)-1:0] pointer;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pointer <= 0;
            grant_o <= 0;
            valid_o <= 0;
        end else begin
            valid_o <= |req_i;

            if (|req_i) begin
                // 简单的轮询仲裁
                integer i;
                for (i = 0; i < NUM_REQUESTS; i = i + 1) begin
                    integer index = (pointer + i) % NUM_REQUESTS;
                    if (req_i[index]) begin
                        grant_o <= index;
                        break;
                    end
                end

                if (valid_o && ready_i) begin
                    pointer <= (grant_o + 1) % NUM_REQUESTS;
                end
            end else begin
                valid_o <= 0;
            end
        end
    end

endmodule
