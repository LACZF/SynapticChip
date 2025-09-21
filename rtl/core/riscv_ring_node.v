// riscv_ring_node.v
// Ring总线节点，支持RISC-V核心

`include "riscv_core_params.v"

module riscv_ring_node (
    input clk,
    input rst_n,
    input [`NODE_ID_WIDTH-1:0] node_id,

    // 本地核心接口
    input local_req,
    input [`ADDR_WIDTH-1:0] local_addr,
    input [`DATA_WIDTH-1:0] local_data_out,
    output reg [`DATA_WIDTH-1:0] local_data_in,
    output reg local_ack,
    input local_we,
    input [3:0] local_be,

    // Ring接口 - 输入
    input ring_in_valid,
    input [`NODE_ID_WIDTH-1:0] ring_in_src,
    input [`NODE_ID_WIDTH-1:0] ring_in_dest,
    input [`ADDR_WIDTH-1:0] ring_in_addr,
    input [`DATA_WIDTH-1:0] ring_in_data,
    input ring_in_we,
    input [3:0] ring_in_be,
    input ring_in_ack,

    // Ring接口 - 输出
    output reg ring_out_valid,
    output reg [`NODE_ID_WIDTH-1:0] ring_out_src,
    output reg [`NODE_ID_WIDTH-1:0] ring_out_dest,
    output reg [`ADDR_WIDTH-1:0] ring_out_addr,
    output reg [`DATA_WIDTH-1:0] ring_out_data,
    output reg ring_out_we,
    output reg [3:0] ring_out_be,
    output reg ring_out_ack,

    // 本地内存/设备接口
    output reg mem_req,
    output reg [`ADDR_WIDTH-1:0] mem_addr,
    output reg [`DATA_WIDTH-1:0] mem_data_out,
    input [`DATA_WIDTH-1:0] mem_data_in,
    output reg mem_we,
    output reg [3:0] mem_be,
    input mem_ack
);

    // 内部状态寄存器
    reg [1:0] state;
    reg [`DATA_WIDTH-1:0] data_buffer;
    reg [`ADDR_WIDTH-1:0] addr_buffer;
    reg [`NODE_ID_WIDTH-1:0] dest_buffer;
    reg we_buffer;
    reg [3:0] be_buffer;

    // 判断是否为本节点数据
    wire is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            local_ack <= 1'b0;
            mem_req <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    local_ack <= 1'b0;
                    ring_out_ack <= 1'b0;
                    mem_req <= 1'b0;

                    if (local_req) begin
                        // 本地请求，准备发送
                        state <= `STATE_ARB;
                        data_buffer <= local_data_out;
                        addr_buffer <= local_addr;
                        dest_buffer <= (local_addr >= `IO_BASE) ? 2 : 1; // 简单路由
                        we_buffer <= local_we;
                        be_buffer <= local_be;
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
                            // 数据是发给本节点的
                            state <= `STATE_DATA;
                            mem_req <= 1'b1;
                            mem_addr <= ring_in_addr;
                            mem_data_out <= ring_in_data;
                            mem_we <= ring_in_we;
                            mem_be <= ring_in_be;
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
                        ring_out_we <= we_buffer;
                        ring_out_be <= be_buffer;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_DATA: begin
                    // 数据处理状态
                    if (mem_ack) begin
                        mem_req <= 1'b0;
                        ring_out_ack <= 1'b1;
                        local_data_in <= mem_data_in;
                        local_ack <= 1'b1;
                        state <= `STATE_IDLE;
                    end
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
