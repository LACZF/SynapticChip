// router_config.v
// 路由配置接口实现（纯Verilog）

`include "pe_router_params.v"

module router_config #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_PORTS = 4
) (
    input clk,
    input rst_n,

    // 配置总线接口
    input cfg_valid,
    input [ADDR_WIDTH-1:0] cfg_addr,
    input [DATA_WIDTH-1:0] cfg_data,
    output cfg_ack,

    // 到路由核心的配置输出
    output reg route_cfg_valid,
    output reg [ADDR_WIDTH-1:0] route_cfg_addr,
    output reg [DATA_WIDTH-1:0] route_cfg_data,
    input route_cfg_ack,

    // 状态输入
    input [DATA_WIDTH-1:0] route_status,
    output reg [DATA_WIDTH-1:0] status_out
);

    // 配置寄存器
    reg [DATA_WIDTH-1:0] config_registers_0;
    reg [DATA_WIDTH-1:0] config_registers_1;
    reg [DATA_WIDTH-1:0] config_registers_2;
    reg [DATA_WIDTH-1:0] config_registers_3;
    reg [DATA_WIDTH-1:0] config_registers_4;
    reg [DATA_WIDTH-1:0] config_registers_5;
    reg [DATA_WIDTH-1:0] config_registers_6;
    reg [DATA_WIDTH-1:0] config_registers_7;
    reg [DATA_WIDTH-1:0] config_registers_8;
    reg [DATA_WIDTH-1:0] config_registers_9;
    reg [DATA_WIDTH-1:0] config_registers_10;
    reg [DATA_WIDTH-1:0] config_registers_11;
    reg [DATA_WIDTH-1:0] config_registers_12;
    reg [DATA_WIDTH-1:0] config_registers_13;
    reg [DATA_WIDTH-1:0] config_registers_14;
    reg [DATA_WIDTH-1:0] config_registers_15;

    // 状态机
    reg [1:0] state;

    // 配置接口处理
    assign cfg_ack = (state == `STATE_ACK);

    // 配置接口状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            route_cfg_valid <= 1'b0;
            route_cfg_addr <= 0;
            route_cfg_data <= 0;
            status_out <= 0;

            // 初始化配置寄存器
            config_registers_0 <= 0;
            config_registers_1 <= 0;
            config_registers_2 <= 0;
            config_registers_3 <= 0;
            config_registers_4 <= 0;
            config_registers_5 <= 0;
            config_registers_6 <= 0;
            config_registers_7 <= 0;
            config_registers_8 <= 0;
            config_registers_9 <= 0;
            config_registers_10 <= 0;
            config_registers_11 <= 0;
            config_registers_12 <= 0;
            config_registers_13 <= 0;
            config_registers_14 <= 0;
            config_registers_15 <= 0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    route_cfg_valid <= 1'b0;

                    if (cfg_valid) begin
                        if (cfg_addr < 16) begin
                            // 本地配置寄存器访问
                            case (cfg_addr)
                                0: config_registers_0 <= cfg_data;
                                1: config_registers_1 <= cfg_data;
                                2: config_registers_2 <= cfg_data;
                                3: config_registers_3 <= cfg_data;
                                4: config_registers_4 <= cfg_data;
                                5: config_registers_5 <= cfg_data;
                                6: config_registers_6 <= cfg_data;
                                7: config_registers_7 <= cfg_data;
                                8: config_registers_8 <= cfg_data;
                                9: config_registers_9 <= cfg_data;
                                10: config_registers_10 <= cfg_data;
                                11: config_registers_11 <= cfg_data;
                                12: config_registers_12 <= cfg_data;
                                13: config_registers_13 <= cfg_data;
                                14: config_registers_14 <= cfg_data;
                                15: config_registers_15 <= cfg_data;
                            endcase
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
