// riscv_bus_interface.v
// RISC-V核心与Ring总线的接口单元

`include "riscv_core_params.v"

module riscv_bus_interface (
    input clk,
    input rst_n,

    // RISC-V核心接口
    input core_req,
    input [`ADDR_WIDTH-1:0] core_addr,
    input [`DATA_WIDTH-1:0] core_data_out,
    output reg [`DATA_WIDTH-1:0] core_data_in,
    output reg core_ack,
    input core_we,
    input [3:0] core_be,

    // Ring总线节点接口
    output reg ring_req,
    output reg [`NODE_ID_WIDTH-1:0] ring_dest,
    output reg [`ADDR_WIDTH-1:0] ring_addr,
    output reg [`DATA_WIDTH-1:0] ring_data_out,
    input [`DATA_WIDTH-1:0] ring_data_in,
    input ring_ack,
    input ring_we_ack
);

    // 地址解码
    wire is_memory = (core_addr >= `MEM_BASE && core_addr < `MEM_BASE + `MEM_SIZE);
    wire is_io = (core_addr >= `IO_BASE && core_addr < `IO_BASE + `IO_SIZE);

    // 确定目标节点
    always @(*) begin
        if (is_memory) begin
            ring_dest = 1; // 假设节点1是内存
        end else if (is_io) begin
            ring_dest = 2; // 假设节点2是IO设备
        end else begin
            ring_dest = 0; // 无效地址，发送到节点0（可能处理错误）
        end
    end

    // 状态机
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_req <= 0;
            core_ack <= 0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    core_ack <= 0;

                    if (core_req) begin
                        ring_req <= 1;
                        ring_addr <= core_addr;
                        ring_data_out <= core_data_out;
                        state <= `STATE_ARB;
                    end
                end

                `STATE_ARB: begin
                    // 等待总线仲裁
                    if (ring_ack) begin
                        state <= `STATE_DATA;
                    end
                end

                `STATE_DATA: begin
                    if (ring_we_ack) begin
                        // 写操作完成
                        ring_req <= 0;
                        core_ack <= 1;
                        state <= `STATE_IDLE;
                    end else if (!core_we) begin
                        // 读操作完成
                        core_data_in <= ring_data_in;
                        ring_req <= 0;
                        core_ack <= 1;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
