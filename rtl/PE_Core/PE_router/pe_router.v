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

    // Configuration decoding - 使用独立的bit位控制每个输出方向
    wire output_north = pe_config[4];   // 输出到北方向
    wire output_south = pe_config[5];   // 输出到南方向
    wire output_east  = pe_config[6];   // 输出到东方向
    wire output_west  = pe_config[7];   // 输出到西方向
    wire store_to_mem = pe_config[8];   // 存储结果到内存

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
                // 根据配置位同时输出到多个方向
                if (output_north) begin
                    north_out       <= pe_result;
                    north_valid_out <= 1'b1;
                end

                if (output_south) begin
                    south_out       <= pe_result;
                    south_valid_out <= 1'b1;
                end

                if (output_east) begin
                    east_out       <= pe_result;
                    east_valid_out <= 1'b1;
                end

                if (output_west) begin
                    west_out       <= pe_result;
                    west_valid_out <= 1'b1;
                end

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