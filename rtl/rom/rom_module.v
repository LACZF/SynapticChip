// rom_module.v
// ROM模块实现

`include "rom_params.v"

module rom_module #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ROM_DEPTH = 2048
) (
    input clk,
    input rst_n,

    // 控制接口
    input req,
    input [ADDR_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg ack,

    // 初始化接口
    input init_req,
    input [ADDR_WIDTH-1:0] init_addr,
    input [DATA_WIDTH-1:0] init_data,
    output reg init_ack,

    // 状态输出
    output reg initialized
);

    // ROM存储阵列
    reg [DATA_WIDTH-1:0] memory [0:ROM_DEPTH-1];

    // 内部状态
    reg [1:0] state;

    // 初始化ROM
    initial begin
        // 可以在这里设置默认值
        // 例如：memory[0] = 32'h00000000;
    end

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ack <= 1'b0;
            init_ack <= 1'b0;
            data_out <= {DATA_WIDTH{1'b0}};
            initialized <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ack <= 1'b0;
                    init_ack <= 1'b0;

                    if (init_req) begin
                        // 初始化请求
                        memory[init_addr] <= init_data;
                        init_ack <= 1'b1;
                        state <= `STATE_ACK;
                    end else if (req) begin
                        // 读操作
                        data_out <= memory[addr];
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // 确认操作完成
                    if (init_req) begin
                        init_ack <= 1'b1;
                    end else begin
                        ack <= 1'b1;
                    end

                    // 检查是否所有地址都已初始化
                    if (init_addr == `ROM_DEPTH - 1 && init_req) begin
                        initialized <= 1'b1;
                    end

                    state <= `STATE_IDLE;
                end
            endcase
        end
    end

endmodule