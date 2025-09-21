// pe_router_core.v
// 路由模块核心实现

`include "pe_router_params.v"

module router_core (
    input clk,
    input rst_n,

    // 配置接口
    input cfg_valid,
    input [`ADDR_WIDTH-1:0] cfg_addr,
    input [`DATA_WIDTH-1:0] cfg_data,
    output cfg_ack,

    // 数据输入接口 (北、南、东、西、本地)
    input [`NUM_PORTS-1:0] data_in_valid,
    input [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_in,
    output reg [`NUM_PORTS-1:0] data_in_ready,

    // 数据输出接口 (北、南、东、西、本地)
    output reg [`NUM_PORTS-1:0] data_out_valid,
    output reg [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_out,
    input [`NUM_PORTS-1:0] data_out_ready,

    // 状态输出
    output reg [`DATA_WIDTH-1:0] status
);

    // 配置寄存器
    reg [1:0] route_algorithm;
    reg [(`NUM_PORTS*`NUM_PORTS)-1:0] route_table; // 路由表: 输入端口 -> 输出端口映射
    reg [`NUM_PORTS-1:0] port_enable;

    // 输入缓冲区
    reg [`DATA_WIDTH-1:0] input_buffers [0:`NUM_PORTS-1][0:`BUFFER_DEPTH-1];
    reg [`BUFFER_ADDR_WIDTH-1:0] write_ptr [0:`NUM_PORTS-1];
    reg [`BUFFER_ADDR_WIDTH-1:0] read_ptr [0:`NUM_PORTS-1];
    reg [`NUM_PORTS-1:0] buffer_empty;
    reg [`NUM_PORTS-1:0] buffer_full;

    // 输出仲裁器
    reg [2:0] arbiter_state [0:`NUM_PORTS-1];
    reg [`PORT_ID_WIDTH-1:0] current_grant [0:`NUM_PORTS-1];

    // 目标地址提取
    wire [`ADDR_WIDTH-1:0] dest_addr [0:`NUM_PORTS-1];

    generate
        for (genvar i = 0; i < `NUM_PORTS; i = i + 1) begin : dest_extract
            assign dest_addr[i] = data_in[i*`DATA_WIDTH +: `ADDR_WIDTH];
        end
    endgenerate

    // 配置接口处理
    assign cfg_ack = cfg_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_algorithm <= `ROUTE_XY;
            route_table <= {(`NUM_PORTS*`NUM_PORTS){1'b0}};
            port_enable <= {`NUM_PORTS{1'b1}}; // 默认所有端口使能
        end else if (cfg_valid) begin
            case (cfg_addr)
                `REG_ROUTE_ALGO: route_algorithm <= cfg_data[1:0];
                `REG_ROUTE_TABLE: route_table <= cfg_data[(`NUM_PORTS*`NUM_PORTS)-1:0];
                `REG_PORT_CTRL: port_enable <= cfg_data[`NUM_PORTS-1:0];
            endcase
        end
    end

    // 输入缓冲区管理
    generate
        for (genvar i = 0; i < `NUM_PORTS; i = i + 1) begin : buffer_management
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    write_ptr[i] <= 0;
                    read_ptr[i] <= 0;
                    buffer_empty[i] <= 1'b1;
                    buffer_full[i] <= 1'b0;
                    for (integer j = 0; j < `BUFFER_DEPTH; j = j + 1) begin
                        input_buffers[i][j] <= 0;
                    end
                end else begin
                    // 写入缓冲区
                    if (data_in_valid[i] && data_in_ready[i] && port_enable[i]) begin
                        input_buffers[i][write_ptr[i]] <= data_in[i*`DATA_WIDTH +: `DATA_WIDTH];
                        write_ptr[i] <= write_ptr[i] + 1;
                        buffer_empty[i] <= 1'b0;

                        if (write_ptr[i] + 1 == read_ptr[i]) begin
                            buffer_full[i] <= 1'b1;
                        end
                    end

                    // 读取缓冲区
                    if (!buffer_empty[i] && (arbiter_state[i] == `STATE_DATA)) begin
                        read_ptr[i] <= read_ptr[i] + 1;
                        if (read_ptr[i] + 1 == write_ptr[i]) begin
                            buffer_empty[i] <= 1'b1;
                        end
                        buffer_full[i] <= 1'b0;
                    end
                end
            end

            // 准备好接收数据当缓冲区未满
            always @(*) begin
                data_in_ready[i] = !buffer_full[i] && port_enable[i];
            end
        end
    endgenerate

    // 路由决策
    function [`PORT_ID_WIDTH-1:0] route_decision;
        input [`PORT_ID_WIDTH-1:0] input_port;
        input [`ADDR_WIDTH-1:0] dest_address;
        input [1:0] algorithm;
        input [(`NUM_PORTS*`NUM_PORTS)-1:0] table;

        reg [`PORT_ID_WIDTH-1:0] result;
        begin
            case (algorithm)
                `ROUTE_XY: begin
                    // XY维度路由: 先东/西，后北/南
                    // 这里简化实现，实际应根据目标地址和当前地址计算
                    result = table[input_port*`NUM_PORTS +: `NUM_PORTS];
                end

                `ROUTE_WESTFIRST: begin
                    // 西向优先路由
                    // 这里简化实现
                    result = table[input_port*`NUM_PORTS +: `NUM_PORTS];
                end

                `ROUTE_NORTHLAST: begin
                    // 北向最后路由
                    // 这里简化实现
                    result = table[input_port*`NUM_PORTS +: `NUM_PORTS];
                end

                `ROUTE_CUSTOM: begin
                    // 自定义路由表
                    result = table[input_port*`NUM_PORTS +: `NUM_PORTS];
                end

                default: result = `PORT_LOCAL;
            endcase

            route_decision = result;
        end
    endfunction

    // 输出仲裁和数据转发
    generate
        for (genvar i = 0; i < `NUM_PORTS; i = i + 1) begin : output_arbitration
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    arbiter_state[i] <= `STATE_IDLE;
                    current_grant[i] <= 0;
                    data_out_valid[i] <= 1'b0;
                    data_out[i*`DATA_WIDTH +: `DATA_WIDTH] <= 0;
                end else begin
                    case (arbiter_state[i])
                        `STATE_IDLE: begin
                            data_out_valid[i] <= 1'b0;

                            // 检查所有输入端口是否有数据要发送到当前输出端口
                            for (integer j = 0; j < `NUM_PORTS; j = j + 1) begin
                                if (!buffer_empty[j] && port_enable[j]) begin
                                    // 计算路由决策
                                    if (route_decision(j, dest_addr[j], route_algorithm, route_table) == i) begin
                                        arbiter_state[i] <= `STATE_ARB;
                                        current_grant[i] <= j;
                                        break;
                                    end
                                end
                            end
                        end

                        `STATE_ARB: begin
                            // 仲裁状态，等待输出端口就绪
                            if (data_out_ready[i]) begin
                                arbiter_state[i] <= `STATE_DATA;
                                data_out_valid[i] <= 1'b1;
                                data_out[i*`DATA_WIDTH +: `DATA_WIDTH] <= input_buffers[current_grant[i]][read_ptr[current_grant[i]]];
                            end
                        end

                        `STATE_DATA: begin
                            // 数据传输状态
                            if (data_out_ready[i]) begin
                                data_out_valid[i] <= 1'b0;
                                arbiter_state[i] <= `STATE_IDLE;
                            end
                        end
                    endcase
                end
            end
        end
    endgenerate

    // 状态监控
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status <= 0;
        end else begin
            // 汇总状态信息
            status <= {
                buffer_empty,    // 高位: 缓冲区空状态
                buffer_full,     // 中间: 缓冲区满状态
                port_enable,     // 低位: 端口使能状态
                4'b0            // 保留位
            };
        end
    end

endmodule
