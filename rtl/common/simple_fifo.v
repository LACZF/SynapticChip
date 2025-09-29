`timescale 1ns / 1ps

module simple_fifo #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire rd_en,
    output wire rd_done,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire full,
    output wire empty
);

    reg [DATA_WIDTH-1:0] fifo [FIFO_DEPTH-1:0];
    reg [31:0] wr_ptr;
    reg [31:0] rd_ptr;
    reg [31:0] count;

    // FIFO write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            fifo[wr_ptr] <= data_in;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // FIFO read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

    // FIFO count logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b01: count <= count - 1;
                2'b10: count <= count + 1;
                default: count <= count;
            endcase
        end
    end

    // Output assignments
    assign data_out = (rd_en && !empty) ? fifo[rd_ptr] : DATA_WIDTH`b0;
    assign full = (count == FIFO_DEPTH);
    assign empty = (count == 0);
    assign rd_done = (rd_en && !empty) ? 1`b1 : 1`b0;

endmodule
