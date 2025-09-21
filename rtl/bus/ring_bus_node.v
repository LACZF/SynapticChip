// ring_node.v
// Ring总线节点模块

`include "ring_params.v"

module ring_node (
    input clk,
    input rst_n,

    // 节点配置
    input [`NODE_ID_WIDTH-1:0] node_id,

    // 本地接口
    input local_req,
    input [`ADDR_WIDTH-1:0] local_addr,
    input [`DATA_WIDTH-1:0] local_data_in,
    output reg local_ack,
    output reg [`DATA_WIDTH-1:0] local_data_out,

    // Ring接口 - 输入
    input ring_in_valid,
    input [`NODE_ID_WIDTH-1:0] ring_in_src,
    input [`NODE_ID_WIDTH-1:0] ring_in_dest,
    input [`ADDR_WIDTH-1:0] ring_in_addr,
    input [`DATA_WIDTH-1:0] ring_in_data,
    input ring_in_ack,

    // Ring接口 - 输出
    output reg ring_out_valid,
    output reg [`NODE_ID_WIDTH-1:0] ring_out_src,
    output reg [`NODE_ID_WIDTH-1:0] ring_out_dest,
    output reg [`ADDR_WIDTH-1:0] ring_out_addr,
    output reg [`DATA_WIDTH-1:0] ring_out_data,
    output reg ring_out_ack
);

    // 内部状态寄存器
    reg [1:0] state;
    reg [`DATA_WIDTH-1:0] data_buffer;
    reg [`ADDR_WIDTH-1:0] addr_buffer;
    reg [`NODE_ID_WIDTH-1:0] dest_buffer;

    // 仲裁信号
    wire is_for_me;
    assign is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            local_ack <= 1'b0;
            local_data_out <= {`DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                `STATE_IDLE: begin
                    local_ack <= 1'b0;
                    ring_out_ack <= 1'b0;

                    if (local_req) begin
                        // 本地请求，准备发送
                        state <= `STATE_ARB;
                        data_buffer <= local_data_in;
                        addr_buffer <= local_addr;
                        // 简单地将目标设置为下一个节点
                        dest_buffer <= node_id + 1;
                        if (dest_buffer >= `NODES) dest_buffer <= 0;
                    end else if (ring_in_valid) begin
                        // 转发或处理环上数据
                        ring_out_valid <= ring_in_valid;
                        ring_out_src <= ring_in_src;
                        ring_out_dest <= ring_in_dest;
                        ring_out_addr <= ring_in_addr;
                        ring_out_data <= ring_in_data;

                        if (is_for_me) begin
                            // 数据是发给本节点的
                            state <= `STATE_DATA;
                            local_data_out <= ring_in_data;
                        end
                    end else begin
                        ring_out_valid <= 1'b0;
                    end
                end

                `STATE_ARB: begin
                    // 仲裁状态，等待机会发送
                    if (!ring_in_valid) begin
                        // 环空闲，可以发送
                        ring_out_valid <= 1'b1;
                        ring_out_src <= node_id;
                        ring_out_dest <= dest_buffer;
                        ring_out_addr <= addr_buffer;
                        ring_out_data <= data_buffer;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_DATA: begin
                    // 数据处理状态
                    local_ack <= 1'b1;
                    state <= `STATE_IDLE;
                end

                `STATE_ACK: begin
                    // 等待确认
                    if (ring_in_ack && (ring_in_dest == node_id)) begin
                        ring_out_valid <= 1'b0;
                        ring_out_ack <= 1'b0;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
