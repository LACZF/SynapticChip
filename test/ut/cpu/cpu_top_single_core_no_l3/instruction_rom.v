`timescale 1ns/1ps

// 从文件读取指令的ROM模块
module instruction_rom #(
    parameter MEM_SIZE = 4096,          // 内存大小（指令数量）
    parameter ADDR_WIDTH = 64,          // 地址宽度
    parameter INSTR_WIDTH = 32,         // 指令宽度
    parameter INSTR_FILE = "instructions.hex" // 指令文件路径
) (
    input wire [ADDR_WIDTH-1:0] addr,   // 指令地址
    output wire [INSTR_WIDTH-1:0] instr // 输出指令
);

    // 指令内存数组
    reg [INSTR_WIDTH-1:0] mem[0:MEM_SIZE-1];
    integer i;
    reg [255:0] instr_file_var;  // 用于存储从命令行参数读取的文件名

    // 初始化内存，从文件读取指令
    initial begin
        // 设置默认文件名
        instr_file_var = INSTR_FILE;
        $display("Loading instructions from %0s...", instr_file_var);
        // 尝试从文件读取指令文件名
        if ($value$plusargs("instr_file=%s", instr_file_var)) begin
            $display("Using custom instruction file: %0s", instr_file_var);
        end

        // 初始化所有内存位置为NOP指令
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = {INSTR_WIDTH{1'b0}};  // 默认值（NOP指令）
        end

        // 从文件读取指令到内存
        $readmemh(instr_file_var, mem);

        // 打印前几条指令用于调试
        $display("First few instructions loaded:");
        for (i = 0; i < 8; i = i + 1) begin
            $display("MEM[%0d] = 0x%h", i, mem[i]);
        end
    end

    // 从内存中读取指令
    assign instr = mem[addr[ADDR_WIDTH-1:2]];  // 假设指令是按字对齐的，忽略低2位

endmodule