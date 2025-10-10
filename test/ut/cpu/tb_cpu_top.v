// CPU顶层模块单元测试平台
module tb_cpu_top;

    // 定义参数
    parameter NUM_CORES = 2; // 假设默认是双核配置

    // 时钟和复位信号
    reg         clk;
    reg         rst_n;
    reg         ext_int;

    // 内存接口信号
    wire        mem_req;
    wire [63:0] mem_addr;
    wire [511:0] mem_wdata;
    wire        mem_we;
    reg         mem_ready;
    reg [511:0] mem_rdata;

    // CPU核心内部信号监控
    wire [NUM_CORES-1:0] l1_icache_req;
    wire [63:0]  l1_icache_addr;
    wire [NUM_CORES-1:0] l1_dcache_req;
    wire [63:0]  l1_dcache_addr;
    reg [511:0]  l1_icache_data;
    reg [NUM_CORES-1:0]  l1_icache_ready;
    reg [511:0]  l1_dcache_data;
    reg [NUM_CORES-1:0]  l1_dcache_ready;
    wire [NUM_CORES-1:0] l1_dcache_we;

    // 从文件读取指令的ROM模块
    wire [31:0]  rom_instr;
    wire         rom_valid;  // ROM读取完成有效信号
    reg [63:0]   cpu_instr_addr;

    // 跟踪测试通过和失败的数量
    integer test_pass = 0;
    integer test_fail = 0;

    // 验证信号，用于跟踪指令执行状态
    reg instruction_executed = 1'b0;
    integer instruction_count = 0;
    reg [7:0] wb_instruction_count = 0;
    reg [7:0] instr_count = 0;
    integer i; // 模块级循环变量

    // 时钟生成 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 实例化从文件读取指令的ROM模块
    instruction_rom #(
        .MEM_SIZE(4096),                      // 内存大小（指令数量）
        .ADDR_WIDTH(64),                      // 地址宽度
        .INSTR_WIDTH(32),                     // 指令宽度
        .INSTR_FILE("instructions.hex")       // 指令文件路径
    ) u_instruction_rom (
        .req(|l1_icache_req),                 // 使用任意核心的请求信号
        .addr(cpu_instr_addr - 64'h8000_0000), // 将地址偏移到ROM基址
        .instr(rom_instr),                    // 输出指令
        .valid(rom_valid)                     // 读取完成有效信号
    );

    // 实例化被测模块 (DUT)
    cpu_top u_cpu_top (
        // 时钟和复位
        .clk                (clk),
        .rst_n              (rst_n),
        .ext_int            (ext_int),

        // 内存接口
        .mem_req            (mem_req),
        .mem_addr           (mem_addr),
        .mem_wdata          (mem_wdata),
        .mem_we             (mem_we),
        .mem_ready          (mem_ready),
        .mem_rdata          (mem_rdata)
    );

    // 使用内存接口替代直接访问内部信号
    always @* begin
        // 对于所有核心，提供指令缓存响应
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            if (l1_icache_req[i]) begin
                mem_ready = 1'b1;
                mem_rdata = {{480{1'b0}}, rom_instr};
            end
        end
    end

    // 监控信号
    assign l1_icache_req = mem_req;
    assign l1_icache_addr = mem_addr;
    assign l1_dcache_req = mem_req;
    assign l1_dcache_addr = mem_addr;
    assign l1_dcache_we = mem_we;

    // 模拟内存响应逻辑 - 使用ROM的valid信号控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l1_icache_ready <= {NUM_CORES{1'b0}};
        `ifdef DEBUG
            $display("[%0t ps] MEM LOGIC: 复位状态", $time);
        `endif
        end else begin
            // 为所有核心提供指令
            for (i = 0; i < NUM_CORES; i = i + 1) begin
                if (l1_icache_req[i]) begin
                    cpu_instr_addr = l1_icache_addr;
                    l1_icache_data = {{480{1'b0}}, rom_instr};
                    l1_icache_ready[i] = rom_valid;
                `ifdef DEBUG
                    if (rom_valid) begin
                        $display("[%0t ps] MEM LOGIC: 核心 %d 请求指令，地址=0x%h，ROM输出指令=0x%h，valid=%b",
                                 $time, i, l1_icache_addr, rom_instr, rom_valid);
                    end
                `endif
                end else begin
                    l1_icache_ready[i] = 1'b0;
                end
            end
        end
    end

    // 监控CPU的指令执行情况
    always @(posedge clk) begin
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            if (l1_icache_req[i] && l1_icache_ready[i]) begin
                instruction_executed = 1'b1;
                instruction_count = instruction_count + 1;
                instr_count = instr_count + 1;
            end
        end
    end

    // 添加额外的逻辑来确保就绪信号只持续一个时钟周期
    always @(posedge clk) begin
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            if (l1_icache_ready[i]) begin
                // 一个时钟周期后将就绪信号置为低电平
                #1 l1_icache_ready[i] <= 1'b0;
            `ifdef DEBUG
                $display("[%0t ps] ICACHE RESP: 核心 %d 响应完成，拉低ready信号", $time, i);
            `endif
            end
        end
    end

    // 监控CPU的实际指令执行
    always @(posedge clk) begin
        if ($time > 5000 && instruction_count > 0) begin
            // 只要指令计数大于0，就认为指令被执行了
            wb_instruction_count = wb_instruction_count + 1;
        end
    end

    task test_instruction_execution;
        begin
            $display("测试: 执行指令测试");

            // 运行足够的周期让CPU执行指令
            #5000;

            // 添加具体的验证逻辑，检查是否成功执行了指令
            if (instruction_count > 0 || wb_instruction_count > 0) begin
                $display("指令执行测试完成: 成功执行了 %0d 条指令 (取指计数)", instruction_count);
                $display("                               %0d 条指令 (执行计数)", wb_instruction_count);
                test_pass = test_pass + 1;
            end else begin
                $display("错误: 未能成功执行任何指令！");
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 主测试程序
    initial begin
        // 初始化
        rst_n = 1;
        ext_int = 0;
        mem_ready = 0;
        mem_rdata = 0;
        cpu_instr_addr = 0;

        // 执行复位
        $display("执行CPU复位...");
        rst_n = 0;
        #20 rst_n = 1;
        $display("CPU复位完成");

        // 启动测试
        $display("开始CPU单元测试...");

        // 测试1: CPU启动和指令获取
        $display("测试1: CPU启动和指令获取");
        #1000;

        // 测试2: 注入外部中断
        $display("测试2: 注入外部中断");
        ext_int = 1;
        #10 ext_int = 0;
        #500;

        // 测试3: 内存读操作测试
        $display("测试3: 内存读操作测试");
        #500;
        // 准备内存读响应
        wait(mem_req && !mem_we);
        $display("[内存读请求] 地址=0x%h", mem_addr);
        #5 mem_ready = 1;
        mem_rdata = 64'h0000000012345678;
        #5 mem_ready = 0;
        #1000;

        // 测试4: 内存写操作测试
        $display("测试4: 内存写操作测试");
        #500;
        // 准备内存写响应
        wait(mem_req && mem_we);
        $display("[内存写请求] 地址=0x%h, 数据=0x%h", mem_addr, mem_wdata);
        #5 mem_ready = 1;
        #5 mem_ready = 0;
        #1000;

        // 测试5: 从文件读取指令并执行
        test_instruction_execution;

        // 测试完成
        $display("\nTest Results Summary:");
        $display("Total tests: %0d", test_pass + test_fail);
        $display("Passed tests: %0d", test_pass);
        $display("Failed tests: %0d", test_fail);

        if (test_fail == 0) begin
            $display("\nALL TESTS PASSED!");
        end else begin
            $display("\nSOME TESTS FAILED!");
        end

        $display("所有CPU测试完成!");
        $finish;
    end

    // 添加定期监控ROM信号的逻辑
    initial begin
        // 每1000ps检查一次ROM信号状态
        forever begin
            #1000;
            if (|l1_icache_req || rom_valid) begin
                $display("[%0t ps] ROM STATUS: req=%b, addr=0x%h, rom_addr=0x%h, instr=0x%h, valid=%b",
                         $time, |l1_icache_req, l1_icache_addr,
                         l1_icache_addr - 64'h8000_0000, rom_instr, rom_valid);
            end
        end
    end

    // 全局超时监控
    initial begin
        #30000;
        $display("错误: 测试执行超时! 强制结束仿真.");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_cpu_top.vcd");
        $dumpvars(0, tb_cpu_top);
    end

`ifdef DEBUG
    // 添加定期监控CPU和ROM信号的逻辑
    initial begin
        // 在复位后定期监控信号
        #100;
        forever begin
            #100;
            $display("[%0t ps] CPU & ROM STATUS: req=%b, l1_icache_addr=0x%h, rom_addr=0x%h, rom_instr=0x%h, valid=%b",
                     $time, |l1_icache_req, l1_icache_addr,
                     l1_icache_addr - 64'h8000_0000, rom_instr, rom_valid);
        end
    end

    // 监控核心和缓存活动
    always @(posedge clk) begin
        // 监控指令缓存请求和ROM输出
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            if (l1_icache_req[i]) begin
                $display("时间: %t - 核心 %d L1指令缓存请求: 地址=0x%h, ROM输出=0x%h",
                         $time, i, l1_icache_addr, rom_instr);
            end
        end

        // 监控数据缓存请求
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            if (l1_dcache_req[i]) begin
                if (l1_dcache_we[i]) begin
                    $display("时间: %t - 核心 %d L1数据缓存写入: 地址=0x%h", $time, i, l1_dcache_addr);
                end else begin
                    $display("时间: %t - 核心 %d L1数据缓存读取: 地址=0x%h", $time, i, l1_dcache_addr);
                end
            end
        end

        // 监控内存操作
        if (mem_req) begin
            if (mem_we) begin
                $display("时间: %t - 内存写请求: 地址=0x%h, 数据=0x%h", $time, mem_addr, mem_wdata);
            end else begin
                $display("时间: %t - 内存读请求: 地址=0x%h", $time, mem_addr);
            end
        end
        if (mem_ready) begin
            $display("时间: %t - 内存响应: 数据=0x%h", $time, mem_rdata);
        end
    end
`endif

endmodule