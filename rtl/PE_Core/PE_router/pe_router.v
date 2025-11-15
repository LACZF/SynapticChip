module pe_router #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // From PE
    input  wire [DATA_WIDTH-1:0] pe_result_i,
    input  wire                  pe_result_valid_i,

    // Configuration
    input  wire [DATA_WIDTH-1:0] pe_config_i,

    // To neighboring PEs
    output reg  [DATA_WIDTH-1:0] north_out_o,
    output reg  [DATA_WIDTH-1:0] south_out_o,
    output reg  [DATA_WIDTH-1:0] east_out_o,
    output reg  [DATA_WIDTH-1:0] west_out_o,
    output reg                   north_valid_out_o,
    output reg                   south_valid_out_o,
    output reg                   east_valid_out_o,
    output reg                   west_valid_out_o
);

    // Configuration decoding - 路由输出控制位从bit16开始，低16位用于PE操作数和操作码
    wire output_north = pe_config_i[16];  // 输出到北方向
    wire output_south = pe_config_i[17];  // 输出到南方向
    wire output_east  = pe_config_i[18];  // 输出到东方向
    wire output_west  = pe_config_i[19];  // 输出到西方向

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            north_out_o       <= {DATA_WIDTH{1'b0}};
            south_out_o       <= {DATA_WIDTH{1'b0}};
            east_out_o        <= {DATA_WIDTH{1'b0}};
            west_out_o        <= {DATA_WIDTH{1'b0}};
            north_valid_out_o <= 1'b0;
            south_valid_out_o <= 1'b0;
            east_valid_out_o  <= 1'b0;
            west_valid_out_o  <= 1'b0;
        end else begin
            north_out_o       <= {DATA_WIDTH{1'b0}};
            south_out_o       <= {DATA_WIDTH{1'b0}};
            east_out_o        <= {DATA_WIDTH{1'b0}};
            west_out_o        <= {DATA_WIDTH{1'b0}};
            north_valid_out_o <= 1'b0;
            south_valid_out_o <= 1'b0;
            east_valid_out_o  <= 1'b0;
            west_valid_out_o  <= 1'b0;

            if (pe_result_valid_i) begin
                // 根据配置位同时输出到多个方向
                if (output_north) begin
                    north_out_o       <= pe_result_i;
                    north_valid_out_o <= 1'b1;
                end

                if (output_south) begin
                    south_out_o       <= pe_result_i;
                    south_valid_out_o <= 1'b1;
                end

                if (output_east) begin
                    east_out_o       <= pe_result_i;
                    east_valid_out_o <= 1'b1;
                end

                if (output_west) begin
                    west_out_o       <= pe_result_i;
                    west_valid_out_o <= 1'b1;
                end
            end
        end
    end

endmodule