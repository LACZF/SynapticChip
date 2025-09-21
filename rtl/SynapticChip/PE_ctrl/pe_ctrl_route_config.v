// pe_ctrl_route_config.v
// 路由配置模块实现

`include "pe_ctrl_params.v"

module route_config (
    input clk,
    input rst_n,
    input cfg_valid,
    input [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] cfg_data,

    // 到各个PE的路由配置输出
    output reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] north_routes,
    output reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] south_routes,
    output reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] east_routes,
    output reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] west_routes
);

    // 路由配置寄存器
    reg [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] route_table;

    // 更新路由配置
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_table <= {(`NUM_PES*4*`PE_ID_WIDTH){1'b0}};
            north_routes <= {(`NUM_PES*4*`PE_ID_WIDTH){1'b0}};
            south_routes <= {(`NUM_PES*4*`PE_ID_WIDTH){1'b0}};
            east_routes <= {(`NUM_PES*4*`PE_ID_WIDTH){1'b0}};
            west_routes <= {(`NUM_PES*4*`PE_ID_WIDTH){1'b0}};
        end else if (cfg_valid) begin
            route_table <= cfg_data;

            // 根据PE位置配置路由
            for (integer y = 0; y < `ARRAY_ROWS; y = y + 1) begin
                for (integer x = 0; x < `ARRAY_COLS; x = x + 1) begin
                    // integer pe_idx = y * `ARRAY_COLS + x;

                    // 北方向路由
                    if (y > 0) begin
                        north_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            (y-1) * `ARRAY_COLS + x;
                    end else begin
                        north_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            cfg_data[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH];
                    end

                    // 南方向路由
                    if (y < `ARRAY_ROWS-1) begin
                        south_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            (y+1) * `ARRAY_COLS + x;
                    end else begin
                        south_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            cfg_data[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH + `PE_ID_WIDTH +: `PE_ID_WIDTH];
                    end

                    // 东方向路由
                    if (x < `ARRAY_COLS-1) begin
                        east_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            y * `ARRAY_COLS + (x+1);
                    end else begin
                        east_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            cfg_data[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH + 2*`PE_ID_WIDTH +: `PE_ID_WIDTH];
                    end

                    // 西方向路由
                    if (x > 0) begin
                        west_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            y * `ARRAY_COLS + (x-1);
                    end else begin
                        west_routes[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH +: `PE_ID_WIDTH] =
                            cfg_data[(y * `ARRAY_COLS + x)*4*`PE_ID_WIDTH + 3*`PE_ID_WIDTH +: `PE_ID_WIDTH];
                    end
                end
            end
        end
    end

endmodule
