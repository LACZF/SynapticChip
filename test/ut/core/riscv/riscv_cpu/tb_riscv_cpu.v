// tb_riscv_cpu.v
module tb_riscv_cpu;

    reg clk;
    reg rst_n;

    // 存储器接口
    reg [31:0] imem_data;
    reg imem_ack;
    reg [31:0] dmem_data_in;
    reg dmem_ack;

    wire [31:0] imem_addr;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_data_out;
    wire dmem_we;
    wire [3:0] dmem_sel;
    wire imem_req;
    wire dmem_req;

    // 中断信号
    reg ext_int;
    reg timer_int;
    reg soft_int;

    // 指令存储器内容
    reg [31:0] instruction_mem [0:255];
    reg [31:0] data_mem [0:255];

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化CPU
    riscv_cpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_data(imem_data),
        .imem_req(imem_req),
        .imem_ack(imem_ack),
        .dmem_addr(dmem_addr),
        .dmem_data_out(dmem_data_out),
        .dmem_data_in(dmem_data_in),
        .dmem_we(dmem_we),
        .dmem_sel(dmem_sel),
        .dmem_req(dmem_req),
        .dmem_ack(dmem_ack),
        .ext_interrupt(ext_int),
        .timer_interrupt(timer_int),
        .soft_interrupt(soft_int)
    );

    // 指令存储器模拟
    always @(posedge clk) begin
        if (imem_req) begin
            imem_data <= instruction_mem[imem_addr[9:2]];  // 字地址
            imem_ack <= 1'b1;
        end else begin
            imem_ack <= 1'b0;
        end
    end

    // 数据存储器模拟
    always @(posedge clk) begin
        if (dmem_req && dmem_we) begin
            // 写操作
            data_mem[dmem_addr[9:2]] <= dmem_data_out;
            dmem_ack <= 1'b1;
        end else if (dmem_req && !dmem_we) begin
            // 读操作
            dmem_data_in <= data_mem[dmem_addr[9:2]];
            dmem_ack <= 1'b1;
        end else begin
            dmem_ack <= 1'b0;
        end
    end

    // 加载测试程序
    // task load_program(input [31:0] prog [0:31]);
    //     integer i;
    //     begin
    //         for (i = 0; i < 32; i = i + 1) begin
    //             instruction_mem[i] = prog[i];
    //         end
    //     end
    // endtask

    // 简单测试程序：计算斐波那契数列
    reg [31:0] test_program [0:31] = '{
        // main:
        32'h00000293,  // addi x5, x0, 0     // x5 = 0 (a)
        32'h00100313,  // addi x6, x0, 1     // x6 = 1 (b)
        32'h00a00413,  // addi x8, x0, 10    // x8 = 10 (循环次数)
        32'h00000493,  // addi x9, x0, 0     // x9 = 0 (计数器)

        // loop:
        32'h00532023,  // sw x5, 0(x6)       // 存储a
        32'h0062a223,  // sw x6, 4(x5)       // 存储b
        32'h00530333,  // add x6, x6, x5     // b = a + b
        32'h406282b3,  // sub x5, x5, x6     // a = b - a (实际上是旧b值)
        32'h00148493,  // addi x9, x9, 1     // 计数器++
        32'h00940863,  // beq x8, x9, end    // 如果计数器==10，跳转到end
        32'hff5ff06f,  // jal x0, loop       // 跳转到loop

        // end:
        32'h00000073,  // ecall              // 系统调用
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000,  // nop
        32'h00000000   // nop
    };

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        ext_int = 0;
        timer_int = 0;
        soft_int = 0;

        // 初始化存储器
        $readmemh("zeros.mem", instruction_mem);
        $readmemh("zeros.mem", data_mem);

        /* TODO */
        // 加载测试程序
        // load_program(test_program);
        // genvar i;
        // generate
        //     for (i = 0; i < 32; i = i + 1) begin
        //         instruction_mem[i] = test_program[i];
        //     end
        // endgenerate

        // 复位
        #20;
        rst_n = 1;

        $display("=== 开始RISC-V CPU测试 ===");
        $display("时间: %t - CPU复位完成", $time);

        // 运行基本程序测试
        #500;

        // 测试中断
        $display("时间: %t - 触发定时器中断", $time);
        timer_int = 1;
        #30;
        timer_int = 0;

        #200;

        // 测试异常
        $display("时间: %t - 测试ECALL异常", $time);
        // 程序中的ECALL指令会触发异常

        #1000;

        $display("=== CPU测试完成 ===");
        $display("最终寄存器状态:");
        $display("x5 (a) = %d", uut.reg_file.registers[5]);
        $display("x6 (b) = %d", uut.reg_file.registers[6]);
        $display("x8 (limit) = %d", uut.reg_file.registers[8]);
        $display("x9 (counter) = %d", uut.reg_file.registers[9]);

        $finish;
    end

    // 监控关键信号
    always @(posedge clk) begin
        if (uut.if_id_valid) begin
            $display("时间: %t - IF: PC=0x%h, INST=0x%h",
                    $time, uut.if_id_pc, uut.if_id_inst);
        end

        if (uut.id_ex_valid) begin
            $display("时间: %t - ID: RS1=%d, RS2=%d, RD=%d",
                    $time, uut.id_ex_rs1_data, uut.id_ex_rs2_data, uut.id_ex_rd);
        end

        if (uut.ex_wb_valid && uut.ex_wb_reg_we) begin
            $display("时间: %t - WB: x%d = 0x%h",
                    $time, uut.ex_wb_rd, uut.reg_wdata);
        end

        if (uut.trap_taken) begin
            $display("时间: %t - 陷阱处理: 跳转到0x%h", $time, uut.trap_handler_addr);
        end
    end

endmodule
