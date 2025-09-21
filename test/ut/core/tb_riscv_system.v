// tb_riscv_system.v
// RISC-V系统测试平台

`include "riscv_core_params.v"
`timescale 1ns/1ps

module tb_riscv_system;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 内存接口
    wire [`ADDR_WIDTH-1:0] mem_addr;
    wire [`DATA_WIDTH-1:0] mem_data_out;
    reg [`DATA_WIDTH-1:0] mem_data_in;
    wire mem_we;
    wire [3:0] mem_be;
    reg mem_ack;

    // 内存模型
    reg [`DATA_WIDTH-1:0] memory [0:1023];

    // 实例化DUT
    riscv_system dut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_we(mem_we),
        .mem_be(mem_be),
        .mem_ack(mem_ack)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 内存访问处理
    always @(posedge clk) begin
        mem_ack <= 0;

        if (mem_we && mem_addr < 1024) begin
            // 写内存
            case (mem_be)
                4'b0001: memory[mem_addr[11:2]][7:0] <= mem_data_out[7:0];
                4'b0011: memory[mem_addr[11:2]][15:0] <= mem_data_out[15:0];
                4'b1111: memory[mem_addr[11:2]] <= mem_data_out;
            endcase
            mem_ack <= 1;
        end else if (!mem_we && mem_addr < 1024) begin
            // 读内存
            mem_data_in <= memory[mem_addr[11:2]];
            mem_ack <= 1;
        end
    end

    // 主测试程序
    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        mem_ack = 0;

        // 初始化内存
        for (integer i = 0; i < 1024; i = i + 1) begin
            memory[i] = 0;
        end

        // 复位
        #20 rst_n = 1;

        $display("Starting RISC-V System Test");

        // 运行一定周期
        #1000;

        // 检查结果
        $display("Test completed at time %0t", $time);
        $display("Register x1 value: %h", dut.core.reg_file[1]);
        $display("Register x2 value: %h", dut.core.reg_file[2]);

        // 检查内存中的结果
        $display("Memory[0]: %h", memory[0]);
        $display("Memory[1]: %h", memory[1]);

        $display("Test finished");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("riscv_system.vcd");
        $dumpvars(0, tb_riscv_system);
    end

endmodule
