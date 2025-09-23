// tb_riscv_timer.v
module tb_riscv_timer;

    reg clk;
    reg rst_n;

    // 测试信号
    reg [31:0] bus_addr;
    reg [31:0] bus_data_in;
    reg [3:0] bus_sel;
    reg bus_we;
    reg bus_re;

    wire [31:0] bus_data_out;
    wire bus_ack;

    reg [11:0] csr_addr;
    reg [31:0] csr_data_in;
    reg csr_we;
    reg [2:0] csr_op;

    wire [31:0] csr_data_out;
    wire csr_ack;

    wire timer_int;
    reg use_memory_map;

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化被测模块
    riscv_timer uut (
        .clk(clk),
        .rst_n(rst_n),
        .bus_addr_i(bus_addr),
        .bus_data_i(bus_data_in),
        .bus_sel_i(bus_sel),
        .bus_we_i(bus_we),
        .bus_re_i(bus_re),
        .bus_data_o(bus_data_out),
        .bus_ack_o(bus_ack),
        .csr_addr_i(csr_addr),
        .csr_data_i(csr_data_in),
        .csr_we_i(csr_we),
        .csr_op_i(csr_op),
        .csr_data_o(csr_data_out),
        .csr_ack_o(csr_ack),
        .timer_interrupt_o(timer_int),
        .use_memory_map(use_memory_map)
    );

    // 测试任务：内存映射写
    task mm_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(posedge clk);
            bus_addr = address;
            bus_data_in = data;
            bus_sel = 4'b1111;
            bus_we = 1'b1;
            bus_re = 1'b0;
            @(posedge clk);
            bus_we = 1'b0;
            wait(bus_ack);
            @(posedge clk);
        end
    endtask

    // 测试任务：内存映射读
    task mm_read;
        input [31:0] address;
        begin
            @(posedge clk);
            bus_addr = address;
            bus_we = 1'b0;
            bus_re = 1'b1;
            @(posedge clk);
            bus_re = 1'b0;
            wait(bus_ack);
            @(posedge clk);
        end
    endtask

    // 测试任务：CSR写
    task csr_write;
        input [11:0] address;
        input [31:0] data;
        begin
            @(posedge clk);
            csr_addr = address;
            csr_data_in = data;
            csr_we = 1'b1;
            csr_op = 3'b001;  // CSRRW
            @(posedge clk);
            csr_we = 1'b0;
            wait(csr_ack);
            @(posedge clk);
        end
    endtask

    // 测试任务：CSR读
    task csr_read;
        input [11:0] address;
        begin
            @(posedge clk);
            csr_addr = address;
            csr_we = 1'b0;
            @(posedge clk);
            wait(csr_ack);
            @(posedge clk);
        end
    endtask

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        bus_addr = 32'h0;
        bus_data_in = 32'h0;
        bus_sel = 4'b0000;
        bus_we = 0;
        bus_re = 0;
        csr_addr = 12'h0;
        csr_data_in = 32'h0;
        csr_we = 0;
        csr_op = 3'b000;
        use_memory_map = 1'b1;

        // 复位
        #20;
        rst_n = 1;

        $display("=== 开始RISC-V定时器测试 ===");

        // 测试1: 内存映射接口测试
        $display("测试1: 内存映射接口");
        use_memory_map = 1'b1;

        // 设置比较值为100
        mm_write(32'h02004008, 32'd100);  // MTIMECMP_LOW
        mm_write(32'h0200400C, 32'h0);    // MTIMECMP_HIGH

        // 读取当前时间值
        mm_read(32'h02004000);  // MTIME_LOW
        $display("MTIME_LOW = 0x%h", bus_data_out);

        // 等待定时器中断
        #1000;
        if (timer_int) begin
            $display("定时器中断触发成功!");
        end else begin
            $display("错误: 定时器中断未触发");
        end

        // 测试2: CSR接口测试
        $display("测试2: CSR接口");
        use_memory_map = 1'b0;

        // 通过CSR设置比较值
        csr_write(12'h7C2, 32'd200);  // MTIMECMP_LO
        csr_write(12'h7C3, 32'h0);    // MTIMECMP_HI

        // 读取控制寄存器
        csr_read(12'h7C4);  // MTIMECTL
        $display("控制寄存器 = 0x%h", csr_data_out);

        // 等待定时器中断
        #2000;
        if (timer_int) begin
            $display("CSR定时器中断触发成功!");
        end

        // 测试3: 定时器精度测试
        $display("测试3: 定时器精度测试");

        // 读取开始时间
        if (use_memory_map) begin
            mm_read(32'h02004000);
        end else begin
            csr_read(12'h7C0);
        end
        $display("开始时间: 0x%h", use_memory_map ? bus_data_out : csr_data_out);

        // 等待100个时钟周期
        #1000;

        // 读取结束时间
        if (use_memory_map) begin
            mm_read(32'h02004000);
        end else begin
            csr_read(12'h7C0);
        end
        $display("结束时间: 0x%h", use_memory_map ? bus_data_out : csr_data_out);

        $display("=== 定时器测试完成 ===");
        $finish;
    end

    // 监控中断信号
    always @(posedge timer_int) begin
        $display("时间: %t - 检测到定时器中断", $time);
    end

    // 监控定时器值变化（抽样）
    integer last_time = 0;
    always @(posedge clk) begin
        if (last_time !== uut.mm_timer.mtime_reg[31:0]) begin
            last_time = uut.mm_timer.mtime_reg[31:0];
            if (last_time % 50 == 0) begin
                $display("时间: %t - MTIME = %d", $time, last_time);
            end
        end
    end

endmodule
