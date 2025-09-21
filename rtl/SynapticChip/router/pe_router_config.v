// pe_router_config.v
// 路由配置接口实现

`include "pe_router_params.v"

module router_config (
    input clk,
    input rst_n,

    // 配置总线接口
    input cfg_valid,
    input [`ADDR_WIDTH-1:0] cfg_addr,
    input [`DATA_WIDTH-1:0] cfg_data,
    output cfg_ack,

    // 到路由核心的配置输出
    output reg route_cfg_valid,
    output reg [`ADDR_WIDTH-1:0] route_cfg_addr,
    output reg [`DATA_WIDTH-1:0] route_cfg_data,
    input route_cfg_ack,

    // 状态输入
    input [`DATA_WIDTH-1:0] route_status,
    output reg [`DATA_WIDTH-1:0] status_out
);

    // 配置寄存器
    reg [`DATA_WIDTH-1:0] config_registers [0:15];

    // 状态机
    reg [1:0] state;

    // 配置接口处理
    assign cfg_ack = (state == `STATE_ACK);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            route_cfg_valid <= 1'b0;
            route_cfg_addr <= 0;
            route_cfg_data <= 0;
            status_out <= 0;

            // 初始化配置寄存器
            for (integer i = 0; i < 16; i = i + 1) begin
                config_registers[i] <= 0;
            end
        end else begin
            case (state)
                `STATE_IDLE: begin
                    route_cfg_valid <= 1'b0;

                    if (cfg_valid) begin
                        if (cfg_addr < 16) begin
                            // 本地配置寄存器访问
                            config_registers[cfg_addr] <= cfg_data;
                            state <= `STATE_ACK;
                        end else begin
                            // 路由核心配置访问
                            route_cfg_valid <= 1'b1;
                            route_cfg_addr <= cfg_addr;
                            route_cfg_data <= cfg_data;
                            state <= `STATE_DATA;
                        end
                    end

                    // 更新状态输出
                    status_out <= route_status;
                end

                `STATE_DATA: begin
                    if (route_cfg_ack) begin
                        route_cfg_valid <= 1'b0;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    state <= `STATE_IDLE;
                end
            endcase
        end
    end

endmodule
