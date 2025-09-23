// csr_timer.v
module csr_timer (
    input wire clk,
    input wire rst_n,

    // CSR接口
    input wire [31:0] csr_addr_i,
    input wire [31:0] csr_data_i,
    input wire csr_we_i,
    input wire [2:0] csr_op_i,  // CSR操作类型

    output reg [31:0] csr_data_o,
    output reg csr_ack_o,

    // 中断输出
    output wire timer_int_o
);

    // CSR地址定义（自定义，符合RISC-V标准范围）
    localparam MTIME_LO    = 12'h7C0;
    localparam MTIME_HI    = 12'h7C1;
    localparam MTIMECMP_LO = 12'h7C2;
    localparam MTIMECMP_HI = 12'h7C3;
    localparam MTIMECTL    = 12'h7C4;  // 定时器控制寄存器

    // 控制寄存器位定义
    localparam CTL_ENABLE  = 0;  // 定时器使能
    localparam CTL_INTEN   = 1;  // 中断使能
    localparam CTL_MODE    = 2;  // 模式选择 [2:3]
    localparam CTL_PENDING = 4;  // 中断等待位

    // 内部寄存器
    reg [63:0] mtime_reg;
    reg [63:0] mtimecmp_reg;
    reg [7:0] control_reg;
    reg ack_delay;

    wire timer_enabled = control_reg[CTL_ENABLE];
    wire int_enabled = control_reg[CTL_INTEN];
    wire [1:0] timer_mode = control_reg[3:2];
    wire timer_match = (mtime_reg >= mtimecmp_reg) && timer_enabled;

    // 中断输出
    assign timer_int_o = timer_match && int_enabled;

    // CSR读操作
    always @(*) begin
        csr_data_o = 32'h0;
        case (csr_addr_i)
            MTIME_LO:    csr_data_o = mtime_reg[31:0];
            MTIME_HI:    csr_data_o = mtime_reg[63:32];
            MTIMECMP_LO: csr_data_o = mtimecmp_reg[31:0];
            MTIMECMP_HI: csr_data_o = mtimecmp_reg[63:32];
            MTIMECTL:    csr_data_o = {24'h0, control_reg};
            default:     csr_data_o = 32'h0;
        endcase
    end

    // CSR写操作和定时器逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime_reg <= 64'h0;
            mtimecmp_reg <= 64'hFFFF_FFFF_FFFF_FFFF;
            control_reg <= 8'h03;  // 默认使能定时器和中断
            csr_ack_o <= 1'b0;
            ack_delay <= 1'b0;
        end else begin
            // 定时器自动递增
            if (timer_enabled) begin
                mtime_reg <= mtime_reg + 64'h1;
            end

            // 响应延迟
            csr_ack_o <= ack_delay;
            ack_delay <= 1'b0;

            // 更新中断等待位
            control_reg[CTL_PENDING] <= timer_match && int_enabled;

            // CSR写操作
            if (csr_we_i) begin
                ack_delay <= 1'b1;
                case (csr_addr_i)
                    MTIME_LO: begin
                        mtime_reg[31:0] = apply_csr_op(mtime_reg[31:0], csr_data_i, csr_op_i);
                    end
                    MTIME_HI: begin
                        mtime_reg[63:32] = apply_csr_op(mtime_reg[63:32], csr_data_i, csr_op_i);
                    end
                    MTIMECMP_LO: begin
                        mtimecmp_reg[31:0] = apply_csr_op(mtimecmp_reg[31:0], csr_data_i, csr_op_i);
                    end
                    MTIMECMP_HI: begin
                        mtimecmp_reg[63:32] = apply_csr_op(mtimecmp_reg[63:32], csr_data_i, csr_op_i);
                    end
                    /* TODO */
                    // MTIMECTL: begin
                    //     control_reg = apply_csr_op({24'h0, control_reg}, csr_data_i, csr_op_i)[7:0];
                    // end
                endcase
            end else begin
                case (csr_addr_i)
                    MTIME_LO, MTIME_HI, MTIMECMP_LO, MTIMECMP_HI, MTIMECTL: begin
                        // CSR读操作确认
                        ack_delay <= 1'b1;
                    end
                endcase
            end
        end
    end

    // CSR操作函数
    function [31:0] apply_csr_op;
        input [31:0] original;
        input [31:0] new_val;
        input [2:0] op;
        begin
            case (op)
                3'b001: apply_csr_op = new_val;                    // CSRRW
                3'b010: apply_csr_op = original | new_val;         // CSRRS
                3'b011: apply_csr_op = original & ~new_val;        // CSRRC
                3'b101: apply_csr_op = new_val;                    // CSRRWI
                3'b110: apply_csr_op = original | new_val;         // CSRRSI
                3'b111: apply_csr_op = original & ~new_val;        // CSRRCI
                default: apply_csr_op = original;
            endcase
        end
    endfunction

endmodule