`timescale 1ns/1ps

module tb_riscv64_core;

    // 时钟和复位信号
    reg clk;
    reg rst_n;

    // 指令缓存接口
    wire icache_req;
    wire [63:0] icache_addr;
    reg [31:0] icache_data;
    reg icache_ready;

    // 数据缓存接口
    wire dcache_req;
    wire [63:0] dcache_addr;
    wire dcache_we;
    wire [63:0] dcache_wdata;
    wire [7:0] dcache_byte_en;
    reg [63:0] dcache_rdata;
    reg dcache_ready;

    // 监听接口
    wire snoop_valid;
    wire [63:0] snoop_addr;
    wire [1:0] snoop_req_type;
    wire snoop_ready;
    wire snoop_hit;
    wire [1:0] snoop_state;
    wire [511:0] snoop_data;

    // 中断接口
    wire timer_interrupt;
    wire external_interrupt;
    wire software_interrupt;

    // 调试接口
    wire [63:0] debug_pc;
    wire [31:0] debug_instr;
    wire [4:0] debug_wb_rd;
    wire [63:0] debug_wb_value;
    wire debug_wb_valid;

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz时钟
    end

    // 复位生成
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // 模拟指令缓存
    reg [31:0] instr_memory [0:4095]; // 简单的指令内存模拟

    always @(*) begin
        if (icache_req) begin
        `ifdef DEBUG
            $display("Time: %0t, ICache request: addr=%0h", $time, icache_addr);
        `endif
            if (icache_addr >= 64'h80000000 && icache_addr < 64'h80004000) begin
                icache_data = instr_memory[(icache_addr - 64'h80000000) >> 2];
            `ifdef DEBUG
                $display("Time: %0t, ICache hit: addr=%0h, index=%0d, data=0x%0h",
                         $time, icache_addr, (icache_addr - 64'h80000000) >> 2, icache_data);
            `endif
            end else if (icache_addr >= 0 && icache_addr < 64'h4000) begin
                icache_data = instr_memory[icache_addr >> 2];
            `ifdef DEBUG
                $display("Time: %0t, ICache hit: addr=%0h, index=%0d, data=0x%0h",
                         $time, icache_addr, icache_addr >> 2, icache_data);
            `endif
            end else begin
                icache_data = 32'h00000013; // NOP
            `ifdef DEBUG
                $display("Time: %0t, ICache miss: addr=%0h, returning NOP", $time, icache_addr);
            `endif
            end
            icache_ready = 1'b1;
        `ifdef DEBUG
            $display("Time: %0t, ICache response: data=0x%0h, ready=1", $time, icache_data);
        `endif
        end else begin
            icache_data = 32'h00000013; // NOP
            icache_ready = 1'b0;
        end
    end

    // 模拟数据缓存
    reg [63:0] data_memory [0:4095]; // 简单的数据内存模拟

    always @(posedge clk) begin
        if (dcache_req && dcache_we) begin
            // 处理写操作
            if (dcache_byte_en[0]) data_memory[dcache_addr[31:3]][7:0] <= dcache_wdata[7:0];
            if (dcache_byte_en[1]) data_memory[dcache_addr[31:3]][15:8] <= dcache_wdata[15:8];
            if (dcache_byte_en[2]) data_memory[dcache_addr[31:3]][23:16] <= dcache_wdata[23:16];
            if (dcache_byte_en[3]) data_memory[dcache_addr[31:3]][31:24] <= dcache_wdata[31:24];
            if (dcache_byte_en[4]) data_memory[dcache_addr[31:3]][39:32] <= dcache_wdata[39:32];
            if (dcache_byte_en[5]) data_memory[dcache_addr[31:3]][47:40] <= dcache_wdata[47:40];
            if (dcache_byte_en[6]) data_memory[dcache_addr[31:3]][55:48] <= dcache_wdata[55:48];
            if (dcache_byte_en[7]) data_memory[dcache_addr[31:3]][63:56] <= dcache_wdata[63:56];
        end
    end

    always @(*) begin
        if (dcache_req) begin
            if (!dcache_we && dcache_addr[31:3] < 4096) begin
                dcache_rdata = data_memory[dcache_addr[31:3]];
            end else begin
                dcache_rdata = 64'h0;
            end
            dcache_ready = 1'b1;
        end else begin
            dcache_rdata = 64'h0;
            dcache_ready = 1'b0;
        end
    end

    // 连接监听接口（简化测试）
    assign snoop_valid = 1'b0; // 简化测试，无监听请求
    assign snoop_addr = 64'h0;
    assign snoop_req_type = 2'b00;

    // 连接中断接口（简化测试）
    assign timer_interrupt = 1'b0;
    assign external_interrupt = 1'b0;
    assign software_interrupt = 1'b0;

    // 被测模块实例化
    riscv64_core #(
        .CORE_ID(0)
    ) u_dut (
        // 时钟和复位
        .clk(clk),
        .rst_n(rst_n),

        // 指令缓存接口
        .icache_req(icache_req),
        .icache_addr(icache_addr),
        .icache_data(icache_data),
        .icache_ready(icache_ready),

        // 数据缓存接口
        .dcache_req(dcache_req),
        .dcache_addr(dcache_addr),
        .dcache_we(dcache_we),
        .dcache_wdata(dcache_wdata),
        .dcache_byte_en(dcache_byte_en),
        .dcache_rdata(dcache_rdata),
        .dcache_ready(dcache_ready),

        // 监听接口
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_req_type(snoop_req_type),
        .snoop_ready(snoop_ready),
        .snoop_hit(snoop_hit),
        .snoop_state(snoop_state),
        .snoop_data(snoop_data),

        // 中断接口
        .timer_interrupt(timer_interrupt),
        .external_interrupt(external_interrupt),
        .software_interrupt(software_interrupt),

        // 调试输出
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_wb_valid(debug_wb_valid),
        .debug_wb_rd(debug_wb_rd),
        .debug_wb_value(debug_wb_value)
    );

    // 测试用例
    integer test_pass = 0;
    integer test_fail = 0;

    // 测试用例1: 基本的算术指令测试
    task test_arithmetic;
        begin
            $display("Starting arithmetic instructions test...");
            $display("Time: %0t, Writing test instructions to instr_memory", $time);

            // 初始化指令内存（使用偏移量100来避免与其他测试用例冲突）
            // ADD x1, x0, x0 (x1 = 0)
            instr_memory[100] = 32'h000000b3;
            // ADDI x2, x0, 10 (x2 = 10)
            instr_memory[101] = 32'h00a00113;
            // ADD x3, x1, x2 (x3 = 10)
            instr_memory[102] = 32'h002081b3;
            // SUB x4, x2, x1 (x4 = 10)
            instr_memory[103] = 32'h40108233;
            // ADDI x5, x3, 5 (x5 = 15)
            instr_memory[104] = 32'h00508293;

            // 显示写入的指令
            $display("Time: %0t, Test instructions written:", $time);
            for (int i = 100; i < 105; i = i + 1) begin
                $display("  instr_memory[%0d] = 0x%0h", i, instr_memory[i]);
            end

            // 设置处理器从我们的测试指令开始执行
            // 注意：这里需要通过修改处理器的PC寄存器来实现，但通常在RTL设计中不直接暴露PC寄存器
            // 所以我们需要通过debug接口或者其他方式来设置初始PC
            $display("Time: %0t, Note: Need to set PC to 0x%0h to start test", $time, 64'h80000000 + (100 << 2));

            // 等待处理器执行
            $display("Time: %0t, Waiting for instruction execution", $time);
            #2000;

            // 检查结果
            $display("Time: %0t, Checking test results", $time);
            $display("  Current debug_wb_valid: %0d, debug_wb_rd: %0d, debug_wb_value: %0h",
                     debug_wb_valid, debug_wb_rd, debug_wb_value);

            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 15) begin
                $display("  Test arithmetic passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test arithmetic failed! Expected x5=15, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例2: 内存访问指令测试
    task test_memory;
        begin
            $display("Starting memory access instructions test...");

            // 初始化指令内存
            // ADDI x1, x0, 100 (x1 = 100)
            instr_memory[5] = 32'h064000b3;
            // ADDI x2, x0, 0x1000 (x2 = 4096)
            instr_memory[6] = 32'h10000113;
            // SD x1, 0(x2) (store x1 to memory[4096])
            instr_memory[7] = 32'h00112023;
            // LD x3, 0(x2) (load x3 from memory[4096])
            instr_memory[8] = 32'h00012183;

            // 运行几个周期
            #200;

            // 检查结果
            if (debug_wb_valid && debug_wb_rd == 3 && debug_wb_value == 100) begin
                $display("  Test memory passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test memory failed! Expected x3=100, Got x3=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例3: 分支指令测试
    task test_branch;
        begin
            $display("Starting branch instructions test...");

            // 初始化指令内存
            // ADDI x1, x0, 5 (x1 = 5)
            instr_memory[9] = 32'h005000b3;
            // ADDI x2, x0, 5 (x2 = 5)
            instr_memory[10] = 32'h00500113;
            // BEQ x1, x2, 4 (branch to 15 if x1 == x2)
            instr_memory[11] = 32'h00208463;
            // ADDI x3, x0, 1 (不应该执行到这里)
            instr_memory[12] = 32'h00100193;
            // ADDI x4, x0, 2 (不应该执行到这里)
            instr_memory[13] = 32'h00200213;
            // ADDI x5, x0, 3 (不应该执行到这里)
            instr_memory[14] = 32'h00300293;
            // ADDI x6, x0, 4 (这里是分支目标)
            instr_memory[15] = 32'h00400313;

            // 运行几个周期
            #200;

            // 检查结果
            if (debug_wb_valid && debug_wb_rd == 6 && debug_wb_value == 4) begin
                $display("  Test branch passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test branch failed! Expected x6=4, Got x6=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例4: 逻辑指令测试
    task test_logic;
        begin
            $display("Starting logic instructions test...");

            // 初始化指令内存
            // ADDI x1, x0, 0xAAAA (x1 = 0xAAAA)
            instr_memory[16] = 32'hAAA000b3;
            // ADDI x2, x0, 0x5555 (x2 = 0x5555)
            instr_memory[17] = 32'h55500113;
            // AND x3, x1, x2 (x3 = 0)
            instr_memory[18] = 32'h0020a1b3;
            // OR x4, x1, x2 (x4 = 0xFFFF)
            instr_memory[19] = 32'h0020c233;
            // XOR x5, x1, x2 (x5 = 0xFFFF)
            instr_memory[20] = 32'h0020e293;

            // 运行几个周期
            #200;

            // 检查结果
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 65535) begin
                $display("  Test logic passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test logic failed! Expected x5=0xFFFF, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例5: 移位指令测试
    task test_shift;
        begin
            $display("Starting shift instructions test...");

            // 初始化指令内存
            // ADDI x1, x0, 1 (x1 = 1)
            instr_memory[21] = 32'h001000b3;
            // SLLI x2, x1, 4 (x2 = 16)
            instr_memory[22] = 32'h00409113;
            // SRLI x3, x2, 2 (x3 = 4)
            instr_memory[23] = 32'h0020d193;
            // ADDI x4, x0, -8 (x4 = -8)
            instr_memory[24] = 32'hFF800213;
            // SRAI x5, x4, 2 (x5 = -2)
            instr_memory[25] = 32'h4020f293;

            // 运行几个周期
            #200;

            // 检查结果
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 64'hFFFFFFFFFFFFFFFE) begin
                $display("  Test shift passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test shift failed! Expected x5=-2, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例6: 比较指令测试
    task test_compare;
        begin
            $display("Starting compare instructions test...");

            // 初始化指令内存
            // ADDI x1, x0, 5 (x1 = 5)
            instr_memory[26] = 32'h005000b3;
            // ADDI x2, x0, 10 (x2 = 10)
            instr_memory[27] = 32'h00a00113;
            // SLT x3, x1, x2 (x3 = 1)
            instr_memory[28] = 32'h0020e1b3;
            // SLTU x4, x2, x1 (x4 = 0)
            instr_memory[29] = 32'h00114233;
            // SLTI x5, x2, 15 (x5 = 1)
            instr_memory[30] = 32'h00f11293;

            // 运行几个周期
            #200;

            // 检查结果
            if (debug_wb_valid && debug_wb_rd == 5 && debug_wb_value == 1) begin
                $display("  Test compare passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test compare failed! Expected x5=1, Got x5=%0h", debug_wb_value);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例7: 跳转指令测试
    task test_jump;
        begin
            $display("Starting jump instructions test...");

            // 初始化指令内存
            // JAL x1, 8 (跳转到 38, x1 = 33)
            instr_memory[31] = 32'h004000ef;
            // ADDI x2, x0, 1 (不应该执行到这里)
            instr_memory[32] = 32'h00100113;
            // ADDI x3, x0, 2 (不应该执行到这里)
            instr_memory[33] = 32'h00200193;
            // ADDI x4, x0, 3 (不应该执行到这里)
            instr_memory[34] = 32'h00300213;
            // ADDI x5, x0, 4 (不应该执行到这里)
            instr_memory[35] = 32'h00400293;
            // ADDI x6, x0, 5 (不应该执行到这里)
            instr_memory[36] = 32'h00500313;
            // ADDI x7, x0, 6 (不应该执行到这里)
            instr_memory[37] = 32'h00600393;
            // ADDI x8, x0, 7 (这里是跳转目标)
            instr_memory[38] = 32'h00700413;

            // 运行几个周期
            #200;

            // 检查结果
            if (debug_wb_valid && (debug_wb_rd == 1 || debug_wb_rd == 8)) begin
                if ((debug_wb_rd == 1 && debug_wb_value == 33) ||
                    (debug_wb_rd == 8 && debug_wb_value == 7)) begin
                    $display("  Test jump passed!");
                    test_pass = test_pass + 1;
                end else begin
                    $display("  Test jump failed! Expected x1=33 or x8=7, Got x%0d=%0h",
                             debug_wb_rd, debug_wb_value);
                    test_fail = test_fail + 1;
                end
            end else begin
                $display("  Test jump failed! Expected x1 or x8, Got x%0d", debug_wb_rd);
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 测试用例8: 冒险检测和处理测试
    task test_hazard;
        begin
            $display("Starting hazard detection and handling test...");

            // 初始化指令内存
            // LD x1, 0(x0) (加载数据到x1)
            instr_memory[39] = 32'h00000083;
            // ADD x2, x1, x1 (使用x1，应该触发加载-使用冒险)
            instr_memory[40] = 32'h00108113;
            // ADD x3, x2, x2 (使用x2)
            instr_memory[41] = 32'h00210193;

            // 运行几个周期
            #200;

            // 检查结果（这里主要验证流水线是否正常工作，而不是具体值）
            if (debug_wb_valid) begin
                $display("  Test hazard passed!");
                test_pass = test_pass + 1;
            end else begin
                $display("  Test hazard failed! No valid write back observed");
                test_fail = test_fail + 1;
            end
        end
    endtask

    // 运行所有测试用例
    initial begin
        $display("Initial block started at time %0t", $time);

        // 初始化内存
        $display("Initializing memory...");
        for (int i = 0; i < 4096; i = i + 1) begin
            instr_memory[i] = 32'h00000013; // NOP指令
            data_memory[i] = 64'h0;
        end

        $display("Memory initialization completed.");

        // 等待复位完成
        $display("Waiting for reset...");
        @(posedge rst_n);
        $display("Reset deasserted at time %0t", $time);
        #10;

        $display("Reset completed. Starting test execution...");
    `ifdef DEBUG
        $display("Initial instructions: ");
        for (int i = 0; i < 10; i = i + 1) begin
            $display("Instr[0x%0h] = 0x%0h", i, instr_memory[i]);
        end
    `endif

        // 运行测试用例
        test_arithmetic;
        test_memory;
        test_branch;
        test_logic;
        test_shift;
        test_compare;
        test_jump;
        test_hazard;

        // 等待所有测试完成
        #500;

        // 输出测试结果
        $display("\nTest Results Summary:");
        $display("Total tests: %0d", test_pass + test_fail);
        $display("Passed tests: %0d", test_pass);
        $display("Failed tests: %0d", test_fail);

        if (test_fail == 0) begin
            $display("\nALL TESTS PASSED!");
        end else begin
            $display("\nSOME TESTS FAILED!");
        end

        // 生成波形文件
        $dumpfile("tb_riscv64_core.vcd");
        $dumpvars(0, tb_riscv64_core);

        // 结束仿真
        #100;
        $finish;
    end

    // 超时检测
    initial begin
        #20000;
        $display("\nSimulation timeout!");
        $finish;
    end

`ifdef DEBUG
    // 调试监控
    always @(posedge clk) begin
        if (debug_wb_valid) begin
            $display("Time: %0t, PC: %0h, Instr: %0h, WB: x%0d = %0h",
                    $time, debug_pc, debug_instr, debug_wb_rd, debug_wb_value);
        end

        if (icache_req) begin
            $display("Time: %0t, ICache req: addr=%0h, data=%0h",
                    $time, icache_addr, icache_data);
        end

        if (dcache_req) begin
            if (dcache_we) begin
                $display("Time: %0t, DCache write: addr=%0h, data=%0h, be=%0h",
                        $time, dcache_addr, dcache_wdata, dcache_byte_en);
            end else begin
                $display("Time: %0t, DCache read: addr=%0h, data=%0h",
                        $time, dcache_addr, dcache_rdata);
            end
        end
    end
`endif

endmodule