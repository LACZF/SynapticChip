module fifo #(
    parameter DATA_WIDTH                = 32,
    parameter FIFO_DEPTH                = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         wr_en_i,
    input  wire [DATA_WIDTH-1:0]        data_in_i,
    input  wire                         rd_en_i,
    output reg                          rd_done_o,
    output reg  [DATA_WIDTH-1:0]        data_out_o,
    output reg                          full_o,
    output reg                          empty_o
);

    reg [DATA_WIDTH-1:0] fifo [FIFO_DEPTH-1:0];
    reg [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    reg [$clog2(FIFO_DEPTH)-1:0] rd_ptr;

    reg [$clog2(FIFO_DEPTH+1)-1:0] count;

    // FIFO write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en_i && !full_o) begin
            fifo[wr_ptr] <= data_in_i;
            wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
        end
    end

    // FIFO read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            rd_done_o <= 0;
            data_out_o <= {DATA_WIDTH{1'b0}};
        end else if (rd_en_i && !empty_o) begin
            data_out_o <= fifo[rd_ptr];
            rd_done_o <= 1;
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
        end else begin
            rd_done_o <= 0;
            if (empty_o) begin
                data_out_o <= {DATA_WIDTH{1'b0}};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            if (wr_en_i && !full_o) begin
                if (rd_en_i && (count > 0)) begin
                    count <= count;
                end else begin
                    count <= count + 1;
                end
            end else if (rd_en_i && (count > 0)) begin
                count <= count - 1;
            end else begin
                count <= count;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full_o <= 0;
            empty_o <= 1;
        end else begin
            full_o <= (count == FIFO_DEPTH);
            empty_o <= (count == 0);
        end
    end

endmodule