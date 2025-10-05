// pe_ctrl.v
// PE控制模块实现

`include "pe_ctrl_params.v"

module pe_controller #(
    parameter NODE_ID_WIDTH = 5,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_PES = 4,
    parameter INST_WIDTH = 128,
    parameter PE_ID_WIDTH = 3
) (
    input clk,
    input rst_n,

    // Ring总线接口
    input ring_in_valid,
    input [NODE_ID_WIDTH-1:0] ring_in_src,
    input [NODE_ID_WIDTH-1:0] ring_in_dest,
    input [ADDR_WIDTH-1:0] ring_in_addr,
    input [DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,

    output reg ring_out_valid,
    output reg [NODE_ID_WIDTH-1:0] ring_out_src,
    output reg [NODE_ID_WIDTH-1:0] ring_out_dest,
    output reg [ADDR_WIDTH-1:0] ring_out_addr,
    output reg [DATA_WIDTH-1:0] ring_out_data,
    output reg ring_out_we,
    output reg [3:0] ring_out_be,
    output reg ring_out_ack,

    // PE阵列控制接口
    output reg [NUM_PES-1:0] pe_enable,
    output reg [NUM_PES-1:0] pe_reset,
    output reg [(NUM_PES*INST_WIDTH)-1:0] pe_instructions,
    output reg pe_inst_valid,

    // PE状态输入
    input [(NUM_PES*DATA_WIDTH)-1:0] pe_status,
    input [(NUM_PES*DATA_WIDTH)-1:0] pe_outputs,
    input [NUM_PES-1:0] pe_busy,

    // 路由配置接口
    output reg [(NUM_PES*4*PE_ID_WIDTH)-1:0] route_config, // 每个PE有4个方向的路由配置
    output reg route_cfg_valid
);

    // 内部寄存器
    reg [DATA_WIDTH-1:0] control_reg;
    reg [DATA_WIDTH-1:0] status_reg;
    reg [(NUM_PES*INST_WIDTH)-1:0] inst_buffer;
    reg [(NUM_PES*4*PE_ID_WIDTH)-1:0] route_buffer;

    // 状态机
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] data_buffer;
    reg [ADDR_WIDTH-1:0] addr_buffer;
    reg [NODE_ID_WIDTH-1:0] src_buffer;
    reg we_buffer;

    // 判断是否为本节点数据
    wire is_for_me = (ring_in_dest == {NODE_ID_WIDTH{1'b0}}) && ring_in_valid; // 假设控制器节点ID为0

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            pe_enable <= {`NUM_PES{1'b0}};
            pe_reset <= {`NUM_PES{1'b0}};
            pe_inst_valid <= 1'b0;
            route_cfg_valid <= 1'b0;
            control_reg <= {`DATA_WIDTH{1'b0}};
            status_reg <= {`DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    pe_inst_valid <= 1'b0;
                    route_cfg_valid <= 1'b0;

                    if (ring_in_valid) begin
                        // 处理环上数据
                        ring_out_valid <= ring_in_valid;
                        ring_out_src <= ring_in_src;
                        ring_out_dest <= ring_in_dest;
                        ring_out_addr <= ring_in_addr;
                        ring_out_data <= ring_in_data;
                        ring_out_we <= ring_in_we;
                        ring_out_be <= ring_in_be;

                        if (is_for_me) begin
                            // 数据是发给本控制器的
                            state <= `STATE_DATA;

                            // 保存源信息以便回复
                            src_buffer <= ring_in_src;
                            we_buffer <= ring_in_we;
                            addr_buffer <= ring_in_addr;
                            data_buffer <= ring_in_data;

                            // 处理写操作
                            if (ring_in_we) begin
                                case (ring_in_addr)
                                    `REG_PE_CTRL: begin
                                        control_reg <= ring_in_data;
                                        // 解析控制寄存器
                                        pe_enable <= ring_in_data[`NUM_PES-1:0];
                                        pe_reset <= ring_in_data[31:`NUM_PES];
                                    end

                                    `REG_PE_INST: begin
                                        // 将指令存储到缓冲区
                                        inst_buffer <= ring_in_data;
                                    end

                                    `REG_PE_DATA: begin
                                        // 数据寄存器，可以用于批量配置
                                        // 这里简化处理，实际可能需要更复杂的逻辑
                                    end

                                    `REG_ROUTE_CFG: begin
                                        // 路由配置
                                        route_buffer <= ring_in_data;
                                        route_cfg_valid <= 1'b1;
                                    end
                                endcase
                            end
                        end
                    end else begin
                        ring_out_valid <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    // 数据处理状态
                    if (!we_buffer) begin
                        // 读操作，准备数据
                        case (addr_buffer)
                            `REG_PE_CTRL: ring_out_data <= control_reg;
                            `REG_PE_STAT: begin
                                // 汇总PE状态
                                status_reg <= {
                                    pe_busy,
                                    pe_status[(`DATA_WIDTH-`NUM_PES-1):0]
                                };
                                ring_out_data <= status_reg;
                            end
                            `REG_PE_DATA: begin
                                // 读取PE输出数据
                                ring_out_data <= pe_outputs[`DATA_WIDTH-1:0]; // 只返回第一个PE的输出
                            end
                            default: ring_out_data <= {`DATA_WIDTH{1'b0}};
                        endcase

                        state <= `STATE_ARB;
                    end else begin
                        // 写操作完成，发送确认
                        ring_out_ack <= 1'b1;
                        state <= `STATE_IDLE;
                    end
                end

                `STATE_ARB: begin
                    // 仲裁状态，等待机会发送回复
                    if (!ring_in_valid) begin
                        // 环空闲，可以发送回复
                        ring_out_valid <= 1'b1;
                        ring_out_src <= `NODE_ID_WIDTH'd0; // 控制器节点ID
                        ring_out_dest <= src_buffer;       // 回复给请求者
                        ring_out_addr <= addr_buffer;
                        ring_out_data <= data_buffer;
                        ring_out_we <= 1'b0;               // 表示这是读回复
                        ring_out_be <= 4'b1111;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // 等待确认
                    if (ring_in_ack && (ring_in_dest == src_buffer)) begin
                        ring_out_valid <= 1'b0;
                        ring_out_ack <= 1'b0;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

    // 将指令缓冲区分发到各个PE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_instructions <= {(`NUM_PES*`INST_WIDTH){1'b0}};
        end else if (control_reg[0]) begin // 如果启用指令广播
            for (integer i = 0; i < `NUM_PES; i = i + 1) begin
                pe_instructions[i*`INST_WIDTH +: `INST_WIDTH] <= inst_buffer;
            end
            pe_inst_valid <= 1'b1;
        end else begin
            // 可以根据地址将指令发送到特定PE
            // 这里简化处理，实际实现会更复杂
            pe_inst_valid <= 1'b0;
        end
    end

    // 将路由配置分发到各个PE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_config <= {(`NUM_PES*4*`PE_ID_WIDTH){1'b0}};
        end else if (route_cfg_valid) begin
            for (integer i = 0; i < `NUM_PES; i = i + 1) begin
                // 每个PE的4个方向的路由配置
                route_config[i*4*`PE_ID_WIDTH +: 4*`PE_ID_WIDTH] <= route_buffer;
            end
        end
    end

endmodule