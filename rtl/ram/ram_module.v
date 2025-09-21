// ram_module.v
// RAM模块实现

`include "ram_params.v"

module ram_module (
    input clk,
    input rst_n,

    // 控制接口
    input req,
    input we,
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] data_in,
    input [3:0] be,  // 字节使能
    output reg [`DATA_WIDTH-1:0] data_out,
    output reg ack
);

    // RAM存储阵列
    reg [`DATA_WIDTH-1:0] memory [0:`RAM_DEPTH-1];

    // 内部状态
    reg [1:0] state;

    // 初始化RAM（可选）
    initial begin
        // 可以在这里初始化RAM内容
        // 例如：memory[0] = 32'h00000000;
    end

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ack <= 1'b0;
            data_out <= {`DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ack <= 1'b0;

                    if (req) begin
                        if (we) begin
                            // 写操作
                            if (be[0]) memory[addr][7:0]   <= data_in[7:0];
                            if (be[1]) memory[addr][15:8]  <= data_in[15:8];
                            if (be[2]) memory[addr][23:16] <= data_in[23:16];
                            if (be[3]) memory[addr][31:24] <= data_in[31:24];
                        end else begin
                            // 读操作
                            data_out <= memory[addr];
                        end

                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // 确认操作完成
                    ack <= 1'b1;
                    state <= `STATE_IDLE;
                end
            endcase
        end
    end

endmodule
