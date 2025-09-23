// interrupt_controller.v
module interrupt_controller (
    input wire clk,
    input wire rst_n,

    // 中断源
    input wire ext_int,
    input wire timer_int,
    input wire soft_int,

    // CSR接口
    input wire global_int_enable,
    input wire [31:0] mie,
    input wire [31:0] mip,

    // 输出
    output reg interrupt_valid,
    output reg [3:0] interrupt_cause
);

    // 中断原因码
    localparam CAUSE_MSOFT_INT  = 4'h3;
    localparam CAUSE_MTIMER_INT = 4'h7;
    localparam CAUSE_MEXT_INT   = 4'hB;

    // 中断使能信号
    wire soft_int_enabled = mie[3] && mip[3];  // MSIE & MSIP
    wire timer_int_enabled = mie[7] && mip[7]; // MTIE & MTIP
    wire ext_int_enabled = mie[11] && mip[11]; // MEIE & MEIP

    // 中断优先级：外部中断 > 定时器中断 > 软件中断
    always @(*) begin
        interrupt_valid = 1'b0;
        interrupt_cause = 4'h0;

        if (global_int_enable) begin
            if (ext_int_enabled && ext_int) begin
                interrupt_valid = 1'b1;
                interrupt_cause = CAUSE_MEXT_INT;
            end else if (timer_int_enabled && timer_int) begin
                interrupt_valid = 1'b1;
                interrupt_cause = CAUSE_MTIMER_INT;
            end else if (soft_int_enabled && soft_int) begin
                interrupt_valid = 1'b1;
                interrupt_cause = CAUSE_MSOFT_INT;
            end
        end
    end

endmodule
