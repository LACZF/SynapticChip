// uart_ring_node.v
// UART的Ring总线节点接口

`include "uart_params.v"

module uart_ring_node #(
    parameter NODE_ID_WIDTH = 5,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input clk,
    input rst_n,
    input [NODE_ID_WIDTH-1:0] node_id,

    // Ring接口 - 输入
    input ring_in_valid,
    input [NODE_ID_WIDTH-1:0] ring_in_src,
    input [NODE_ID_WIDTH-1:0] ring_in_dest,
    input [ADDR_WIDTH-1:0] ring_in_addr,
    input [DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,

    // Ring接口 - 输出
    output reg ring_out_valid,
    output reg [NODE_ID_WIDTH-1:0] ring_out_src,
    output reg [NODE_ID_WIDTH-1:0] ring_out_dest,
    output reg [ADDR_WIDTH-1:0] ring_out_addr,
    output reg [DATA_WIDTH-1:0] ring_out_data,
    output reg ring_out_we,
    output reg [3:0] ring_out_be,
    output reg ring_out_ack,

    // UART接口
    output reg uart_req,
    output reg uart_we,
    output reg [ADDR_WIDTH-1:0] uart_addr,
    input      [DATA_WIDTH-1:0] uart_data_out,
    output reg [DATA_WIDTH-1:0] uart_data_in,
    input uart_ack,

    // 中断接口
    input uart_int,
    output reg int_ack
);

    // 内部状态寄存器
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] data_buffer;
    reg [ADDR_WIDTH-1:0] addr_buffer;
    reg [NODE_ID_WIDTH-1:0] src_buffer;
    reg we_buffer;

    // 判断是否为本节点数据
    wire is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // 中断状态
    reg int_pending;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            uart_req <= 1'b0;
            int_pending <= 1'b0;
            int_ack <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    uart_req <= 1'b0;
                    int_ack <= 1'b0;

                    if (int_pending) begin
                        // 有中断待处理，发送中断消息
                        state <= `STATE_ARB;
                        ring_out_valid <= 1'b1;
                        ring_out_src <= node_id;
                        ring_out_dest <= 0; // 发送给主控制器
                        ring_out_addr <= `REG_IIR;
                        ring_out_data <= {DATA_WIDTH{1'b1}}; // 中断标识
                        ring_out_we <= 1'b1;
                        int_pending <= 1'b0;
                    end else if (ring_in_valid) begin
                        // 处理环上数据
                        ring_out_valid <= ring_in_valid;
                        ring_out_src <= ring_in_src;
                        ring_out_dest <= ring_in_dest;
                        ring_out_addr <= ring_in_addr;
                        ring_out_data <= ring_in_data;
                        ring_out_we <= ring_in_we;
                        ring_out_be <= ring_in_be;

                        if (is_for_me) begin
                            // 数据是发给本节点的UART
                            state <= `STATE_DATA;
                            uart_req <= 1'b1;
                            uart_addr <= ring_in_addr;
                            uart_data_in <= ring_in_data;
                            uart_we <= ring_in_we;

                            // 保存源信息以便回复
                            src_buffer <= ring_in_src;
                            we_buffer <= ring_in_we;
                            addr_buffer <= ring_in_addr;
                        end
                    end else begin
                        ring_out_valid <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    // UART数据处理状态
                    if (uart_ack) begin
                        uart_req <= 1'b0;

                        if (!we_buffer) begin
                            // 读操作完成，准备发送回复
                            data_buffer <= uart_data_out;
                            state <= `STATE_ARB;
                        end else begin
                            // 写操作完成，发送确认
                            ring_out_ack <= 1'b1;
                            state <= `STATE_IDLE;
                        end
                    end
                end

                `STATE_ARB: begin
                    // 仲裁状态，等待机会发送回复
                    if (!ring_in_valid) begin
                        // 环空闲，可以发送回复
                        ring_out_valid <= 1'b1;
                        ring_out_src <= node_id;
                        ring_out_dest <= src_buffer;  // 回复给请求者
                        ring_out_addr <= addr_buffer;
                        ring_out_data <= data_buffer;
                        ring_out_we <= 1'b0;  // 表示这是读回复
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

            // 检测中断
            if (uart_int && !int_pending) begin
                int_pending <= 1'b1;
            end
        end
    end

endmodule