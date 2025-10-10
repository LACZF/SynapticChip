`timescale 1ns/1ps

// 从文件读取指令的ROM模块 - 带req和valid信号控制
module instruction_rom #(
    parameter MEM_SIZE = 4096,          // 内存大小（指令数量）
    parameter ADDR_WIDTH = 64,          // 地址宽度
    parameter INSTR_WIDTH = 32,         // 指令宽度
    parameter INSTR_FILE = "instructions.hex" // 指令文件路径
) (
    input wire                   req,   // 指令请求信号
    input wire [ADDR_WIDTH-1:0]  addr,  // 指令地址
    output wire [INSTR_WIDTH-1:0] instr, // 输出指令
    output wire                  valid  // 读取完成有效信号
);

    // 指令内存数组
    reg [INSTR_WIDTH-1:0] mem[0:MEM_SIZE-1];
    integer i;

    // 初始化内存，从文件读取指令
    initial begin
        $readmemh(INSTR_FILE, mem);

        $display("First few instructions loaded:");
        for (i = 0; i < 128; i = i + 1) begin
            $display("MEM[%0d] = 0x%h", i, mem[i]);
        end
    end

    // 从内存中读取指令 - 添加地址范围检查和请求控制
    wire [ADDR_WIDTH-1:0] addr_index = addr[ADDR_WIDTH-1:2];
    wire addr_valid = (addr_index < MEM_SIZE);

    // 当请求有效且地址有效时，设置valid信号并输出正常指令
    // 否则输出NOP指令且valid信号无效
    assign valid = req && addr_valid;
    assign instr = (req && addr_valid) ? mem[addr_index] : {INSTR_WIDTH{1'b0}};

    // 添加调试信息 - 只在有请求时显示
    always @(posedge req) begin
        if (addr_valid) begin
            $display("[%0t ps] ROM: 收到请求，地址=0x%h, 索引=%d, 指令=0x%h",
                     $time, addr, addr_index, mem[addr_index]);
        end else begin
            $display("[%0t ps] WARNING: ROM 地址超出范围: 0x%h, 索引=%d",
                     $time, addr, addr_index);
        end
    end

endmodule