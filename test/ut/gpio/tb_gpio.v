
module tb_gpio;
    // 时钟周期定义
    localparam CLK_PERIOD = 10;  // 10ns = 100MHz

    // 错误计数器
    integer error_count = 0;

    // 时钟和复位信号
    reg        clk;
    reg        rst_n;

    // OBI总线接口信号
    reg        req_i;
    reg        we_i;
    reg [31:0] addr_i;
    reg [31:0] wr_data_i;
    wire [31:0] data_out_o;
    wire       gnt_o;
    wire       rvalid_o;

    // GPIO接口信号
    reg [3:0]  gpio_in;
    wire [3:0] gpio_out;
    wire [3:0] gpio_io;

    // 测试用双向IO引脚
    reg [3:0]  gpio_io_test;
    reg [3:0]  gpio_io_dir;

    // 连接双向IO引脚
    assign gpio_io = gpio_io_dir ? gpio_io_test : {4{1'bz}};

    // 实例化GPIO模块
    gpio_top #(
        .GPIO_IN_CH    (4),
        .GPIO_OUT_CH   (4),
        .GPIO_IO_CH    (4)
    ) u_gpio (
        .clk           (clk),
        .rst_n         (rst_n),

        .req_i         (req_i),
        .we_i          (we_i),
        .addr_i        (addr_i),
        .wr_data_i     (wr_data_i),
        .data_out_o    (data_out_o),
        .gnt_o         (gnt_o),
        .rvalid_o      (rvalid_o),

        .gpio_in       (gpio_in),
        .gpio_out      (gpio_out),
        .gpio_io       (gpio_io)
    );

    // 时钟生成
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // 写寄存器任务
    task write_register;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            req_i = 1'b1;
            we_i = 1'b1;
            addr_i = addr;
            wr_data_i = data;

            // 等待gnt_o
            while (!gnt_o) @(posedge clk);

            @(posedge clk);
            req_i = 1'b0;

            // 等待rvalid_o
            while (!rvalid_o) @(posedge clk);
            @(posedge clk);
        end
    endtask

    // 读寄存器任务
    task read_register;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            req_i = 1'b1;
            we_i = 1'b0;
            addr_i = addr;

            // 等待gnt_o
            while (!gnt_o) @(posedge clk);

            @(posedge clk);
            req_i = 1'b0;

            // 等待rvalid_o并读取数据
            while (!rvalid_o) @(posedge clk);
            data = data_out_o;
            @(posedge clk);
        end
    endtask

    // 测试用例: GPIO初始化测试
    task test_initialization;
        reg [31:0] data;
        begin
            $display("Test 1: GPIO Initialization Test");

            // 读取初始状态
            read_register(32'h04, data); // 读取输出寄存器
            if (data != 32'h00000000) begin
                $display("ERROR: GPIO output register not initialized to 0");
                error_count = error_count + 1;
            end

            read_register(32'h08, data); // 读取方向寄存器
            if (data != 32'h00000000) begin
                $display("ERROR: GPIO direction register not initialized to 0");
                error_count = error_count + 1;
            end

            $display("GPIO Initialization Test completed");
        end
    endtask

    // 测试用例: GPIO输出功能测试
    task test_output;
        reg [31:0] data;
        begin
            $display("Test 2: GPIO Output Function Test");

            // 设置输出值
            write_register(32'h04, 32'h000000A5); // 设置输出为0xA5

            // 验证输出值
            @(posedge clk);
            if (gpio_out !== 4'ha) begin
                $display("ERROR: GPIO output does not match expected value. Expected: %h, Actual: %h", 4'ha, gpio_out);
                error_count = error_count + 1;
            end

            // 读取输出寄存器验证
            read_register(32'h04, data);
            if (data[3:0] !== 4'ha) begin
                $display("ERROR: GPIO output register does not match expected value. Expected: %h, Actual: %h", 4'ha, data[3:0]);
                error_count = error_count + 1;
            end

            $display("GPIO Output Function Test completed");
        end
    endtask

    // 测试用例: GPIO输入功能测试
    task test_input;
        reg [31:0] data;
        begin
            $display("Test 3: GPIO Input Function Test");

            // 设置输入值
            gpio_in = 4'h5;

            // 读取输入寄存器
            read_register(32'h00, data);
            if (data[3:0] !== 4'h5) begin
                $display("ERROR: GPIO input register does not match expected value. Expected: %h, Actual: %h", 4'h5, data[3:0]);
                error_count = error_count + 1;
            end

            // 更改输入值并再次读取
            gpio_in = 4'hF;
            read_register(32'h00, data);
            if (data[3:0] !== 4'hF) begin
                $display("ERROR: GPIO input register does not update correctly. Expected: %h, Actual: %h", 4'hF, data[3:0]);
                error_count = error_count + 1;
            end

            $display("GPIO Input Function Test completed");
        end
    endtask

    // 测试用例: GPIO双向IO功能测试
    task test_io;
        reg [31:0] data;
        begin
            $display("Test 4: GPIO Bidirectional IO Function Test");

            // 设置IO方向为输入
            write_register(32'h08, 32'h00000000); // 所有IO设置为输入
            gpio_io_dir = 4'h0; // 测试端也设置为输入

            // 模拟外部输入
            gpio_io_test = 4'h3;
            gpio_io_dir = 4'hF; // 测试端设置为输出

            // 读取IO值
            read_register(32'h0C, data);
            if (data[3:0] !== 4'h3) begin
                $display("ERROR: GPIO IO input does not match expected value. Expected: %h, Actual: %h", 4'h3, data[3:0]);
                error_count = error_count + 1;
            end

            // 设置IO方向为输出
            write_register(32'h08, 32'h0000000F); // 所有IO设置为输出
            write_register(32'h0C, 32'h000000CC); // 设置IO输出值

            // 验证IO输出
            @(posedge clk);
            if (gpio_io !== 4'hC) begin
                $display("ERROR: GPIO IO output does not match expected value. Expected: %h, Actual: %h", 4'hC, gpio_io);
                error_count = error_count + 1;
            end

            // 部分IO设置为输入，部分为输出
            write_register(32'h08, 32'h00000005); // IO0和IO2设置为输出，IO1和IO3设置为输入
            write_register(32'h0C, 32'h0000000A); // 设置IO输出值

            // 模拟外部输入到输入IO
            gpio_io_dir = 4'hA; // 测试端将IO1和IO3设置为输出
            gpio_io_test = 4'h5;

            // 读取IO值
            read_register(32'h0C, data);
            if (data[3:0] !== 4'h5) begin
                $display("ERROR: GPIO mixed IO does not work correctly. Expected: %h, Actual: %h", 4'h5, data[3:0]);
                error_count = error_count + 1;
            end

            $display("GPIO Bidirectional IO Function Test completed");
        end
    endtask

    // 主测试流程
    initial begin
        // 初始化信号
        req_i = 1'b0;
        we_i = 1'b0;
        addr_i = 32'h0;
        wr_data_i = 32'h0;
        gpio_in = 4'h0;
        gpio_io_test = 4'h0;
        gpio_io_dir = 4'h0;

        // 复位
        rst_n = 1'b0;
        #(10 * CLK_PERIOD);
        rst_n = 1'b1;

        $display("Starting GPIO Test...");

        // 运行测试用例
        test_initialization;
        test_output;
        test_input;
        test_io;

        // 检查测试结果
        if (error_count == 0) begin
            $display("All tests passed successfully!");
        end else begin
            $display("Test completed with %0d errors", error_count);
        end

        // 结束模拟
        #(10 * CLK_PERIOD);
        $finish;
    end

    // 全局超时保护
    initial begin
        #(10000 * CLK_PERIOD);
        $display("ERROR: Global timeout after 10000 cycles");
        $finish;
    end

    // 生成波形文件
    initial begin
        $dumpfile("tb_gpio.vcd");
        $dumpvars(0, tb_gpio);
    end

endmodule