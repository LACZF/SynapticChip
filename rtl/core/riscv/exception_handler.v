// exception_handler.v
module exception_handler (
    input wire clk,
    input wire rst_n,

    // 来自CPU的输入
    input wire [31:0] current_pc,
    input wire [31:0] inst,
    input wire [31:0] mem_addr,
    input wire mem_write,
    input wire mem_read,
    input wire inst_valid,
    input wire mem_access_valid,
    input wire mret_exec,

    // 中断输入
    input wire ext_int,
    input wire timer_int,
    input wire soft_int,

    // CSR接口
    output wire [11:0] csr_addr,
    output wire [31:0] csr_wdata,
    output wire csr_we,
    input wire [31:0] csr_rdata,

    // 输出到CPU
    output wire trap_taken,
    output wire [31:0] trap_handler_addr,
    output wire [31:0] return_addr
);

    // 内部信号
    wire exception_valid;
    wire [3:0] exception_cause;
    wire [31:0] exception_pc;
    wire [31:0] exception_tval;

    wire interrupt_valid;
    wire [3:0] interrupt_cause;

    wire global_int_enable;
    wire [31:0] mtvec_addr;
    wire [31:0] mepc_addr;
    wire [31:0] mstatus;

    // 陷阱类型选择
    wire trap_valid = exception_valid || interrupt_valid;
    wire [3:0] trap_cause = interrupt_valid ? interrupt_cause : exception_cause;
    wire [31:0] trap_pc = interrupt_valid ? current_pc : exception_pc;
    wire [31:0] trap_tval = interrupt_valid ? 32'h0 : exception_tval;

    // 模块实例化
    csr_registers csr (
        .clk(clk),
        .rst_n(rst_n),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_we(csr_we),
        .csr_rdata(csr_rdata),
        .exception_valid(trap_valid),
        .exception_cause(trap_cause),
        .exception_pc(trap_pc),
        .exception_tval(trap_tval),
        .ext_interrupt(ext_int),
        .timer_interrupt(timer_int),
        .soft_interrupt(soft_int),
        .mret_exec(mret_exec),
        .global_int_enable(global_int_enable),
        .mtvec_addr(mtvec_addr),
        .mepc_addr(mepc_addr),
        .mstatus_val(mstatus)
    );

    exception_detect exc_detect (
        .inst(inst),
        .pc(current_pc),
        .mem_addr(mem_addr),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .inst_valid(inst_valid),
        .mem_access_valid(mem_access_valid),
        .exception_valid(exception_valid),
        .exception_cause(exception_cause),
        .exception_pc(exception_pc),
        .exception_tval(exception_tval)
    );

    interrupt_controller int_controller (
        .clk(clk),
        .rst_n(rst_n),
        .ext_int(ext_int),
        .timer_int(timer_int),
        .soft_int(soft_int),
        .global_int_enable(global_int_enable),
        .mie(csr_rdata),  // 从CSR读取MIE
        .mip(csr_rdata),  // 从CSR读取MIP
        .interrupt_valid(interrupt_valid),
        .interrupt_cause(interrupt_cause)
    );

    // 陷阱处理地址生成
    assign trap_handler_addr = mtvec_addr;
    assign return_addr = mepc_addr;
    assign trap_taken = trap_valid;

    // CSR控制逻辑（简化）
    assign csr_addr = 12'h0;  // 实际中应根据指令解码
    assign csr_wdata = 32'h0;
    assign csr_we = 1'b0;

endmodule
