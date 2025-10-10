// tb_gpio_module.v
// GPIO模块测试平台

`include "gpio_params.v"
`timescale 1ns/1ps

module tb_gpio_module;

    // 时钟和复位
    reg clk;
    reg rst_n;

    // 控制接口信号
    reg req;
    reg we;
    reg [`ADDR_WIDTH-1:0] addr;
    reg [`DATA_WIDTH-1:0] data_in;
    wire [`DATA_WIDTH-1:0] data_out;
    wire ack;

    // GPIO引脚
    wire [`GPIO_WIDTH-1:0] gpio_pins;
    reg [`GPIO_WIDTH-1:0] gpio_ext_drive;
    reg [`GPIO_WIDTH-1:0] gpio_dir;

    // 初始化为输入模式
    initial begin
        gpio_dir = {`GPIO_WIDTH{1'b0}};
    end

    // 根据方向寄存器的值控制GPIO引脚
    genvar i;
    generate
        for (i = 0; i < `GPIO_WIDTH; i = i + 1) begin : gpio_bidirectional
            assign gpio_pins[i] = gpio_dir[i] ? gpio_ext_drive[i] : 1'bz;
        end
    endgenerate

    // 中断信号
    wire int_out;

    // 实例化DUT
    gpio_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .ack(ack),
        .gpio_pins(gpio_pins),
        .int_out(int_out)
    );

    // 时钟生成
    always #5 clk = ~clk;

    // 测试任务：寄存器写操作
    task write_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        input [`DATA_WIDTH-1:0] write_data;
        reg [31:0] timeout_count;
        reg timeout;
        begin
            timeout_count = 0;
            timeout = 0;

        `ifdef DEBUG
            $display("[write_register] Writing to addr=0x%h, data=0x%h", reg_addr, write_data);
        `endif
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b1;
            addr <= reg_addr;
            data_in <= write_data;

            // 等待确认并添加超时机制
            while (!ack && !timeout) begin
                timeout_count = timeout_count + 1;
                if (timeout_count >= 100) begin
                    $display("ERROR: write_register timeout at address 0x%h", reg_addr);
                    timeout = 1;
                end
                @(posedge clk);
            end

            if (!timeout) begin
                $display("[write_register] Write completed successfully");
            end else begin
                $display("Warning: Write operation may not have completed");
            end

            @(posedge clk);
            req <= 1'b0;
            we <= 1'b0;
            addr <= 0;
            data_in <= 0;
        end
    endtask

    // 测试任务：寄存器读操作
    task read_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        output [`DATA_WIDTH-1:0] read_data;
        reg [31:0] timeout_count;
        reg timeout;
        begin
            timeout_count = 0;
            timeout = 0;

        `ifdef DEBUG
            $display("[read_register] Reading from addr=0x%h", reg_addr);
        `endif
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b0;
            addr <= reg_addr;

            // 等待确认并添加超时机制
            while (!ack && !timeout) begin
                timeout_count = timeout_count + 1;
                if (timeout_count >= 100) begin
                    $display("ERROR: read_register timeout at address 0x%h", reg_addr);
                    timeout = 1;
                end
                @(posedge clk);
            end

            if (!timeout) begin
                read_data = data_out;
                $display("[read_register] Read completed: data=0x%h", read_data);
            end else begin
                read_data = {`DATA_WIDTH{1'bx}};
                $display("Warning: Read operation may not have completed");
            end

            @(posedge clk);
            req <= 1'b0;
            we <= 1'b0;
            addr <= 0;
        end
    endtask

    // 主测试程序
    reg [`DATA_WIDTH-1:0] read_data;
    reg error_occurred = 0;

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        req = 0;
        we = 0;
        addr = 0;
        data_in = 0;
        gpio_ext_drive = {`GPIO_WIDTH{1'b0}};

        // 复位
        #20 rst_n = 1;

        $display("Starting GPIO Module Test");
        $display("=========================");
        $display("Direct testing of gpio_module without Ring Bus");
        $display("=========================");

        // 等待复位完成
        #100;

        $display("\n--- GPIO Register Test ---");

        // 测试寄存器基本读写功能
        $display("\n1. Testing register read/write operations");

        // 测试方向寄存器
        write_register(`REG_DIR, 32'h0000FFFF);
        #50;
        read_register(`REG_DIR, read_data);
        if (read_data == 32'h0000FFFF) begin
            $display("   ✓ Direction register readback verified: 0x%h", read_data);
        end else begin
            $display("   ✗ ERROR: Direction register readback mismatch: 0x%h (expected: 0x0000FFFF)", read_data);
            error_occurred = 1;
        end

        // 测试数据寄存器（先设置方向为输出）
        write_register(`REG_DATA, 32'h0000AAAA);
        #50;
        read_register(`REG_DATA, read_data);
        if (read_data == 32'h0000AAAA) begin
            $display("   ✓ Data register readback verified: 0x%h", read_data);
        end else begin
            $display("   ✗ ERROR: Data register readback mismatch: 0x%h (expected: 0x0000AAAA)", read_data);
            error_occurred = 1;
        end

        // 测试中断相关寄存器
        write_register(`REG_INTEN, 32'h00010000);
        #50;
        read_register(`REG_INTEN, read_data);
        if (read_data == 32'h00010000) begin
            $display("   ✓ Interrupt enable register readback verified: 0x%h", read_data);
        end else begin
            $display("   ✗ ERROR: Interrupt enable register readback mismatch: 0x%h (expected: 0x00010000)", read_data);
            error_occurred = 1;
        end

        // 最终测试结果
        if (error_occurred) begin
            $display("\nTEST FAILED: Some errors occurred during testing.");
        end else begin
            $display("\nTEST PASSED: GPIO module register functionality verified successfully!");
        end

        $display("\nTest completed.");

        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_gpio_module.vcd");
        $dumpvars(0, tb_gpio_module);
    end

endmodule