`include "riscv64_instruction_defs.v"

module riscv64_zifencei_extension #(
    parameter DATA_WIDTH = 64
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire [DATA_WIDTH-1:0]         pc_in_i,
    input  wire [31:0]                   instr_in_i,
    input  wire [15:0]                   ctrl_in_i,
    input  wire [2:0]                    funct3,
    input  wire [6:0]                    opcode,
    output wire                          is_zifencei_extension
);

    // 判断是否为Zifencei扩展指令
    assign is_zifencei_extension = (opcode == `FENCE_I_OPCODE) && (funct3 == `FENCE_I_FUNCT3);

    // FENCE.I指令处理逻辑
    // 注意：实际实现中可能需要与处理器的缓存控制单元交互
    // 此处仅提供基本框架，具体实现需根据处理器架构调整

    // DEBUG信息输出
    `ifdef DEBUG
        always @(posedge clk) begin
            if (is_zifencei_extension) begin
                $display("[Zifencei-Extension] Handling FENCE.I instruction");
            end
        end
    `endif

endmodule