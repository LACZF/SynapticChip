// riscv_timer.v
module riscv_timer (
    input wire clk,
    input wire rst_n,

    // 内存总线接口
    input wire [31:0] bus_addr_i,
    input wire [31:0] bus_data_i,
    input wire [3:0] bus_sel_i,
    input wire bus_we_i,
    input wire bus_re_i,

    output reg [31:0] bus_data_o,
    output reg bus_ack_o,

    // CSR接口
    input wire [31:0] csr_addr_i,
    input wire [31:0] csr_data_i,
    input wire csr_we_i,
    input wire [2:0] csr_op_i,

    output reg [31:0] csr_data_o,
    output reg csr_ack_o,

    // 中断输出
    output wire timer_interrupt_o,

    // 配置
    input wire use_memory_map  // 1=使用内存映射，0=使用CSR
);

    // 内部信号
    wire [31:0] mm_data_o;
    wire mm_ack_o;
    wire mm_interrupt;

    wire [31:0] csr_data_o_w;
    wire csr_ack_o_w;
    wire csr_interrupt;

    // 实例化内存映射定时器
    memory_mapped_timer mm_timer (
        .clk(clk),
        .rst_n(rst_n),
        .addr_i(bus_addr_i),
        .data_i(bus_data_i),
        .write_mask_i(bus_sel_i),
        .read_enable_i(bus_re_i),
        .write_enable_i(bus_we_i),
        .data_o(mm_data_o),
        .ack_o(mm_ack_o),
        .timer_interrupt_o(mm_interrupt)
    );

    // 实例化CSR定时器
    csr_timer csr_timer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .csr_addr_i(csr_addr_i),
        .csr_data_i(csr_data_i),
        .csr_we_i(csr_we_i),
        .csr_op_i(csr_op_i),
        .csr_data_o(csr_data_o_w),
        .csr_ack_o(csr_ack_o_w),
        .timer_int_o(csr_interrupt)
    );

    // 输出选择
    always @(*) begin
        if (use_memory_map) begin
            bus_data_o = mm_data_o;
            bus_ack_o = mm_ack_o;
            csr_data_o = 32'h0;
            csr_ack_o = 1'b0;
        end else begin
            bus_data_o = 32'h0;
            bus_ack_o = 1'b0;
            csr_data_o = csr_data_o_w;
            csr_ack_o = csr_ack_o_w;
        end
    end

    assign timer_interrupt_o = use_memory_map ? mm_interrupt : csr_interrupt;

endmodule
