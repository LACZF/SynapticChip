module router #(
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,

    // Local data input with valid
    input wire [DATA_WIDTH-1:0] local_data,
    input wire local_valid,

    // Routing configuration
    input wire [15:0] config_in,

    // Output ports with valid signals
    output reg [DATA_WIDTH-1:0] north_out,
    output reg north_valid_out,
    output reg [DATA_WIDTH-1:0] south_out,
    output reg south_valid_out,
    output reg [DATA_WIDTH-1:0] east_out,
    output reg east_valid_out,
    output reg [DATA_WIDTH-1:0] west_out,
    output reg west_valid_out,
    output reg [DATA_WIDTH-1:0] reg_out,
    output reg reg_valid_out,

    // External data output with valid
    output reg [DATA_WIDTH-1:0] data_out_port,
    output reg data_valid_out_port
);

// Routing configuration fields
wire north_enable;
wire south_enable;
wire east_enable;
wire west_enable;
wire reg_enable;
wire output_enable;

assign north_enable = config_in[0];
assign south_enable = config_in[1];
assign east_enable = config_in[2];
assign west_enable = config_in[3];
assign reg_enable = config_in[4];
assign output_enable = config_in[5];

// Routing logic with valid signals
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        north_out <= {DATA_WIDTH{1'b0}};
        north_valid_out <= 1'b0;
        south_out <= {DATA_WIDTH{1'b0}};
        south_valid_out <= 1'b0;
        east_out <= {DATA_WIDTH{1'b0}};
        east_valid_out <= 1'b0;
        west_out <= {DATA_WIDTH{1'b0}};
        west_valid_out <= 1'b0;
        reg_out <= {DATA_WIDTH{1'b0}};
        reg_valid_out <= 1'b0;
        data_out_port <= {DATA_WIDTH{1'b0}};
        data_valid_out_port <= 1'b0;
    end else begin
        // Route data to enabled outputs with valid signals
        north_out <= north_enable ? local_data : {DATA_WIDTH{1'b0}};
        north_valid_out <= north_enable ? local_valid : 1'b0;

        south_out <= south_enable ? local_data : {DATA_WIDTH{1'b0}};
        south_valid_out <= south_enable ? local_valid : 1'b0;

        east_out <= east_enable ? local_data : {DATA_WIDTH{1'b0}};
        east_valid_out <= east_enable ? local_valid : 1'b0;

        west_out <= west_enable ? local_data : {DATA_WIDTH{1'b0}};
        west_valid_out <= west_enable ? local_valid : 1'b0;

        reg_out <= reg_enable ? local_data : {DATA_WIDTH{1'b0}};
        reg_valid_out <= reg_enable ? local_valid : 1'b0;

        data_out_port <= output_enable ? local_data : {DATA_WIDTH{1'b0}};
        data_valid_out_port <= output_enable ? local_valid : 1'b0;
    end
end

endmodule