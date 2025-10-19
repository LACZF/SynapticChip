// riscv64_privileged_execution.v
// 特权指令执行模块
`include "riscv64_instruction_defs.v"

module riscv64_privileged_execution #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64,
    parameter ENABLE_HV_EXT     = 1
)(
    input wire                  clk,
    input wire                  rst_n,
    input wire [63:0]           pc_in_i,
    input wire [31:0]           instr_in_i,
    input wire [63:0]           rs1_data_i,
    input wire [63:0]           rs2_data_i,
    input wire [63:0]           imm_i,
    input wire [15:0]           ctrl_in_i,
    output wire [63:0]          alu_result_o,
    output wire                 branch_taken_o,
    output wire [63:0]          branch_target_o,
    output wire                 is_privileged_instr // 标识是否为特权指令
);

    // 信号定义
    wire [2:0]  alu_op      = ctrl_in_i[14:12];
    wire [2:0]  funct3      = instr_in_i[14:12];
    wire        funct7_30   = instr_in_i[30];
    wire [6:0]  opcode      = instr_in_i[6:0];

    // 提取指令中的寄存器地址
    wire [4:0]  rs1_addr_i = instr_in_i[19:15];
    wire [4:0]  rs2_addr_i = instr_in_i[24:20];
    wire [4:0]  rd_addr_i = instr_in_i[11:7];
    wire [11:0] csr_addr_i = instr_in_i[31:20]; // CSR地址在指令的31:20位

    // HV扩展模块输出信号
    wire [63:0] hv_result;
    wire        is_hv_extension;

    // 扩展模块使能信号（根据参数配置）
    wire enable_hv_ext = ENABLE_HV_EXT;

    // 条件实例化HV扩展模块
    generate
        if (ENABLE_HV_EXT)
            riscv64_hv_extension #(
                .DATA_WIDTH(DATA_WIDTH)
            ) u_hv_extension (
                .clk(clk),
                .rst_n(rst_n), // 注意：需要从顶层传入rst_n信号
                .pc_in_i(pc_in_i),
                .instr_in_i(instr_in_i),
                .rs1_data_i(rs1_data_i),
                .rs2_data_i(rs2_data_i),
                .imm_i(imm_i),
                .rs1_addr_i(rs1_addr_i),
                .rs2_addr_i(rs2_addr_i),
                .rd_addr_i(rd_addr_i),
                .csr_addr_i(csr_addr_i),
                .alu_result_o(hv_result),
                .is_hv_extension(is_hv_extension)
            );
        else begin
            assign hv_result = 64'b0;
            assign is_hv_extension = 1'b0;
        end
    endgenerate

    // 特权指令判断逻辑
    assign is_privileged_instr = is_hv_extension;

    // 结果选择逻辑（考虑使能参数）
    assign alu_result_o = is_hv_extension ? hv_result : 64'b0;

    // 分支结果选择
    assign branch_taken_o = 1'b0; // HV扩展目前不涉及分支指令
    assign branch_target_o = 64'b0;

    // 特权指令处理框架
    // 未来可以在此处添加具体的特权指令处理逻辑，如：
    // - ECALL/EBREAK 指令处理
    // - MRET/SRET/URET 指令处理
    // - SFENCE.VMA 指令处理
    // - CSR读写指令的特权级检查

`ifdef DEBUG
    always @(posedge clk) begin
        if (is_privileged_instr) begin
            $display("[%0t ps] PRIV: Processing privileged instruction: %h", $time, instr_in_i);
        end
    end
`endif

endmodule