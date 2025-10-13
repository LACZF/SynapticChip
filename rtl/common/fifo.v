`timescale 1ns / 1ps

module fifo #(
    parameter DATA_WIDTH                = 32,
    parameter FIFO_DEPTH                = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         wr_en_i,
    input  wire [DATA_WIDTH-1:0]        data_in_i,
    input  wire                         rd_en_i,
    output wire                         rd_done_o,
    output wire [DATA_WIDTH-1:0]        data_out_o,
    output wire                         full_o,
    output wire                         empty_o
);

    reg [DATA_WIDTH-1:0] fifo [FIFO_DEPTH-1:0];
    reg [31:0] wr_ptr;
    reg [31:0] rd_ptr;
    reg [31:0] count;

    // FIFO write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en_i && !full_o) begin
            fifo[wr_ptr] <= data_in_i;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // FIFO read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en_i && !empty_o) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

    // FIFO count logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({wr_en_i && !full_o, rd_en_i && !empty_o})
                2'b01: count <= count - 1;
                2'b10: count <= count + 1;
                default: count <= count;
            endcase
        end
    end

    // Output assignments
    assign data_out_o = (rd_en_i && !empty_o) ? fifo[rd_ptr] : {DATA_WIDTH{1'b0}};
    assign full_o = (count == FIFO_DEPTH);
    assign empty_o = (count == 0);
    assign rd_done_o = (rd_en_i && !empty_o) ? 1'b1 : 1'b0;

endmodule