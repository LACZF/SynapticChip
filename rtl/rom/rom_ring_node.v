// rom_ring_node.v
// ROM的Ring总线节点接口

`include "rom_params.v"

module rom_ring_node #(
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

    // ROM接口
    output reg rom_req,
    output reg [ADDR_WIDTH-1:0] rom_addr,
    input [DATA_WIDTH-1:0] rom_data_out,
    input rom_ack,

    // 初始化接口
    output reg init_req,
    input init_done
);

    // 内部状态寄存器
    reg [1:0] state;
    reg [DATA_WIDTH-1:0] data_buffer;
    reg [ADDR_WIDTH-1:0] addr_buffer;
    reg [NODE_ID_WIDTH-1:0] src_buffer;

    // 判断是否为本节点数据
    wire is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            rom_req <= 1'b0;
            init_req <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    rom_req <= 1'b0;

                    if (!init_done) begin
                        // 初始化未完成，请求初始化
                        init_req <= 1'b1;
                        state <= `STATE_DATA;
                    end else if (ring_in_valid) begin
                        // 处理环上数据
                        ring_out_valid <= ring_in_valid;
                        ring_out_src <= ring_in_src;
                        ring_out_dest <= ring_in_dest;
                        ring_out_addr <= ring_in_addr;
                        ring_out_data <= ring_in_data;
                        ring_out_we <= ring_in_we;
                        ring_out_be <= ring_in_be;

                        if (is_for_me && !ring_in_we) begin
                            // 数据是发给本节点的ROM（读请求）
                            state <= `STATE_DATA;
                            rom_req <= 1'b1;
                            rom_addr <= ring_in_addr;

                            // 保存源信息以便回复
                            src_buffer <= ring_in_src;
                            addr_buffer <= ring_in_addr;
                        end else if (is_for_me && ring_in_we) begin
                            // ROM不支持写操作，忽略写请求
                            ring_out_ack <= 1'b1; // 确认但不执行
                        end
                    end else begin
                        ring_out_valid <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    if (init_req) begin
                        // 初始化请求已发送，等待初始化完成
                        if (init_done) begin
                            init_req <= 1'b0;
                            state <= `STATE_IDLE;
                        end
                    end else if (rom_ack) begin
                        // ROM读操作完成，准备发送回复
                        rom_req <= 1'b0;
                        data_buffer <= rom_data_out;
                        state <= `STATE_ARB;
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