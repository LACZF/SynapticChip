// tb_riscv64_multicore.v
module tb_riscv64_multicore;

    reg clk;
    reg rst_n;
    reg [1:0] ipi_interrupt;
    wire [63:0] mem_addr;
    wire [63:0] mem_wdata;
    reg [63:0] mem_rdata;
    wire mem_we;
    wire [7:0] mem_byte_en;
    wire mem_req;
    reg mem_ready;
    wire [1:0] core_halted;

    // 实例化多核CPU
    riscv64_multicore #(
        .NUM_CORES(2),
        .CORE_ID_WIDTH(2)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_we(mem_we),
        .mem_byte_en(mem_byte_en),
        .mem_req(mem_req),
        .mem_ready(mem_ready),
        .ipi_interrupt(ipi_interrupt),
        .core_halted(core_halted)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 简单内存模型
    reg [63:0] memory [0:1023];

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        ipi_interrupt = 2'b00;
        mem_ready = 0;

        // 加载测试程序
        memory[0] = 64'h00000013_00000013; // 两个NOP
        memory[1] = 64'h00100093_00200113; // ADDI x1, x0, 1; ADDI x2, x0, 2

        #20 rst_n = 1;

        // 内存访问模拟
        forever begin
            @(posedge mem_req);
            #10 mem_ready = 1;
            mem_rdata = memory[mem_addr[63:3]];
            @(posedge clk);
            mem_ready = 0;
        end
    end

    initial begin
        #1000;
        $display("Simulation completed");
        $finish;
    end

endmodule
