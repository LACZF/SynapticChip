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
    integer file;
    reg [255:0] line;
    reg [7:0]  comment_char;
    integer status;
    integer count = 0;

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

        // 直接使用内置的测试指令来确保ROM能够提供有效指令
        // 以下指令将被直接加载到ROM中
        mem[0] = 32'h001000b3;  // ADDI x1 x0 1      // x1 = 1
        mem[1] = 32'h00200113;  // ADDI x2 x0 2      // x2 = 2
        mem[2] = 32'h00300193;  // ADDI x3 x0 3      // x3 = 3
        mem[3] = 32'h00400213;  // ADDI x4 x0 4      // x4 = 4
        mem[4] = 32'h00500293;  // ADDI x5 x0 5      // x5 = 5
        mem[5] = 32'h00208133;  // ADD x2 x1 x2      // x2 = x1 + x2 = 3
        mem[6] = 32'h403101b3;  // SUB x3 x2 x3      // x3 = x2 - x3 = 0
        mem[7] = 32'h00418233;  // MUL x4 x3 x4      // x4 = x3 * x4 = 0

        // 备用方案：尝试从文件读取指令
        file = $fopen(instr_file_var, "r");
        if (file) begin
            $display("Successfully opened instruction file");
            count = 0;
            while (!$feof(file) && count < MEM_SIZE) begin
                status = $fgets(line, file);
                if (status > 0) begin
                    // 跳过空行和注释行
                    if (line[0] != "//" && line != "" && count < MEM_SIZE) begin
                        // 尝试解析指令
                        if ($sscanf(line, "%h", mem[count])) begin
                            count = count + 1;
                        end else if ($sscanf(line, "%h //", mem[count])) begin
                            count = count + 1;
                        end
                    end
                end
            end
            $fclose(file);
        end else begin
            $display("Warning: Could not open instruction file %s, using default instructions", instr_file_var);
        end

        // 打印前几条指令用于调试
        $display("First few instructions loaded:");
        for (i = 0; i < 8; i = i + 1) begin
            $display("MEM[%0d] = 0x%h", i, mem[i]);
        end
    end

    // 从内存中读取指令 - 添加地址范围检查
    wire [ADDR_WIDTH-1:0] addr_index = addr[ADDR_WIDTH-1:2];
    wire addr_valid = (addr_index < MEM_SIZE);

    // 当地址有效时输出正常指令，否则输出NOP指令
    assign instr = addr_valid ? mem[addr_index] : {INSTR_WIDTH{1'b0}};

    // 添加调试信息
    always @(addr) begin
        if (addr_valid) begin
            // 只在请求有效时才显示调试信息，避免过度打印
            $display("ROM addr: 0x%h, index: %d, instr: 0x%h", addr, addr_index, instr);
        end else if (addr != 0) begin
            $display("WARNING: ROM address out of range: 0x%h, index: %d", addr, addr_index);
        end
    end

endmodule