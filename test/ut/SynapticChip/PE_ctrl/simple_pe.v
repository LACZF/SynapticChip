// simple_pe.v
// 简化的PE模块用于测试

`include "pe_ctrl_params.v"

module simple_pe (
    input clk,
    input rst_n,
    input enable,
    input [`INST_WIDTH-1:0] instruction,
    input inst_valid,

    // 邻居通信接口
    input north_valid,
    input [`DATA_WIDTH-1:0] north_data,
    output north_ready,

    input south_valid,
    input [`DATA_WIDTH-1:0] south_data,
    output south_ready,

    input east_valid,
    input [`DATA_WIDTH-1:0] east_data,
    output east_ready,

    input west_valid,
    input [`DATA_WIDTH-1:0] west_data,
    output west_ready,

    // 路由配置
    input [`PE_ID_WIDTH-1:0] north_route,
    input [`PE_ID_WIDTH-1:0] south_route,
    input [`PE_ID_WIDTH-1:0] east_route,
    input [`PE_ID_WIDTH-1:0] west_route,

    // 输出
    output reg [`DATA_WIDTH-1:0] data_out,
    output reg out_valid,
    output reg busy,
    output reg [`DATA_WIDTH-1:0] status
);

    // 内部寄存器
    reg [`DATA_WIDTH-1:0] accumulator;
    reg [`INST_WIDTH-1:0] current_inst;

    // 指令解码
    wire [`OPCODE_WIDTH-1:0] opcode = current_inst[31:26];
    wire [`DATA_WIDTH-1:0] immediate = {{(`DATA_WIDTH-16){1'b0}}, current_inst[15:0]};

    // 状态机
    reg [1:0] state;
    parameter S_IDLE = 2'b00;
    parameter S_EXECUTE = 2'b01;
    parameter S_COMM = 2'b10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            accumulator <= 0;
            data_out <= 0;
            out_valid <= 0;
            busy <= 0;
            status <= 0;
        end else if (enable) begin
            case (state)
                S_IDLE: begin
                    out_valid <= 0;
                    busy <= 0;

                    if (inst_valid) begin
                        current_inst <= instruction;
                        state <= S_EXECUTE;
                        busy <= 1;
                    end
                end

                S_EXECUTE: begin
                    case (opcode)
                        `OP_NOP: begin
                            // 无操作
                            state <= S_IDLE;
                        end

                        `OP_CFG_PE: begin
                            // 配置操作，这里简化处理
                            accumulator <= immediate;
                            state <= S_IDLE;
                        end

                        default: begin
                            // 其他操作
                            data_out <= accumulator;
                            out_valid <= 1;
                            state <= S_IDLE;
                        end
                    endcase
                end

                S_COMM: begin
                    // 通信状态，简化处理
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // 通信接口，简化处理
    assign north_ready = 1'b1;
    assign south_ready = 1'b1;
    assign east_ready = 1'b1;
    assign west_ready = 1'b1;

    // 状态更新
    always @(posedge clk) begin
        status <= {accumulator[31:16], busy, out_valid, accumulator[13:0]};
    end

endmodule
