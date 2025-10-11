// pe_ctrl_route_config.v
// Routing configuration module implementation

`include "pe_ctrl_params.v"

module pe_route_config #(
    parameter NUM_PES                              = 4,
    parameter PE_ID_WIDTH                          = 4,
    parameter PE_ARRAY_ROWS                        = 2,
    parameter PE_ARRAY_COLS                        = 2
) (
    input                                          clk,
    input                                          rst_n,
    input                                          cfg_valid,
    input       [(NUM_PES*4*PE_ID_WIDTH)-1:0]      cfg_data,

    // Routing configuration output to each PE
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]      north_routes,
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]      south_routes,
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]      east_routes,
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]      west_routes
);

    // Routing configuration register
    reg [(NUM_PES*4*PE_ID_WIDTH)-1:0] route_table;

    // Update routing configuration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_table <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
            north_routes <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
            south_routes <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
            east_routes <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
            west_routes <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
        end else if (cfg_valid) begin
            route_table <= cfg_data;

            // Configure routing based on PE position
            for (integer y = 0; y < PE_ARRAY_ROWS; y = y + 1) begin
                for (integer x = 0; x < PE_ARRAY_COLS; x = x + 1) begin
                    // integer pe_idx = y * PE_ARRAY_COLS + x;

                    // North direction routing
                    if (y > 0) begin
                        north_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            (y-1) * PE_ARRAY_COLS + x;
                    end else begin
                        north_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            cfg_data[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH];
                    end

                    // South direction routing
                    if (y < PE_ARRAY_ROWS-1) begin
                        south_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            (y+1) * PE_ARRAY_COLS + x;
                    end else begin
                        south_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            cfg_data[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH + PE_ID_WIDTH +: PE_ID_WIDTH];
                    end

                    // East direction routing
                    if (x < PE_ARRAY_COLS-1) begin
                        east_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            y * PE_ARRAY_COLS + (x+1);
                    end else begin
                        east_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            cfg_data[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH + 2*PE_ID_WIDTH +: PE_ID_WIDTH];
                    end

                    // West direction routing
                    if (x > 0) begin
                        west_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            y * PE_ARRAY_COLS + (x-1);
                    end else begin
                        west_routes[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH +: PE_ID_WIDTH] =
                            cfg_data[(y * PE_ARRAY_COLS + x)*4*PE_ID_WIDTH + 3*PE_ID_WIDTH +: PE_ID_WIDTH];
                    end
                end
            end
        end
    end

endmodule