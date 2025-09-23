// csr_registers.v
module csr_registers (
    input wire clk,
    input wire rst_n,

    // CSR读写接口
    input wire [11:0] csr_addr,
    input wire [31:0] csr_wdata,
    input wire csr_we,
    output reg [31:0] csr_rdata,

    // 异常/中断信号
    input wire exception_valid,
    input wire [3:0] exception_cause,
    input wire [31:0] exception_pc,
    input wire [31:0] exception_tval,

    // 中断信号
    input wire ext_interrupt,
    input wire timer_interrupt,
    input wire soft_interrupt,

    // 控制信号
    input wire mret_exec,
    output wire global_int_enable,
    output wire [31:0] mtvec_addr,
    output wire [31:0] mepc_addr,
    output wire [31:0] mstatus_val
);

    // CSR地址定义
    localparam MSTATUS  = 12'h300;
    localparam MIE      = 12'h304;
    localparam MTVEC    = 12'h305;
    localparam MEPC     = 12'h341;
    localparam MCAUSE   = 12'h342;
    localparam MTVAL    = 12'h343;
    localparam MIP      = 12'h344;

    // 异常原因码
    localparam CAUSE_INST_MISALIGN  = 4'h0;
    localparam CAUSE_INST_ACCESS    = 4'h1;
    localparam CAUSE_ILLEGAL_INST   = 4'h2;
    localparam CAUSE_BREAKPOINT     = 4'h3;
    localparam CAUSE_LOAD_MISALIGN  = 4'h4;
    localparam CAUSE_LOAD_ACCESS    = 4'h5;
    localparam CAUSE_STORE_MISALIGN = 4'h6;
    localparam CAUSE_STORE_ACCESS   = 4'h7;
    localparam CAUSE_ECALL_U        = 4'h8;
    localparam CAUSE_ECALL_M        = 4'hB;

    // 中断原因码
    localparam CAUSE_MSOFT_INT      = 4'h3;
    localparam CAUSE_MTIMER_INT     = 4'h7;
    localparam CAUSE_MEXT_INT       = 4'hB;

    // CSR寄存器
    reg [31:0] mstatus;   // 机器状态寄存器
    reg [31:0] mie;       // 机器中断使能寄存器
    reg [31:0] mtvec;     // 机器陷阱向量基地址
    reg [31:0] mepc;      // 机器异常程序计数器
    reg [31:0] mcause;    // 机器异常原因
    reg [31:0] mtval;     // 机器陷阱值
    reg [31:0] mip;       // 机器中断等待寄存器

    // 输出连线
    assign global_int_enable = mstatus[3];  // MIE位
    assign mtvec_addr = {mtvec[31:2], 2'b00};
    assign mepc_addr = mepc;
    assign mstatus_val = mstatus;

    // CSR读操作
    always @(*) begin
        case (csr_addr)
            MSTATUS: csr_rdata = mstatus;
            MIE:     csr_rdata = mie;
            MTVEC:   csr_rdata = mtvec;
            MEPC:    csr_rdata = mepc;
            MCAUSE:  csr_rdata = mcause;
            MTVAL:   csr_rdata = mtval;
            MIP:     csr_rdata = mip;
            default: csr_rdata = 32'h0;
        endcase
    end

    // CSR写操作和异常处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'h0;
            mie <= 32'h0;
            mtvec <= 32'h00000100;  // 陷阱向量基地址设为0x100
            mepc <= 32'h0;
            mcause <= 32'h0;
            mtval <= 32'h0;
            mip <= 32'h0;
        end else begin
            // 更新中断等待寄存器
            mip[3] <= soft_interrupt;   // MSIP
            mip[7] <= timer_interrupt;  // MTIP
            mip[11] <= ext_interrupt;   // MEIP

            // 处理MRET指令
            if (mret_exec) begin
                mstatus[3] <= mstatus[7];  // 恢复MIE位
                mstatus[7] <= 1'b1;        // 设置MPIE
            end
            // 处理异常/中断
            else if (exception_valid) begin
                mepc <= exception_pc;
                mcause <= {28'h0, exception_cause};
                mtval <= exception_tval;

                // 更新mstatus
                mstatus[3] <= 1'b0;        // 禁用中断(MIE=0)
                mstatus[7] <= mstatus[3];  // 保存之前的MIE到MPIE
            end
            // 正常的CSR写操作
            else if (csr_we) begin
                case (csr_addr)
                    MSTATUS: mstatus <= csr_wdata;
                    MIE:     mie <= csr_wdata;
                    MTVEC:   mtvec <= {csr_wdata[31:2], 2'b00};
                    MEPC:    mepc <= {csr_wdata[31:2], 2'b00};
                    MCAUSE:  mcause <= csr_wdata;
                    MTVAL:   mtval <= csr_wdata;
                    MIP:     mip <= csr_wdata;
                endcase
            end
        end
    end

endmodule
