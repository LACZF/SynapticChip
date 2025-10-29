`include "stddef.v"
`include "global_config.v"

`include "pe_addr.v"
`include "pe.v"

module pe_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_PES = 4,
    parameter INST_WIDTH = 32,
    parameter PE_ID_WIDTH = 4,
    parameter PE_ARRAY_ROWS = 2,
    parameter PE_ARRAY_COLS = 2
) (
    input                              clk,
    input                              reset,

    // OBI Bus interface
    input                              req_i,
    input                              we_i,
    input  [ADDR_WIDTH-1:0]            addr_i,
    input  [DATA_WIDTH-1:0]            wr_data_i,
    output [DATA_WIDTH-1:0]            rd_data_o,
    output                             gnt_o,
    output                             rvalid_o
);

    // Internal control signals (previously between pe_ctrl and pe_top)
    wire [NUM_PES-1:0]                 pe_enable;
    wire [NUM_PES-1:0]                 pe_reset;
    wire [(NUM_PES*INST_WIDTH)-1:0]    pe_instructions;
    wire                               pe_inst_valid;
    wire [(NUM_PES*`DATA_WIDTH)-1:0]   pe_status;
    wire [(NUM_PES*`DATA_WIDTH)-1:0]   pe_outputs;
    wire [NUM_PES-1:0]                 pe_busy;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] route_config;
    wire                               route_cfg_valid;
    wire [`DATA_WIDTH-1:0]             fabric_status;

    // --------------------------
    // Control Logic (from pe_ctrl)
    // --------------------------

    // Internal registers
    reg [NUM_PES-1:0]                  pe_enable_reg;
    reg [NUM_PES-1:0]                  pe_reset_reg;
    reg [(NUM_PES*INST_WIDTH)-1:0]     pe_inst_reg;
    reg                                pe_inst_valid_reg;
    reg [(NUM_PES*4*PE_ID_WIDTH)-1:0]  route_config_reg;
    reg                                route_cfg_valid_reg;

    // Register selection
    wire [7:0]                         reg_offset = addr_i[7:0];
    wire                               cs_valid = req_i; // OBI req_i replaces cs_n_i & ~as_n_i

    // Read data mux
    assign rd_data_o = (cs_valid && !we_i) ?
                    (reg_offset == `PE_CTRL_ADDR ? {{(DATA_WIDTH-2){1'b0}}, pe_enable_reg, pe_reset_reg} :
                     reg_offset == `PE_STATUS_ADDR ? pe_status[DATA_WIDTH-1:0] :
                     reg_offset == `PE_INST_ADDR ? pe_inst_reg[DATA_WIDTH-1:0] :
                     reg_offset == `PE_DATA_ADDR ? pe_outputs[DATA_WIDTH-1:0] :
                     reg_offset == `PE_ROUTE_ADDR ? route_config_reg[DATA_WIDTH-1:0] :
                     0) : 0;

    // Write handling
    always @(posedge clk or negedge reset) begin
        if (reset == 0) begin
            pe_enable_reg       <= {NUM_PES{1'b0}};
            pe_reset_reg        <= {NUM_PES{1'b0}};
            pe_inst_reg         <= 0;
            pe_inst_valid_reg   <= 1'b0;
            route_config_reg    <= 0;
            route_cfg_valid_reg <= 1'b0;
        end else begin
            // Default values
            pe_inst_valid_reg <= 1'b0;
            route_cfg_valid_reg <= 1'b0;

            if (cs_valid && we_i) begin
                case (reg_offset)
                    `PE_CTRL_ADDR: begin
                        pe_enable_reg <= wr_data_i[0+:NUM_PES];
                        pe_reset_reg  <= wr_data_i[NUM_PES+:NUM_PES];
                    end
                    `PE_INST_ADDR: begin
                        pe_inst_reg       <= wr_data_i;
                        pe_inst_valid_reg <= 1'b1;
                    end
                    `PE_ROUTE_ADDR: begin
                        route_config_reg    <= wr_data_i;
                        route_cfg_valid_reg <= 1'b1;
                    end
                endcase
            end
        end
    end

    // OBI protocol signals
    assign gnt_o = req_i; // Always grant immediately

    // rvalid_o generation
    reg rvalid_d;
    always @(posedge clk or negedge reset) begin
        if (reset == 0) begin
            rvalid_d <= 1'b0;
        end else begin
            rvalid_d <= req_i;
        end
    end

    assign rvalid_o = rvalid_d;

    // Output assignments (internal connections)
    assign pe_enable       = pe_enable_reg;
    assign pe_reset        = pe_reset_reg;
    assign pe_instructions = pe_inst_reg;
    assign pe_inst_valid   = pe_inst_valid_reg;
    assign route_config    = route_config_reg;
    assign route_cfg_valid = route_cfg_valid_reg;

    // --------------------------
    // PE Array Implementation (from pe_top)
    // --------------------------

    // PE interconnection signals
    wire [NUM_PES-1:0]               pe_north_valid;
    wire [(NUM_PES*`DATA_WIDTH)-1:0] pe_north_data;
    wire [NUM_PES-1:0]               pe_north_ready;

    wire [NUM_PES-1:0]               pe_south_valid;
    wire [(NUM_PES*`DATA_WIDTH)-1:0] pe_south_data;
    wire [NUM_PES-1:0]               pe_south_ready;

    wire [NUM_PES-1:0]               pe_east_valid;
    wire [(NUM_PES*`DATA_WIDTH)-1:0] pe_east_data;
    wire [NUM_PES-1:0]               pe_east_ready;

    wire [NUM_PES-1:0]               pe_west_valid;
    wire [(NUM_PES*`DATA_WIDTH)-1:0] pe_west_data;
    wire [NUM_PES-1:0]               pe_west_ready;

    // Instantiate PE array
    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : pe_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : pe_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;
                pe_node #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(`DATA_WIDTH),
                    .NUM_PES(NUM_PES),
                    .INST_WIDTH(INST_WIDTH),
                    .PE_ID_WIDTH(PE_ID_WIDTH),
                    .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
                    .PE_ARRAY_COLS(PE_ARRAY_COLS)
                ) pe (
                    .clk(clk),
                    .rst_n(reset == `RESET_DISABLE ? 1'b1 : 1'b0 & !pe_reset[pe_idx]),
                    .enable_i(pe_enable[pe_idx]),
                    .instruction_i(pe_instructions[pe_idx*INST_WIDTH +: INST_WIDTH]),
                    .inst_valid_i(pe_inst_valid),
                    .north_valid_i(pe_north_valid[pe_idx]),
                    .north_data_i(pe_north_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .north_ready_o(pe_north_ready[pe_idx]),
                    .south_valid_i(pe_south_valid[pe_idx]),
                    .south_data_i(pe_south_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .south_ready_o(pe_south_ready[pe_idx]),
                    .east_valid_i(pe_east_valid[pe_idx]),
                    .east_data_i(pe_east_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .east_ready_o(pe_east_ready[pe_idx]),
                    .west_valid_i(pe_west_valid[pe_idx]),
                    .west_data_i(pe_west_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .west_ready_o(pe_west_ready[pe_idx]),
                    .out_data_o(pe_outputs[pe_idx*`DATA_WIDTH +: `DATA_WIDTH]),
                    .out_valid_o(),
                    .busy_o(pe_busy[pe_idx]),
                    .status_o(pe_status[pe_idx*`DATA_WIDTH +: `DATA_WIDTH])
                );
            end
        end
    endgenerate

    // Instantiate routing configuration module
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] north_routes;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] south_routes;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] east_routes;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0] west_routes;

    pe_route_config #(
        .NUM_PES(NUM_PES),
        .PE_ID_WIDTH(PE_ID_WIDTH)
    ) route_cfg (
        .clk(clk),
        .rst_n(reset == `RESET_DISABLE ? 1'b1 : 1'b0),
        .cfg_valid_i(route_cfg_valid),
        .cfg_data_i(route_config),
        .north_routes_o(north_routes),
        .south_routes_o(south_routes),
        .east_routes_o(east_routes),
        .west_routes_o(west_routes)
    );

    // Connect PE inter-routing
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : connect_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : connect_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;

                // North connection
                if (i > 0) begin
                    assign pe_north_valid[pe_idx] = pe_south_valid[(i-1)*PE_ARRAY_COLS+j];
                    assign pe_north_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_south_data[((i-1)*PE_ARRAY_COLS+j)*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_south_ready[(i-1)*PE_ARRAY_COLS+j] = pe_north_ready[pe_idx];
                end else begin
                    assign pe_north_valid[pe_idx] = 1'b0;
                    assign pe_north_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end

                // South connection
                if (i < PE_ARRAY_ROWS-1) begin
                    assign pe_south_valid[pe_idx] = pe_north_valid[(i+1)*PE_ARRAY_COLS+j];
                    assign pe_south_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_north_data[((i+1)*PE_ARRAY_COLS+j)*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_north_ready[(i+1)*PE_ARRAY_COLS+j] = pe_south_ready[pe_idx];
                end else begin
                    assign pe_south_valid[pe_idx] = 1'b0;
                    assign pe_south_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end

                // East connection
                if (j < PE_ARRAY_COLS-1) begin
                    assign pe_east_valid[pe_idx] = pe_west_valid[i*PE_ARRAY_COLS+(j+1)];
                    assign pe_east_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_west_data[(i*PE_ARRAY_COLS+(j+1))*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_west_ready[i*PE_ARRAY_COLS+(j+1)] = pe_east_ready[pe_idx];
                end else begin
                    assign pe_east_valid[pe_idx] = 1'b0;
                    assign pe_east_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end

                // West connection
                if (j > 0) begin
                    assign pe_west_valid[pe_idx] = pe_east_valid[i*PE_ARRAY_COLS+(j-1)];
                    assign pe_west_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] =
                        pe_east_data[(i*PE_ARRAY_COLS+(j-1))*`DATA_WIDTH +: `DATA_WIDTH];
                    assign pe_east_ready[i*PE_ARRAY_COLS+(j-1)] = pe_west_ready[pe_idx];
                end else begin
                    assign pe_west_valid[pe_idx] = 1'b0;
                    assign pe_west_data[pe_idx*`DATA_WIDTH +: `DATA_WIDTH] = 0;
                end
            end
        end
    endgenerate

    // Status output (internal)
    assign fabric_status = {
        pe_busy,        // PE busy status
        pe_enable       // PE enable status
    };

endmodule