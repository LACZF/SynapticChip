// boot_rom_init.v
// ROM初始化内容 - 启动代码
initial begin
    // 简单的启动代码：设置栈指针，跳转到主程序
    memory[0] = 32'h00000117;  // auipc sp, 0x0
    memory[1] = 32'hffc10113;  // addi sp, sp, -4
    memory[2] = 32'h00000517;  // auipc a0, 0x0
    memory[3] = 32'h01050513;  // addi a0, a0, 16
    memory[4] = 32'h00050067;  // jalr zero, a0, 0

    // 主程序入口（在Flash中）
    memory[5] = 32'h20000000;  // Flash中的主程序地址

    // 中断向量表（简化）
    memory[16] = 32'h00000013;  // nop (中断处理占位)
    memory[17] = 32'h00000013;  // nop
    memory[18] = 32'h00000013;  // nop
end
