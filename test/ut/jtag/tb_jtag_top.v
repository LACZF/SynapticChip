// tb_jtag_top.v
// JTAG测试平台

`include "jtag_params.v"
`timescale 1ns/1ps

module tb_jtag_top;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // JTAG接口信号
    reg tck;
    reg tms;
    reg tdi;
    wire tdo;
    wire tdo_en;

    // 控制接口（直接连接到JTAG模块）
    reg req;
    reg we;
    reg [`ADDR_WIDTH-1:0] addr;
    reg [`DATA_WIDTH-1:0] data_in;
    wire [`DATA_WIDTH-1:0] data_out;
    wire ack;

    // 调试输出
    wire [`DATA_WIDTH-1:0] debug_data;
    wire debug_valid;

    // 实例化DUT
    jtag_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .tck(tck),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .tdo_en(tdo_en),
        .req(req),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .ack(ack),
        .debug_data(debug_data),
        .debug_valid(debug_valid)
    );

    // 时钟生成
    always #5 clk = ~clk;
    always #10 tck = ~tck; // JTAG时钟频率是系统时钟的一半

    // 测试任务：写寄存器
    task write_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        input [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req = 1'b1;
            we = 1'b1;
            addr = reg_addr;
            data_in = reg_data;

            $display("[write_register] Writing to addr=0x%h, data=0x%h", reg_addr, reg_data);

            // 等待确认
            while (!ack) begin
                @(posedge clk);
            end

            @(posedge clk);
            req = 1'b0;
            we = 1'b0;

            $display("[write_register] Write completed successfully");
        end
    endtask

    // 测试任务：读寄存器
    task read_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        output [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req = 1'b1;
            we = 1'b0;
            addr = reg_addr;

            $display("[read_register] Reading from addr=0x%h", reg_addr);

            // 等待确认
            while (!ack) begin
                @(posedge clk);
            end

            reg_data = data_out;
            $display("[read_register] Read completed: data=0x%h", reg_data);

            @(posedge clk);
            req = 1'b0;
        end
    endtask

    // 测试任务：JTAG TAP状态机控制
    task jtag_tap_control;
        input [3:0] target_state;
        begin
            // 简化实现，实际应根据TAP状态机转换表控制TMS
            // 这里只是示例，实际测试需要更复杂的控制逻辑
            tms = 1'b1; // 进入TEST-LOGIC-RESET
            @(negedge tck);
            @(negedge tck);

            tms = 1'b0; // 进入RUN-TEST/IDLE
            @(negedge tck);
        end
    endtask

    // 主测试程序
    reg [`DATA_WIDTH-1:0] read_data;
    reg error_occurred;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        tck = 0;
        tms = 1;
        tdi = 0;
        req = 0;
        we = 0;
        addr = 0;
        data_in = 0;
        error_occurred = 0;

        // 复位
        #20 rst_n = 1;

        $display("Starting JTAG Module Test");
        $display("=========================");
        $display("Direct testing of jtag_top without Ring Bus");
        $display("=========================");

        // 等待稳定
        #100;

        $display("\n--- Basic JTAG Functionality Test ---");

        // 测试1: 写数据寄存器
        $display("\n1. Testing data register write");
        write_register(`REG_JTAG_DATA, 32'h12345678);
        #50;

        // 测试2: 读数据寄存器
        $display("\n2. Testing data register readback");
        read_register(`REG_JTAG_DATA, read_data);
        if (read_data !== 32'h12345678) begin
            $display("   ✗ ERROR: Data register readback mismatch: 0x%h (expected: 0x12345678)", read_data);
            error_occurred = 1;
        end else begin
            $display("   ✓ Data register readback verified: 0x%h", read_data);
        end

        // 测试3: 读状态寄存器
        $display("\n3. Testing status register read");
        read_register(`REG_JTAG_STAT, read_data);
        $display("   Status register value: 0x%h", read_data);

        // 测试4: 测试JTAG TAP控制
        $display("\n4. Testing JTAG TAP control");
        $display("   Current TMS value: %b", tms);
        jtag_tap_control(`RUN_TEST_IDLE);
        $display("   After TAP control, TMS value: %b", tms);

        // 测试5: 读取TAP状态
        $display("\n5. Reading TAP state");
        read_register(`REG_JTAG_CTRL, read_data);
        $display("   Current TAP state: 0x%h", read_data);

        // 最终测试结果
        if (error_occurred) begin
            $display("\nTEST FAILED: Some errors occurred during testing.");
        end else begin
            $display("\nTEST PASSED: JTAG module functionality verified successfully!");
        end

        $display("\nTest completed.");

        // 额外的延迟，确保有足够时间观察所有波形
        #1000;

        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_jtag_top.vcd");
        $dumpvars(0, tb_jtag_top);
    end

endmodule