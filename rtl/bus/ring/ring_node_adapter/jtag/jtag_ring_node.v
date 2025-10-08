// jtag_ring_node.v
// JTAG的Ring总线节点接口

`include "jtag_params.v"

module jtag_ring_node #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = `ADDR_WIDTH,
    parameter DATA_WIDTH        = `DATA_WIDTH,
    parameter NODE_ID_WIDTH     = `NODE_ID_WIDTH,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2
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

    // JTAG接口
    output reg jtag_req,
    output reg jtag_we,
    output reg [ADDR_WIDTH-1:0] jtag_addr,
    output reg [DATA_WIDTH-1:0] jtag_data_out,
    input [DATA_WIDTH-1:0] jtag_data_in,
    input jtag_ack,

    // 调试接口
    input [DATA_WIDTH-1:0] jtag_debug_data,
    input jtag_debug_valid
);

    // 内部状态寄存器
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] data_buffer;
    reg [ADDR_WIDTH-1:0] addr_buffer;
    reg [NODE_ID_WIDTH-1:0] src_buffer;
    reg we_buffer;

    // 判断是否为本节点数据
    wire is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            jtag_req <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    jtag_req <= 1'b0;

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
                            // 数据是发给本节点的JTAG
                            state <= `STATE_DATA;
                            jtag_req <= 1'b1;
                            jtag_addr <= ring_in_addr;
                            jtag_data_out <= ring_in_data;
                            jtag_we <= ring_in_we;

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
                    // JTAG数据处理状态
                    if (jtag_ack) begin
                        jtag_req <= 1'b0;

                        if (!we_buffer) begin
                            // 读操作完成，准备发送回复
                            data_buffer <= jtag_data_in;
                            state <= `STATE_ARB;
                        end else begin
                            // 写操作完成，发送确认
                            ring_out_ack <= 1'b1;
                            state <= `STATE_IDLE;
                        end
                    end

                    // 处理调试数据
                    if (jtag_debug_valid) begin
                        // 这里可以添加调试数据处理逻辑
                        // 例如，将调试数据发送到其他节点
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
        end
    end

endmodule
