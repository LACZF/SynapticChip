module pe_router #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // From PE
    input  wire [DATA_WIDTH-1:0] pe_result,
    input  wire                  pe_result_valid,

    // Configuration
    input  wire [DATA_WIDTH-1:0] pe_config,

    // To memory
    output reg  [DATA_WIDTH-1:0] pe_output,

    // To neighboring PEs
    output reg  [DATA_WIDTH-1:0] north_out,
    output reg  [DATA_WIDTH-1:0] south_out,
    output reg  [DATA_WIDTH-1:0] east_out,
    output reg  [DATA_WIDTH-1:0] west_out,
    output reg                   north_valid_out,
    output reg                   south_valid_out,
    output reg                   east_valid_out,
    output reg                   west_valid_out
);

    // Configuration decoding
    wire [1:0] output_dest  = pe_config[5:4];       // Output destination
    wire       store_to_mem = pe_config[6];         // Store result to memory

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            north_out       <= {DATA_WIDTH{1'b0}};
            south_out       <= {DATA_WIDTH{1'b0}};
            east_out        <= {DATA_WIDTH{1'b0}};
            west_out        <= {DATA_WIDTH{1'b0}};
            north_valid_out <= 1'b0;
            south_valid_out <= 1'b0;
            east_valid_out  <= 1'b0;
            west_valid_out  <= 1'b0;
            pe_output       <= {DATA_WIDTH{1'b0}};
        end else begin
            // Default outputs
            north_out       <= {DATA_WIDTH{1'b0}};
            south_out       <= {DATA_WIDTH{1'b0}};
            east_out        <= {DATA_WIDTH{1'b0}};
            west_out        <= {DATA_WIDTH{1'b0}};
            north_valid_out <= 1'b0;
            south_valid_out <= 1'b0;
            east_valid_out  <= 1'b0;
            west_valid_out  <= 1'b0;

            if (pe_result_valid) begin
                // Route result based on configuration
                case (output_dest)
                    2'b00: begin // North
                        north_out       <= pe_result;
                        north_valid_out <= 1'b1;
                    end
                    2'b01: begin // South
                        south_out       <= pe_result;
                        south_valid_out <= 1'b1;
                    end
                    2'b10: begin // East
                        east_out       <= pe_result;
                        east_valid_out <= 1'b1;
                    end
                    2'b11: begin // West
                        west_out       <= pe_result;
                        west_valid_out <= 1'b1;
                    end
                endcase

                // Store to memory if configured
                if (store_to_mem) begin
                    pe_output <= pe_result;
                end else begin
                    pe_output <= {DATA_WIDTH{1'b0}};
                end
            end else begin
                pe_output <= {DATA_WIDTH{1'b0}};
            end
        end
    end

endmodule