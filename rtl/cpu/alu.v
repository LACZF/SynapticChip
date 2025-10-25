
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"
`include "riscv_isa.v"

module alu (
    input  wire                   clk,
    input  wire                   reset,
    input  wire [`WordDataBus]    id_insn_i,

    input  wire [`WordDataBus]    in0_i,
    input  wire [`WordDataBus]    in1_i,
    input  wire [`AluOpBus]       op_i,
    output reg  [`WordDataBus]    result_o,
    output reg                    overflow_o
);
    wire [`WordDataBus] base_out;
    wire base_of;
    wire [`WordDataBus] muldiv_out;

    // 实例化基本ALU模块（RV64I指令集）
    RV64I u_rv64i (
        .clk(clk),
        .reset(reset),
        .id_insn_i(id_insn_i),
        .in0_i(in0_i),
        .in1_i(in1_i),
        .op_i(op_i),
        .result_o(base_out),
        .overflow_o(base_of)
    );

    // 实例化乘除法ALU模块（RV64M指令集）
    `ifdef SUPPORT_RV64M
        RV64M u_rv64m (
            .clk(clk),
            .reset(reset),
            .id_insn_i(id_insn_i),
            .in0_i(in0_i),
            .in1_i(in1_i),
            .op_i(op_i),
            .result_o(muldiv_out)
        );
    `else
        // 如果不支持RV64M，将乘除输出设为0
        assign muldiv_out = 0;
    `endif

    // 根据操作码选择输出
    always @(*) begin
        `ifdef SUPPORT_RV64M
            case (op_i)
                // 选择乘除法操作的输出
                `ALU_OP_MUL, `ALU_OP_MULH, `ALU_OP_MULHSU, `ALU_OP_MULHU,
                `ALU_OP_DIV, `ALU_OP_DIVU: begin
                    result_o    = muldiv_out;
                    overflow_o  = `DISABLE;
                end
                // 其他操作使用基本ALU的输出
                default: begin
                    result_o    = base_out;
                    overflow_o  = base_of;
                end
            endcase
        `else
            // 如果不支持RV64M，始终使用基本ALU的输出
            result_o    = base_out;
            overflow_o  = base_of;
        `endif
    end

endmodule