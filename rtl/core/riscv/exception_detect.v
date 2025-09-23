// exception_detect.v
module exception_detect (
    input wire [31:0] inst,
    input wire [31:0] pc,
    input wire [31:0] mem_addr,
    input wire mem_write,
    input wire mem_read,
    input wire inst_valid,
    input wire mem_access_valid,

    output reg exception_valid,
    output reg [3:0] exception_cause,
    output reg [31:0] exception_pc,
    output reg [31:0] exception_tval
);

    // 异常原因码
    localparam CAUSE_INST_MISALIGN  = 4'h0;
    localparam CAUSE_INST_ACCESS    = 4'h1;
    localparam CAUSE_ILLEGAL_INST   = 4'h2;
    localparam CAUSE_BREAKPOINT     = 4'h3;
    localparam CAUSE_LOAD_MISALIGN  = 4'h4;
    localparam CAUSE_LOAD_ACCESS    = 4'h5;
    localparam CAUSE_STORE_MISALIGN = 4'h6;
    localparam CAUSE_STORE_ACCESS   = 4'h7;
    localparam CAUSE_ECALL_M        = 4'hB;

    // 指令解码
    wire is_ecall = (inst == 32'h00000073);  // ECALL指令
    wire is_ebreak = (inst == 32'h00100073); // EBREAK指令

    // 地址对齐检查
    wire pc_misaligned = (pc[1:0] != 2'b00);
    wire mem_misaligned = mem_access_valid &&
                         ((mem_read && mem_addr[1:0] != 2'b00) ||
                          (mem_write && mem_addr[1:0] != 2'b00));

    always @(*) begin
        exception_valid = 1'b0;
        exception_cause = 4'h0;
        exception_pc = pc;
        exception_tval = 32'h0;

        // 指令地址不对齐
        if (inst_valid && pc_misaligned) begin
            exception_valid = 1'b1;
            exception_cause = CAUSE_INST_MISALIGN;
            exception_tval = pc;
        end
        // 非法指令
        else if (inst_valid && !is_ecall && !is_ebreak &&
                (inst[1:0] != 2'b11)) begin  // 简化检查
            exception_valid = 1'b1;
            exception_cause = CAUSE_ILLEGAL_INST;
            exception_tval = inst;
        end
        // ECALL指令
        else if (inst_valid && is_ecall) begin
            exception_valid = 1'b1;
            exception_cause = CAUSE_ECALL_M;
            exception_tval = 32'h0;
        end
        // EBREAK指令
        else if (inst_valid && is_ebreak) begin
            exception_valid = 1'b1;
            exception_cause = CAUSE_BREAKPOINT;
            exception_tval = pc;
        end
        // 内存访问不对齐
        else if (mem_access_valid && mem_misaligned) begin
            exception_valid = 1'b1;
            exception_cause = mem_write ? CAUSE_STORE_MISALIGN : CAUSE_LOAD_MISALIGN;
            exception_tval = mem_addr;
        end
    end

endmodule
