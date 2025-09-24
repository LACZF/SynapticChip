// tb_riscv64_cache_system.v
module tb_riscv64_cache_system;

    reg clk;
    reg rst_n;

    // 测试参数
    parameter NUM_CORES = 2;

    // L2缓存接口
    wire [NUM_CORES-1:0] l2_icache_req;
    wire [NUM_CORES*64-1:0] l2_icache_addr;
    wire [NUM_CORES*512-1:0] l2_icache_data;
    wire [NUM_CORES-1:0] l2_icache_ready;

    wire [NUM_CORES-1:0] l2_dcache_req;
    wire [NUM_CORES*64-1:0] l2_dcache_addr;
    wire [NUM_CORES*512-1:0] l2_dcache_wdata;
    wire [NUM_CORES*512-1:0] l2_dcache_data;
    wire [NUM_CORES-1:0] l2_dcache_we;
    wire [NUM_CORES-1:0] l2_dcache_ready;

    // 一致性接口
    wire [NUM_CORES-1:0] snoop_valid;
    wire [NUM_CORES*64-1:0] snoop_addr;
    wire [NUM_CORES-1:0] snoop_we;
    wire [NUM_CORES-1:0] snoop_hit;
    wire [NUM_CORES*512-1:0] snoop_data;

    // 内存接口
    wire mem_req;
    wire [63:0] mem_addr;
    wire [511:0] mem_wdata;
    reg [511:0] mem_rdata;
    wire mem_we;
    reg mem_ready;

    // 时钟生成
    always #5 clk = ~clk;

    // L2缓存控制器
    l2_cache_controller #(
        .NUM_CORES(NUM_CORES)
    ) u_l2_controller (
        .clk(clk),
        .rst_n(rst_n),
        .l1_icache_req(l2_icache_req),
        .l1_icache_addr(l2_icache_addr),
        .l1_icache_data(l2_icache_data),
        .l1_icache_ready(l2_icache_ready),
        .l1_dcache_req(l2_dcache_req),
        .l1_dcache_addr(l2_dcache_addr),
        .l1_dcache_wdata(l2_dcache_wdata),
        .l1_dcache_data(l2_dcache_data),
        .l1_dcache_we(l2_dcache_we),
        .l1_dcache_ready(l2_dcache_ready),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(mem_we),
        .mem_ready(mem_ready),
        .snoop_valid(snoop_valid),
        .snoop_addr(snoop_addr),
        .snoop_we(snoop_we),
        .snoop_hit(snoop_hit),
        .snoop_data(snoop_data)
    );

    // 生成多个带缓存的CPU核
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : core_gen
            riscv64_core_with_cache #(
                .CORE_ID(i)
            ) u_core (
                .clk(clk),
                .rst_n(rst_n),
                .l2_icache_req(l2_icache_req[i]),
                .l2_icache_addr(l2_icache_addr[i*64 +: 64]),
                .l2_icache_data(l2_icache_data[i*512 +: 512]),
                .l2_icache_ready(l2_icache_ready[i]),
                .l2_dcache_req(l2_dcache_req[i]),
                .l2_dcache_addr(l2_dcache_addr[i*64 +: 64]),
                .l2_dcache_wdata(l2_dcache_wdata[i*512 +: 512]),
                .l2_dcache_data(l2_dcache_data[i*512 +: 512]),
                .l2_dcache_we(l2_dcache_we[i]),
                .l2_dcache_ready(l2_dcache_ready[i]),
                .snoop_valid(snoop_valid[i]),
                .snoop_addr(snoop_addr[i*64 +: 64]),
                .snoop_we(snoop_we[i]),
                .snoop_hit(snoop_hit[i]),
                .snoop_data(snoop_data[i*512 +: 512]),
                .ipi_interrupt(1'b0),
                .timer_interrupt(1'b0),
                .external_interrupt(1'b0),
                .halted()
            );
        end
    endgenerate

    // 主内存模型
    reg [511:0] main_memory [0:4095]; // 32KB内存

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        mem_ready = 0;

        // 初始化内存内容
        for (integer j = 0; j < 4096; j = j + 1) begin
            main_memory[j] = 512'b0;
        end

        // 加载测试程序
        main_memory[0] = {32'h00000013, 32'h00000013, 32'h00000013, 32'h00000013,
                         32'h00000013, 32'h00000013, 32'h00000013, 32'h00000013}; // NOPs
        main_memory[1] = {32'h00100093, 32'h00200113, 32'h00300193, 32'h00400213,
                         32'h00500293, 32'h00600313, 32'h00700393, 32'h00800413}; // ADDI指令

        #20 rst_n = 1;

        // 内存访问模拟
        forever begin
            @(posedge mem_req);
            #15 mem_ready = 1;

            if (mem_we) begin
                main_memory[mem_addr[18:6]] <= mem_wdata;
                $display("Time %0t: L2 Write to address %h", $time, mem_addr);
            end else begin
                mem_rdata <= main_memory[mem_addr[18:6]];
                $display("Time %0t: L2 Read from address %h", $time, mem_addr);
            end

            @(posedge clk);
            mem_ready = 0;
        end
    end

    // 监控缓存行为
    always @(posedge clk) begin
        for (integer i = 0; i < NUM_CORES; i = i + 1) begin
            if (l2_icache_req[i] && l2_icache_ready[i]) begin
                $display("Time %0t: Core %0d ICache Miss Handled", $time, i);
            end
            if (l2_dcache_req[i] && l2_dcache_ready[i]) begin
                $display("Time %0t: Core %0d DCache Miss Handled", $time, i);
            end
        end
    end

    initial begin
        #1000;
        $display("Cache System Test Completed");
        $finish;
    end

endmodule
