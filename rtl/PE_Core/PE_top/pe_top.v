// pe_top.v
// Fabric module integrating PE array and routing

module pe_top #(
    parameter NUM_RINGS                           = 2,
    parameter ADDR_WIDTH                          = 64,
    parameter DATA_WIDTH                          = 64,
    parameter NODE_ID_WIDTH                       = 8,
    parameter OPCODE_WIDTH                        = 8,
    parameter MATCH_TYPE_WIDTH                    = 2,
    parameter NUM_PES                             = 4,
    parameter INST_WIDTH                          = 32,
    parameter PE_ID_WIDTH                         = 4,
    parameter PE_ARRAY_ROWS                       = 2,
    parameter PE_ARRAY_COLS                       = 2
) (
    input                                         clk,
    input                                         rst_n,

    input  wire [NUM_PES-1:0]                     pe_enable_i,
    input  wire [NUM_PES-1:0]                     pe_reset_i,
    input  wire [(NUM_PES*INST_WIDTH)-1:0]        pe_instructions_i,
    input  wire                                   pe_inst_valid_i,
    output     [(NUM_PES*DATA_WIDTH)-1:0]         pe_status_o,
    output     [(NUM_PES*DATA_WIDTH)-1:0]         pe_outputs_o,
    output     [NUM_PES-1:0]                      pe_busy_o,
    input  wire [(NUM_PES*4*PE_ID_WIDTH)-1:0]     route_config_i,
    input  wire                                   route_cfg_valid_i,

    output [DATA_WIDTH-1:0]                       fabric_status_o
);
    // PE interconnection signals
    wire [NUM_PES-1:0] pe_north_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_north_data;
    wire [NUM_PES-1:0] pe_north_ready;

    wire [NUM_PES-1:0] pe_south_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_south_data;
    wire [NUM_PES-1:0] pe_south_ready;

    wire [NUM_PES-1:0] pe_east_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_east_data;
    wire [NUM_PES-1:0] pe_east_ready;

    wire [NUM_PES-1:0] pe_west_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0] pe_west_data;
    wire [NUM_PES-1:0] pe_west_ready;

    // Instantiate PE array
    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : pe_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : pe_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;
                pe_node #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .NUM_PES(NUM_PES),
                    .INST_WIDTH(INST_WIDTH),
                    .PE_ID_WIDTH(PE_ID_WIDTH),
                    .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
                    .PE_ARRAY_COLS(PE_ARRAY_COLS)
                ) pe (
                    .clk(clk),
                    .rst_n(rst_n & !pe_reset_i[pe_idx]),
                    .enable_i(pe_enable_i[pe_idx]),
                    .instruction_i(pe_instructions_i[pe_idx*INST_WIDTH +: INST_WIDTH]),
                    .inst_valid_i(pe_inst_valid_i),
                    .north_valid_i(pe_north_valid[pe_idx]),
                    .north_data_i(pe_north_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .north_ready_o(pe_north_ready[pe_idx]),
                    .south_valid_i(pe_south_valid[pe_idx]),
                    .south_data_i(pe_south_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .south_ready_o(pe_south_ready[pe_idx]),
                    .east_valid_i(pe_east_valid[pe_idx]),
                    .east_data_i(pe_east_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .east_ready_o(pe_east_ready[pe_idx]),
                    .west_valid_i(pe_west_valid[pe_idx]),
                    .west_data_i(pe_west_data[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .west_ready_o(pe_west_ready[pe_idx]),
                    .out_data_o(pe_outputs_o[pe_idx*DATA_WIDTH +: DATA_WIDTH]),
                    .out_valid_o(),
                    .busy_o(pe_busy_o[pe_idx]),
                    .status_o(pe_status_o[pe_idx*DATA_WIDTH +: DATA_WIDTH])
                );
            end
        end
    endgenerate

    // Instantiate routing configuration module
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] north_routes_o;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] south_routes_o;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] east_routes_o;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] west_routes_o;

    pe_route_config #(
        .NUM_PES(NUM_PES),
        .PE_ID_WIDTH(PE_ID_WIDTH)
    ) route_cfg (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid_i(route_cfg_valid_i),
        .cfg_data_i(route_config_i),
        .north_routes_o(north_routes_o),
        .south_routes_o(south_routes_o),
        .east_routes_o(east_routes_o),
        .west_routes_o(west_routes_o)
    );

    // PE array row and column parameters are defined in module parameters

    // Connect PE inter-routing
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : connect_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : connect_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;

                // North connection
                if (i > 0) begin
                    assign pe_north_valid[pe_idx] = pe_south_valid[(i-1)*PE_ARRAY_COLS+j];
                    assign pe_north_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_south_data[((i-1)*PE_ARRAY_COLS+j)*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_south_ready[(i-1)*PE_ARRAY_COLS+j] = pe_north_ready[pe_idx];
                end else begin
                    assign pe_north_valid[pe_idx] = 1'b0;
                    assign pe_north_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end

                // South connection
                if (i < PE_ARRAY_ROWS-1) begin
                    assign pe_south_valid[pe_idx] = pe_north_valid[(i+1)*PE_ARRAY_COLS+j];
                    assign pe_south_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_north_data[((i+1)*PE_ARRAY_COLS+j)*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_north_ready[(i+1)*PE_ARRAY_COLS+j] = pe_south_ready[pe_idx];
                end else begin
                    assign pe_south_valid[pe_idx] = 1'b0;
                    assign pe_south_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end

                // East connection
                if (j < PE_ARRAY_COLS-1) begin
                    assign pe_east_valid[pe_idx] = pe_west_valid[i*PE_ARRAY_COLS+(j+1)];
                    assign pe_east_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_west_data[(i*PE_ARRAY_COLS+(j+1))*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_west_ready[i*PE_ARRAY_COLS+(j+1)] = pe_east_ready[pe_idx];
                end else begin
                    assign pe_east_valid[pe_idx] = 1'b0;
                    assign pe_east_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end

                // West connection
                if (j > 0) begin
                    assign pe_west_valid[pe_idx] = pe_east_valid[i*PE_ARRAY_COLS+(j-1)];
                    assign pe_west_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] =
                        pe_east_data[(i*PE_ARRAY_COLS+(j-1))*DATA_WIDTH +: DATA_WIDTH];
                    assign pe_east_ready[i*PE_ARRAY_COLS+(j-1)] = pe_west_ready[pe_idx];
                end else begin
                    assign pe_west_valid[pe_idx] = 1'b0;
                    assign pe_west_data[pe_idx*DATA_WIDTH +: DATA_WIDTH] = 0;
                end
            end
        end
    endgenerate

    // Status output
    assign fabric_status_o = {
        pe_busy_o,        // PE busy status
        pe_enable_i       // PE enable status
    };

endmodule