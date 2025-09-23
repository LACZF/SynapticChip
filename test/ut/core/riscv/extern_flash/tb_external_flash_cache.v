// tb_external_flash_cache.v
module tb_external_flash_cache;

    reg clk;
    reg rst_n;

    // CPU接口信号
    reg [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_data;
    reg cpu_imem_req;
    wire cpu_imem_ack;

    reg [31:0] cpu_dmem_addr;
    reg [31:0] cpu_dmem_data_out;
    wire [31:0] cpu_dmem_data_in;
    reg cpu_dmem_we;
    reg [3:0] cpu_dmem_sel;
    reg cpu_dmem_req;
    wire cpu_dmem_ack;

    // 外部Flash物理接口
    wire flash_cs_n;
    wire flash_clk;
    wire flash_mosi;
    reg flash_miso;
    wire [3:0] flash_dq_o;
    reg [3:0] flash_dq_i;
    wire flash_dq_oe;

    // 性能统计
    wire [31:0] perf_icache_hits;
    wire [31:0] perf_icache_misses;
    wire [31:0] perf_dcache_hits;
    wire [31:0] perf_dcache_misses;
    wire [31:0] perf_l2cache_hits;
    wire [31:0] perf_l2cache_misses;
    wire [31:0] perf_flash_reads;
    wire [31:0] perf_flash_writes;

    // 调试信号
    wire [3:0] cache_state;
    wire [2:0] flash_state;

    // 模拟外部Flash存储器
    reg [7:0] external_flash [0:1048575];  // 1MB外部Flash

    // 时钟生成
    always #5 clk = ~clk;

    // 实例化带外部Flash接口的缓存系统
    cache_system_external_flash uut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_imem_addr(cpu_imem_addr),
        .cpu_imem_data(cpu_imem_data),
        .cpu_imem_req(cpu_imem_req),
        .cpu_imem_ack(cpu_imem_ack),
        .cpu_dmem_addr(cpu_dmem_addr),
        .cpu_dmem_data_out(cpu_dmem_data_out),
        .cpu_dmem_data_in(cpu_dmem_data_in),
        .cpu_dmem_we(cpu_dmem_we),
        .cpu_dmem_sel(cpu_dmem_sel),
        .cpu_dmem_req(cpu_dmem_req),
        .cpu_dmem_ack(cpu_dmem_ack),
        .flash_cs_n(flash_cs_n),
        .flash_clk(flash_clk),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso),
        .flash_dq_o(flash_dq_o),
        .flash_dq_i(flash_dq_i),
        .flash_dq_oe(flash_dq_oe),
        .perf_icache_hits(perf_icache_hits),
        .perf_icache_misses(perf_icache_misses),
        .perf_dcache_hits(perf_dcache_hits),
        .perf_dcache_misses(perf_dcache_misses),
        .perf_l2cache_hits(perf_l2cache_hits),
        .perf_l2cache_misses(perf_l2cache_misses),
        .perf_flash_reads(perf_flash_reads),
        .perf_flash_writes(perf_flash_writes),
        .cache_state(cache_state),
        .flash_state(flash_state)
    );

    // 测试任务：指令读取
    task read_instruction;
        input [31:0] address;
        begin
            @(posedge clk);
            cpu_imem_addr = address;
            cpu_imem_req = 1'b1;
            @(posedge clk);
            wait(cpu_imem_ack);
            cpu_imem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 测试任务：数据读取
    task read_data;
        input [31:0] address;
        begin
            @(posedge clk);
            cpu_dmem_addr = address;
            cpu_dmem_we = 1'b0;
            cpu_dmem_req = 1'b1;
            @(posedge clk);
            wait(cpu_dmem_ack);
            cpu_dmem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 测试任务：数据写入
    task write_data;
        input [31:0] address;
        input [31:0] data;
        begin
            @(posedge clk);
            cpu_dmem_addr = address;
            cpu_dmem_data_out = data;
            cpu_dmem_we = 1'b1;
            cpu_dmem_sel = 4'b1111;
            cpu_dmem_req = 1'b1;
            @(posedge clk);
            wait(cpu_dmem_ack);
            cpu_dmem_req = 1'b0;
            @(posedge clk);
        end
    endtask

    // 初始化外部Flash内容
    // task init_external_flash;
    //     integer i;
    //     begin
    //         for (i = 0; i < 1048576; i = i + 4) begin
    //             external_flash[i]   = i[7:0];
    //             external_flash[i+1] = (i+1)[7:0];
    //             external_flash[i+2] = (i+2)[7:0];
    //             external_flash[i+3] = (i+3)[7:0];
    //         end
    //     end
    // endtask

    // 模拟外部Flash行为
    reg [7:0] spi_bit_counter;
    reg [7:0] spi_byte_counter;
    reg [31:0] current_flash_addr;
    reg [2:0] spi_mode;

    always @(negedge flash_clk or negedge rst_n) begin
        if (!rst_n) begin
            flash_miso <= 1'b0;
            flash_dq_i <= 4'h0;
            spi_bit_counter <= 8'h0;
            spi_byte_counter <= 8'h0;
            current_flash_addr <= 32'h0;
            spi_mode <= 2'b00;
        end else if (!flash_cs_n) begin
            // SPI通信进行中
            if (spi_bit_counter < 8) begin
                spi_bit_counter <= spi_bit_counter + 1;

                // 模拟Flash响应（简化）
                if (spi_byte_counter >= 4) begin  // 命令和地址发送完成后
                    if (spi_mode == 2'b00) begin  // SPI模式
                        flash_miso <= external_flash[current_flash_addr][7 - spi_bit_counter[2:0]];
                    end else if (spi_mode == 2'b10) begin  // QSPI模式
                        flash_dq_i <= external_flash[current_flash_addr + spi_byte_counter - 4];
                    end
                end
            end else begin
                spi_bit_counter <= 8'h0;
                spi_byte_counter <= spi_byte_counter + 1;

                if (spi_byte_counter == 0) begin
                    // 第一个字节是命令
                    if (flash_mosi == 1'b0) begin  // 读命令
                        spi_mode <= 2'b00;
                    end
                end else if (spi_byte_counter >= 1 && spi_byte_counter <= 3) begin
                    // 地址字节
                    current_flash_addr <= {current_flash_addr[23:0], flash_mosi};
                end
            end
        end else begin
            spi_bit_counter <= 8'h0;
            spi_byte_counter <= 8'h0;
        end
    end

    initial begin
        // 初始化
        clk = 0;
        rst_n = 0;
        cpu_imem_addr = 32'h0;
        cpu_imem_req = 1'b0;
        cpu_dmem_addr = 32'h0;
        cpu_dmem_data_out = 32'h0;
        cpu_dmem_we = 1'b0;
        cpu_dmem_sel = 4'h0;
        cpu_dmem_req = 1'b0;
        flash_miso = 1'b0;
        flash_dq_i = 4'h0;

        // 创建VCD文件
        $dumpfile("external_flash_cache.vcd");
        $dumpvars(0, tb_external_flash_cache);

        // 初始化外部Flash内容
        /* TODO */
        // init_external_flash;

        // 复位
        #20;
        rst_n = 1;

        $display("=== 外部Flash缓存系统测试开始 ===");

        // 测试1: 外部Flash读取测试（L2缓存未命中）
        $display("测试1: 外部Flash读取测试");
        read_instruction(32'h00010000);
        $display("读取地址 0x00010000: 数据=0x%h", cpu_imem_data);

        // 测试2: 缓存命中测试
        $display("测试2: 缓存命中测试");
        read_instruction(32'h00010000);  // 应该命中L2缓存
        read_instruction(32'h00010004);  // 应该命中L2缓存

        // 测试3: 外部Flash写入测试
        $display("测试3: 外部Flash写入测试");
        write_data(32'h00020000, 32'h12345678);

        // 测试4: 混合访问测试
        $display("测试4: 混合访问测试");
        read_instruction(32'h00030000);
        write_data(32'h00040000, 32'hdeadbeef);
        read_data(32'h00020000);

        // 显示性能统计
        $display("=== 性能统计 ===");
        $display("L1指令缓存: 命中=%d, 未命中=%d, 命中率=%.1f%%",
                perf_icache_hits, perf_icache_misses,
                (perf_icache_hits * 100.0) / (perf_icache_hits + perf_icache_misses));

        $display("L1数据缓存: 命中=%d, 未命中=%d, 命中率=%.1f%%",
                perf_dcache_hits, perf_dcache_misses,
                (perf_dcache_hits * 100.0) / (perf_dcache_hits + perf_dcache_misses));

        $display("L2缓存: 命中=%d, 未命中=%d, 命中率=%.1f%%",
                perf_l2cache_hits, perf_l2cache_misses,
                (perf_l2cache_hits * 100.0) / (perf_l2cache_hits + perf_l2cache_misses));

        $display("Flash操作: 读取=%d, 写入=%d", perf_flash_reads, perf_flash_writes);

        $display("=== 测试完成 ===");
        $finish;
    end

    // 监控系统行为
    always @(posedge clk) begin
        if (cpu_imem_ack) begin
            $display("时间: %t - 指令读取: 地址=0x%h, 数据=0x%h, 缓存状态=%d",
                    $time, cpu_imem_addr, cpu_imem_data, cache_state);
        end

        if (cpu_dmem_ack) begin
            if (cpu_dmem_we) begin
                $display("时间: %t - 数据写入: 地址=0x%h, 数据=0x%h, 缓存状态=%d",
                        $time, cpu_dmem_addr, cpu_dmem_data_out, cache_state);
            end else begin
                $display("时间: %t - 数据读取: 地址=0x%h, 数据=0x%h, 缓存状态=%d",
                        $time, cpu_dmem_addr, cpu_dmem_data_in, cache_state);
            end
        end

        if (!flash_cs_n) begin
            $display("时间: %t - Flash通信: CS_N=0, CLK=%d, MOSI=%d, 状态=%d",
                    $time, flash_clk, flash_mosi, flash_state);
        end
    end

endmodule
