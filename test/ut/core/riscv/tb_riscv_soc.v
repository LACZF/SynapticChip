// tb_riscv_soc.v
module tb_riscv_soc;

    reg clk;
    reg rst_n;
    reg ext_int;

    // 调试信号
    wire [31:0] debug_pc;
    wire [31:0] debug_instruction;
    wire [4:0] debug_state;
    // wire [31:0] debug_registers [0:31];

    // 外部存储器接口（未使用）
    wire [31:0] ext_mem_addr;
    wire [31:0] ext_mem_data_out;
    reg [31:0] ext_mem_data_in;
    wire ext_mem_we;
    wire ext_mem_re;
    reg ext_mem_ack;

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化SoC
    riscv_soc uut (
        .clk(clk),
        .rst_n(rst_n),
        .ext_int(ext_int),
        .debug_pc(debug_pc),
        .debug_instruction(debug_instruction),
        .debug_state(debug_state),
        // .debug_registers(debug_registers),
        .ext_mem_addr(ext_mem_addr),
        .ext_mem_data_out(ext_mem_data_out),
        .ext_mem_data_in(ext_mem_data_in),
        .ext_mem_we(ext_mem_we),
        .ext_mem_re(ext_mem_re),
        .ext_mem_ack(ext_mem_ack)
    );

    // 测试任务：单步执行
    task single_step;
        integer steps;
        begin
            steps = 10;  // 执行10个时钟周期
            repeat (steps) @(posedge clk);
        end
    endtask

    // 测试任务：触发中断
    task trigger_interrupt;
        input integer cycles;
        begin
            #(cycles * 10);
            ext_int = 1'b1;
            @(posedge clk);
            ext_int = 1'b0;
        end
    endtask

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        ext_int = 0;
        ext_mem_data_in = 32'h0;
        ext_mem_ack = 1'b0;

        // 创建VCD文件用于波形查看
        $dumpfile("riscv_soc.vcd");
        $dumpvars(0, tb_riscv_soc);

        $display("=== RISC-V SoC集成测试开始 ===");
        $display("时间: %t - 初始化完成", $time);

        // 复位
        #20;
        rst_n = 1;
        $display("时间: %t - 系统复位释放", $time);

        // 测试1: 基本指令执行
        $display("测试1: 基本指令执行测试");
        single_step(100);

        // 测试2: 中断测试
        $display("测试2: 外部中断测试");
        trigger_interrupt(50);
        single_step(50);

        // 测试3: 存储器访问测试
        $display("测试3: 存储器访问测试");
        single_step(200);

        // 测试4: 异常处理测试
        $display("测试4: 异常处理测试");
        // 通过调试接口监控异常状态
        single_step(100);

        // 测试5: 综合测试
        $display("测试5: 综合性能测试");
        single_step(1000);

        $display("=== SoC测试完成 ===");
        $display("最终PC: 0x%h", debug_pc);
        $display("当前指令: 0x%h", debug_instruction);
        $display("系统状态: %b", debug_state);

        // 显示关键寄存器值
        $display("寄存器状态:");
        // $display("x1 (ra): 0x%h", debug_registers[1]);
        // $display("x2 (sp): 0x%h", debug_registers[2]);
        // $display("x8 (s0): 0x%h", debug_registers[8]);
        // $display("x9 (s1): 0x%h", debug_registers[9]);

        $finish;
    end

    // 实时监控系统状态
    always @(posedge clk) begin
        if (debug_state[3]) begin  // 陷阱发生
            $display("时间: %t - 检测到陷阱，PC: 0x%h", $time, debug_pc);
        end

        if (debug_state[4]) begin  // 流水线暂停
            $display("时间: %t - 流水线暂停", $time);
        end

        // 每100个周期显示一次进度
        if ($time % 1000 == 0) begin
            $display("时间: %t - 执行中... PC: 0x%h", $time, debug_pc);
        end
    end

    // 监控存储器访问
    always @(posedge clk) begin
        if (uut.cpu_core.dmem_req && uut.cpu_core.dmem_we) begin
            $display("时间: %t - 存储器写: 地址=0x%h, 数据=0x%h",
                    $time, uut.cpu_core.dmem_addr, uut.cpu_core.dmem_data_out);
        end
    end

endmodule
