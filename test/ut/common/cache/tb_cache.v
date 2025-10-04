`timescale 1ns / 1ps

module tb_cache;

    // 时钟和复位信号
    reg clk;
    reg rst_n;

    // CPU接口信号
    reg cpu_req_valid;
    reg [31:0] cpu_req_addr;
    reg cpu_req_rw;
    reg [31:0] cpu_req_data;
    reg [3:0] cpu_req_strb;
    wire cpu_rsp_valid;
    wire [31:0] cpu_rsp_data;
    wire cpu_rsp_error;

    // 内存接口信号
    reg mem_req_valid;
    reg [31:0] mem_req_addr;
    reg mem_req_rw;
    reg [63:0] mem_req_data;
    reg mem_rsp_valid;
    reg [63:0] mem_rsp_data;
    reg mem_rsp_error;

    // 一致性接口信号
    reg [31:0] coh_req_addr;
    reg coh_req_valid;
    reg [2:0] coh_req_type;
    wire coh_rsp_valid;
    wire [2:0] coh_rsp_state;

    // L1+L2多级缓存信号
    wire [31:0] l2_cpu_req_addr;
    reg [31:0] l2_cpu_req_data;
    reg [3:0] l2_cpu_req_strb;
    wire l2_cpu_req_valid;
    wire l2_cpu_req_rw;
    wire [31:0] l2_cpu_rsp_data;
    wire l2_cpu_rsp_valid;
    wire l2_cpu_rsp_error;

    // L1+L2+L3多级缓存信号
    reg [31:0] l3_cpu_req_addr;
    reg [31:0] l3_cpu_req_data;
    reg [3:0] l3_cpu_req_strb;
    reg l3_cpu_req_valid;
    reg l3_cpu_req_rw;
    wire [31:0] l3_cpu_rsp_data;
    wire l3_cpu_rsp_valid;
    wire l3_cpu_rsp_error;

    // 测试选择信号
    reg [1:0] test_mode;
    localparam SINGLE_LEVEL = 2'b00;
    localparam L1_L2_CACHE = 2'b01;
    localparam L1_L2_L3_CACHE = 2'b10;

    // 测试完成标志
    reg test_done = 0;

    // 中间信号，用于解决端口连接中的条件表达式问题
    wire [31:0] l2_mem_req_addr;
    wire l2_mem_req_valid;
    wire l2_mem_req_rw;
    wire [63:0] l2_mem_req_data;
    wire [31:0] l3_mem_req_addr;
    wire l3_mem_req_valid;
    wire l3_mem_req_rw;
    wire [63:0] l3_mem_req_data;
    wire [31:0] dut_mem_req_addr;
    wire dut_mem_req_valid;
    wire dut_mem_req_rw;
    wire [63:0] dut_mem_req_data;
    wire [63:0] l1_mem_req_data; // L1缓存内存请求数据中间信号

    // 用于修复iverilog警告的中间信号 - 避免在always_comb块中使用常量选择器
    wire [31:0] l1_mem_req_data_32bit; // 截取l1_mem_req_data的低32位
    wire [63:0] l2_cache_cpu_rsp_data_64bit; // 将l2_cache.cpu_rsp_data扩展为64位
    wire [63:0] l3_cache_cpu_rsp_data_64bit; // 将l3_cache.cpu_rsp_data扩展为64位
    wire [31:0] l2_cache_mem_req_data_32bit; // 截取l2_cache.mem_req_data的低32位
    wire [3:0] full_strb; // 全选通信号常量

    // 在always_comb块外部定义这些信号的连接
    assign l1_mem_req_data_32bit = l1_mem_req_data[31:0];
    assign l2_cache_cpu_rsp_data_64bit = {32'b0, l2_cache.cpu_rsp_data};
    assign l3_cache_cpu_rsp_data_64bit = {32'b0, l3_cache.cpu_rsp_data};
    assign l2_cache_mem_req_data_32bit = l2_cache.mem_req_data[31:0];
    assign full_strb = 4'b1111; // 在外部定义常量值

    // 缓存模块内存响应信号 - 改为reg类型以便在always_comb中赋值
    reg l1_mem_rsp_valid;
    reg [63:0] l1_mem_rsp_data;
    reg l1_mem_rsp_error;
    reg l2_mem_rsp_valid;
    reg [63:0] l2_mem_rsp_data;
    reg l2_mem_rsp_error;
    reg l3_mem_rsp_valid;
    reg [63:0] l3_mem_rsp_data;
    reg l3_mem_rsp_error;
    reg dut_mem_rsp_valid;
    reg [63:0] dut_mem_rsp_data;
    reg dut_mem_rsp_error;

    // 根据测试模式选择连接方式
    always_comb begin
        case(test_mode)
            L1_L2_CACHE:
            begin
                // L1+L2模式：L2连接到主内存
                mem_req_valid = l2_mem_req_valid;
                mem_req_addr = l2_mem_req_addr;
                mem_req_rw = l2_mem_req_rw;
                mem_req_data = l2_mem_req_data;

                // L2的CPU请求数据直接连接到L1的内存请求数据的低32位
                l2_cpu_req_data = l1_mem_req_data[31:0];
                l2_cpu_req_strb = 4'b1111; // 全选通

                // L2的内存响应连接到主内存响应
                l2_mem_rsp_valid = mem_rsp_valid;
                l2_mem_rsp_data = mem_rsp_data;
                l2_mem_rsp_error = mem_rsp_error;

                // L1的内存响应连接到L2的CPU响应
                l1_mem_rsp_valid = l2_cache.cpu_rsp_valid;
                l1_mem_rsp_data = l2_cache_cpu_rsp_data_64bit;
                l1_mem_rsp_error = l2_cache.cpu_rsp_error;

                // 单级缓存禁用
                dut_mem_rsp_valid = 1'b0;
                dut_mem_rsp_data = 64'b0;
                dut_mem_rsp_error = 1'b0;

                // L3缓存禁用
                l3_mem_rsp_valid = 1'b0;
                l3_mem_rsp_data = 64'b0;
                l3_mem_rsp_error = 1'b0;
            end

            L1_L2_L3_CACHE:
            begin
                // L1+L2+L3模式：L2连接到L3，L3连接到主内存
                l3_cpu_req_valid = l2_mem_req_valid;
                l3_cpu_req_addr = l2_mem_req_addr;
                l3_cpu_req_rw = l2_mem_req_rw;
                // L3的CPU请求数据直接连接到L2的内存请求数据的低32位
                l3_cpu_req_data = l2_mem_req_data[31:0];
                l3_cpu_req_strb = 4'b1111; // 全选通

                // L2的CPU请求数据连接到L1的内存请求数据
                l2_cpu_req_data = l1_mem_req_data_32bit;
                l2_cpu_req_strb = full_strb;

                // L2的内存响应连接到L3的CPU响应
                l2_mem_rsp_valid = l3_cache.cpu_rsp_valid;
                l2_mem_rsp_data = l3_cache_cpu_rsp_data_64bit;
                l2_mem_rsp_error = l3_cache.cpu_rsp_error;

                // L3连接到主内存
                mem_req_valid = l3_mem_req_valid;
                mem_req_addr = l3_mem_req_addr;
                mem_req_rw = l3_mem_req_rw;
                mem_req_data = l3_mem_req_data;

                // L3的内存响应连接到主内存响应
                l3_mem_rsp_valid = mem_rsp_valid;
                l3_mem_rsp_data = mem_rsp_data;
                l3_mem_rsp_error = mem_rsp_error;

                // L1的内存响应连接到L2的CPU响应
                l1_mem_rsp_valid = l2_cache.cpu_rsp_valid;
                l1_mem_rsp_data = l2_cache_cpu_rsp_data_64bit;
                l1_mem_rsp_error = l2_cache.cpu_rsp_error;

                // 单级缓存禁用
                dut_mem_rsp_valid = 1'b0;
                dut_mem_rsp_data = 64'b0;
                dut_mem_rsp_error = 1'b0;
            end

            default: // SINGLE_LEVEL
            begin
                // 单级缓存模式
                mem_req_valid = dut_mem_req_valid;
                mem_req_addr = dut_mem_req_addr;
                mem_req_rw = dut_mem_req_rw;
                mem_req_data = dut_mem_req_data;

                // 单级缓存的内存响应连接到主内存响应
                dut_mem_rsp_valid = mem_rsp_valid;
                dut_mem_rsp_data = mem_rsp_data;
                dut_mem_rsp_error = mem_rsp_error;

                // 其他缓存禁用
                l1_mem_rsp_valid = 1'b0;
                l1_mem_rsp_data = 64'b0;
                l1_mem_rsp_error = 1'b0;
                l2_mem_rsp_valid = 1'b0;
                l2_mem_rsp_data = 64'b0;
                l2_mem_rsp_error = 1'b0;
                l3_mem_rsp_valid = 1'b0;
                l3_mem_rsp_data = 64'b0;
                l3_mem_rsp_error = 1'b0;
            end
        endcase
    end

    // 实例化L1缓存
    cache #(
        .CACHE_LINE_SIZE(64),          // 64字节cache line
        .CACHE_SIZE(256),              // 256B - 较小的L1缓存
        .ASSOCIATIVITY(2),             // 2路组相联
        .ADDR_WIDTH(32),               // 32位地址宽度
        .DATA_WIDTH(32),               // 32位数据宽度
        .SUPPORT_COHERENCY(1),         // 支持一致性
        .CACHE_LEVEL(1),               // L1缓存
        .REPLACEMENT_POLICY("LRU")     // LRU替换策略
    ) l1_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(cpu_req_valid),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_data(cpu_req_data),
        .cpu_req_strb(cpu_req_strb),
        .cpu_rsp_valid(cpu_rsp_valid),
        .cpu_rsp_data(cpu_rsp_data),
        .cpu_rsp_error(cpu_rsp_error),
        .mem_req_valid(l2_cpu_req_valid),
        .mem_req_addr(l2_cpu_req_addr),
        .mem_req_rw(l2_cpu_req_rw),
        .mem_req_data(l1_mem_req_data), // 连接到中间信号
        .mem_rsp_valid(l1_mem_rsp_valid), // 连接到中间信号
        .mem_rsp_data(l1_mem_rsp_data),  // 连接到中间信号
        .mem_rsp_error(l1_mem_rsp_error), // 连接到中间信号
        .coh_req_addr(coh_req_addr),
        .coh_req_valid(coh_req_valid),
        .coh_req_type(coh_req_type),
        .coh_rsp_valid(coh_rsp_valid),
        .coh_rsp_state(coh_rsp_state)
    );

    // 实例化L2缓存
    cache #(
        .CACHE_LINE_SIZE(64),          // 64字节cache line
        .CACHE_SIZE(1024),             // 1KB cache容量
        .ASSOCIATIVITY(4),             // 4路组相联
        .ADDR_WIDTH(32),               // 32位地址宽度
        .DATA_WIDTH(32),               // 32位数据宽度
        .SUPPORT_COHERENCY(1),         // 支持一致性
        .CACHE_LEVEL(2),               // L2缓存
        .REPLACEMENT_POLICY("LRU")     // LRU替换策略
    ) l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(l2_cpu_req_valid),
        .cpu_req_addr(l2_cpu_req_addr),
        .cpu_req_rw(l2_cpu_req_rw),
        .cpu_req_data(l2_cpu_req_data),
        .cpu_req_strb(l2_cpu_req_strb),
        .cpu_rsp_valid(cpu_rsp_valid),
        .cpu_rsp_data(l2_cpu_rsp_data),
        .cpu_rsp_error(l2_cpu_rsp_error),
        .mem_req_valid(l2_mem_req_valid),
        .mem_req_addr(l2_mem_req_addr),
        .mem_req_rw(l2_mem_req_rw),
        .mem_req_data(l2_mem_req_data), // 保持64位数据宽度
        .mem_rsp_valid(l2_mem_rsp_valid), // 连接到中间信号
        .mem_rsp_data(l2_mem_rsp_data),  // 连接到中间信号
        .mem_rsp_error(l2_mem_rsp_error), // 连接到中间信号
        .coh_req_addr(32'h0),
        .coh_req_valid(1'b0),
        .coh_req_type(3'b0),
        .coh_rsp_valid(),
        .coh_rsp_state()
    );

    // 实例化L3缓存
    cache #(
        .CACHE_LINE_SIZE(64),          // 64字节cache line
        .CACHE_SIZE(4096),             // 4KB cache容量
        .ASSOCIATIVITY(8),             // 8路组相联
        .ADDR_WIDTH(32),               // 32位地址宽度
        .DATA_WIDTH(32),               // 32位数据宽度
        .SUPPORT_COHERENCY(1),         // 支持一致性
        .CACHE_LEVEL(3),               // L3缓存
        .REPLACEMENT_POLICY("LRU")     // LRU替换策略
    ) l3_cache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(l3_cpu_req_valid),
        .cpu_req_addr(l3_cpu_req_addr),
        .cpu_req_rw(l3_cpu_req_rw),
        .cpu_req_data(l3_cpu_req_data),
        .cpu_req_strb(l3_cpu_req_strb),
        .cpu_rsp_valid(l3_cpu_rsp_valid),
        .cpu_rsp_data(l3_cpu_rsp_data),
        .cpu_rsp_error(l3_cpu_rsp_error),
        .mem_req_valid(l3_mem_req_valid),
        .mem_req_addr(l3_mem_req_addr),
        .mem_req_rw(l3_mem_req_rw),
        .mem_req_data(l3_mem_req_data), // 保持64位数据宽度
        .mem_rsp_valid(l3_mem_rsp_valid), // 连接到中间信号
        .mem_rsp_data(l3_mem_rsp_data),  // 连接到中间信号
        .mem_rsp_error(l3_mem_rsp_error), // 连接到中间信号
        .coh_req_addr(32'h0),
        .coh_req_valid(1'b0),
        .coh_req_type(3'b0),
        .coh_rsp_valid(),
        .coh_rsp_state()
    );

    // 原始单级缓存实例 - 保留用于原有测试
    cache #(
        .CACHE_LINE_SIZE(64),          // 64字节cache line
        .CACHE_SIZE(1024),             // 1KB cache容量
        .ASSOCIATIVITY(4),             // 4路组相联
        .ADDR_WIDTH(32),               // 32位地址宽度
        .DATA_WIDTH(32),               // 32位数据宽度
        .SUPPORT_COHERENCY(1),         // 支持一致性
        .CACHE_LEVEL(2),               // L2缓存
        .REPLACEMENT_POLICY("LRU")     // LRU替换策略
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(test_mode == SINGLE_LEVEL ? cpu_req_valid : 1'b0),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_data(cpu_req_data),
        .cpu_req_strb(cpu_req_strb),
        .cpu_rsp_valid(cpu_rsp_valid),
        .cpu_rsp_data(cpu_rsp_data),
        .cpu_rsp_error(cpu_rsp_error),
        .mem_req_valid(dut_mem_req_valid),
        .mem_req_addr(dut_mem_req_addr),
        .mem_req_rw(dut_mem_req_rw),
        .mem_req_data(dut_mem_req_data),
        .mem_rsp_valid(dut_mem_rsp_valid), // 连接到中间信号
        .mem_rsp_data(dut_mem_rsp_data),  // 连接到中间信号
        .mem_rsp_error(dut_mem_rsp_error), // 连接到中间信号
        .coh_req_addr(coh_req_addr),
        .coh_req_valid(coh_req_valid),
        .coh_req_type(coh_req_type),
        .coh_rsp_valid(coh_rsp_valid),
        .coh_rsp_state(coh_rsp_state)
    );

    // 创建参考内存模型
    reg [7:0] ref_memory [0:4095];

    // 时钟生成
    always #5 clk = ~clk;

    // 内存模型初始化
    initial begin
        for (integer i = 0; i < 4096; i = i + 1) begin
            ref_memory[i] = i & 8'hFF;
        end
    end

    // 内存延迟计数器
    reg [3:0] mem_delay_count;
    reg mem_req_pending;
    reg [31:0] pending_addr;
    reg pending_rw;
    reg [63:0] pending_data;

    // 内存响应逻辑 - 修复了延迟实现方式
    always @(posedge clk) begin
        if (~rst_n) begin
            mem_rsp_valid <= 1'b0;
            mem_delay_count <= 4'h0;
            mem_req_pending <= 1'b0;
        end else begin
            if (mem_req_valid && ~mem_req_pending) begin
                // 新的内存请求
                pending_addr <= mem_req_addr;
                pending_rw <= mem_req_rw;
                pending_data <= mem_req_data;
                mem_req_pending <= 1'b1;
                mem_delay_count <= 4'h9; // 设置10个周期的延迟
                mem_rsp_valid <= 1'b0;
            end else if (mem_req_pending) begin
                // 等待延迟完成
                mem_delay_count <= mem_delay_count - 1'b1;
                if (mem_delay_count == 0) begin
                    // 延迟完成，产生响应
                    mem_req_pending <= 1'b0;
                    mem_rsp_valid <= 1'b1;
                    if (pending_rw) begin
                        // 内存写操作
                        for (integer i = 0; i < 64; i = i + 1) begin
                            ref_memory[pending_addr + i] = pending_data[i*8 +: 8];
                        end
                    end else begin
                        // 内存读操作
                        for (integer i = 0; i < 64; i = i + 1) begin
                            mem_rsp_data[i*8 +: 8] = ref_memory[pending_addr + i];
                        end
                    end
                end else begin
                    mem_rsp_valid <= 1'b0;
                end
            end else begin
                mem_rsp_valid <= 1'b0;
            end
            mem_rsp_error <= 1'b0;
        end
    end

    // 超时参数定义
    localparam TIMEOUT_CYCLES = 1000;

    // 测试任务：数据读取 - 添加超时机制
    task read_data;
        input [31:0] address;
        integer timeout;
        begin
            @(posedge clk);
            cpu_req_valid = 1'b1;
            cpu_req_addr = address;
            cpu_req_rw = 1'b0;  // 读操作
            cpu_req_data = 32'h0;
            cpu_req_strb = 4'b1111;

            timeout = 0;
            while (~cpu_rsp_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (cpu_rsp_valid) begin
                $display("时间: %t - 读取地址: 0x%h, 数据: 0x%h", $time, address, cpu_rsp_data);
            end else begin
                $display("时间: %t - 读取地址: 0x%h 超时! 测试可能存在问题.", $time, address);
            end

            @(posedge clk);
            cpu_req_valid = 1'b0;
        end
    endtask

    // 测试任务：数据写入 - 添加超时机制
    task write_data;
        input [31:0] address;
        input [31:0] data;
        input [3:0] strb;
        integer timeout;
        begin
            @(posedge clk);
            cpu_req_valid = 1'b1;
            cpu_req_addr = address;
            cpu_req_rw = 1'b1;  // 写操作
            cpu_req_data = data;
            cpu_req_strb = strb;

            timeout = 0;
            while (~cpu_rsp_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (cpu_rsp_valid) begin
                $display("时间: %t - 写入地址: 0x%h, 数据: 0x%h, 选通: 0x%h", $time, address, data, strb);
            end else begin
                $display("时间: %t - 写入地址: 0x%h 超时! 测试可能存在问题.", $time, address);
            end

            @(posedge clk);
            cpu_req_valid = 1'b0;
        end
    endtask

    // 定义MESI协议状态常量
    localparam INVALID   = 3'd0;
    localparam SHARED    = 3'd1;
    localparam EXCLUSIVE = 3'd2;
    localparam MODIFIED  = 3'd3;

    // 定义一致性请求类型常量
    localparam COH_READ      = 3'd0;
    localparam COH_WRITE     = 3'd1;
    localparam COH_INVALIDATE = 3'd2;

    // 测试任务：一致性操作 - 添加超时机制
    task coherency_op;
        input [31:0] address;
        input [2:0] req_type;
        input string req_name;
        integer timeout;
        begin
            @(posedge clk);
            coh_req_valid = 1'b1;
            coh_req_addr = address;
            coh_req_type = req_type;

            timeout = 0;
            while (~coh_rsp_valid && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (coh_rsp_valid) begin
                $display("时间: %t - 一致性操作: %s, 地址=0x%h, 状态=%s",
                         $time, req_name, address, get_state_name(coh_rsp_state));
            end else begin
                $display("时间: %t - 一致性操作: %s, 地址=0x%h 超时! 测试可能存在问题.", $time, req_name, address);
            end

            @(posedge clk);
            coh_req_valid = 1'b0;
        end
    endtask

    // 辅助函数：获取状态名称
    function string get_state_name;
        input [2:0] state;
        begin
            case (state)
                INVALID:   get_state_name = "INVALID";
                SHARED:    get_state_name = "SHARED";
                EXCLUSIVE: get_state_name = "EXCLUSIVE";
                MODIFIED:  get_state_name = "MODIFIED";
                default:   get_state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // 主测试流程
    initial begin
        // 初始化信号
        clk = 0;
        rst_n = 0;
        cpu_req_valid = 0;
        cpu_req_addr = 0;
        cpu_req_rw = 0;
        cpu_req_data = 0;
        cpu_req_strb = 0;
        mem_rsp_valid = 0;
        mem_rsp_data = 0;
        mem_rsp_error = 0;
        coh_req_valid = 0;
        coh_req_addr = 0;
        coh_req_type = 0;

        // 启动全局超时监控
        fork
            // 主测试线程
            begin

        // 创建VCD文件
        $dumpfile("tb_cache.vcd");
        $dumpvars(0, tb_cache);

        // 复位
        #20;
        rst_n = 1;

        $display("=== 缓存模块测试开始 ===");

        // 测试1: 基本读取测试
        $display("测试1: 基本读取测试");
        read_data(32'h00000000);  // 第一次读取，应该未命中
        read_data(32'h00000000);  // 第二次读取，应该命中

        // 测试2: 缓存行填充测试
        $display("测试2: 缓存行填充测试");
        read_data(32'h00000010);  // 同一缓存行，应该命中
        read_data(32'h00000020);  // 同一缓存行，应该命中

        // 测试3: 基本写入测试
        $display("测试3: 基本写入测试");
        write_data(32'h00001000, 32'h12345678, 4'b1111);  // 写未命中
        read_data(32'h00001000);  // 读取刚才写入的数据，应该命中

        // 测试4: 部分写入测试
        $display("测试4: 部分写入测试");
        write_data(32'h00001000, 32'hFF00FF00, 4'b1010);  // 只写字节0和2
        read_data(32'h00001000);  // 读取验证部分写入

        // 测试5: 缓存替换测试
        $display("测试5: 缓存替换测试");
        // 由于我们的缓存大小为1KB，4路组相联，每行64字节，总共有 (1024/64)/4 = 4 组
        // 访问足够多的不同组，触发替换
        for (integer i = 0; i < 8; i = i + 1) begin
            read_data(32'h00002000 + i*64);
        end
        // 验证最早的行已被替换
        read_data(32'h00002000);  // 应该未命中

        // 测试6: MESI协议一致性操作测试
        $display("测试6: MESI协议一致性操作测试");
        if (dut.SUPPORT_COHERENCY) begin
            // 先写入一个地址，让其进入MODIFIED状态
            write_data(32'h00001000, 32'h12345678, 4'b1111);
            read_data(32'h00001000);  // 确认数据已写入

            // 测试MODIFIED -> SHARED转换
            $display("测试6.1: MODIFIED -> SHARED状态转换 (读请求)");
            coherency_op(32'h00001000, COH_READ, "读请求");

            // 写入另一个地址，让其进入EXCLUSIVE状态
            read_data(32'h00001040);  // 首次读取，应该进入EXCLUSIVE状态

            // 测试EXCLUSIVE -> SHARED转换
            $display("测试6.2: EXCLUSIVE -> SHARED状态转换 (读请求)");
            coherency_op(32'h00001040, COH_READ, "读请求");

            // 测试SHARED -> INVALID转换
            $display("测试6.3: SHARED -> INVALID状态转换 (写请求)");
            coherency_op(32'h00001040, COH_WRITE, "写请求");

            // 测试无效化操作
            $display("测试6.4: 直接无效化操作 (使无效请求)");
            write_data(32'h00001080, 32'h87654321, 4'b1111);
            coherency_op(32'h00001080, COH_INVALIDATE, "使无效请求");

            // 验证无效化后的读取行为
            $display("测试6.5: 验证无效化后的读取行为");
            read_data(32'h00001080);  // 应该重新从内存加载
        end else begin
            $display("一致性功能未开启，跳过MESI协议测试");
        end

        // 测试7: 配置参数验证
        $display("测试7: 配置参数验证");
        $display("Cache大小: %d KB", dut.CACHE_SIZE/1024);
        $display("Cache Line大小: %d 字节", dut.CACHE_LINE_SIZE);
        $display("相联度: %d路", dut.ASSOCIATIVITY);
        $display("Cache层级: L%d", dut.CACHE_LEVEL);
        $display("替换策略: %s", dut.REPLACEMENT_POLICY);
        $display("一致性支持: %s", dut.SUPPORT_COHERENCY ? "是" : "否");

        // 测试8: L1+L2多级缓存测试
        $display("测试8: L1+L2多级缓存测试");
        test_mode = L1_L2_CACHE;
        @(posedge clk);

        // 简化L1+L2测试：只测试基本功能，避免复杂的缓存状态管理
        $display("测试8.1: 基本L1+L2读取测试");
        read_data(32'h00003000);  // L1不命中，L2不命中，从内存加载
        read_data(32'h00003000);  // L1命中

        // 测试9: L1+L2+L3多级缓存测试
        $display("测试9: L1+L2+L3多级缓存测试");
        test_mode = L1_L2_L3_CACHE;
        @(posedge clk);

        // 简化L1+L2+L3测试：只测试基本功能，避免复杂的缓存状态管理
        $display("测试9.1: 基本L1+L2+L3读取测试");
        read_data(32'h00004000);  // L1不命中，L2不命中，L3不命中，从内存加载
        read_data(32'h00004000);  // L1命中

        $display("=== 缓存模块测试完成 ===");

        // 等待所有操作完成
        repeat (10) @(posedge clk);

        $finish;
            end

            // 全局超时监控线程
            begin
                #1000000;  // 1ms的全局超时
                $display("时间: %t - 测试执行超时! 强制结束仿真.", $time);
                $finish;
            end
        join
    end

    // 监控缓存操作
    always @(posedge clk) begin
        if (mem_req_valid) begin
            if (mem_req_rw) begin
                $display("时间: %t - 缓存刷新: 地址=0x%h, 数据=0x%h",
                         $time, mem_req_addr, mem_req_data);
            end else begin
                $display("时间: %t - 缓存填充: 地址=0x%h", $time, mem_req_addr);
            end
        end
    end

endmodule