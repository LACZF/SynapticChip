// tb_exception_handler.v
module tb_exception_handler;

    reg clk;
    reg rst_n;

    // 测试信号
    reg [31:0] current_pc;
    reg [31:0] inst;
    reg [31:0] mem_addr;
    reg mem_write;
    reg mem_read;
    reg inst_valid;
    reg mem_access_valid;
    reg mret_exec;
    reg ext_int;
    reg timer_int;
    reg soft_int;

    wire trap_taken;
    wire [31:0] trap_handler_addr;
    wire [31:0] return_addr;
    wire [11:0] csr_addr;
    wire [31:0] csr_wdata;
    wire csr_we;
    wire [31:0] csr_rdata;

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化被测模块
    exception_handler uut (
        .clk(clk),
        .rst_n(rst_n),
        .current_pc(current_pc),
        .inst(inst),
        .mem_addr(mem_addr),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .inst_valid(inst_valid),
        .mem_access_valid(mem_access_valid),
        .mret_exec(mret_exec),
        .ext_int(ext_int),
        .timer_int(timer_int),
        .soft_int(soft_int),
        .csr_addr(csr_addr),
        .csr_wdata(csr_wdata),
        .csr_we(csr_we),
        .csr_rdata(csr_rdata),
        .trap_taken(trap_taken),
        .trap_handler_addr(trap_handler_addr),
        .return_addr(return_addr)
    );

    // 模拟CSR读取（简化）
    assign csr_rdata = 32'h00000FFF;  // 所有中断使能

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        current_pc = 32'h0;
        inst = 32'h0;
        mem_addr = 32'h0;
        mem_write = 0;
        mem_read = 0;
        inst_valid = 0;
        mem_access_valid = 0;
        mret_exec = 0;
        ext_int = 0;
        timer_int = 0;
        soft_int = 0;

        // 复位
        #20;
        rst_n = 1;

        // 测试1: 非法指令异常
        $display("Test 1: Illegal instruction exception");
        #10;
        inst_valid = 1;
        current_pc = 32'h00000010;
        inst = 32'h00000000;  // 非法指令
        #10;
        inst_valid = 0;
        #20;

        // 测试2: ECALL异常
        $display("Test 2: ECALL exception");
        #10;
        inst_valid = 1;
        current_pc = 32'h00000020;
        inst = 32'h00000073;  // ECALL指令
        #10;
        inst_valid = 0;
        #20;

        // 测试3: 内存不对齐异常
        $display("Test 3: Memory misaligned exception");
        #10;
        mem_access_valid = 1;
        mem_read = 1;
        mem_addr = 32'h00000001;  // 不对齐地址
        #10;
        mem_access_valid = 0;
        mem_read = 0;
        #20;

        // 测试4: 软件中断
        $display("Test 4: Software interrupt");
        #10;
        soft_int = 1;
        #20;
        soft_int = 0;
        #20;

        // 测试5: 定时器中断
        $display("Test 5: Timer interrupt");
        #10;
        timer_int = 1;
        #20;
        timer_int = 0;
        #20;

        // 测试6: 外部中断
        $display("Test 6: External interrupt");
        #10;
        ext_int = 1;
        #20;
        ext_int = 0;
        #20;

        // 测试7: MRET指令
        $display("Test 7: MRET instruction");
        #10;
        mret_exec = 1;
        #10;
        mret_exec = 0;
        #20;

        $display("All tests completed");
        $finish;
    end

    // 监控输出
    always @(posedge clk) begin
        if (trap_taken) begin
            $display("Trap taken at time %t: Handler addr = 0x%h", $time, trap_handler_addr);
        end
    end

endmodule
