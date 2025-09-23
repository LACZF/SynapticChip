// memory_mapped_timer.v
module memory_mapped_timer (
    input wire clk,
    input wire rst_n,

    // 内存总线接口
    input wire [31:0] addr_i,
    input wire [31:0] data_i,
    input wire [3:0] write_mask_i,  // 字节写使能
    input wire read_enable_i,
    input wire write_enable_i,

    output reg [31:0] data_o,
    output reg ack_o,

    // 中断输出
    output wire timer_interrupt_o
);

    // 内存映射地址定义（符合RISC-V标准）
    localparam MTIME_LOW   = 32'h0200_4000;
    localparam MTIME_HIGH  = 32'h0200_4004;
    localparam MTIMECMP_LOW  = 32'h0200_4008;
    localparam MTIMECMP_HIGH = 32'h0200_400C;

    // 内部信号
    reg [63:0] mtime_reg;
    reg [63:0] mtimecmp_reg;
    reg ack_delay;

    wire [63:0] mtime_next = mtime_reg + 64'h1;
    wire timer_match = (mtime_reg >= mtimecmp_reg);

    // 中断输出
    assign timer_interrupt_o = timer_match;

    // 定时器计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime_reg <= 64'h0;
            mtimecmp_reg <= 64'hFFFF_FFFF_FFFF_FFFF;
            data_o <= 32'h0;
            ack_o <= 1'b0;
            ack_delay <= 1'b0;
        end else begin
            // 定时器自动递增
            mtime_reg <= mtime_next;

            // 响应延迟
            ack_o <= ack_delay;
            ack_delay <= 1'b0;

            // 写操作处理
            if (write_enable_i) begin
                case (addr_i)
                    MTIME_LOW: begin
                        if (write_mask_i[0]) mtime_reg[7:0]   <= data_i[7:0];
                        if (write_mask_i[1]) mtime_reg[15:8]  <= data_i[15:8];
                        if (write_mask_i[2]) mtime_reg[23:16] <= data_i[23:16];
                        if (write_mask_i[3]) mtime_reg[31:24] <= data_i[31:24];
                        ack_delay <= 1'b1;
                    end
                    MTIME_HIGH: begin
                        if (write_mask_i[0]) mtime_reg[39:32] <= data_i[7:0];
                        if (write_mask_i[1]) mtime_reg[47:40] <= data_i[15:8];
                        if (write_mask_i[2]) mtime_reg[55:48] <= data_i[23:16];
                        if (write_mask_i[3]) mtime_reg[63:56] <= data_i[31:24];
                        ack_delay <= 1'b1;
                    end
                    MTIMECMP_LOW: begin
                        if (write_mask_i[0]) mtimecmp_reg[7:0]   <= data_i[7:0];
                        if (write_mask_i[1]) mtimecmp_reg[15:8]  <= data_i[15:8];
                        if (write_mask_i[2]) mtimecmp_reg[23:16] <= data_i[23:16];
                        if (write_mask_i[3]) mtimecmp_reg[31:24] <= data_i[31:24];
                        ack_delay <= 1'b1;
                    end
                    MTIMECMP_HIGH: begin
                        if (write_mask_i[0]) mtimecmp_reg[39:32] <= data_i[7:0];
                        if (write_mask_i[1]) mtimecmp_reg[47:40] <= data_i[15:8];
                        if (write_mask_i[2]) mtimecmp_reg[55:48] <= data_i[23:16];
                        if (write_mask_i[3]) mtimecmp_reg[63:56] <= data_i[31:24];
                        ack_delay <= 1'b1;
                    end
                    default: begin
                        ack_delay <= 1'b1;  // 即使地址错误也响应
                    end
                endcase
            end

            // 读操作处理
            if (read_enable_i) begin
                case (addr_i)
                    MTIME_LOW: begin
                        data_o <= mtime_reg[31:0];
                        ack_delay <= 1'b1;
                    end
                    MTIME_HIGH: begin
                        data_o <= mtime_reg[63:32];
                        ack_delay <= 1'b1;
                    end
                    MTIMECMP_LOW: begin
                        data_o <= mtimecmp_reg[31:0];
                        ack_delay <= 1'b1;
                    end
                    MTIMECMP_HIGH: begin
                        data_o <= mtimecmp_reg[63:32];
                        ack_delay <= 1'b1;
                    end
                    default: begin
                        data_o <= 32'hDEAD_BEEF;  // 调试值
                        ack_delay <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
